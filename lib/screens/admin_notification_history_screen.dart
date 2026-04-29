import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../core/locale_text.dart';
import '../services/auth_service.dart';
import '../services/notifications/fcm_service.dart';
import '../widgets/notifications/notification_history_row.dart';

// Superadmin-only history of notifications/{id}. The list reads the public
// root doc and merges notifications/{id}/admin_meta/meta for admin-only
// diagnostics, while preserving a legacy fallback until migration completes.

const int _kPageSize = 20;

enum _TriggerFilter { all, manual, autoJamaatChange }

enum _StatusFilter { all, sent, failed, queued, cancelled, fallbackText }

enum _PriorityFilter { all, normal, high, critical }

enum _TypeFilter {
  all,
  announcement,
  jamaatTimeChange,
  prayerTimeChange,
  event,
  urgent,
  info,
  other,
}

enum _VisibilityFilter { all, visible, hidden }

class _MergedNotificationRow {
  const _MergedNotificationRow({
    required this.id,
    required this.root,
    required this.data,
    required this.legacy,
  });

  final String id;
  final QueryDocumentSnapshot<Map<String, dynamic>> root;
  final Map<String, dynamic> data;
  final bool legacy;
}

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
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  final ScrollController _scrollCtrl = ScrollController();

  final List<_MergedNotificationRow> _rows = [];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _loading = false;
  bool _exhausted = false;
  String? _error;
  bool _diagnosticsLoading = false;
  String? _diagnosticsError;
  Map<String, dynamic>? _diagnostics;
  Map<String, String?>? _localDiagnostics;

  _TriggerFilter _triggerFilter = _TriggerFilter.all;
  _StatusFilter _statusFilter = _StatusFilter.all;
  _PriorityFilter _priorityFilter = _PriorityFilter.all;
  _TypeFilter _typeFilter = _TypeFilter.all;
  _VisibilityFilter _visibilityFilter = _VisibilityFilter.all;
  final Set<String> _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadMore(reset: true);
    _loadDiagnostics();
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
        q = q.where(
          'triggerSource',
          whereIn: ['auto_jamaat', 'auto_jamaat_change'],
        );
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

    final priority = switch (_priorityFilter) {
      _PriorityFilter.normal => 'normal',
      _PriorityFilter.high => 'high',
      _PriorityFilter.critical => 'critical',
      _PriorityFilter.all => null,
    };
    if (priority != null) q = q.where('priority', isEqualTo: priority);

    final type = switch (_typeFilter) {
      _TypeFilter.announcement => 'announcement',
      _TypeFilter.jamaatTimeChange => 'jamaat_time_change',
      _TypeFilter.prayerTimeChange => 'prayer_time_change',
      _TypeFilter.event => 'event',
      _TypeFilter.urgent => 'urgent',
      _TypeFilter.info => 'info',
      _TypeFilter.other => 'other',
      _TypeFilter.all => null,
    };
    if (type != null) q = q.where('type', isEqualTo: type);

    switch (_visibilityFilter) {
      case _VisibilityFilter.visible:
        q = q.where('publicVisible', isEqualTo: true);
        break;
      case _VisibilityFilter.hidden:
        q = q.where('publicVisible', isEqualTo: false);
        break;
      case _VisibilityFilter.all:
        break;
    }

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
      final mergedRows = await Future.wait(
        snap.docs.map((doc) async {
          final metaSnap = await doc.reference
              .collection('admin_meta')
              .doc('meta')
              .get();
          final meta = metaSnap.data();
          return _MergedNotificationRow(
            id: doc.id,
            root: doc,
            data: <String, dynamic>{...doc.data(), if (meta != null) ...meta},
            legacy: meta == null,
          );
        }),
      );
      if (!mounted) return;
      setState(() {
        _rows.addAll(mergedRows);
        if (snap.docs.isNotEmpty) _cursor = snap.docs.last;
        if (snap.docs.length < _kPageSize) _exhausted = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDiagnostics() async {
    if (_diagnosticsLoading) return;
    setState(() {
      _diagnosticsLoading = true;
      _diagnosticsError = null;
    });
    try {
      final resp = await _functions
          .httpsCallable('getNotificationDiagnostics')
          .call<Map<Object?, Object?>>({});
      final local = await FcmService().debugSnapshot();
      if (!mounted) return;
      setState(() {
        _diagnostics = Map<String, dynamic>.from(resp.data);
        _localDiagnostics = local;
      });
    } catch (e) {
      if (mounted) setState(() => _diagnosticsError = e.toString());
    } finally {
      if (mounted) setState(() => _diagnosticsLoading = false);
    }
  }

  Future<void> _onRetry(String notifId) async {
    final row = _rows.firstWhere((d) => d.id == notifId);
    final data = row.data;
    setState(() => _busy.add(notifId));
    try {
      final targetKind = (data['target'] as Map?)?['kind'] ?? 'all_users';
      final imageUrl = data['imageUrl']?.toString();
      final broadcastType =
          data['broadcastType']?.toString() ??
          ((imageUrl != null && imageUrl.isNotEmpty) ? 'image' : 'text');
      await _functions.httpsCallable('broadcastNotification').call({
        'type': broadcastType,
        'title': data['title'],
        'body': data['body'],
        'imageUrl': imageUrl,
        'target': {'kind': targetKind},
        'deepLink': data['deepLink'],
        'idempotencyKey': data['idempotencyKey'],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(bn: 'Retry accepted', en: 'Retry accepted')),
        ),
      );
      await _loadMore(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Retry failed: $e')));
    } finally {
      if (mounted) setState(() => _busy.remove(notifId));
    }
  }

  Future<void> _onCancel(String notifId) async {
    setState(() => _busy.add(notifId));
    try {
      await _functions.httpsCallable('cancelScheduledBroadcast').call({
        'notifId': notifId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(bn: 'Cancelled', en: 'Cancelled')),
        ),
      );
      await _loadMore(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
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
                context.tr(bn: 'Superadmin only.', en: 'Superadmin only.'),
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
          context.tr(bn: 'Notification History', en: 'Notification History'),
        ),
        actions: [
          IconButton(
            tooltip: context.tr(bn: 'Refresh', en: 'Refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: _loading || _diagnosticsLoading
                ? null
                : () {
                    _loadDiagnostics();
                    _loadMore(reset: true);
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(context),
          _buildDiagnosticsCard(context),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
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
                label: Text(context.tr(bn: 'All', en: 'All')),
              ),
              ButtonSegment(
                value: _TriggerFilter.manual,
                label: Text(context.tr(bn: 'Manual', en: 'Manual')),
              ),
              ButtonSegment(
                value: _TriggerFilter.autoJamaatChange,
                label: Text(context.tr(bn: 'Auto', en: 'Auto')),
              ),
            ],
            selected: {_triggerFilter},
            onSelectionChanged: (s) {
              setState(() => _triggerFilter = s.first);
              _loadMore(reset: true);
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterDropdown<_StatusFilter>(
                width: 170,
                label: 'Status',
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(
                    value: _StatusFilter.all,
                    child: Text('All'),
                  ),
                  DropdownMenuItem(
                    value: _StatusFilter.sent,
                    child: Text('accepted'),
                  ),
                  DropdownMenuItem(
                    value: _StatusFilter.fallbackText,
                    child: Text('fallback_text'),
                  ),
                  DropdownMenuItem(
                    value: _StatusFilter.failed,
                    child: Text('failed'),
                  ),
                  DropdownMenuItem(
                    value: _StatusFilter.queued,
                    child: Text('queued'),
                  ),
                  DropdownMenuItem(
                    value: _StatusFilter.cancelled,
                    child: Text('cancelled'),
                  ),
                ],
                onChanged: (v) => setState(() => _statusFilter = v),
              ),
              _filterDropdown<_PriorityFilter>(
                width: 160,
                label: 'Priority',
                value: _priorityFilter,
                items: const [
                  DropdownMenuItem(
                    value: _PriorityFilter.all,
                    child: Text('All'),
                  ),
                  DropdownMenuItem(
                    value: _PriorityFilter.normal,
                    child: Text('normal'),
                  ),
                  DropdownMenuItem(
                    value: _PriorityFilter.high,
                    child: Text('high'),
                  ),
                  DropdownMenuItem(
                    value: _PriorityFilter.critical,
                    child: Text('critical'),
                  ),
                ],
                onChanged: (v) => setState(() => _priorityFilter = v),
              ),
              _filterDropdown<_TypeFilter>(
                width: 210,
                label: 'Type',
                value: _typeFilter,
                items: const [
                  DropdownMenuItem(value: _TypeFilter.all, child: Text('All')),
                  DropdownMenuItem(
                    value: _TypeFilter.announcement,
                    child: Text('announcement'),
                  ),
                  DropdownMenuItem(
                    value: _TypeFilter.jamaatTimeChange,
                    child: Text('jamaat_time_change'),
                  ),
                  DropdownMenuItem(
                    value: _TypeFilter.prayerTimeChange,
                    child: Text('prayer_time_change'),
                  ),
                  DropdownMenuItem(
                    value: _TypeFilter.event,
                    child: Text('event'),
                  ),
                  DropdownMenuItem(
                    value: _TypeFilter.urgent,
                    child: Text('urgent'),
                  ),
                  DropdownMenuItem(
                    value: _TypeFilter.info,
                    child: Text('info'),
                  ),
                  DropdownMenuItem(
                    value: _TypeFilter.other,
                    child: Text('other'),
                  ),
                ],
                onChanged: (v) => setState(() => _typeFilter = v),
              ),
              _filterDropdown<_VisibilityFilter>(
                width: 160,
                label: 'Visibility',
                value: _visibilityFilter,
                items: const [
                  DropdownMenuItem(
                    value: _VisibilityFilter.all,
                    child: Text('All'),
                  ),
                  DropdownMenuItem(
                    value: _VisibilityFilter.visible,
                    child: Text('visible'),
                  ),
                  DropdownMenuItem(
                    value: _VisibilityFilter.hidden,
                    child: Text('hidden'),
                  ),
                ],
                onChanged: (v) => setState(() => _visibilityFilter = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown<T>({
    required double width,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isDense: true,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        items: items,
        onChanged: (v) {
          if (v == null) return;
          onChanged(v);
          _loadMore(reset: true);
        },
      ),
    );
  }

  Widget _buildDiagnosticsCard(BuildContext context) {
    final counts = (_diagnostics?['counts'] as Map?) ?? const {};
    final local = _localDiagnostics ?? const <String, String?>{};
    final localTokenPresent = ((local['fcmToken'] ?? '').isNotEmpty)
        ? 'yes'
        : 'no';
    final permission = local['authorizationStatus'] ?? 'unknown';
    final androidEnabled = local['androidNotificationsEnabled'] ?? 'unknown';
    final detailsMaxHeight = (MediaQuery.sizeOf(context).height * 0.34)
        .clamp(180.0, 260.0)
        .toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Card(
        child: ExpansionTile(
          leading: const Icon(Icons.analytics_outlined),
          title: Text(context.tr(bn: 'FCM diagnostics', en: 'FCM diagnostics')),
          subtitle: Text(
            _diagnosticsLoading
                ? context.tr(bn: 'Loading...', en: 'Loading...')
                : (_diagnosticsError ??
                      context.tr(
                        bn: 'Topic send accepted by FCM is not receipt.',
                        en: 'Topic send accepted by FCM is not receipt.',
                      )),
          ),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: detailsMaxHeight),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(
                  children: [
                    _diagLine(context, 'Send mode', 'topic: all_users'),
                    _diagLine(
                      context,
                      'Delivery receipt',
                      'not tracked for topic sends',
                    ),
                    _diagLine(
                      context,
                      'Device token docs',
                      _countText(counts, 'deviceTokenDocs'),
                    ),
                    _diagLine(
                      context,
                      'User token docs',
                      _countText(counts, 'userTokenDocs'),
                    ),
                    _diagLine(
                      context,
                      'This device permission',
                      '$permission; Android enabled: $androidEnabled',
                    ),
                    _diagLine(
                      context,
                      'This device FCM token',
                      localTokenPresent,
                    ),
                    if (_diagnosticsError != null)
                      _diagLine(
                        context,
                        'Diagnostics error',
                        _diagnosticsError!,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _countText(Map<dynamic, dynamic> counts, String key) {
    return counts[key]?.toString() ?? 'unknown';
  }

  Widget _diagLine(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
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
          context.tr(bn: 'No notifications.', en: 'No notifications.'),
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
                      context.tr(bn: 'End of history.', en: 'End of history.'),
                      style: TextStyle(color: Colors.grey[600]),
                    )
                  : const CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final row = _rows[i];
        return NotificationHistoryRow(
          notifId: row.id,
          data: row.data,
          legacy: row.legacy,
          onRetry: _onRetry,
          onCancel: _onCancel,
          onViewRaw: () => _showRawDrawer(row),
          busy: _busy.contains(row.id),
        );
      },
    );
  }

  void _showRawDrawer(_MergedNotificationRow row) {
    final encoder = const JsonEncoder.withIndent('  ');
    final raw = encoder.convert(
      _toJsonSafe({
        'notifId': row.id,
        'legacy': row.legacy,
        'root': row.root.data(),
        'merged': row.data,
      }),
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.35,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Raw notification JSON',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: controller,
                      child: SelectableText(
                        raw,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Object? _toJsonSafe(Object? value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is GeoPoint) {
      return {'latitude': value.latitude, 'longitude': value.longitude};
    }
    if (value is DocumentReference) return value.path;
    if (value is Iterable) return value.map(_toJsonSafe).toList();
    if (value is Map) {
      return value.map(
        (key, dynamic v) => MapEntry(key.toString(), _toJsonSafe(v)),
      );
    }
    return value;
  }
}
