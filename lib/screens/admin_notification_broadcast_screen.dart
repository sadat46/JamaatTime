import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../core/locale_text.dart';
import '../services/auth_service.dart';
import '../widgets/notifications/broadcast_preview_card.dart';
import '../widgets/notifications/broadcast_send_confirm_dialog.dart';

// SuperAdmin-only composer that calls the `broadcastNotification` Cloud
// Function. Only "all_users" + "Now" ship in P6; other target kinds and the
// scheduled path land in later phases but their controls are rendered
// disabled so the final shape is visible.
class AdminNotificationBroadcastScreen extends StatefulWidget {
  const AdminNotificationBroadcastScreen({super.key});

  @override
  State<AdminNotificationBroadcastScreen> createState() =>
      _AdminNotificationBroadcastScreenState();
}

enum _BroadcastType { text, image }

enum _ImageSource { upload, url }

class _AdminNotificationBroadcastScreenState
    extends State<AdminNotificationBroadcastScreen> {
  static const int _titleMax = 65;
  static const int _bodyMax = 240;
  static const int _deepLinkMax = 500;
  static const int _imageUrlMax = 2000;

  final AuthService _authService = AuthService();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();
  final TextEditingController _imageUrlCtrl = TextEditingController();
  final TextEditingController _deepLinkCtrl = TextEditingController();

  _BroadcastType _type = _BroadcastType.text;
  _ImageSource _imageSource = _ImageSource.url;
  String _targetKind = 'all_users';
  final List<String> _deepLinkPresets = const ['/home', '/settings', '/admin/jamaat'];

  bool _uploading = false;
  bool _sending = false;
  String? _uploadedImageUrl;

  @override
  void initState() {
    super.initState();
    for (final c in [_titleCtrl, _bodyCtrl, _imageUrlCtrl, _deepLinkCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _imageUrlCtrl.dispose();
    _deepLinkCtrl.dispose();
    super.dispose();
  }

  String? get _currentImageUrl {
    if (_type != _BroadcastType.image) return null;
    if (_imageSource == _ImageSource.upload) return _uploadedImageUrl;
    final typed = _imageUrlCtrl.text.trim();
    return typed.isEmpty ? null : typed;
  }

  Future<void> _pickAndUploadImage() async {
    setState(() => _uploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      final bytes = picked.bytes;
      final path = picked.path;
      if (bytes == null && path == null) {
        throw StateError('Picked file has no bytes or path.');
      }

      final ext = (picked.extension ?? 'jpg').toLowerCase();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref()
          .child('notification_images/$stamp.$ext');
      final metadata = SettableMetadata(contentType: 'image/$ext');

      final task = bytes != null
          ? ref.putData(bytes, metadata)
          : ref.putFile(File(path!), metadata);
      await task;
      final url = await ref.getDownloadURL();
      if (!mounted) return;
      setState(() => _uploadedImageUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(bn: 'ছবি আপলোড ব্যর্থ: $e', en: 'Image upload failed: $e'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  bool get _canSubmit {
    if (_sending || _uploading) return false;
    if (_titleCtrl.text.trim().isEmpty) return false;
    if (_bodyCtrl.text.trim().isEmpty) return false;
    if (_titleCtrl.text.trim().length > _titleMax) return false;
    if (_bodyCtrl.text.trim().length > _bodyMax) return false;
    if (_type == _BroadcastType.image && (_currentImageUrl ?? '').isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _onSendPressed() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    final imageUrl = _currentImageUrl;
    final typeStr = _type == _BroadcastType.image ? 'image' : 'text';

    final confirmed = await BroadcastSendConfirmDialog.show(
      context,
      title: title,
      body: body,
      type: typeStr,
      imageUrl: imageUrl,
    );
    if (!confirmed) return;

    setState(() => _sending = true);
    try {
      final deepLink = _deepLinkCtrl.text.trim();
      final payload = <String, dynamic>{
        'type': typeStr,
        'title': title,
        'body': body,
        'target': {'kind': _targetKind},
        if (deepLink.isNotEmpty) 'deepLink': deepLink,
        if (typeStr == 'image' && imageUrl != null) 'imageUrl': imageUrl,
      };

      final callable = _functions.httpsCallable('broadcastNotification');
      final resp = await callable.call<Map<Object?, Object?>>(payload);
      final data = resp.data;
      final status = data['status']?.toString() ?? 'sent';
      final notifId = data['notifId']?.toString() ?? '';
      final failureReason = data['failureReason']?.toString();

      if (!mounted) return;
      final label = status == 'fallback_text'
          ? context.tr(
              bn: 'টেক্সট ফলব্যাক পাঠানো হয়েছে ($failureReason) • $notifId',
              en: 'Sent as text fallback ($failureReason) • $notifId',
            )
          : context.tr(
              bn: 'ব্রডকাস্ট পাঠানো হয়েছে • $notifId',
              en: 'Broadcast sent • $notifId',
            );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(label)));
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              bn: 'ব্রডকাস্ট ব্যর্থ: ${e.code} ${e.message ?? ''}',
              en: 'Broadcast failed: ${e.code} ${e.message ?? ''}',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(bn: 'ব্রডকাস্ট ব্যর্থ: $e', en: 'Broadcast failed: $e'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(bn: 'নোটিফিকেশন ব্রডকাস্ট', en: 'Notification Broadcast'),
        ),
      ),
      body: FutureBuilder<bool>(
        future: _authService.isSuperAdmin(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data != true) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr(
                    bn: 'শুধুমাত্র সুপার-অ্যাডমিন এই স্ক্রিনে অ্যাক্সেস পাবেন।',
                    en: 'Only super-admins can access this screen.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _buildForm(context);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTypeSelector(),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _titleCtrl,
                label: context.tr(bn: 'শিরোনাম', en: 'Title'),
                maxLength: _titleMax,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _bodyCtrl,
                label: context.tr(bn: 'বার্তা', en: 'Body'),
                maxLength: _bodyMax,
                maxLines: 4,
              ),
              if (_type == _BroadcastType.image) ...[
                const SizedBox(height: 16),
                _buildImageSection(),
              ],
              const SizedBox(height: 16),
              _buildTargetDropdown(),
              const SizedBox(height: 12),
              _buildDeepLinkField(),
              const SizedBox(height: 16),
              _buildScheduleRadio(),
              const SizedBox(height: 20),
              Text(
                context.tr(bn: 'প্রিভিউ', en: 'Preview'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              BroadcastPreviewCard(
                title: _titleCtrl.text,
                body: _bodyCtrl.text,
                imageUrl: _currentImageUrl,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _canSubmit ? _onSendPressed : null,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  context.tr(bn: 'সবার কাছে পাঠান', en: 'Send to everyone'),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SegmentedButton<_BroadcastType>(
      segments: [
        ButtonSegment(
          value: _BroadcastType.text,
          label: Text(context.tr(bn: 'টেক্সট', en: 'Text')),
          icon: const Icon(Icons.short_text),
        ),
        ButtonSegment(
          value: _BroadcastType.image,
          label: Text(context.tr(bn: 'ছবি', en: 'Image')),
          icon: const Icon(Icons.image),
        ),
      ],
      selected: {_type},
      onSelectionChanged: (s) => setState(() => _type = s.first),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required int maxLength,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_ImageSource>(
          segments: [
            ButtonSegment(
              value: _ImageSource.upload,
              label: Text(context.tr(bn: 'আপলোড', en: 'Upload')),
              icon: const Icon(Icons.cloud_upload),
            ),
            ButtonSegment(
              value: _ImageSource.url,
              label: Text(context.tr(bn: 'লিঙ্ক', en: 'Paste URL')),
              icon: const Icon(Icons.link),
            ),
          ],
          selected: {_imageSource},
          onSelectionChanged: (s) => setState(() => _imageSource = s.first),
        ),
        const SizedBox(height: 10),
        if (_imageSource == _ImageSource.upload)
          Row(
            children: [
              Expanded(
                child: Text(
                  _uploadedImageUrl == null
                      ? context.tr(bn: 'কোনো ছবি বাছাই করা হয়নি', en: 'No image picked yet')
                      : _uploadedImageUrl!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _uploading ? null : _pickAndUploadImage,
                icon: _uploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload),
                label: Text(context.tr(bn: 'বাছাই করুন', en: 'Pick')),
              ),
            ],
          )
        else
          TextField(
            controller: _imageUrlCtrl,
            maxLength: _imageUrlMax,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: context.tr(bn: 'ছবির লিঙ্ক (HTTPS)', en: 'Image URL (HTTPS)'),
              border: const OutlineInputBorder(),
              hintText: 'https://…',
            ),
          ),
      ],
    );
  }

  Widget _buildTargetDropdown() {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: _targetKind,
      decoration: InputDecoration(
        labelText: context.tr(bn: 'প্রাপক', en: 'Target'),
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem(
          value: 'all_users',
          child: Text(context.tr(bn: 'সকল ব্যবহারকারী', en: 'All users')),
        ),
        DropdownMenuItem(
          value: 'affected_location',
          enabled: false,
          child: Text(
            '${context.tr(bn: 'প্রভাবিত এলাকা', en: 'Affected location')} — ${context.tr(bn: 'শীঘ্রই', en: 'coming soon')}',
          ),
        ),
        DropdownMenuItem(
          value: 'selected_users',
          enabled: false,
          child: Text(
            '${context.tr(bn: 'নির্দিষ্ট ব্যবহারকারী', en: 'Selected users')} — ${context.tr(bn: 'শীঘ্রই', en: 'coming soon')}',
          ),
        ),
        DropdownMenuItem(
          value: 'role_based',
          enabled: false,
          child: Text(
            '${context.tr(bn: 'রোল-ভিত্তিক', en: 'Role-based')} — ${context.tr(bn: 'শীঘ্রই', en: 'coming soon')}',
          ),
        ),
      ],
      onChanged: (v) {
        if (v == 'all_users') setState(() => _targetKind = v!);
      },
    );
  }

  Widget _buildDeepLinkField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _deepLinkCtrl,
            maxLength: _deepLinkMax,
            decoration: InputDecoration(
              labelText: context.tr(bn: 'ডিপ লিঙ্ক (ঐচ্ছিক)', en: 'Deep link (optional)'),
              border: const OutlineInputBorder(),
              hintText: '/home',
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: context.tr(bn: 'সাধারণ রুট', en: 'Common routes'),
          icon: const Icon(Icons.list),
          onSelected: (v) => setState(() => _deepLinkCtrl.text = v),
          itemBuilder: (_) => _deepLinkPresets
              .map((r) => PopupMenuItem(value: r, child: Text(r)))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildScheduleRadio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(bn: 'কখন পাঠাবেন', en: 'When to send'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.bolt),
              label: Text(context.tr(bn: 'এখন', en: 'Now')),
              style: FilledButton.styleFrom(
                disabledBackgroundColor: Theme.of(context).colorScheme.primary,
                disabledForegroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: context.tr(bn: 'শীঘ্রই', en: 'Coming soon'),
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.schedule),
                label: Text(context.tr(bn: 'শিডিউল…', en: 'Schedule…')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
