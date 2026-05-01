package com.sadat.jamaattime.familysafety.vpn

import java.net.IDN

internal object DomainNormalizer {

    private val ipv4Regex = Regex(
        "^(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)\\." +
            "(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)\\." +
            "(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)\\." +
            "(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)$"
    )
    private val ipv6Regex = Regex("^[0-9a-f:]+$")

    fun normalize(input: String): String {
        var value = input.trim().lowercase()
        if (value.isEmpty()) return ""

        val schemeIndex = value.indexOf("://")
        if (schemeIndex >= 0) {
            value = value.substring(schemeIndex + 3)
        } else if (value.startsWith("//")) {
            value = value.substring(2)
        }

        val stopIndex = firstStopIndex(value)
        if (stopIndex >= 0) value = value.substring(0, stopIndex)

        val atIndex = value.lastIndexOf('@')
        if (atIndex >= 0) value = value.substring(atIndex + 1)

        if (value.startsWith("[")) {
            val close = value.indexOf(']')
            if (close > 0) value = value.substring(1, close)
        } else {
            val singleColon = singleColonIndex(value)
            if (singleColon != null) value = value.substring(0, singleColon)
        }

        while (value.endsWith(".")) value = value.dropLast(1)

        if (value.startsWith("www.")) value = value.substring(4)

        if (value.isEmpty() || isIpLiteral(value)) return value

        return value.split('.')
            .filter { it.isNotEmpty() }
            .joinToString(".") { toAceLabel(it) }
    }

    fun isIpLiteral(normalized: String): Boolean {
        return ipv4Regex.matches(normalized) ||
            (normalized.contains(':') && ipv6Regex.matches(normalized))
    }

    private fun firstStopIndex(value: String): Int {
        val candidates = listOf(
            value.indexOf('/'),
            value.indexOf('?'),
            value.indexOf('#'),
        ).filter { it >= 0 }
        return candidates.minOrNull() ?: -1
    }

    private fun singleColonIndex(value: String): Int? {
        val first = value.indexOf(':')
        if (first < 0) return null
        return if (value.indexOf(':', first + 1) < 0) first else null
    }

    private fun toAceLabel(label: String): String {
        if (label.all { it.code < 0x80 }) return label
        return try {
            IDN.toASCII(label, IDN.ALLOW_UNASSIGNED).lowercase()
        } catch (_: IllegalArgumentException) {
            label
        }
    }
}
