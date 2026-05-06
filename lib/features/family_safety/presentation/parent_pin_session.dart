/// In-memory unlock cache for the Parent Control PIN.
///
/// Once verified, the PIN gate stays satisfied for [_ttl] so the user can
/// navigate between Family Safety sub-pages and toggle protections without
/// being re-prompted constantly. Cleared on app pause and on hub disposal.
class ParentPinSession {
  ParentPinSession._();

  static const Duration _ttl = Duration(minutes: 5);

  static DateTime? _unlockedUntil;

  static bool isUnlocked() {
    final until = _unlockedUntil;
    if (until == null) {
      return false;
    }
    if (until.isAfter(DateTime.now())) {
      return true;
    }
    _unlockedUntil = null;
    return false;
  }

  static void markUnlocked() {
    _unlockedUntil = DateTime.now().add(_ttl);
  }

  static void clear() {
    _unlockedUntil = null;
  }
}
