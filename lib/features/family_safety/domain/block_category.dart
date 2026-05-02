enum BlockCategory {
  adult(1),
  gambling(2),
  proxyBypass(3),
  focusGuardShortVideo(4);

  const BlockCategory(this.id);

  final int id;

  bool get isWebsiteProtectionCategory {
    return switch (this) {
      BlockCategory.adult ||
      BlockCategory.gambling ||
      BlockCategory.proxyBypass => true,
      BlockCategory.focusGuardShortVideo => false,
    };
  }
}

const Set<BlockCategory> websiteProtectionBlockCategories = <BlockCategory>{
  BlockCategory.adult,
  BlockCategory.gambling,
  BlockCategory.proxyBypass,
};
