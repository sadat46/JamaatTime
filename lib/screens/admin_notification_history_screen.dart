import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../core/locale_text.dart';
import '../services/auth_service.dart';
import '../widgets/notifications/notification_history_row.dart';

// Superadmin-only history of every notifications/{id}. Reads are gated by
// Firestore rules (isAdminOrAbove). Retry posts stored payload back through
// broadcastNotification; cancel posts through cancelScheduledBroadcast.

const int _kPageSize = 20;

enum _TriggerFilter { all, manual, autoJamaatChange }

enum _StatusFilter { all, sent, failed, queued, cancelled, fallbackText }

class AdminNotificationHistoryScreen extends StatefulWidget {
  const AdminNotificationHistoryScreen({super.key});

  @override
  State<AdminNotificationHistoryScreen> createState() =>
      _AdminNotificationHistoryScreenState();
}

class _AdminNotificationHistoryScreenState
    extends State<AdminNotificationHistoryScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');
  final ScrollController _scrollCtrl = ScrollController();

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _rows = [];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _loading = false;
  bool _exhausted = false;
  String? _error;

  _TriggerFilter _triggerFilter = _TriggerFilter.all;
  _StatusFilter _statusFilter = _StatusFilter.all;
  final Set<String> _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadMore(reset: true);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _exhausted) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 280) {
      _loadMore();
    }
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = _firestore
        .collection('notifications')
        .orderBy('createdAt', descending: true);
    switch (_triggerFilter) {
      case _TriggerFilter.manual:
        q = q.where('triggerSource', isEqualTo: 'manual');
        break;
      case _TriggerFilter.autoJamaatChange:
        q = q.where('triggerSource', isEqualTo: 'auto_jamaat_change');
        break;
      case _TriggerFilter.all:
        break;
    }
    final status = switch (_statusFilter) {
      _StatusFilter.sent => 'sent',
      _StatusFilter.failed => 'failed',
      _StatusFilter.queued => 'queued',
      _StatusFilter.cancelled => 'cancelled',
      _StatusFilter.fallbackText => 'fallback_text',
      _StatusFilter.all => null,
    };
    if (status != null) q = q.where('status', isEqualTo: status);
    return q;
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _rows.clear();
        _cursor = null;
        _exhausted = false;
      }
    });

    try {
      Query<Map<String, dynamic>> q = _buildQuery().limit(_kPageSize);
      if (_cursor != null) q = q.startAfterDocument(_cursor!);
      final snap = await q.get();
      setState(() {
        _rows.addAll(snap.docs);
        if (snap.docs.isNotEmpty) _cursor = snap.docs.last;
        if (snap.docs.length < _kPageSize) _exhausted = true;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRetry(String notifId) async {
    final row = _rows.firstWhere((d) => d.id == notifId);
    final data = row.data();
    setState(() => _busy.add(notifId));
    try {
      await _functions.httpsCallable('broadcastNotification').call({
        'type': data['type'],
        'title': data['title'],
        'body': data['body'],
        'imageUrl': data['imageUrl'],
        'targetKind': (data['target'] as Map?)?['kind'] ?? 'all_users',
        'deepLink': data['deepLink'],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(bn: 'আবার পাঠানো হয়েছে', en: 'Retry sent')),
        ),
      );
      await _loadMore(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Retry failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(notifId));
    }
  }

  Future<void> _onCancel(String notifId) async {
    setState(() => _busy.add(notifId));
    try {
      await _functions
          .httpsCallable('cancelScheduledBroadcast')
          .call({'notifId': notifId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(bn: 'বাতিল করা হয়েছে', en: 'Cancelled')),
        ),
      );
      await _loadMore(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cancel failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(notifId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authService.isSuperAdmin(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('Notification History')),
            body: Center(
              child: Text(
                context.tr(
                  bn: 'শুধু সুপার-অ্যাডমিনের জন্য।',
                  en: 'Superadmin only.',
                ),
              ),
            ),
          );
        }
        return _buildScaffold(context);
      },
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(bn: 'নোটিফিকেশন ইতিহাস', en: 'Notification History'),
        ),
        actions: [
          IconButton(
            tooltip: context.tr(bn: 'রিফ্রেশ', en: 'Refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _loadMore(reset: true),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(context),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(child: _buildList(context)),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<_TriggerFilter>(
            segments: [
              ButtonSegment(
                value: _TriggerFilter.all,
                label: Text(context.tr(bn: 'সব', en: 'All')),
              ),
              ButtonSegment(
                value: _TriggerFilter.manual,
                label: Text(context.tr(bn: 'ম্যানুয়াল', en: 'Manual')),
              ),
              ButtonSegment(
                value: _TriggerFilter.autoJamaatChange,
                label: Text(context.tr(bn: 'অটো', en: 'Auto')),
              ),
            ],
            selected: {_triggerFilter},
            onSelectionChanged: (s) {
              setState(() => _triggerFilter = s.first);
              _loadMore(reset: true);
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<_StatusFilter>(
            initialValue: _statusFilter,
            isDense: true,
            decoration: InputDecoration(
              labelText: context.tr(bn: 'স্ট্যাটাস', en: 'Status'),
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: _StatusFilter.all, child: Text('All')),
              DropdownMenuItem(value: _StatusFilter.sent, child: Text('sent')),
              DropdownMenuItem(
                  value: _StatusFilter.fallbackText,
                  child: Text('fallback_text')),
              DropdownMenuItem(
                  value: _StatusFilter.failed, child: Text('failed')),
              DropdownMenuItem(
                  value: _StatusFilter.queued, child: Text('queued')),
              DropdownMenuItem(
                  value: _StatusFilter.cancelled, child: Text('cancelled')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _statusFilter = v);
              _loadMore(reset: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (_rows.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rows.isEmpty) {
      return Center(
        child: Text(
          context.tr(bn: 'কোনো নোটিফিকেশন নেই।', en: 'No notifications.'),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      itemCount: _rows.length + 1,
      itemBuilder: (context, i) {
        if (i == _rows.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: _exhausted
                  ? Text(
                      context.tr(bn: 'শেষ।', en: 'End of history.'),
                      style: TextStyle(color: Colors.grey[600]),
                    )
                  : const CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final row = _rows[i];
        return NotificationHistoryRow(
          doc: row,
          onRetry: _onRetry,
          onCancel: _onCancel,
          busy: _busy.contains(row.id),
        );
      },
    );
  }
}
