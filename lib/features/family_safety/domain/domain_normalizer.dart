class DomainNormalizer {
  const DomainNormalizer._();

  static final RegExp _ipv4Pattern = RegExp(
    r'^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.'
    r'(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.'
    r'(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.'
    r'(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$',
  );
  static final RegExp _ipv6Pattern = RegExp(r'^[0-9a-f:]+$');

  static String normalize(String input) {
    var value = input.trim().toLowerCase();
    if (value.isEmpty) {
      return '';
    }

    final schemeIndex = value.indexOf('://');
    if (schemeIndex >= 0) {
      value = value.substring(schemeIndex + 3);
    } else if (value.startsWith('//')) {
      value = value.substring(2);
    }

    final stopIndex = _firstStopIndex(value);
    if (stopIndex >= 0) {
      value = value.substring(0, stopIndex);
    }

    final atIndex = value.lastIndexOf('@');
    if (atIndex >= 0) {
      value = value.substring(atIndex + 1);
    }

    if (value.startsWith('[')) {
      final closeBracket = value.indexOf(']');
      if (closeBracket > 0) {
        value = value.substring(1, closeBracket);
      }
    } else if (_singleColonIndex(value) case final portIndex?) {
      value = value.substring(0, portIndex);
    }

    while (value.endsWith('.')) {
      value = value.substring(0, value.length - 1);
    }

    if (value.startsWith('www.')) {
      value = value.substring(4);
    }

    if (value.isEmpty || isIpLiteral(value)) {
      return value;
    }

    return value
        .split('.')
        .where((label) => label.isNotEmpty)
        .map(_toAceLabel)
        .join('.');
  }

  static bool isIpLiteral(String normalizedDomain) {
    return _ipv4Pattern.hasMatch(normalizedDomain) ||
        (normalizedDomain.contains(':') &&
            _ipv6Pattern.hasMatch(normalizedDomain));
  }

  static int _firstStopIndex(String value) {
    final indexes = <int>[
      value.indexOf('/'),
      value.indexOf('?'),
      value.indexOf('#'),
    ].where((index) => index >= 0);
    if (indexes.isEmpty) {
      return -1;
    }
    return indexes.reduce((a, b) => a < b ? a : b);
  }

  static int? _singleColonIndex(String value) {
    final firstColon = value.indexOf(':');
    if (firstColon < 0) {
      return null;
    }
    return value.indexOf(':', firstColon + 1) < 0 ? firstColon : null;
  }

  static String _toAceLabel(String label) {
    if (label.codeUnits.every((unit) => unit < 0x80)) {
      return label;
    }
    return 'xn--${_punycodeEncode(label)}';
  }

  static String _punycodeEncode(String input) {
    const base = 36;
    const tMin = 1;
    const tMax = 26;
    const skew = 38;
    const damp = 700;
    const initialBias = 72;
    const initialN = 128;

    final codePoints = input.runes.toList(growable: false);
    final output = StringBuffer();

    var basicCount = 0;
    for (final codePoint in codePoints) {
      if (codePoint < 0x80) {
        output.writeCharCode(codePoint);
        basicCount++;
      }
    }

    var handledCount = basicCount;
    if (basicCount > 0) {
      output.write('-');
    }

    var n = initialN;
    var delta = 0;
    var bias = initialBias;

    while (handledCount < codePoints.length) {
      var nextCodePoint = 0x10ffff;
      for (final codePoint in codePoints) {
        if (codePoint >= n && codePoint < nextCodePoint) {
          nextCodePoint = codePoint;
        }
      }

      delta += (nextCodePoint - n) * (handledCount + 1);
      n = nextCodePoint;

      for (final codePoint in codePoints) {
        if (codePoint < n) {
          delta++;
        }
        if (codePoint == n) {
          var q = delta;
          for (var k = base; ; k += base) {
            final t = k <= bias
                ? tMin
                : k >= bias + tMax
                ? tMax
                : k - bias;
            if (q < t) {
              break;
            }
            output.writeCharCode(_encodeDigit(t + ((q - t) % (base - t))));
            q = (q - t) ~/ (base - t);
          }
          output.writeCharCode(_encodeDigit(q));
          bias = _adaptBias(
            delta,
            handledCount + 1,
            handledCount == basicCount,
            damp,
            skew,
            base,
            tMin,
            tMax,
          );
          delta = 0;
          handledCount++;
        }
      }

      delta++;
      n++;
    }

    return output.toString();
  }

  static int _adaptBias(
    int delta,
    int numPoints,
    bool firstTime,
    int damp,
    int skew,
    int base,
    int tMin,
    int tMax,
  ) {
    var adjustedDelta = firstTime ? delta ~/ damp : delta ~/ 2;
    adjustedDelta += adjustedDelta ~/ numPoints;

    var k = 0;
    while (adjustedDelta > ((base - tMin) * tMax) ~/ 2) {
      adjustedDelta ~/= base - tMin;
      k += base;
    }

    return k + (((base - tMin + 1) * adjustedDelta) ~/ (adjustedDelta + skew));
  }

  static int _encodeDigit(int digit) {
    return digit < 26 ? 0x61 + digit : 0x30 + digit - 26;
  }
}
