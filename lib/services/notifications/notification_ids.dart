class NotificationIds {
  NotificationIds._();

  static const Map<String, int> prayerEndReminders = {
    'Fajr': 1101,
    'Dhuhr': 1102,
    'Asr': 1103,
    'Maghrib': 1104,
    'Isha': 1105,
  };

  static const Map<String, int> prayerEndRemindersTomorrow = {
    'Fajr': 1201,
    'Dhuhr': 1202,
    'Asr': 1203,
    'Maghrib': 1204,
    'Isha': 1205,
  };

  static const Map<String, int> jamaatReminders = {
    'Fajr': 2101,
    'Dhuhr': 2102,
    'Asr': 2103,
    'Maghrib': 2104,
    'Isha': 2105,
  };

  static const Map<String, int> jamaatRemindersTomorrow = {
    'Fajr': 2201,
    'Dhuhr': 2202,
    'Asr': 2203,
    'Maghrib': 2204,
    'Isha': 2205,
  };

  static const int fajrVoice = 3101;
  static const int fajrVoiceTomorrow = 3102;

  // FCM broadcast notices share a single dynamic range, offset well clear of
  // the reminder ranges above (max 3102). The local id is derived
  // deterministically from the server notifId so a later data-only "tombstone"
  // push can cancel the exact notification it produced.
  static const int _broadcastBase = 4000000;

  static int broadcast(String notifId) {
    return _broadcastBase + (notifId.hashCode & 0x7FFFFF);
  }
}
