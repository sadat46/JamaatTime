class AppVersion {
  static const Set<int> _flutterSplitAbiPrefixes = {1, 2, 3, 4};

  /// Flutter split-per-ABI APKs encode Android versionCode as:
  /// ABI prefix * 1000 + pubspec build number.
  static String publicBuildNumber(String buildNumber) {
    final value = int.tryParse(buildNumber.trim());
    if (value == null) return buildNumber;

    final abiPrefix = value ~/ 1000;
    final publicBuild = value % 1000;
    if (_flutterSplitAbiPrefixes.contains(abiPrefix)) {
      return publicBuild.toString();
    }

    return value.toString();
  }

  static String label({required String version, required String buildNumber}) {
    return 'v $version (${publicBuildNumber(buildNumber)})';
  }
}
