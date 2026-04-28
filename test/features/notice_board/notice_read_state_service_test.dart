import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/features/notice_board/data/notice_model.dart';
import 'package:jamaat_time/features/notice_board/data/notice_read_state_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('markRead stores a bounded LRU set', () async {
    final service = NoticeReadStateService();

    for (var i = 0; i < 505; i++) {
      await service.markRead('notice-$i');
    }

    expect(await service.isRead('notice-0'), isFalse);
    expect(await service.isRead('notice-5'), isTrue);
    expect(await service.isRead('notice-504'), isTrue);
  });

  test('markAllSeen stores newest published timestamp', () async {
    final service = NoticeReadStateService();
    final older = DateTime.utc(2026, 1, 1);
    final newer = DateTime.utc(2026, 1, 2);

    await service.markAllSeen([_notice('old', older), _notice('new', newer)]);

    expect(await service.isRead('old'), isTrue);
    expect(await service.isRead('new'), isTrue);
    expect(
      (await service.latestSeenPublishedAt())?.millisecondsSinceEpoch,
      newer.millisecondsSinceEpoch,
    );
  });

  test('hasUnreadLatest respects latest seen and explicit read id', () async {
    final service = NoticeReadStateService();
    final notice = _notice('n1', DateTime.utc(2026, 1, 3));

    expect(await service.hasUnreadLatest(notice), isTrue);
    await service.markRead('n1');
    expect(await service.hasUnreadLatest(notice), isFalse);
  });
}

NoticeModel _notice(String id, DateTime publishedAt) {
  return NoticeModel.fromMap(id, {
    'schemaVersion': 1,
    'notifId': id,
    'type': 'announcement',
    'title': id,
    'body': 'body',
    'status': 'sent',
    'publicVisible': true,
    'publishedAt': publishedAt.millisecondsSinceEpoch,
  });
}
