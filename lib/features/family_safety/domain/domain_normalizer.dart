class DomainNormalizer {
  const DomainNormalizer._();

  static String normalize(String input) {
    var value = input.trim().toLowerCase();
    final schemeIndex = value.indexOf('://');
    if (schemeIndex >= 0) {
      value = value.substring(schemeIndex + 3);
    }
    final slashIndex = value.indexOf('/');
    if (slashIndex >= 0) {
      value = value.substring(0, slashIndex);
    }
    final colonIndex = value.indexOf(':');
    if (colonIndex >= 0 && !value.contains(']')) {
      value = value.substring(0, colonIndex);
    }
    if (value.startsWith('www.')) {
      value = value.substring(4);
    }
    return value;
  }
}
