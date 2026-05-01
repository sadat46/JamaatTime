import 'package:flutter/services.dart';

import '../domain/block_category.dart';
import '../domain/domain_block_matcher.dart';
import '../domain/domain_normalizer.dart';

class BlocklistBundle {
  const BlocklistBundle({required this.blockedByCategory});

  final Map<BlockCategory, Set<String>> blockedByCategory;

  int get domainCount {
    return blockedByCategory.values.fold<int>(
      0,
      (count, domains) => count + domains.length,
    );
  }

  DomainBlockMatcher toMatcher({
    Set<String> whitelistedDomains = const <String>{},
  }) {
    return DomainBlockMatcher.fromCategoryDomains(
      blockedByCategory: blockedByCategory,
      whitelistedDomains: whitelistedDomains,
    );
  }
}

class BlocklistRepository {
  BlocklistRepository({
    AssetBundle? assetBundle,
    Map<BlockCategory, String> blocklistAssets = defaultBlocklistAssets,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _blocklistAssets = blocklistAssets;

  static const Map<BlockCategory, String> defaultBlocklistAssets =
      <BlockCategory, String>{
        BlockCategory.adult:
            'assets/family_safety/blocklists/adult_2026_05_seed.txt',
        BlockCategory.gambling:
            'assets/family_safety/blocklists/gambling_2026_05_seed.txt',
        BlockCategory.proxyBypass:
            'assets/family_safety/blocklists/proxy_bypass_2026_05_seed.txt',
      };

  final AssetBundle _assetBundle;
  final Map<BlockCategory, String> _blocklistAssets;
  Future<BlocklistBundle>? _cachedBundle;

  Future<BlocklistBundle> loadBlocklists() {
    return _cachedBundle ??= _loadBlocklists();
  }

  Future<DomainBlockMatcher> loadMatcher({
    Set<String> whitelistedDomains = const <String>{},
  }) async {
    final bundle = await loadBlocklists();
    return bundle.toMatcher(whitelistedDomains: whitelistedDomains);
  }

  Future<BlocklistBundle> _loadBlocklists() async {
    final blockedByCategory = <BlockCategory, Set<String>>{};
    for (final entry in _blocklistAssets.entries) {
      final raw = await _assetBundle.loadString(entry.value);
      blockedByCategory[entry.key] = _parseDomainList(raw);
    }
    return BlocklistBundle(blockedByCategory: blockedByCategory);
  }

  Set<String> _parseDomainList(String raw) {
    final domains = <String>{};
    for (final line in raw.split('\n')) {
      final parsed = _parseLine(line);
      if (parsed != null) {
        domains.add(parsed);
      }
    }
    return domains;
  }

  String? _parseLine(String line) {
    var value = line.trim();
    if (value.isEmpty || value.startsWith('#')) {
      return null;
    }

    final commentIndex = value.indexOf('#');
    if (commentIndex >= 0) {
      value = value.substring(0, commentIndex).trim();
    }
    if (value.isEmpty) {
      return null;
    }

    final parts = value.split(RegExp(r'\s+'));
    final candidate =
        parts.length > 1 && DomainNormalizer.isIpLiteral(parts.first)
        ? parts[1]
        : parts.first;
    final normalized = DomainNormalizer.normalize(candidate);
    return normalized.isEmpty ? null : normalized;
  }
}
