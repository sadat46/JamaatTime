/// Extension to get date part only
extension DateTimeExtension on DateTime {
  DateTime toDate() {
    return DateTime(year, month, day);
  }
} 