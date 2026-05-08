import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/locale_text.dart';

// Expandable list tile for one merged notifications/{id} +
// notifications/{id}/admin_meta/meta row.
class NotificationHistoryRow extends StatelessWidget {
  const NotificationHistoryRow({
    super.key,
    required this.notifId,
    required this.data,
    required this.legacy,
    required this.onRetry,
    required this.onCancel,
    required this.onViewRaw,
    required this.busy,
  });

  final String notifId;
  final Map<String, dynamic> data;
  final bool legacy;
  final Future<void> Function(String notifId)? onRetry;
  final Future<void> Function(String notifId)? onCancel;
  final VoidCallback? onViewRaw;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] as String?) ?? 'unknown';
    final noticeType = (data['type'] as String?) ?? 'announcement';
    final broadcastType =
        (data['broadcastType'] as String?) ??
        (((data['imageUrl'] as String?)?.isNotEmpty ?? false)
            ? 'image'
            : 'text');
    final title = (data['title'] as String?) ?? '(no title)';
    final body = (data['body'] as String?) ?? '';
    final trigger = (data['triggerSource'] as String?) ?? 'manual';
    final createdBy = (data['createdBy'] as String?) ?? 'unknown';
    final failureReason = data['failureReason'] as String?;
    final createdAt = data['createdAt'] as Timestamp?;
    final scheduledFor = data['scheduledFor'] as Timestamp?;
    final fcmResponse = data['fcmResponse'] as Map?;
    final imageUrl = data['imageUrl'] as String?;
    final deepLink = data['deepLink'] as String?;
    final dedupKey = data['dedupKey'] as String?;
    final priority = (data['priority'] as String?) ?? 'normal';
    final publicVisible = data['publicVisible'] == true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        key: ValueKey('notif-row-$notifId'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Row(
          children: [
            _StatusChip(status: status),
            if (legacy) ...[const SizedBox(width: 6), const _LegacyChip()],
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
            '${_fmtTs(createdAt) ?? '-'}  |  $trigger  |  $noticeType/$broadcastType',
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(context, 'Notice ID', notifId),
                _kv(context, 'Body', body, multi: true),
                _kv(context, 'Priority', priority),
                _kv(context, 'Public visible', publicVisible.toString()),
                if (imageUrl != null && imageUrl.isNotEmpty)
                  _kv(context, 'Image', imageUrl),
                if (deepLink != null && deepLink.isNotEmpty)
                  _kv(context, 'Deep link', deepLink),
                _kv(context, 'Created by', createdBy),
                if (scheduledFor != null)
                  _kv(context, 'Scheduled for', _fmtTs(scheduledFor) ?? '-'),
                if (fcmResponse != null)
                  _kv(
                    context,
                    'FCM accepted response',
                    fcmResponse.toString(),
                    multi: true,
                  ),
                if (status == 'sent' || status == 'fallback_text')
                  _kv(
                    context,
                    'Delivery meaning',
                    'FCM accepted the topic send; device receipt is not tracked.',
                    multi: true,
                  ),
                if (failureReason != null && failureReason.isNotEmpty)
                  _kv(context, 'Failure', failureReason, multi: true),
                if (dedupKey != null && dedupKey.isNotEmpty)
                  _kv(context, 'Dedup', _shorten(dedupKey)),
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
          onPressed: busy ? null : () => onRetry!(notifId),
          icon: const Icon(Icons.refresh),
          label: Text(context.tr(bn: 'Retry', en: 'Retry')),
        ),
      );
    }
    if (status == 'queued' && onCancel != null) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: busy ? null : () => onCancel!(notifId),
          icon: const Icon(Icons.cancel),
          label: Text(context.tr(bn: 'Cancel', en: 'Cancel')),
        ),
      );
    }
    if (onViewRaw != null) {
      buttons.add(
        TextButton.icon(
          onPressed: onViewRaw,
          icon: const Icon(Icons.data_object),
          label: const Text('View raw'),
        ),
      );
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  String _shorten(String value) {
    if (value.length <= 12) return value;
    return '${value.substring(0, 12)}...';
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
    final label = status == 'sent' ? 'accepted' : status;
    final color = switch (status) {
      'sent' => Colors.green,
      'fallback_text' => Colors.orange,
      'failed' => Colors.red,
      'queued' => Colors.blue,
      'cancelled' => Colors.grey,
      'sending' => Colors.amber,
      'expired' => Colors.blueGrey,
      _ => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _LegacyChip extends StatelessWidget {
  const _LegacyChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withAlpha(35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'legacy',
        style: TextStyle(
          color: Colors.deepOrange,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
