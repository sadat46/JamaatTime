import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/models/ebadat_topic.dart';

void main() {
  const topic = EbadatTopic(
    id: 100,
    titleBangla: 'ঈমান',
    titleEnglish: 'Eman (Faith)',
    icon: Icons.favorite,
  );

  test('getTitle returns Bengali for bn locale', () {
    expect(topic.getTitle(const Locale('bn')), 'ঈমান');
  });

  test('getTitle returns English for en locale', () {
    expect(topic.getTitle(const Locale('en')), 'Eman (Faith)');
  });
}
