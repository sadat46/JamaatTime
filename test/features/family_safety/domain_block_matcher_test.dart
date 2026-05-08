import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/features/family_safety/domain/block_category.dart';
import 'package:jamaat_time/features/family_safety/domain/domain_block_matcher.dart';
import 'package:jamaat_time/features/family_safety/domain/domain_normalizer.dart';

void main() {
  group('DomainNormalizer', () {
    test('lowercases and strips schemes, paths, query strings, and ports', () {
      expect(
        DomainNormalizer.normalize(' HTTPS://WWW.Example.COM:443/a?b=1 '),
        'example.com',
      );
    });

    test('strips leading www only, not other www prefixes', () {
      expect(DomainNormalizer.normalize('www.example.com'), 'example.com');
      expect(
        DomainNormalizer.normalize('www3.example.com'),
        'www3.example.com',
      );
      expect(DomainNormalizer.normalize('www-example.com'), 'www-example.com');
    });

    test('converts IDN labels to ACE form', () {
      expect(
        DomainNormalizer.normalize('b\u00FCcher.example'),
        'xn--bcher-kva.example',
      );
    });
  });

  group('DomainBlockMatcher', () {
    test('matches case-insensitively on label-boundary suffixes', () {
      final matcher = DomainBlockMatcher(blockedDomains: {'Example.COM'});

      expect(matcher.isBlocked('example.com'), isTrue);
      expect(matcher.isBlocked('Sub.Example.Com'), isTrue);
      expect(matcher.isBlocked('badexample.com'), isFalse);
      expect(matcher.isBlocked('example.com.evil.test'), isFalse);
    });

    test('blocks subdomain depth of at least three labels', () {
      final matcher = DomainBlockMatcher(blockedDomains: {'example.com'});

      expect(matcher.isBlocked('a.b.c.example.com'), isTrue);
    });

    test('whitelist always wins over blocked parent domains', () {
      final matcher = DomainBlockMatcher(
        blockedDomains: {'example.com'},
        whitelistedDomains: {'safe.example.com'},
      );

      expect(matcher.isBlocked('safe.example.com'), isFalse);
      expect(matcher.isBlocked('deep.safe.example.com'), isFalse);
      expect(matcher.isBlocked('unsafe.example.com'), isTrue);
    });

    test('matches IDN input against ACE blocklist entries', () {
      final matcher = DomainBlockMatcher(
        blockedDomains: {'xn--bcher-kva.example'},
      );

      expect(matcher.isBlocked('www.b\u00FCcher.example'), isTrue);
      expect(matcher.isBlocked('shop.b\u00FCcher.example'), isTrue);
    });

    test('matches IPv4 literals exactly only', () {
      final matcher = DomainBlockMatcher(blockedDomains: {'192.0.2.10'});

      expect(matcher.isBlocked('192.0.2.10'), isTrue);
      expect(matcher.isBlocked('sub.192.0.2.10'), isFalse);
      expect(matcher.isBlocked('192.0.2.100'), isFalse);
    });

    test('returns the matched category for category-backed lists', () {
      final matcher = DomainBlockMatcher.fromCategoryDomains(
        blockedByCategory: {
          BlockCategory.gambling: {'bet.example'},
          BlockCategory.proxyBypass: {'dns.example'},
        },
      );

      expect(
        matcher.match('sports.bet.example')?.category,
        BlockCategory.gambling,
      );
      expect(matcher.match('dns.example')?.category, BlockCategory.proxyBypass);
    });
  });
}
