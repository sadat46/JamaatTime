package com.sadat.jamaattime.familysafety.vpn

import java.nio.ByteBuffer
import java.nio.ByteOrder

internal object DnsPacketParser {

    sealed class Parsed {
        data class Udp(
            val packet: ByteArray,
            val length: Int,
            val ipVersion: Int,
            val ipHeaderLength: Int,
            val srcPort: Int,
            val dstPort: Int,
            val payloadOffset: Int,
            val payloadLength: Int,
        ) : Parsed()

        object Other : Parsed()
    }

    data class DnsQuery(
        val transactionId: Int,
        val flags: Int,
        val qname: String,
        val qtype: Int,
        val qclass: Int,
        val questionStart: Int,
        val questionLength: Int,
    )

    fun parse(packet: ByteArray, length: Int): Parsed {
        if (length < 20) return Parsed.Other
        val versionByte = packet[0].toInt() and 0xff
        val version = (versionByte ushr 4) and 0xf
        return when (version) {
            4 -> parseV4(packet, length)
            6 -> parseV6(packet, length)
            else -> Parsed.Other
        }
    }

    private fun parseV4(packet: ByteArray, length: Int): Parsed {
        if (length < 20) return Parsed.Other
        val ihl = (packet[0].toInt() and 0x0f) * 4
        if (ihl < 20 || ihl > length) return Parsed.Other
        val protocol = packet[9].toInt() and 0xff
        if (protocol != 17) return Parsed.Other // UDP only

        val totalLength = ((packet[2].toInt() and 0xff) shl 8) or (packet[3].toInt() and 0xff)
        if (totalLength > length) return Parsed.Other

        val udpStart = ihl
        if (udpStart + 8 > length) return Parsed.Other
        val srcPort = ((packet[udpStart].toInt() and 0xff) shl 8) or (packet[udpStart + 1].toInt() and 0xff)
        val dstPort = ((packet[udpStart + 2].toInt() and 0xff) shl 8) or (packet[udpStart + 3].toInt() and 0xff)
        val udpLength = ((packet[udpStart + 4].toInt() and 0xff) shl 8) or (packet[udpStart + 5].toInt() and 0xff)

        val payloadOffset = udpStart + 8
        val payloadLength = (udpLength - 8).coerceAtLeast(0).coerceAtMost(length - payloadOffset)

        return Parsed.Udp(
            packet = packet,
            length = length,
            ipVersion = 4,
            ipHeaderLength = ihl,
            srcPort = srcPort,
            dstPort = dstPort,
            payloadOffset = payloadOffset,
            payloadLength = payloadLength,
        )
    }

    private fun parseV6(packet: ByteArray, length: Int): Parsed {
        if (length < 40) return Parsed.Other
        val nextHeader = packet[6].toInt() and 0xff
        if (nextHeader != 17) return Parsed.Other

        val udpStart = 40
        if (udpStart + 8 > length) return Parsed.Other
        val srcPort = ((packet[udpStart].toInt() and 0xff) shl 8) or (packet[udpStart + 1].toInt() and 0xff)
        val dstPort = ((packet[udpStart + 2].toInt() and 0xff) shl 8) or (packet[udpStart + 3].toInt() and 0xff)
        val udpLength = ((packet[udpStart + 4].toInt() and 0xff) shl 8) or (packet[udpStart + 5].toInt() and 0xff)

        val payloadOffset = udpStart + 8
        val payloadLength = (udpLength - 8).coerceAtLeast(0).coerceAtMost(length - payloadOffset)

        return Parsed.Udp(
            packet = packet,
            length = length,
            ipVersion = 6,
            ipHeaderLength = 40,
            srcPort = srcPort,
            dstPort = dstPort,
            payloadOffset = payloadOffset,
            payloadLength = payloadLength,
        )
    }

    fun parseDnsQuery(udp: Parsed.Udp): DnsQuery? {
        if (udp.payloadLength < 12) return null
        val payload = ByteBuffer.wrap(udp.packet, udp.payloadOffset, udp.payloadLength)
            .order(ByteOrder.BIG_ENDIAN)
        val transactionId = payload.short.toInt() and 0xffff
        val flags = payload.short.toInt() and 0xffff
        val qdcount = payload.short.toInt() and 0xffff
        // ancount, nscount, arcount
        payload.short
        payload.short
        payload.short
        if (qdcount != 1) return null
        if ((flags and 0x8000) != 0) return null // response, not a query

        val nameStart = 12
        val name = StringBuilder()
        var cursor = nameStart
        var safety = 0
        while (cursor < udp.payloadLength) {
            if (safety++ > 128) return null
            val len = udp.packet[udp.payloadOffset + cursor].toInt() and 0xff
            if (len == 0) {
                cursor++
                break
            }
            if ((len and 0xc0) != 0) return null // pointer compression in question is unusual
            cursor++
            if (cursor + len > udp.payloadLength) return null
            if (name.isNotEmpty()) name.append('.')
            for (i in 0 until len) {
                val b = udp.packet[udp.payloadOffset + cursor + i].toInt() and 0xff
                name.append(b.toChar())
            }
            cursor += len
        }
        if (cursor + 4 > udp.payloadLength) return null
        val qtype = ((udp.packet[udp.payloadOffset + cursor].toInt() and 0xff) shl 8) or
            (udp.packet[udp.payloadOffset + cursor + 1].toInt() and 0xff)
        val qclass = ((udp.packet[udp.payloadOffset + cursor + 2].toInt() and 0xff) shl 8) or
            (udp.packet[udp.payloadOffset + cursor + 3].toInt() and 0xff)
        val questionLength = (cursor + 4) - nameStart

        return DnsQuery(
            transactionId = transactionId,
            flags = flags,
            qname = name.toString().lowercase(),
            qtype = qtype,
            qclass = qclass,
            questionStart = nameStart,
            questionLength = questionLength,
        )
    }
}
