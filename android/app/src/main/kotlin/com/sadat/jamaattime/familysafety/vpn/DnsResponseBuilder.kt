package com.sadat.jamaattime.familysafety.vpn

internal object DnsResponseBuilder {

    fun buildNxDomain(udp: DnsPacketParser.Parsed.Udp, query: DnsPacketParser.DnsQuery): ByteArray {
        val ipHeaderLength = udp.ipHeaderLength
        val dnsLength = 12 + query.questionLength
        val udpLength = 8 + dnsLength
        val totalLength = ipHeaderLength + udpLength
        val response = ByteArray(totalLength)

        // ---- IP header ----
        if (udp.ipVersion == 4) {
            buildIpv4Header(udp, response, totalLength)
        } else {
            buildIpv6Header(udp, response, udpLength)
        }

        // ---- UDP header ----
        val udpStart = ipHeaderLength
        // src port = original dst (53), dst port = original src
        val origSrc = udp.srcPort
        val origDst = udp.dstPort
        response[udpStart] = (origDst ushr 8).toByte()
        response[udpStart + 1] = origDst.toByte()
        response[udpStart + 2] = (origSrc ushr 8).toByte()
        response[udpStart + 3] = origSrc.toByte()
        response[udpStart + 4] = (udpLength ushr 8).toByte()
        response[udpStart + 5] = udpLength.toByte()
        response[udpStart + 6] = 0
        response[udpStart + 7] = 0 // checksum 0 = optional for IPv4; we recompute for v6 below

        // ---- DNS payload ----
        val dnsStart = udpStart + 8
        // Transaction ID
        response[dnsStart] = (query.transactionId ushr 8).toByte()
        response[dnsStart + 1] = query.transactionId.toByte()
        // Flags: QR=1, OPCODE=0, AA=0, TC=0, RD=copy from query, RA=1, Z=0, RCODE=3 (NXDOMAIN)
        val rd = query.flags and 0x0100
        val flags = 0x8000 or rd or 0x0080 or 0x0003
        response[dnsStart + 2] = (flags ushr 8).toByte()
        response[dnsStart + 3] = flags.toByte()
        // QDCOUNT=1, ANCOUNT=0, NSCOUNT=0, ARCOUNT=0
        response[dnsStart + 4] = 0; response[dnsStart + 5] = 1
        response[dnsStart + 6] = 0; response[dnsStart + 7] = 0
        response[dnsStart + 8] = 0; response[dnsStart + 9] = 0
        response[dnsStart + 10] = 0; response[dnsStart + 11] = 0

        // Echo question section verbatim
        val questionSrc = udp.payloadOffset + query.questionStart
        System.arraycopy(udp.packet, questionSrc, response, dnsStart + 12, query.questionLength)

        // ---- Checksums ----
        if (udp.ipVersion == 4) {
            recomputeIpv4Checksum(response, ipHeaderLength)
        } else {
            recomputeUdpChecksumV6(response, ipHeaderLength, udpLength)
        }
        return response
    }

    private fun buildIpv4Header(udp: DnsPacketParser.Parsed.Udp, out: ByteArray, totalLength: Int) {
        val src = udp.packet
        // Version + IHL
        out[0] = ((4 shl 4) or 5).toByte()
        out[1] = 0 // ToS
        out[2] = (totalLength ushr 8).toByte()
        out[3] = totalLength.toByte()
        out[4] = 0; out[5] = 0 // identification
        out[6] = 0x40.toByte(); out[7] = 0 // DF, no fragment
        out[8] = 64 // TTL
        out[9] = 17 // UDP
        out[10] = 0; out[11] = 0 // checksum (computed later)
        // Swap source/destination IPs
        for (i in 0 until 4) {
            out[12 + i] = src[16 + i] // new src = old dst
            out[16 + i] = src[12 + i] // new dst = old src
        }
    }

    private fun buildIpv6Header(udp: DnsPacketParser.Parsed.Udp, out: ByteArray, udpLength: Int) {
        val src = udp.packet
        out[0] = (6 shl 4).toByte()
        out[1] = 0; out[2] = 0; out[3] = 0
        out[4] = (udpLength ushr 8).toByte()
        out[5] = udpLength.toByte()
        out[6] = 17 // next header = UDP
        out[7] = 64 // hop limit
        for (i in 0 until 16) {
            out[8 + i] = src[24 + i]  // src = old dst
            out[24 + i] = src[8 + i]  // dst = old src
        }
    }

    private fun recomputeIpv4Checksum(packet: ByteArray, headerLen: Int) {
        var sum = 0
        var i = 0
        while (i < headerLen) {
            val word = ((packet[i].toInt() and 0xff) shl 8) or (packet[i + 1].toInt() and 0xff)
            sum += word
            i += 2
        }
        while ((sum ushr 16) != 0) {
            sum = (sum and 0xffff) + (sum ushr 16)
        }
        val checksum = sum.inv() and 0xffff
        packet[10] = (checksum ushr 8).toByte()
        packet[11] = checksum.toByte()
    }

    private fun recomputeUdpChecksumV6(packet: ByteArray, ipHeaderLength: Int, udpLength: Int) {
        var sum = 0
        // Pseudo-header: src(16) + dst(16) + length(4) + zeros(3) + nextHeader(1)
        for (i in 0 until 32) {
            val word = if (i % 2 == 0) {
                ((packet[8 + i].toInt() and 0xff) shl 8)
            } else {
                packet[8 + i].toInt() and 0xff
            }
            if (i % 2 == 1) sum += word
        }
        // Re-do that loop correctly:
        sum = 0
        var idx = 8
        while (idx < 8 + 32) {
            val word = ((packet[idx].toInt() and 0xff) shl 8) or (packet[idx + 1].toInt() and 0xff)
            sum += word
            idx += 2
        }
        sum += udpLength
        sum += 17

        // UDP datagram
        val udpStart = ipHeaderLength
        var i = 0
        while (i < udpLength - 1) {
            val word = ((packet[udpStart + i].toInt() and 0xff) shl 8) or (packet[udpStart + i + 1].toInt() and 0xff)
            sum += word
            i += 2
        }
        if (i < udpLength) {
            sum += (packet[udpStart + i].toInt() and 0xff) shl 8
        }
        while ((sum ushr 16) != 0) {
            sum = (sum and 0xffff) + (sum ushr 16)
        }
        var checksum = sum.inv() and 0xffff
        if (checksum == 0) checksum = 0xffff
        packet[udpStart + 6] = (checksum ushr 8).toByte()
        packet[udpStart + 7] = checksum.toByte()
    }
}
