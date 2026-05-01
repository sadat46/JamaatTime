package com.sadat.jamaattime.familysafety.vpn

import android.content.Context
import java.io.BufferedReader
import java.io.InputStreamReader

internal object BlocklistLoader {

    fun load(context: Context): DomainBlockMatcher {
        val blockedByCategory = mutableMapOf<BlockCategory, MutableSet<String>>()
        for (category in BlockCategory.values()) {
            val domains = readAsset(context, category.assetPath)
            blockedByCategory[category] = domains
        }
        return DomainBlockMatcher.fromCategoryDomains(blockedByCategory)
    }

    private fun readAsset(context: Context, path: String): MutableSet<String> {
        val domains = mutableSetOf<String>()
        try {
            context.assets.open(path).use { stream ->
                BufferedReader(InputStreamReader(stream)).use { reader ->
                    var line = reader.readLine()
                    while (line != null) {
                        parseLine(line)?.let(domains::add)
                        line = reader.readLine()
                    }
                }
            }
        } catch (_: Exception) {
            // Asset missing or unreadable: leave category empty rather than crash service.
        }
        return domains
    }

    private fun parseLine(raw: String): String? {
        var value = raw.trim()
        if (value.isEmpty() || value.startsWith("#")) return null

        val commentIndex = value.indexOf('#')
        if (commentIndex >= 0) value = value.substring(0, commentIndex).trim()
        if (value.isEmpty()) return null

        val parts = value.split(Regex("\\s+"))
        val candidate = if (parts.size > 1 && DomainNormalizer.isIpLiteral(parts[0])) {
            parts[1]
        } else {
            parts[0]
        }
        val normalized = DomainNormalizer.normalize(candidate)
        return normalized.ifEmpty { null }
    }
}
