import 'package:flutter/material.dart';

class DebugActionsBar extends StatelessWidget {
  final VoidCallback onTestNotification;
  final VoidCallback onRescheduleNotifications;
  final VoidCallback onCheckPendingNotifications;
  final VoidCallback onScheduleTestJamaatNotification;

  const DebugActionsBar({
    super.key,
    required this.onTestNotification,
    required this.onRescheduleNotifications,
    required this.onCheckPendingNotifications,
    required this.onScheduleTestJamaatNotification,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: onTestNotification,
          tooltip: 'Test Notification',
        ),
        IconButton(
          icon: const Icon(Icons.schedule),
          onPressed: onRescheduleNotifications,
          tooltip: 'Reschedule Notifications',
        ),
        IconButton(
          icon: const Icon(Icons.notifications_active),
          onPressed: onCheckPendingNotifications,
          tooltip: 'Check Pending Notifications',
        ),
        IconButton(
          icon: const Icon(Icons.schedule_send),
          onPressed: onScheduleTestJamaatNotification,
          tooltip: 'Schedule Test Jamaat Notification',
        ),
      ],
    );
  }
} 