import 'domain_normalizer.dart';

class DomainBlockMatcher {
  DomainBlockMatcher({
    Set<String> blockedDomains = const <String>{},
    Set<String> whitelistedDomains = const <String>{},
  }) : _blockedDomains = blockedDomains.map(DomainNormalizer.normalize).toSet(),
       _whitelistedDomains = whitelistedDomains
           .map(DomainNormalizer.normalize)
           .toSet();

  final Set<String> _blockedDomains;
  final Set<String> _whitelistedDomains;

  bool isBlocked(String domain) {
    final normalized = DomainNormalizer.normalize(domain);
    if (_matchesAny(normalized, _whitelistedDomains)) {
      return false;
    }
    return _matchesAny(normalized, _blockedDomains);
  }

  bool _matchesAny(String domain, Set<String> candidates) {
    for (final candidate in candidates) {
      if (domain == candidate || domain.endsWith('.$candidate')) {
        return true;
      }
    }
    return false;
  }
}
