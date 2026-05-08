import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/locale_text.dart';
import '../data/notice_errors.dart';
import '../data/notice_model.dart';
import '../data/notice_read_state_service.dart';
import '../data/notice_repository.dart';
import '../data/notice_telemetry.dart';

class NoticeDetailScreen extends StatefulWidget {
  const NoticeDetailScreen({
    super.key,
    required this.notifId,
    this.repository,
    this.readState,
  });

  final String notifId;
  final NoticeRepository? repository;
  final NoticeReadStateService? readState;

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  late final NoticeRepository _repository =
      widget.repository ?? NoticeRepository();
  late final NoticeReadStateService _readState =
      widget.readState ?? NoticeReadStateService();
  late Future<NoticeModel> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<NoticeModel> _load() async {
    try {
      final notice = await _repository.getById(widget.notifId);
      await _readState.markRead(notice.id);
      NoticeTelemetry.event('notice_detail_open', {'notifId': notice.id});
      return notice;
    } catch (e) {
      NoticeTelemetry.event('notice_unavailable_view', {
        'notifId': widget.notifId,
        'error': e.runtimeType.toString(),
      });
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(bn: 'Notice', en: 'Notice')),
        actions: [
          FutureBuilder<NoticeModel>(
            future: _future,
            builder: (context, snapshot) {
              final notice = snapshot.data;
              return IconButton(
                tooltip: context.tr(bn: 'Share', en: 'Share'),
                onPressed: notice == null ? null : () => _share(notice),
                icon: const Icon(Icons.share),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<NoticeModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _UnavailableState(error: snapshot.error);
          }
          return _NoticeDetailBody(
            notice: snapshot.requireData,
            onOpenDeepLink: _openDeepLink,
            onOpenImage: _openImage,
          );
        },
      ),
    );
  }

  Future<void> _share(NoticeModel notice) async {
    NoticeTelemetry.event('notice_share', {'notifId': notice.id});
    final text =
        '${notice.title}\n\n${notice.body}\n\njamaat-time://notice/${notice.id}';
    await Share.share(text, subject: notice.title);
  }

  void _openDeepLink(NoticeModel notice) {
    final link = notice.deepLink;
    if (link == null || link.isEmpty) return;
    if (link == '/home' || link.startsWith('/home?')) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(bn: 'Route will open soon.', en: 'Route will open soon.'),
        ),
      ),
    );
  }

  void _openImage(NoticeModel notice) {
    final imageUrl = notice.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _NoticeImageViewer(imageUrl: imageUrl, title: notice.title),
      ),
    );
  }
}

class _NoticeDetailBody extends StatelessWidget {
  const _NoticeDetailBody({
    required this.notice,
    required this.onOpenDeepLink,
    required this.onOpenImage,
  });

  final NoticeModel notice;
  final ValueChanged<NoticeModel> onOpenDeepLink;
  final ValueChanged<NoticeModel> onOpenImage;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final title = notice.localizedTitle(locale);
    final body = notice.localizedBody(locale);
    final published = notice.publishedAt ?? notice.sentAt ?? notice.createdAt;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (notice.imageUrl != null && notice.imageUrl!.isNotEmpty)
          Semantics(
            label: title,
            button: true,
            child: GestureDetector(
              onTap: () => onOpenImage(notice),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: _imageAspectRatio(notice),
                  child: Image.network(
                    notice.imageUrl!,
                    fit: BoxFit.cover,
                    cacheWidth: (viewportWidth * dpr).round(),
                    errorBuilder: (_, __, ___) => const _ImageFallback(),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const _ImageSkeleton();
                    },
                  ),
                ),
              ),
            ),
          ),
        if (notice.imageUrl != null && notice.imageUrl!.isNotEmpty)
          const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Badge(label: notice.priority, icon: Icons.priority_high),
            _Badge(
              label: _sourceLabel(notice.triggerSource),
              icon: Icons.campaign,
            ),
            if (notice.pinned)
              const _Badge(label: 'Pinned', icon: Icons.push_pin),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (published != null) ...[
          const SizedBox(height: 8),
          Tooltip(
            message: DateFormat.yMMMMEEEEd(
              locale.toLanguageTag(),
            ).add_jm().format(published.toLocal()),
            child: Text(
              DateFormat.yMMMd(
                locale.toLanguageTag(),
              ).add_jm().format(published.toLocal()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
        const SizedBox(height: 20),
        SelectableText(
          body,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        if (notice.deepLink != null && notice.deepLink!.isNotEmpty) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => onOpenDeepLink(notice),
            icon: const Icon(Icons.open_in_new),
            label: Text(
              context.tr(bn: 'Open related page', en: 'Open related page'),
            ),
          ),
        ],
      ],
    );
  }

  double _imageAspectRatio(NoticeModel notice) {
    final width = notice.imageWidth;
    final height = notice.imageHeight;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return 16 / 9;
    }
    return width / height;
  }

  String _sourceLabel(String source) {
    return switch (source) {
      'auto_jamaat' || 'auto_jamaat_change' => 'Auto',
      'auto_prayer' => 'Prayer',
      'system' => 'System',
      _ => 'Manual',
    };
  }
}

class _UnavailableState extends StatelessWidget {
  const _UnavailableState({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final message = switch (error) {
      NoticeNotFound() => 'Notice not found.',
      NoticeHidden() => 'Notice is unavailable or expired.',
      NoticePermissionDenied() =>
        'You do not have permission to view this notice.',
      _ => 'Could not load this notice.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_off_outlined, size: 52),
            const SizedBox(height: 12),
            Text(
              context.tr(bn: 'Notice unavailable', en: 'Notice unavailable'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                context.tr(
                  bn: 'Back to Notice Board',
                  en: 'Back to Notice Board',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeImageViewer extends StatelessWidget {
  const _NoticeImageViewer({required this.imageUrl, required this.title});

  final String imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ImageSkeleton extends StatelessWidget {
  const _ImageSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.broken_image_outlined, size: 48),
    );
  }
}
