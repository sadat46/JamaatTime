import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

class _SignedR2Upload {
  const _SignedR2Upload({required this.uploadUrl, required this.publicUrl});

  final String uploadUrl;
  final String publicUrl;
}

class _AdminNotificationBroadcastScreenState
    extends State<AdminNotificationBroadcastScreen> {
  static const int _titleMax = 65;
  static const int _bodyMax = 240;
  static const int _deepLinkMax = 500;
  static const int _imageUrlMax = 2000;
  static const int _imageUploadMaxBytes = 1000000;

  final AuthService _authService = AuthService();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();
  final TextEditingController _imageUrlCtrl = TextEditingController();
  final TextEditingController _deepLinkCtrl = TextEditingController();

  _BroadcastType _type = _BroadcastType.text;
  _ImageSource _imageSource = _ImageSource.url;
  String _targetKind = 'all_users';
  final List<String> _deepLinkPresets = const [
    '/home',
    '/settings',
    '/admin/jamaat',
  ];

  bool _uploading = false;
  bool _sending = false;
  String? _uploadedImageUrl;
  bool _scheduleLater = false;
  DateTime? _fireAt;

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

      final uploadBytes = bytes ?? await File(path!).readAsBytes();
      if (uploadBytes.length > _imageUploadMaxBytes) {
        throw StateError('Image must be 1 MB or smaller for FCM.');
      }

      final contentType = _contentTypeForExtension(picked.extension);
      final signedUpload = await _createR2UploadUrl(
        contentType: contentType,
        sizeBytes: uploadBytes.length,
      );

      final uploadResp = await http.put(
        Uri.parse(signedUpload.uploadUrl),
        headers: {
          'Content-Type': contentType,
          'Cache-Control': 'public, max-age=31536000, immutable',
        },
        body: uploadBytes,
      );
      if (uploadResp.statusCode < 200 || uploadResp.statusCode >= 300) {
        throw StateError('R2 upload failed (${uploadResp.statusCode}).');
      }

      if (!mounted) return;
      setState(() => _uploadedImageUrl = signedUpload.publicUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              bn: 'ছবি আপলোড ব্যর্থ: $e',
              en: 'Image upload failed: $e',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _contentTypeForExtension(String? rawExtension) {
    final ext = (rawExtension ?? '').toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        throw StateError('Only JPG, PNG, and WebP images are supported.');
    }
  }

  Future<_SignedR2Upload> _createR2UploadUrl({
    required String contentType,
    required int sizeBytes,
  }) async {
    final callable = _functions.httpsCallable(
      'createNotificationImageUploadUrl',
    );
    final resp = await callable.call<Map<Object?, Object?>>({
      'contentType': contentType,
      'sizeBytes': sizeBytes,
    });
    final data = resp.data;
    final uploadUrl = data['uploadUrl']?.toString();
    final publicUrl = data['publicUrl']?.toString();
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw StateError('Upload URL was not returned.');
    }
    if (publicUrl == null || publicUrl.isEmpty) {
      throw StateError('Public image URL was not returned.');
    }
    return _SignedR2Upload(uploadUrl: uploadUrl, publicUrl: publicUrl);
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
    if (_scheduleLater) {
      if (_fireAt == null) return false;
      if (!_fireAt!.isAfter(DateTime.now())) return false;
    }
    return true;
  }

  Future<void> _pickFireAt() async {
    final now = DateTime.now();
    final initial = _fireAt ?? now.add(const Duration(minutes: 5));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? initial : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!picked.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              bn: 'ভবিষ্যতের একটি সময় বাছাই করুন',
              en: 'Pick a time in the future',
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      _fireAt = picked;
      _scheduleLater = true;
    });
  }

  Future<void> _onSendPressed() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    final imageUrl = _currentImageUrl;
    final typeStr = _type == _BroadcastType.image ? 'image' : 'text';
    final scheduledFor = _scheduleLater ? _fireAt : null;

    final confirmed = await BroadcastSendConfirmDialog.show(
      context,
      title: title,
      body: body,
      type: typeStr,
      imageUrl: imageUrl,
      scheduledFor: scheduledFor,
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
      if (scheduledFor != null) {
        payload['fireAt'] = scheduledFor.millisecondsSinceEpoch;
      }

      final callableName = scheduledFor != null
          ? 'scheduleBroadcast'
          : 'broadcastNotification';
      final callable = _functions.httpsCallable(callableName);
      final resp = await callable.call<Map<Object?, Object?>>(payload);
      final data = resp.data;
      final status = data['status']?.toString() ?? 'sent';
      final notifId = data['notifId']?.toString() ?? '';
      final failureReason = data['failureReason']?.toString();

      if (!mounted) return;
      final String label;
      if (status == 'queued') {
        label = context.tr(
          bn: 'শিডিউল করা হয়েছে • $notifId',
          en: 'Scheduled • $notifId',
        );
      } else if (status == 'fallback_text') {
        label = context.tr(
          bn: 'FCM accepted text fallback ($failureReason) - $notifId',
          en: 'FCM accepted text fallback ($failureReason) - $notifId',
        );
      } else {
        label = context.tr(
          bn: 'FCM accepted broadcast - $notifId',
          en: 'FCM accepted broadcast - $notifId',
        );
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(label)));
      if (status == 'queued') {
        setState(() {
          _scheduleLater = false;
          _fireAt = null;
        });
      }
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
                    : Icon(_scheduleLater ? Icons.schedule_send : Icons.send),
                label: Text(
                  _scheduleLater
                      ? context.tr(bn: 'শিডিউল করুন', en: 'Schedule broadcast')
                      : context.tr(
                          bn: 'সবার কাছে পাঠান',
                          en: 'Send to everyone',
                        ),
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
                      ? context.tr(
                          bn: 'কোনো ছবি বাছাই করা হয়নি',
                          en: 'No image picked yet',
                        )
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
              labelText: context.tr(
                bn: 'ছবির লিঙ্ক (HTTPS)',
                en: 'Image URL (HTTPS)',
              ),
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
              labelText: context.tr(
                bn: 'ডিপ লিঙ্ক (ঐচ্ছিক)',
                en: 'Deep link (optional)',
              ),
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
            Expanded(
              child: _scheduleLater
                  ? OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _scheduleLater = false;
                          _fireAt = null;
                        });
                      },
                      icon: const Icon(Icons.bolt),
                      label: Text(context.tr(bn: 'এখন', en: 'Now')),
                    )
                  : FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.bolt),
                      label: Text(context.tr(bn: 'এখন', en: 'Now')),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _scheduleLater
                  ? FilledButton.icon(
                      onPressed: _pickFireAt,
                      icon: const Icon(Icons.schedule),
                      label: Text(context.tr(bn: 'শিডিউল…', en: 'Schedule…')),
                    )
                  : OutlinedButton.icon(
                      onPressed: _pickFireAt,
                      icon: const Icon(Icons.schedule),
                      label: Text(context.tr(bn: 'শিডিউল…', en: 'Schedule…')),
                    ),
            ),
          ],
        ),
        if (_scheduleLater && _fireAt != null) ...[
          const SizedBox(height: 8),
          Text(
            context.tr(
              bn: 'সময়: ${_formatFireAt(_fireAt!)}',
              en: 'Scheduled for: ${_formatFireAt(_fireAt!)}',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  String _formatFireAt(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}
