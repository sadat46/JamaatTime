import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'family_safety_storage.dart';

class ParentPinStatus {
  const ParentPinStatus({
    required this.hasPin,
    required this.wrongAttempts,
    this.lockedUntil,
  });

  final bool hasPin;
  final int wrongAttempts;
  final DateTime? lockedUntil;

  bool get isLocked {
    final until = lockedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  Duration? get remainingLockout {
    final until = lockedUntil;
    if (until == null) {
      return null;
    }
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

class ParentPinVerificationResult {
  const ParentPinVerificationResult._({
    required this.verified,
    required this.wrongAttempts,
    this.lockedUntil,
  });

  factory ParentPinVerificationResult.verified() {
    return const ParentPinVerificationResult._(
      verified: true,
      wrongAttempts: 0,
    );
  }

  factory ParentPinVerificationResult.failed({
    required int wrongAttempts,
    DateTime? lockedUntil,
  }) {
    return ParentPinVerificationResult._(
      verified: false,
      wrongAttempts: wrongAttempts,
      lockedUntil: lockedUntil,
    );
  }

  final bool verified;
  final int wrongAttempts;
  final DateTime? lockedUntil;

  bool get isLocked {
    final until = lockedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  Duration? get remainingLockout {
    final until = lockedUntil;
    if (until == null) {
      return null;
    }
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

class ParentControlStorage {
  ParentControlStorage({
    FlutterSecureStorage? secureStorage,
    FamilySafetyStorage? familySafetyStorage,
    DateTime Function()? now,
  }) : _secureStorage = secureStorage ?? _defaultSecureStorage,
       _familySafetyStorage = familySafetyStorage ?? FamilySafetyStorage(),
       _now = now ?? DateTime.now;

  static const String pinHashKey = 'family_safety_pin_hash';
  static const String pinMetaKey = 'family_safety_pin_meta';

  static const int _saltLength = 16;
  static const int _hashLength = 32;
  static const int _pbkdf2Iterations = 120000;

  static const FlutterSecureStorage _defaultSecureStorage =
      FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  final FlutterSecureStorage _secureStorage;
  final FamilySafetyStorage _familySafetyStorage;
  final DateTime Function() _now;

  Future<bool> hasPinHash() async {
    final value = await _secureStorage.read(key: pinHashKey);
    return value != null && value.isNotEmpty;
  }

  Future<ParentPinStatus> loadStatus() async {
    final hasPin = await hasPinHash();
    final meta = await _readMeta();
    return ParentPinStatus(
      hasPin: hasPin,
      wrongAttempts: meta.wrongAttempts,
      lockedUntil: meta.lockedUntil,
    );
  }

  Future<void> setPin(String pin) async {
    final salt = _randomSalt();
    final hash = await _deriveHash(pin, salt);
    final record = Uint8List(_saltLength + _hashLength)
      ..setRange(0, _saltLength, salt)
      ..setRange(_saltLength, _saltLength + _hashLength, hash);

    await _secureStorage.write(key: pinHashKey, value: base64Encode(record));
    await _writeMeta(const _PinMeta());
  }

  Future<ParentPinVerificationResult> verifyPin(String pin) async {
    final storedRecord = await _readStoredRecord();
    if (storedRecord == null) {
      return ParentPinVerificationResult.failed(wrongAttempts: 0);
    }

    final meta = await _readMeta();
    final lockedUntil = meta.lockedUntil;
    if (lockedUntil != null && lockedUntil.isAfter(_now())) {
      return ParentPinVerificationResult.failed(
        wrongAttempts: meta.wrongAttempts,
        lockedUntil: lockedUntil,
      );
    }

    final salt = storedRecord.sublist(0, _saltLength);
    final storedHash = storedRecord.sublist(_saltLength);
    final submittedHash = await _deriveHash(pin, salt);

    if (_constantTimeEquals(storedHash, submittedHash)) {
      await _writeMeta(const _PinMeta());
      return ParentPinVerificationResult.verified();
    }

    final wrongAttempts = meta.wrongAttempts + 1;
    final nextLockedUntil = _lockoutUntilFor(wrongAttempts);
    await _writeMeta(
      _PinMeta(wrongAttempts: wrongAttempts, lockedUntil: nextLockedUntil),
    );
    return ParentPinVerificationResult.failed(
      wrongAttempts: wrongAttempts,
      lockedUntil: nextLockedUntil,
    );
  }

  Future<void> clearPin() async {
    await _secureStorage.delete(key: pinHashKey);
    await _secureStorage.delete(key: pinMetaKey);
  }

  Future<void> resetPinAndDisableWebsiteProtection() async {
    await clearPin();
    final settings = await _familySafetyStorage.loadWebsiteProtectionSettings();
    if (settings.enabled) {
      await _familySafetyStorage.saveWebsiteProtectionSettings(
        settings.copyWith(enabled: false),
      );
    }
  }

  DateTime? _lockoutUntilFor(int wrongAttempts) {
    if (wrongAttempts >= 20) {
      return _now().add(const Duration(hours: 1));
    }
    if (wrongAttempts >= 10) {
      return _now().add(const Duration(minutes: 5));
    }
    if (wrongAttempts >= 5) {
      return _now().add(const Duration(seconds: 60));
    }
    return null;
  }

  Future<_PinMeta> _readMeta() async {
    final raw = await _secureStorage.read(key: pinMetaKey);
    if (raw == null || raw.isEmpty) {
      return const _PinMeta();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        return const _PinMeta();
      }
      return _PinMeta.fromJson(decoded);
    } on FormatException {
      return const _PinMeta();
    }
  }

  Future<void> _writeMeta(_PinMeta meta) async {
    await _secureStorage.write(key: pinMetaKey, value: jsonEncode(meta));
  }

  Future<Uint8List?> _readStoredRecord() async {
    final raw = await _secureStorage.read(key: pinHashKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = base64Decode(raw);
      if (decoded.length != _saltLength + _hashLength) {
        return null;
      }
      return Uint8List.fromList(decoded);
    } on FormatException {
      return null;
    }
  }

  Uint8List _randomSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_saltLength, (_) => random.nextInt(256)),
    );
  }

  Future<Uint8List> _deriveHash(String pin, List<int> salt) {
    return Isolate.run(
      () => _pbkdf2HmacSha256(
        utf8.encode(pin),
        salt,
        _pbkdf2Iterations,
        _hashLength,
      ),
    );
  }
}

class _PinMeta {
  const _PinMeta({this.wrongAttempts = 0, this.lockedUntil});

  factory _PinMeta.fromJson(Map<String, Object?> json) {
    final wrongAttempts = json['wrongAttempts'];
    final lockedUntilMs = json['lockedUntilMs'];
    return _PinMeta(
      wrongAttempts: wrongAttempts is int ? max(0, wrongAttempts) : 0,
      lockedUntil: lockedUntilMs is int
          ? DateTime.fromMillisecondsSinceEpoch(lockedUntilMs)
          : null,
    );
  }

  final int wrongAttempts;
  final DateTime? lockedUntil;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'wrongAttempts': wrongAttempts,
      'lockedUntilMs': lockedUntil?.millisecondsSinceEpoch,
    };
  }
}

Uint8List _pbkdf2HmacSha256(
  List<int> password,
  List<int> salt,
  int iterations,
  int length,
) {
  final hmac = Hmac(sha256, password);
  final digestLength = sha256.convert(const <int>[]).bytes.length;
  final blockCount = (length / digestLength).ceil();
  final output = BytesBuilder(copy: false);

  for (var blockIndex = 1; blockIndex <= blockCount; blockIndex++) {
    var block = Uint8List.fromList(
      hmac.convert(<int>[
        ...salt,
        (blockIndex >> 24) & 0xff,
        (blockIndex >> 16) & 0xff,
        (blockIndex >> 8) & 0xff,
        blockIndex & 0xff,
      ]).bytes,
    );
    var previous = block;

    for (var iteration = 1; iteration < iterations; iteration++) {
      previous = Uint8List.fromList(hmac.convert(previous).bytes);
      for (var i = 0; i < block.length; i++) {
        block[i] ^= previous[i];
      }
    }

    output.add(block);
  }

  return Uint8List.sublistView(output.toBytes(), 0, length);
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }

  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
