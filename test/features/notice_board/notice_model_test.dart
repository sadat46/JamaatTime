import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/features/notice_board/data/notice_model.dart';

void main() {
  test('parses v1 public notice fields safely', () {
    final published = DateTime.utc(2026, 1, 2, 3, 4);
    final notice = NoticeModel.fromMap('n1', {
      'schemaVersion': 1,
      'notifId': 'n1',
      'type': 'announcement',
      'title': 'Title',
      'body': 'Body',
      'status': 'sent',
      'publicVisible': true,
      'priority': 'high',
      'pinned': true,
      'publishedAt': Timestamp.fromDate(published),
      'localizedVariants': {
        'bn': {'title': 'BN title', 'body': 'BN body'},
      },
    });

    expect(notice.id, 'n1');
    expect(notice.isReadablePublic, isTrue);
    expect(notice.priority, 'high');
    expect(notice.pinned, isTrue);
    expect(notice.publishedAt?.toUtc(), published);
    expect(notice.localizedTitle(const Locale('bn')), 'BN title');
    expect(notice.localizedBody(const Locale('en')), 'Body');
  });

  test('future schema renders unsupported placeholder', () {
    final notice = NoticeModel.fromMap('n2', {
      'schemaVersion': 2,
      'title': 'New format',
    });

    expect(notice.unsupported, isTrue);
    expect(notice.title, contains('Update app'));
    expect(notice.isReadablePublic, isTrue);
  });

  test('expired visible notice is not readable', () {
    final notice = NoticeModel.fromMap('n3', {
      'schemaVersion': 1,
      'status': 'sent',
      'publicVisible': true,
      'expiresAt': DateTime.now()
          .subtract(const Duration(minutes: 1))
          .millisecondsSinceEpoch,
    });

    expect(notice.isExpired, isTrue);
    expect(notice.isReadablePublic, isFalse);
  });
}
