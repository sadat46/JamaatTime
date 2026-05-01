package com.sadat.jamaattime.familysafety.vpn

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

class FamilySafetyVpnService : VpnService() {

    companion object {
        const val ACTION_STOP = "com.sadat.jamaattime.familysafety.action.STOP"
        private const val VIRTUAL_DNS = "10.0.0.1"
        private const val LOCAL_ADDRESS = "10.0.0.2"
        private const val UPSTREAM_DNS = "1.1.1.1"
        private const val UPSTREAM_PORT = 53
        private const val MTU = 1500
    }

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

        val descriptor = try {
            Builder()
                .addAddress(LOCAL_ADDRESS, 32)
                .addDnsServer(VIRTUAL_DNS)
                .addRoute("0.0.0.0", 0)
                .setMtu(MTU)
                .setBlocking(true)
                .setSession("Jamaat Time – Website Protection")
                .establish()
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
                writeSafely(output, packet, read)
                continue
            }

            when (parsed) {
                is DnsPacketParser.Parsed.Udp -> {
                    if (parsed.dstPort != 53) {
                        writeSafely(output, packet, read)
                        continue
                    }
                    val query = try {
                        DnsPacketParser.parseDnsQuery(parsed)
                    } catch (_: Throwable) {
                        writeSafely(output, packet, read)
                        continue
                    }
                    if (query == null) {
                        writeSafely(output, packet, read)
                        continue
                    }
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
                DnsPacketParser.Parsed.Other -> writeSafely(output, packet, read)
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

        val socket = DatagramSocket()
        try {
            if (!protect(socket)) {
                writeSafely(output, udp.packet, udp.length)
                return
            }
            socket.soTimeout = 5_000
            val outPacket = DatagramPacket(
                dnsPayload,
                dnsPayload.size,
                InetAddress.getByName(UPSTREAM_DNS),
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

    private fun writeSafely(output: FileOutputStream, packet: ByteArray, length: Int) {
        try {
            output.write(packet, 0, length)
            output.flush()
        } catch (_: Exception) {
            // ignore
        }
    }
}
