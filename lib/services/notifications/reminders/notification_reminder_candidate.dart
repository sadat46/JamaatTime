class NotificationReminderCandidate {
  const NotificationReminderCandidate({
    required this.prayerKey,
    required this.id,
    required this.scheduledTime,
  });

  final String prayerKey;
  final int id;
  final DateTime scheduledTime;
}
