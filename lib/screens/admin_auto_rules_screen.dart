import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../core/locale_text.dart';
import '../services/auth_service.dart';

// Superadmin-only editor for the `notification_rules/jamaat_change` doc
// that P9's onJamaatChange trigger consults. Writes go straight to
// Firestore — the superadmin rule gates access at the DB layer.

const String _kRuleDocPath = 'notification_rules/jamaat_change';

const List<String> _kAutoModes = ['off', 'text', 'image', 'both'];
const List<String> _kAutoTargets = ['all_users', 'affected_location'];

enum _ImageSource { upload, url }

class AdminAutoRulesScreen extends StatefulWidget {
  const AdminAutoRulesScreen({super.key});

  @override
  State<AdminAutoRulesScreen> createState() => _AdminAutoRulesScreenState();
}

class _AdminAutoRulesScreenState extends State<AdminAutoRulesScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _minChangeCtrl = TextEditingController(text: '1');
  final TextEditingController _cooldownCtrl = TextEditingController(
    text: '300',
  );
  final TextEditingController _imageUrlCtrl = TextEditingController();

  bool _autoNotifyOn = false;
  String _autoMode = 'text';
  String _autoTarget = 'all_users';
  _ImageSource _imageSource = _ImageSource.url;
  String? _uploadedImageUrl;

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _minChangeCtrl.dispose();
    _cooldownCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final snap = await _firestore.doc(_kRuleDocPath).get();
      if (!mounted) return;
      final data = snap.data();
      if (data != null) {
        setState(() {
          _autoNotifyOn = data['autoNotifyOnJamaatChange'] == true;
          final mode = data['autoNotifyMode'];
          if (mode is String && _kAutoModes.contains(mode)) _autoMode = mode;
          final target = data['autoNotifyTarget'];
          if (target is String && _kAutoTargets.contains(target)) {
            _autoTarget = target;
          }
          final minChange = data['minChangeMinutes'];
          if (minChange is num) {
            _minChangeCtrl.text = minChange.toInt().toString();
          }
          final cooldown = data['cooldownSeconds'];
          if (cooldown is num) _cooldownCtrl.text = cooldown.toInt().toString();
          final url = data['defaultImageUrl'];
          if (url is String && url.isNotEmpty) {
            _imageUrlCtrl.text = url;
            _uploadedImageUrl = url;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(bn: 'লোড ব্যর্থ: $e', en: 'Failed to load: $e'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUpload() async {
    setState(() => _uploading = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final f = picked.files.first;
      final ext = (f.extension ?? 'jpg').toLowerCase();
      final ref = FirebaseStorage.instance.ref().child(
        'notification_images/auto_default_$ext.$ext',
      );
      final metadata = SettableMetadata(contentType: 'image/$ext');
      if (f.bytes != null) {
        await ref.putData(f.bytes!, metadata);
      } else if (f.path != null) {
        await ref.putFile(File(f.path!), metadata);
      } else {
        throw StateError('Picked file has no bytes or path.');
      }
      final url = await ref.getDownloadURL();
      if (!mounted) return;
      setState(() => _uploadedImageUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(bn: 'আপলোড ব্যর্থ: $e', en: 'Upload failed: $e'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String? get _effectiveImageUrl {
    if (_imageSource == _ImageSource.upload) return _uploadedImageUrl;
    final t = _imageUrlCtrl.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    final minChange = int.tryParse(_minChangeCtrl.text.trim());
    final cooldown = int.tryParse(_cooldownCtrl.text.trim());
    if (minChange == null || minChange < 0) {
      _snack(
        context.tr(
          bn: 'minChangeMinutes একটি অ-ঋণাত্মক পূর্ণ সংখ্যা হতে হবে',
          en: 'minChangeMinutes must be a non-negative integer',
        ),
      );
      return;
    }
    if (cooldown == null || cooldown < 0) {
      _snack(
        context.tr(
          bn: 'cooldownSeconds একটি অ-ঋণাত্মক পূর্ণ সংখ্যা হতে হবে',
          en: 'cooldownSeconds must be a non-negative integer',
        ),
      );
      return;
    }
    final imageUrl = _effectiveImageUrl;
    if (_autoMode != 'text' && _autoMode != 'off' && imageUrl == null) {
      _snack(
        context.tr(
          bn: 'মোড = image/both হলে ডিফল্ট ছবি লাগবে',
          en: 'Default image required when mode is image or both',
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _firestore.doc(_kRuleDocPath).set({
        'autoNotifyOnJamaatChange': _autoNotifyOn,
        'autoNotifyMode': _autoMode,
        'autoNotifyTarget': _autoTarget,
        'minChangeMinutes': minChange,
        'cooldownSeconds': cooldown,
        'defaultImageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      _snack(context.tr(bn: 'সংরক্ষণ সফল', en: 'Saved'));
    } catch (e) {
      if (!mounted) return;
      _snack(context.tr(bn: 'সংরক্ষণ ব্যর্থ: $e', en: 'Save failed: $e'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(bn: 'অটো-নোটিফিকেশন নিয়ম', en: 'Auto-notification rules'),
        ),
      ),
      body: FutureBuilder<bool>(
        future: _authService.isSuperAdmin(),
        builder: (context, snap) {
          if (!snap.hasData || _loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.data != true) {
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
          return _buildForm();
        },
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                value: _autoNotifyOn,
                onChanged: (v) => setState(() => _autoNotifyOn = v),
                title: Text(
                  context.tr(
                    bn: 'জামাত পরিবর্তনে অটো-নোটিফাই',
                    en: 'Auto-notify on jamaat change',
                  ),
                ),
                subtitle: Text(
                  context.tr(
                    bn: 'অ্যাডমিন জামাতের সময় বদলালে স্বয়ংক্রিয়ভাবে পাঠানো হবে',
                    en: 'Fires when an admin edits jamaat times',
                  ),
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              Text(
                context.tr(bn: 'মোড', en: 'Mode'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'off',
                    label: Text(context.tr(bn: 'বন্ধ', en: 'Off')),
                  ),
                  ButtonSegment(
                    value: 'text',
                    label: Text(context.tr(bn: 'টেক্সট', en: 'Text')),
                  ),
                  ButtonSegment(
                    value: 'image',
                    label: Text(context.tr(bn: 'ছবি', en: 'Image')),
                  ),
                  ButtonSegment(
                    value: 'both',
                    label: Text(context.tr(bn: 'উভয়', en: 'Both')),
                  ),
                ],
                selected: {_autoMode},
                onSelectionChanged: (s) => setState(() => _autoMode = s.first),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _autoTarget,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.tr(bn: 'প্রাপক', en: 'Target'),
                  border: const OutlineInputBorder(),
                ),
                selectedItemBuilder: (context) => [
                  Text(
                    context.tr(bn: 'সকল ব্যবহারকারী', en: 'All users'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${context.tr(bn: 'প্রভাবিত এলাকা', en: 'Affected location')} — ${context.tr(bn: 'শীঘ্রই', en: 'coming soon')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                items: [
                  DropdownMenuItem(
                    value: 'all_users',
                    child: Text(
                      context.tr(bn: 'সকল ব্যবহারকারী', en: 'All users'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'affected_location',
                    enabled: false,
                    child: Text(
                      '${context.tr(bn: 'প্রভাবিত এলাকা', en: 'Affected location')} — ${context.tr(bn: 'শীঘ্রই', en: 'coming soon')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v == 'all_users') setState(() => _autoTarget = v!);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minChangeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.tr(
                          bn: 'নূন্যতম পরিবর্তন (মিনিট)',
                          en: 'Min change (minutes)',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _cooldownCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.tr(
                          bn: 'কুলডাউন (সেকেন্ড)',
                          en: 'Cooldown (seconds)',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(
                  bn: 'ডিফল্ট ছবি (image/both মোডের জন্য)',
                  en: 'Default image (for image / both modes)',
                ),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
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
                onSelectionChanged: (s) =>
                    setState(() => _imageSource = s.first),
              ),
              const SizedBox(height: 8),
              if (_imageSource == _ImageSource.upload)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _uploadedImageUrl ??
                            context.tr(
                              bn: 'কোনো ছবি আপলোড করা হয়নি',
                              en: 'No image uploaded',
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: _uploading ? null : _pickAndUpload,
                      icon: _uploading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload),
                      label: Text(context.tr(bn: 'বাছাই', en: 'Pick')),
                    ),
                  ],
                )
              else
                TextField(
                  controller: _imageUrlCtrl,
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
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(context.tr(bn: 'সংরক্ষণ', en: 'Save')),
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
}
