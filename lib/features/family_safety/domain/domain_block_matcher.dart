import 'block_category.dart';
import 'domain_normalizer.dart';

class DomainBlockMatch {
  const DomainBlockMatch({
    required this.normalizedDomain,
    required this.matchedDomain,
    this.category,
  });

  final String normalizedDomain;
  final String matchedDomain;
  final BlockCategory? category;
}

class DomainBlockMatcher {
  factory DomainBlockMatcher({
    Set<String> blockedDomains = const <String>{},
    Set<String> whitelistedDomains = const <String>{},
  }) {
    return DomainBlockMatcher._(
      blockedRules: blockedDomains.map(
        (domain) => _BlockRule(DomainNormalizer.normalize(domain)),
      ),
      whitelistedDomains: whitelistedDomains,
    );
  }

  factory DomainBlockMatcher.fromCategoryDomains({
    required Map<BlockCategory, Set<String>> blockedByCategory,
    Set<String> whitelistedDomains = const <String>{},
  }) {
    return DomainBlockMatcher._(
      blockedRules: blockedByCategory.entries.expand(
        (entry) => entry.value.map(
          (domain) => _BlockRule(
            DomainNormalizer.normalize(domain),
            category: entry.key,
          ),
        ),
      ),
      whitelistedDomains: whitelistedDomains,
    );
  }

  DomainBlockMatcher._({
    required Iterable<_BlockRule> blockedRules,
    required Set<String> whitelistedDomains,
  }) {
    for (final rule in blockedRules) {
      if (rule.domain.isEmpty) {
        continue;
      }
      _blockedExactDomains.putIfAbsent(rule.domain, () => rule.category);
      if (!DomainNormalizer.isIpLiteral(rule.domain)) {
        _blockedSuffixRules.add(rule);
      }
    }

    for (final domain in whitelistedDomains.map(DomainNormalizer.normalize)) {
      if (domain.isEmpty) {
        continue;
      }
      _whitelistedExactDomains.add(domain);
      if (!DomainNormalizer.isIpLiteral(domain)) {
        _whitelistedSuffixDomains.add(domain);
      }
    }

    _blockedSuffixRules.sort(
      (a, b) => b.domain.length.compareTo(a.domain.length),
    );
    _whitelistedSuffixDomains.sort((a, b) => b.length.compareTo(a.length));
  }

  final Map<String, BlockCategory?> _blockedExactDomains =
      <String, BlockCategory?>{};
  final List<_BlockRule> _blockedSuffixRules = <_BlockRule>[];
  final Set<String> _whitelistedExactDomains = <String>{};
  final List<String> _whitelistedSuffixDomains = <String>[];

  bool isBlocked(String domain) => match(domain) != null;

  DomainBlockMatch? match(String domain) {
    final normalized = DomainNormalizer.normalize(domain);
    if (normalized.isEmpty || _isWhitelisted(normalized)) {
      return null;
    }

    if (_blockedExactDomains.containsKey(normalized)) {
      return DomainBlockMatch(
        normalizedDomain: normalized,
        matchedDomain: normalized,
        category: _blockedExactDomains[normalized],
      );
    }

    if (DomainNormalizer.isIpLiteral(normalized)) {
      return null;
    }

    for (final rule in _blockedSuffixRules) {
      if (_matchesLabelBoundarySuffix(normalized, rule.domain)) {
        return DomainBlockMatch(
          normalizedDomain: normalized,
          matchedDomain: rule.domain,
          category: rule.category,
        );
      }
    }

    return null;
  }

  bool _isWhitelisted(String domain) {
    if (_whitelistedExactDomains.contains(domain)) {
      return true;
    }
    if (DomainNormalizer.isIpLiteral(domain)) {
      return false;
    }
    for (final candidate in _whitelistedSuffixDomains) {
      if (_matchesLabelBoundarySuffix(domain, candidate)) {
        return true;
      }
    }
    return false;
  }

  bool _matchesLabelBoundarySuffix(String domain, String candidate) {
    return domain != candidate && domain.endsWith('.$candidate');
  }
}

class _BlockRule {
  const _BlockRule(this.domain, {this.category});

  final String domain;
  final BlockCategory? category;
}
