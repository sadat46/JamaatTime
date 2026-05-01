import '../domain/domain_block_matcher.dart';

class BlocklistRepository {
  const BlocklistRepository();

  Future<DomainBlockMatcher> loadMatcher() async {
    return DomainBlockMatcher();
  }
}
