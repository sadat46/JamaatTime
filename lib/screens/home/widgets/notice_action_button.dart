import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/feature_flags.dart';
import '../../../core/locale_text.dart';
import '../../../features/notice_board/data/notice_model.dart';
import '../../../features/notice_board/data/notice_read_state_service.dart';
import '../../../features/notice_board/data/notice_repository.dart';
import '../../../features/notice_board/data/notice_telemetry.dart';
import '../../../features/notice_board/presentation/notice_board_screen.dart';

class NoticeActionButton extends StatefulWidget {
  const NoticeActionButton({
    super.key,
    required this.repository,
    required this.readState,
  });

  final NoticeRepository repository;
  final NoticeReadStateService readState;

  @override
  State<NoticeActionButton> createState() => _NoticeActionButtonState();
}

class _NoticeActionButtonState extends State<NoticeActionButton> {
  final ValueNotifier<bool> _hasUnread = ValueNotifier<bool>(false);
  StreamSubscription<NoticeModel?>? _latestSubscription;
  NoticeModel? _latest;
  int _unreadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant NoticeActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.readState != widget.readState) {
      _latestSubscription?.cancel();
      _latest = null;
      _hasUnread.value = false;
      _subscribe();
    }
  }

  void _subscribe() {
    if (!kNoticeBoardEnabled) {
      return;
    }
    _latestSubscription = widget.repository.watchLatest().listen((latest) {
      _latest = latest;
      _refreshUnread(latest);
    });
  }

  Future<void> _refreshUnread(NoticeModel? latest) async {
    final requestId = ++_unreadRequestId;
    final unread = await widget.readState.hasUnreadLatest(latest);
    if (!mounted ||
        requestId != _unreadRequestId ||
        latest?.id != _latest?.id) {
      return;
    }
    _hasUnread.value = unread;
  }

  Future<void> _openNoticeBoard() async {
    final latest = _latest;
    NoticeTelemetry.event('bell_open', {'latestNotifId': latest?.id});
    if (latest != null) {
      await widget.readState.markAllSeen([latest]);
      _hasUnread.value = false;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoticeBoardScreen(
          repository: widget.repository,
          readState: widget.readState,
        ),
      ),
    );
    if (!mounted) return;
    await _refreshUnread(_latest);
  }

  @override
  void dispose() {
    _latestSubscription?.cancel();
    _hasUnread.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kNoticeBoardEnabled) {
      return const SizedBox(width: 44, height: 44);
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _hasUnread,
      builder: (context, unread, _) {
        return Semantics(
          liveRegion: unread,
          label: context.tr(
            bn: unread ? 'Notice Board, new notices' : 'Notice Board',
            en: unread ? 'Notice Board, new notices' : 'Notice Board',
          ),
          button: true,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: context.tr(bn: 'Notice Board', en: 'Notice Board'),
                    onPressed: _openNoticeBoard,
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                if (unread)
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
