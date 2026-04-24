import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/locale_text.dart';

// Expandable list tile for a single notifications/{id} row on the history
// screen. Kept stateless — the parent screen owns snapshots and callbacks
// for retry/cancel so this widget only renders what it's given.

class NotificationHistoryRow extends StatelessWidget {
  const NotificationHistoryRow({
    super.key,
    required this.doc,
    required this.onRetry,
    required this.onCancel,
    required this.busy,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Future<void> Function(String notifId)? onRetry;
  final Future<void> Function(String notifId)? onCancel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final status = (data['status'] as String?) ?? 'unknown';
    final type = (data['type'] as String?) ?? 'text';
    final title = (data['title'] as String?) ?? '(no title)';
    final body = (data['body'] as String?) ?? '';
    final trigger = (data['triggerSource'] as String?) ?? 'manual';
    final createdBy = (data['createdBy'] as String?) ?? 'unknown';
    final failureReason = data['failureReason'] as String?;
    final createdAt = data['createdAt'] as Timestamp?;
    final scheduledFor = data['scheduledFor'] as Timestamp?;
    final fcmResponse = data['fcmResponse'] as Map<String, dynamic>?;
    final imageUrl = data['imageUrl'] as String?;
    final deepLink = data['deepLink'] as String?;
    final dedupKey = data['dedupKey'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        key: ValueKey('notif-row-${doc.id}'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Row(
          children: [
            _StatusChip(status: status),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${_fmtTs(createdAt) ?? '—'}  •  $trigger  •  $type',
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(context, 'Body', body, multi: true),
                if (imageUrl != null) _kv(context, 'Image', imageUrl),
                if (deepLink != null) _kv(context, 'Deep link', deepLink),
                _kv(context, 'Created by', createdBy),
                if (scheduledFor != null)
                  _kv(context, 'Scheduled for', _fmtTs(scheduledFor) ?? '—'),
                if (fcmResponse != null)
                  _kv(context, 'FCM response', fcmResponse.toString(),
                      multi: true),
                if (failureReason != null)
                  _kv(context, 'Failure', failureReason, multi: true),
                if (dedupKey != null)
                  _kv(context, 'Dedup', '${dedupKey.substring(0, 12)}…'),
                const SizedBox(height: 8),
                _actions(context, status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v, {bool multi = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: RichText(
        maxLines: multi ? null : 1,
        overflow: multi ? TextOverflow.visible : TextOverflow.ellipsis,
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$k: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: v),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, String status) {
    final buttons = <Widget>[];
    if (status == 'failed' && onRetry != null) {
      buttons.add(
        FilledButton.tonalIcon(
          onPressed: busy ? null : () => onRetry!(doc.id),
          icon: const Icon(Icons.refresh),
          label: Text(context.tr(bn: 'আবার পাঠান', en: 'Retry')),
        ),
      );
    }
    if (status == 'queued' && onCancel != null) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: busy ? null : () => onCancel!(doc.id),
          icon: const Icon(Icons.cancel),
          label: Text(context.tr(bn: 'বাতিল', en: 'Cancel')),
        ),
      );
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, children: buttons);
  }

  String? _fmtTs(Timestamp? ts) {
    if (ts == null) return null;
    final dt = ts.toDate().toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'sent' => Colors.green,
      'fallback_text' => Colors.orange,
      'failed' => Colors.red,
      'queued' => Colors.blue,
      'cancelled' => Colors.grey,
      'sending' => Colors.amber,
      _ => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
