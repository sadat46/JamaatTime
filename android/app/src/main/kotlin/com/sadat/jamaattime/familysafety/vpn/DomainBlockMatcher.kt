package com.sadat.jamaattime.familysafety.vpn

data class DomainBlockMatch(
    val normalizedDomain: String,
    val matchedDomain: String,
    val category: BlockCategory?,
)

class DomainBlockMatcher private constructor(
    private val blockedExact: Map<String, BlockCategory?>,
    private val blockedSuffix: List<BlockRule>,
    private val whitelistExact: Set<String>,
    private val whitelistSuffix: List<String>,
) {
    fun isBlocked(domain: String): Boolean = match(domain) != null

    fun match(domain: String): DomainBlockMatch? {
        val normalized = DomainNormalizer.normalize(domain)
        if (normalized.isEmpty() || isWhitelisted(normalized)) return null

        blockedExact[normalized]?.let { category ->
            return DomainBlockMatch(normalized, normalized, category)
        }

        if (DomainNormalizer.isIpLiteral(normalized)) return null

        for (rule in blockedSuffix) {
            if (matchesLabelBoundarySuffix(normalized, rule.domain)) {
                return DomainBlockMatch(normalized, rule.domain, rule.category)
            }
        }
        return null
    }

    private fun isWhitelisted(domain: String): Boolean {
        if (whitelistExact.contains(domain)) return true
        if (DomainNormalizer.isIpLiteral(domain)) return false
        for (candidate in whitelistSuffix) {
            if (matchesLabelBoundarySuffix(domain, candidate)) return true
        }
        return false
    }

    private fun matchesLabelBoundarySuffix(domain: String, candidate: String): Boolean {
        return domain != candidate && domain.endsWith(".$candidate")
    }

    data class BlockRule(val domain: String, val category: BlockCategory?)

    companion object {
        fun fromCategoryDomains(
            blockedByCategory: Map<BlockCategory, Set<String>>,
            whitelistedDomains: Set<String> = emptySet(),
        ): DomainBlockMatcher {
            val blockedExact = mutableMapOf<String, BlockCategory?>()
            val blockedSuffix = mutableListOf<BlockRule>()
            for ((category, domains) in blockedByCategory) {
                for (raw in domains) {
                    val normalized = DomainNormalizer.normalize(raw)
                    if (normalized.isEmpty()) continue
                    blockedExact.putIfAbsent(normalized, category)
                    if (!DomainNormalizer.isIpLiteral(normalized)) {
                        blockedSuffix.add(BlockRule(normalized, category))
                    }
                }
            }
            val whitelistExact = mutableSetOf<String>()
            val whitelistSuffix = mutableListOf<String>()
            for (raw in whitelistedDomains) {
                val normalized = DomainNormalizer.normalize(raw)
                if (normalized.isEmpty()) continue
                whitelistExact.add(normalized)
                if (!DomainNormalizer.isIpLiteral(normalized)) {
                    whitelistSuffix.add(normalized)
                }
            }
            blockedSuffix.sortByDescending { it.domain.length }
            whitelistSuffix.sortByDescending { it.length }
            return DomainBlockMatcher(
                blockedExact = blockedExact,
                blockedSuffix = blockedSuffix,
                whitelistExact = whitelistExact,
                whitelistSuffix = whitelistSuffix,
            )
        }
    }
}
