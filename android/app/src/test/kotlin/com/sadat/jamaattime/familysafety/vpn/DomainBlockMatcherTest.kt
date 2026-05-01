package com.sadat.jamaattime.familysafety.vpn

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DomainBlockMatcherTest {

    private fun matcher(
        adult: Set<String> = emptySet(),
        gambling: Set<String> = emptySet(),
        proxy: Set<String> = emptySet(),
        whitelist: Set<String> = emptySet(),
    ): DomainBlockMatcher {
        return DomainBlockMatcher.fromCategoryDomains(
            blockedByCategory = mapOf(
                BlockCategory.ADULT to adult,
                BlockCategory.GAMBLING to gambling,
                BlockCategory.PROXY_BYPASS to proxy,
            ),
            whitelistedDomains = whitelist,
        )
    }

    @Test fun caseInsensitive_blocksMixedCase() {
        val m = matcher(adult = setOf("Example.COM"))
        assertTrue(m.isBlocked("EXAMPLE.com"))
    }

    @Test fun stripsLeadingWww_butNotWww3() {
        val m = matcher(adult = setOf("example.com"))
        assertTrue(m.isBlocked("www.example.com"))
        // www3.example.com is a subdomain — must be matched via suffix rule
        assertTrue(m.isBlocked("www3.example.com"))
    }

    @Test fun www3_doesNotMatchAsRoot() {
        val m = matcher(adult = setOf("www3.example.com"))
        // The blocklist entry "www3.example.com" must NOT have its www3 stripped.
        // Searching for "example.com" should not match it.
        assertNull(m.match("example.com"))
        // It should still match its own subdomain.
        assertTrue(m.isBlocked("a.www3.example.com"))
        assertTrue(m.isBlocked("www3.example.com"))
    }

    @Test fun labelBoundarySuffix_doesNotMatchInfix() {
        val m = matcher(adult = setOf("example.com"))
        assertFalse(m.isBlocked("badexample.com"))
        assertFalse(m.isBlocked("example.com.attacker.tld"))
        assertTrue(m.isBlocked("sub.example.com"))
    }

    @Test fun rootDomain_doesNotMatchShorterSuffix() {
        val m = matcher(adult = setOf("ample.com"))
        assertFalse(m.isBlocked("example.com"))
    }

    @Test fun whitelistOverridesBlock() {
        val m = matcher(
            adult = setOf("example.com"),
            whitelist = setOf("safe.example.com"),
        )
        assertTrue(m.isBlocked("ads.example.com"))
        assertNull(m.match("safe.example.com"))
        assertNull(m.match("a.safe.example.com"))
    }

    @Test fun idnPunycode_normalizedToAce() {
        val m = matcher(adult = setOf("xn--mnchen-3ya.de"))
        assertTrue(m.isBlocked("münchen.de"))
        assertTrue(m.isBlocked("a.münchen.de"))
    }

    @Test fun ipv4Literal_exactMatchOnly() {
        val m = matcher(proxy = setOf("203.0.113.7"))
        assertTrue(m.isBlocked("203.0.113.7"))
        // Strict exact: subnet siblings must not match.
        assertFalse(m.isBlocked("203.0.113.8"))
        // Suffix-style matching must not apply to IPs.
        assertFalse(m.isBlocked("a.203.0.113.7"))
    }

    @Test fun deepSubdomain_matchesViaLabelBoundary() {
        val m = matcher(gambling = setOf("bet.example"))
        assertTrue(m.isBlocked("a.b.c.bet.example"))
    }

    @Test fun matchedCategory_reportsCorrectBucket() {
        val m = matcher(
            adult = setOf("a.test"),
            gambling = setOf("g.test"),
            proxy = setOf("p.test"),
        )
        assertEquals(BlockCategory.ADULT, m.match("a.test")?.category)
        assertEquals(BlockCategory.GAMBLING, m.match("sub.g.test")?.category)
        assertEquals(BlockCategory.PROXY_BYPASS, m.match("p.test")?.category)
        assertNull(m.match("u.test"))
    }

    @Test fun stripsScheme_path_port_userinfo() {
        val m = matcher(adult = setOf("example.com"))
        assertNotNull(m.match("https://user:pw@www.Example.com:8443/path?q=1#x"))
    }
}
