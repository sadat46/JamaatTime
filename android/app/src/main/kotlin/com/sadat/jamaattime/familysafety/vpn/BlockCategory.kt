package com.sadat.jamaattime.familysafety.vpn

enum class BlockCategory(val id: Int, val assetPath: String) {
    ADULT(1, "flutter_assets/assets/family_safety/blocklists/adult_2026_05_seed.txt"),
    GAMBLING(2, "flutter_assets/assets/family_safety/blocklists/gambling_2026_05_seed.txt"),
    PROXY_BYPASS(3, "flutter_assets/assets/family_safety/blocklists/proxy_bypass_2026_05_seed.txt");

    companion object {
        fun fromId(id: Int): BlockCategory? = values().firstOrNull { it.id == id }
    }
}
