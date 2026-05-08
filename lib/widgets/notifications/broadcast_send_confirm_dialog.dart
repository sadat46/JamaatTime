import 'package:flutter/material.dart';
import '../../core/locale_text.dart';

// Forces the admin to type SEND before the broadcast can fire — final
// guardrail against mis-clicks since "all_users" reaches every installed
// device.
class BroadcastSendConfirmDialog extends StatefulWidget {
  const BroadcastSendConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.type,
    this.imageUrl,
    this.scheduledFor,
  });

  final String title;
  final String body;
  final String type; // 'text' | 'image'
  final String? imageUrl;
  final DateTime? scheduledFor;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String body,
    required String type,
    String? imageUrl,
    DateTime? scheduledFor,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BroadcastSendConfirmDialog(
        title: title,
        body: body,
        type: type,
        imageUrl: imageUrl,
        scheduledFor: scheduledFor,
      ),
    );
    return confirmed ?? false;
  }

  @override
  State<BroadcastSendConfirmDialog> createState() =>
      _BroadcastSendConfirmDialogState();
}

class _BroadcastSendConfirmDialogState
    extends State<BroadcastSendConfirmDialog> {
  final TextEditingController _controller = TextEditingController();
  bool get _canSend => _controller.text.trim().toUpperCase() == 'SEND';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = widget.type == 'image'
        ? context.tr(bn: 'ছবি + টেক্সট', en: 'Image + text')
        : context.tr(bn: 'টেক্সট', en: 'Text');
    final scheduled = widget.scheduledFor;

    return AlertDialog(
      title: Text(
        scheduled != null
            ? context.tr(bn: 'শিডিউল নিশ্চিত করুন', en: 'Confirm schedule')
            : context.tr(bn: 'পাঠানোর আগে নিশ্চিত করুন', en: 'Confirm send'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
            scheduled != null
                ? context.tr(
                    bn: 'নির্দিষ্ট সময়ে অ্যাপের প্রত্যেক ব্যবহারকারীর কাছে পাঠানো হবে।',
                    en: 'Will be sent to EVERY user at the scheduled time.',
                  )
                : context.tr(
                    bn: 'এটি অ্যাপের প্রত্যেক ব্যবহারকারীর কাছে পাঠানো হবে।',
                    en: 'This will be sent to EVERY user of the app.',
                  ),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text('${context.tr(bn: 'ধরন:', en: 'Type:')} $typeLabel'),
          const SizedBox(height: 4),
          Text(
            '${context.tr(bn: 'শিরোনাম:', en: 'Title:')} ${widget.title}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (scheduled != null) ...[
            const SizedBox(height: 4),
            Text(
              '${context.tr(bn: 'সময়:', en: 'When:')} ${_formatScheduled(scheduled)}',
            ),
          ],
          const SizedBox(height: 12),
          Text(
            context.tr(
              bn: 'নিশ্চিত করতে নিচে SEND লিখুন।',
              en: 'Type SEND below to confirm.',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'SEND',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.tr(bn: 'বাতিল', en: 'Cancel')),
        ),
        FilledButton(
          onPressed: _canSend ? () => Navigator.of(context).pop(true) : null,
          child: Text(
            widget.scheduledFor != null
                ? context.tr(bn: 'শিডিউল', en: 'Schedule')
                : context.tr(bn: 'পাঠান', en: 'Send'),
          ),
        ),
      ],
    );
  }

  String _formatScheduled(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}
