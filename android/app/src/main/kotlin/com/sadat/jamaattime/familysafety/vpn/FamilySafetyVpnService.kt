package com.sadat.jamaattime.familysafety.vpn

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.Inet4Address
import java.net.InetAddress
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

class FamilySafetyVpnService : VpnService() {

    companion object {
        const val ACTION_STOP = "com.sadat.jamaattime.familysafety.action.STOP"
        private const val LOCAL_ADDRESS = "10.0.0.2"
        private const val UPSTREAM_PORT = 53
        private const val MTU = 1500

        // Public fallback resolvers if the active network has no usable DNS server.
        // We route DNS targeted at these IPs through our tun and forward upstream from there.
        private val FALLBACK_DNS = listOf("1.1.1.1", "1.0.0.1", "8.8.8.8", "8.8.4.4")
    }

    private var routedDnsServers: List<String> = emptyList()

    private var tunInterface: ParcelFileDescriptor? = null
    private val running = AtomicBoolean(false)
    private var worker: Thread? = null
    private val statusRepo by lazy { VpnStatusRepository(applicationContext) }
    private val activityWriter by lazy { ActivitySummaryWriter(applicationContext) }

    @Volatile private var matcher: DomainBlockMatcher? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopFiltering()
            stopSelf(startId)
            return START_NOT_STICKY
        }

        if (running.get()) {
            return START_STICKY
        }

        try {
            startForeground(VpnNotificationHelper.NOTIFICATION_ID, VpnNotificationHelper.build(applicationContext))
        } catch (e: Exception) {
            statusRepo.markError("foreground_failed")
            stopSelf(startId)
            return START_NOT_STICKY
        }

        matcher = try {
            BlocklistLoader.load(applicationContext)
        } catch (_: Exception) {
            DomainBlockMatcher.fromCategoryDomains(emptyMap())
        }

        // Discover the DNS resolvers currently used by the underlying network and route
        // them through our tun. We deliberately do NOT call addDnsServer(): registering a
        // virtual DNS would cause Android (when Private DNS is in strict/hostname mode) to
        // probe DoT against it, fail, and then drop ALL DNS on the network — which surfaces
        // as "Network has no internet access" + "Private DNS – Couldn't connect."
        //
        // By transparently intercepting traffic destined to the existing resolvers, we
        // filter system DNS queries without changing the network's DNS configuration.
        // Apps that use Private DNS DoT bypass us (documented limitation in the privacy
        // page); apps that use plain UDP/53 to the system resolvers get filtered.
        val systemDns = activeNetworkDnsServers().ifEmpty { FALLBACK_DNS }
        routedDnsServers = systemDns

        val descriptor = try {
            val builder = Builder()
                .addAddress(LOCAL_ADDRESS, 32)
                .setMtu(MTU)
                .setBlocking(true)
                .setSession("Jamaat Time – Website Protection")
            for (ip in systemDns) {
                builder.addRoute(ip, 32)
            }
            // Exclude our own app from the VPN so our protected upstream sockets cannot
            // be looped back through the tun on devices where protect() has surprises.
            try {
                builder.addDisallowedApplication(applicationContext.packageName)
            } catch (_: Exception) {
            }
            builder.establish()
        } catch (e: Exception) {
            statusRepo.markError("establish_failed")
            stopSelf(startId)
            return START_NOT_STICKY
        }

        if (descriptor == null) {
            statusRepo.markError("establish_null")
            stopSelf(startId)
            return START_NOT_STICKY
        }

        tunInterface = descriptor
        running.set(true)
        statusRepo.markRunning()

        worker = thread(name = "FamilySafetyVpn", isDaemon = true) {
            try {
                runFilterLoop(descriptor)
            } catch (e: OutOfMemoryError) {
                statusRepo.markError("oom")
            } catch (_: Throwable) {
                statusRepo.markError("loop_crash")
            } finally {
                running.set(false)
            }
        }

        return START_STICKY
    }

    override fun onRevoke() {
        stopFiltering()
        stopSelf()
        super.onRevoke()
    }

    override fun onDestroy() {
        stopFiltering()
        super.onDestroy()
    }

    private fun stopFiltering() {
        if (!running.compareAndSet(true, false) && tunInterface == null) {
            statusRepo.markStopped()
            return
        }
        try {
            tunInterface?.close()
        } catch (_: Exception) {
        }
        tunInterface = null
        worker = null
        statusRepo.markStopped()
    }

    private fun runFilterLoop(descriptor: ParcelFileDescriptor) {
        val input = FileInputStream(descriptor.fileDescriptor)
        val output = FileOutputStream(descriptor.fileDescriptor)
        val buffer = ByteArray(32767)
        val activeMatcher = matcher ?: DomainBlockMatcher.fromCategoryDomains(emptyMap())

        while (running.get()) {
            val read = try {
                input.read(buffer)
            } catch (_: Exception) {
                if (!running.get()) break else continue
            }
            if (read <= 0) {
                if (!running.get()) break else continue
            }

            val packet = buffer.copyOf(read)
            val parsed = try {
                DnsPacketParser.parse(packet, read)
            } catch (_: Throwable) {
                // Malformed packet on a tun that should only carry UDP/53 to our virtual DNS — drop.
                continue
            }

            when (parsed) {
                is DnsPacketParser.Parsed.Udp -> {
                    if (parsed.dstPort != 53) continue
                    val query = try {
                        DnsPacketParser.parseDnsQuery(parsed)
                    } catch (_: Throwable) {
                        continue
                    }
                    if (query == null) continue
                    val match = try {
                        activeMatcher.match(query.qname)
                    } catch (_: Throwable) {
                        null
                    }
                    if (match != null && match.category != null) {
                        try {
                            val response = DnsResponseBuilder.buildNxDomain(parsed, query)
                            output.write(response)
                            output.flush()
                            activityWriter.increment(match.category)
                        } catch (_: Throwable) {
                            // Drop on error; do not crash service.
                        }
                    } else {
                        forwardDnsQuery(parsed, query, output)
                    }
                }
                DnsPacketParser.Parsed.Other -> {
                    // Only UDP/53 to the virtual DNS should ever reach this tun.
                    // Anything else (TCP/53, ICMP probes, IPv6 ND noise) gets dropped here.
                }
            }
        }
    }

    private fun forwardDnsQuery(
        udp: DnsPacketParser.Parsed.Udp,
        query: DnsPacketParser.DnsQuery,
        output: FileOutputStream,
    ) {
        val dnsPayload = ByteArray(udp.payloadLength)
        System.arraycopy(udp.packet, udp.payloadOffset, dnsPayload, 0, udp.payloadLength)

        // Forward to the resolver the client was originally talking to (e.g. the
        // network's DNS server), so the filter is transparent to whichever resolver
        // each app chose. The protected socket bypasses our VPN, so the upstream query
        // travels via the underlying network and does not loop.
        val upstream = try {
            extractOriginalDestination(udp)
        } catch (_: Throwable) {
            null
        } ?: return

        val socket = DatagramSocket()
        try {
            if (!protect(socket)) {
                return
            }
            socket.soTimeout = 5_000
            val outPacket = DatagramPacket(
                dnsPayload,
                dnsPayload.size,
                upstream,
                UPSTREAM_PORT,
            )
            socket.send(outPacket)

            val buf = ByteArray(2048)
            val reply = DatagramPacket(buf, buf.size)
            socket.receive(reply)

            val response = buildResponseEnvelope(udp, buf, reply.length)
            output.write(response)
            output.flush()
        } catch (_: Throwable) {
            // Upstream timeout / error: silently drop. Client will retry.
        } finally {
            try { socket.close() } catch (_: Exception) {}
        }
    }

    private fun buildResponseEnvelope(
        udp: DnsPacketParser.Parsed.Udp,
        dnsPayload: ByteArray,
        dnsLength: Int,
    ): ByteArray {
        val ipHeaderLength = udp.ipHeaderLength
        val udpLength = 8 + dnsLength
        val totalLength = ipHeaderLength + udpLength
        val out = ByteArray(totalLength)

        if (udp.ipVersion == 4) {
            out[0] = ((4 shl 4) or 5).toByte()
            out[1] = 0
            out[2] = (totalLength ushr 8).toByte()
            out[3] = totalLength.toByte()
            out[4] = 0; out[5] = 0
            out[6] = 0x40.toByte(); out[7] = 0
            out[8] = 64
            out[9] = 17
            out[10] = 0; out[11] = 0
            for (i in 0 until 4) {
                out[12 + i] = udp.packet[16 + i]
                out[16 + i] = udp.packet[12 + i]
            }
            // checksum
            var sum = 0
            var i = 0
            while (i < ipHeaderLength) {
                sum += ((out[i].toInt() and 0xff) shl 8) or (out[i + 1].toInt() and 0xff)
                i += 2
            }
            while ((sum ushr 16) != 0) sum = (sum and 0xffff) + (sum ushr 16)
            val cksum = sum.inv() and 0xffff
            out[10] = (cksum ushr 8).toByte()
            out[11] = cksum.toByte()
        } else {
            out[0] = (6 shl 4).toByte()
            out[4] = (udpLength ushr 8).toByte()
            out[5] = udpLength.toByte()
            out[6] = 17
            out[7] = 64
            for (i in 0 until 16) {
                out[8 + i] = udp.packet[24 + i]
                out[24 + i] = udp.packet[8 + i]
            }
        }

        val udpStart = ipHeaderLength
        out[udpStart] = (udp.dstPort ushr 8).toByte()
        out[udpStart + 1] = udp.dstPort.toByte()
        out[udpStart + 2] = (udp.srcPort ushr 8).toByte()
        out[udpStart + 3] = udp.srcPort.toByte()
        out[udpStart + 4] = (udpLength ushr 8).toByte()
        out[udpStart + 5] = udpLength.toByte()
        out[udpStart + 6] = 0
        out[udpStart + 7] = 0

        System.arraycopy(dnsPayload, 0, out, udpStart + 8, dnsLength)
        return out
    }

    private fun extractOriginalDestination(udp: DnsPacketParser.Parsed.Udp): InetAddress? {
        return if (udp.ipVersion == 4) {
            val bytes = ByteArray(4)
            System.arraycopy(udp.packet, 16, bytes, 0, 4)
            InetAddress.getByAddress(bytes)
        } else {
            val bytes = ByteArray(16)
            System.arraycopy(udp.packet, 24, bytes, 0, 16)
            InetAddress.getByAddress(bytes)
        }
    }

    private fun activeNetworkDnsServers(): List<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return emptyList()
        val cm = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE)
            as? ConnectivityManager ?: return emptyList()
        val active = cm.activeNetwork ?: return emptyList()
        val link = cm.getLinkProperties(active) ?: return emptyList()
        return link.dnsServers
            .filterIsInstance<Inet4Address>()
            .mapNotNull { it.hostAddress }
            .filter { it.isNotEmpty() }
    }
}
