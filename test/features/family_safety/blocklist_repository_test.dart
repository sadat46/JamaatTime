import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/features/family_safety/data/blocklist_repository.dart';
import 'package:jamaat_time/features/family_safety/domain/block_category.dart';

void main() {
  test('loads category blocklists from assets and caches the result', () async {
    final bundle = _MemoryAssetBundle({
      'adult.txt': '''
# comment
Example.COM
0.0.0.0 hosts-format.example
''',
      'gambling.txt': 'bet.example\n',
      'proxy.txt': 'dns.google\n',
    });
    final repository = BlocklistRepository(
      assetBundle: bundle,
      blocklistAssets: const {
        BlockCategory.adult: 'adult.txt',
        BlockCategory.gambling: 'gambling.txt',
        BlockCategory.proxyBypass: 'proxy.txt',
      },
    );

    final firstLoad = await repository.loadBlocklists();
    final secondLoad = await repository.loadBlocklists();

    expect(identical(firstLoad, secondLoad), isTrue);
    expect(bundle.loadCounts['adult.txt'], 1);
    expect(firstLoad.domainCount, 4);
    expect(
      firstLoad.blockedByCategory[BlockCategory.adult],
      containsAll({'example.com', 'hosts-format.example'}),
    );

    final matcher = await repository.loadMatcher(
      whitelistedDomains: {'safe.example.com'},
    );
    expect(matcher.isBlocked('sub.example.com'), isTrue);
    expect(matcher.isBlocked('safe.example.com'), isFalse);
    expect(matcher.match('shop.bet.example')?.category, BlockCategory.gambling);
    expect(matcher.match('dns.google')?.category, BlockCategory.proxyBypass);
  });
}

class _MemoryAssetBundle extends CachingAssetBundle {
  _MemoryAssetBundle(this.assets);

  final Map<String, String> assets;
  final Map<String, int> loadCounts = <String, int>{};

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) {
      throw StateError('Missing test asset: $key');
    }
    loadCounts[key] = (loadCounts[key] ?? 0) + 1;
    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.view(bytes.buffer);
  }
}
