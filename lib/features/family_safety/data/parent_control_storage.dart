import 'package:shared_preferences/shared_preferences.dart';

class ParentControlStorage {
  static const String pinHashKey = 'family_safety_pin_hash';

  Future<bool> hasPinHash() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(pinHashKey);
    return value != null && value.isNotEmpty;
  }
}
