import 'package:home_widget/home_widget.dart';
import 'dart:developer' as developer;

class WidgetService {
  static const String _widgetName = 'PrayerWidgetProvider';

  static Future<void> updatePrayerWidget({
    required String currentPrayerName,
    required String currentPrayerTime,
    required String remainingLabel,
    required String remainingTime,
    required String fajrTime,
    required String asrTime,
    required String maghribTime,
    required String ishaTime,
    required String islamicDate,
    required String location,
  }) async {
    try {
      developer.log('WidgetService: Updating widget with data...', name: 'WidgetService');
      developer.log('WidgetService: prayer_name = $currentPrayerName', name: 'WidgetService');
      developer.log('WidgetService: prayer_time = $currentPrayerTime', name: 'WidgetService');
      
      await HomeWidget.saveWidgetData<String>('prayer_name', currentPrayerName);
      await HomeWidget.saveWidgetData<String>('prayer_time', currentPrayerTime);
      await HomeWidget.saveWidgetData<String>('remaining_label', remainingLabel);
      await HomeWidget.saveWidgetData<String>('remaining_time', remainingTime);
      await HomeWidget.saveWidgetData<String>('fajr_time', fajrTime);
      await HomeWidget.saveWidgetData<String>('asr_time', asrTime);
      await HomeWidget.saveWidgetData<String>('maghrib_time', maghribTime);
      await HomeWidget.saveWidgetData<String>('isha_time', ishaTime);
      await HomeWidget.saveWidgetData<String>('islamic_date', islamicDate);
      await HomeWidget.saveWidgetData<String>('location', location);
      
      developer.log('WidgetService: Data saved, updating widget...', name: 'WidgetService');
      await HomeWidget.updateWidget(
        name: _widgetName,
        iOSName: 'PrayerWidget',
        androidName: 'com.example.jamaat_time.$_widgetName',
      );
      developer.log('WidgetService: Widget update completed', name: 'WidgetService');
    } catch (e) {
      developer.log('WidgetService: Error updating widget: $e', name: 'WidgetService');
    }
  }

  static Future<void> testWidgetData() async {
    try {
      developer.log('WidgetService: Testing widget data...', name: 'WidgetService');
      await HomeWidget.saveWidgetData<String>('prayer_name', 'Test Prayer');
      await HomeWidget.saveWidgetData<String>('prayer_time', '12:00 PM');
      await HomeWidget.saveWidgetData<String>('remaining_label', 'Test Label');
      await HomeWidget.saveWidgetData<String>('remaining_time', '2 hours');
      await HomeWidget.saveWidgetData<String>('fajr_time', '5:00 AM');
      await HomeWidget.saveWidgetData<String>('asr_time', '4:00 PM');
      await HomeWidget.saveWidgetData<String>('maghrib_time', '6:00 PM');
      await HomeWidget.saveWidgetData<String>('isha_time', '8:00 PM');
      await HomeWidget.saveWidgetData<String>('islamic_date', 'Test Date');
      await HomeWidget.saveWidgetData<String>('location', 'Test Location');
      
      await HomeWidget.updateWidget(
        name: _widgetName,
        iOSName: 'PrayerWidget',
        androidName: 'com.example.jamaat_time.$_widgetName',
      );
      developer.log('WidgetService: Test data saved and widget updated', name: 'WidgetService');
    } catch (e) {
      developer.log('WidgetService: Error in test: $e', name: 'WidgetService');
    }
  }
} 