import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/locale_text.dart';
import '../data/notice_model.dart';
import '../data/notice_read_state_service.dart';
import '../data/notice_repository.dart';
import '../data/notice_telemetry.dart';
import 'notice_detail_screen.dart';

enum _NoticeFilter { all, prayer, events, announcements }

class NoticeBoardScreen extends StatefulWidget {
  const NoticeBoardScreen({super.key, this.repository, this.readState});

  final NoticeRepository? repository;
  final NoticeReadStateService? readState;

  @override
  State<NoticeBoardScreen> createState() => _NoticeBoardScreenState();
}

class _NoticeBoardScreenState extends State<NoticeBoardScreen> {
  static const int _publicBoardCap = 200;

  late final NoticeRepository _repository =
      widget.repository ?? NoticeRepository();
  late final NoticeReadStateService _readState =
      widget.readState ?? NoticeReadStateService();
  final ScrollController _scrollController = ScrollController();

  final List<NoticeModel> _notices = [];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _loading = false;
  bool _loadingMore = false;
  bool _exhausted = false;
  bool _fromCache = false;
  Object? _error;
  _NoticeFilter _filter = _NoticeFilter.all;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _loadingMore || _exhausted) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 360) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
      _exhausted = false;
      _cursor = null;
      _fromCache = false;
      _notices.clear();
    });
    try {
      final page = await _repository.fetchPage();
      if (!mounted) return;
      setState(() {
        _notices.addAll(page.items);
        _cursor = page.cursor;
        _fromCache = page.fromCache;
        _exhausted = page.cursor == null || page.items.length < 20;
      });
      await _readState.markAllSeen(_notices);
      NoticeTelemetry.event('notice_board_open', {
        'count': _notices.length,
        'fromCache': page.fromCache,
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadNextPage() async {
    final cursor = _cursor;
    if (cursor == null) return;
    if (_notices.length >= _publicBoardCap) {
      setState(() => _exhausted = true);
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final page = await _repository.fetchPage(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _notices.addAll(page.items.take(_publicBoardCap - _notices.length));
        _cursor = page.cursor;
        _exhausted =
            _notices.length >= _publicBoardCap ||
            page.cursor == null ||
            page.items.length < 20;
      });
    } catch (_) {
      if (mounted) setState(() => _exhausted = true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotices();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(bn: 'Notice Board', en: 'Notice Board')),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _NoticeSkeletonList(),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(error: _error, onRetry: _loadFirstPage),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(fromCache: _fromCache),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final notice = filtered[index];
                    return _NoticeCard(
                      notice: notice,
                      onTap: () => _openNotice(notice),
                      onShare: () => _share(notice),
                    );
                  },
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Center(
                  child: _loadingMore
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : Text(
                          _exhausted
                              ? context.tr(
                                  bn: 'End of notices',
                                  en: 'End of notices',
                                )
                              : '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_fromCache)
            Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  context.tr(
                    bn: 'Showing cached notices. Pull to refresh.',
                    en: 'Showing cached notices. Pull to refresh.',
                  ),
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(context, _NoticeFilter.all, 'All'),
                _chip(context, _NoticeFilter.prayer, 'Prayer'),
                _chip(context, _NoticeFilter.events, 'Events'),
                _chip(context, _NoticeFilter.announcements, 'Announcements'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, _NoticeFilter value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: _filter == value,
        label: Text(label),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  List<NoticeModel> _filteredNotices() {
    return _notices
        .where((notice) {
          return switch (_filter) {
            _NoticeFilter.all => true,
            _NoticeFilter.prayer =>
              notice.type == 'prayer_time_change' ||
                  notice.type == 'jamaat_time_change',
            _NoticeFilter.events => notice.type == 'event',
            _NoticeFilter.announcements => notice.type == 'announcement',
          };
        })
        .toList(growable: false);
  }

  Future<void> _openNotice(NoticeModel notice) async {
    NoticeTelemetry.event('notice_card_tap', {'notifId': notice.id});
    await _readState.markRead(notice.id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoticeDetailScreen(
          notifId: notice.id,
          repository: _repository,
          readState: _readState,
        ),
      ),
    );
  }

  Future<void> _share(NoticeModel notice) async {
    NoticeTelemetry.event('notice_share', {'notifId': notice.id});
    await Share.share(
      '${notice.title}\n\n${notice.body}\n\njamaat-time://notice/${notice.id}',
      subject: notice.title,
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.notice,
    required this.onTap,
    required this.onShare,
  });

  final NoticeModel notice;
  final VoidCallback onTap;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final thumbCacheSize = (86 * dpr).round();
    final published = notice.publishedAt ?? notice.sentAt ?? notice.createdAt;
    final title = notice.localizedTitle(locale);
    final body = notice.localizedBody(locale);
    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: title,
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: notice.pinned ? 3 : 1,
          child: InkWell(
            onTap: onTap,
            onLongPress: onShare,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (notice.imageUrl != null && notice.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        notice.imageUrl!,
                        width: 86,
                        height: 86,
                        cacheWidth: thumbCacheSize,
                        cacheHeight: thumbCacheSize,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _ThumbFallback(),
                      ),
                    ),
                  if (notice.imageUrl != null && notice.imageUrl!.isNotEmpty)
                    const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (notice.priority == 'high' ||
                                notice.priority == 'critical')
                              _MiniBadge(label: notice.priority),
                            if (notice.pinned)
                              const _MiniBadge(label: 'pinned'),
                          ],
                        ),
                        if (notice.priority == 'high' ||
                            notice.priority == 'critical' ||
                            notice.pinned)
                          const SizedBox(height: 6),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              _sourceIcon(notice.triggerSource),
                              size: 15,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _sourceLabel(notice.triggerSource),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (published != null) ...[
                              const Text('  |  '),
                              Tooltip(
                                message: DateFormat.yMMMMEEEEd(
                                  locale.toLanguageTag(),
                                ).add_jm().format(published.toLocal()),
                                child: Text(
                                  _relativeTime(context, published),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                            const Spacer(),
                            Semantics(
                              label: 'Share notice',
                              button: true,
                              child: IconButton(
                                tooltip: context.tr(bn: 'Share', en: 'Share'),
                                onPressed: onShare,
                                icon: const Icon(
                                  Icons.share_outlined,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _sourceIcon(String source) {
    return switch (source) {
      'auto_prayer' => Icons.mosque_outlined,
      'auto_jamaat' || 'auto_jamaat_change' => Icons.schedule,
      'system' => Icons.settings_suggest_outlined,
      _ => Icons.campaign_outlined,
    };
  }

  String _sourceLabel(String source) {
    return switch (source) {
      'auto_prayer' => 'Prayer',
      'auto_jamaat' || 'auto_jamaat_change' => 'Auto',
      'system' => 'System',
      _ => 'Manual',
    };
  }

  String _relativeTime(BuildContext context, DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return context.tr(bn: 'now', en: 'now');
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat.MMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(value.toLocal());
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NoticeSkeletonList extends StatelessWidget {
  const _NoticeSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return Container(
          height: 128,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 52),
            const SizedBox(height: 12),
            Text(
              context.tr(
                bn: 'Could not load notices',
                en: 'Could not load notices',
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.tr(bn: 'Retry', en: 'Retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.fromCache});

  final bool fromCache;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none, size: 52),
            const SizedBox(height: 12),
            Text(
              context.tr(bn: 'No notices yet', en: 'No notices yet'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              fromCache
                  ? context.tr(
                      bn: 'No cached notices are available.',
                      en: 'No cached notices are available.',
                    )
                  : context.tr(
                      bn: 'New public announcements will appear here.',
                      en: 'New public announcements will appear here.',
                    ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.image_not_supported_outlined),
    );
  }
}
