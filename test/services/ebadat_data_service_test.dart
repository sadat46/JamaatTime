import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/services/ebadat_data_service.dart';

const String _mockAyatsJson = '''
{
  "ayats": [
    {
      "id": 1,
      "titleBangla": "রহমতের আয়াত",
      "surahName": "যুমার",
      "surahNameArabic": "الزمر",
      "surahNumber": 39,
      "ayatNumber": "53",
      "arabicText": "قل يا عبادي",
      "banglaTransliteration": "কুল ইয়া ইবাদি",
      "banglaMeaning": "এই আয়াতে আল্লাহর রহমত নিয়ে বলা হয়েছে।",
      "reference": "সূরা যুমার ৫৩",
      "category": "তাওবা",
      "displayOrder": 1,
      "titleEnglish": "Ayat of Mercy",
      "surahNameEnglish": "Az-Zumar",
      "englishTransliteration": "Qul ya ibadi",
      "englishMeaning": "Allah's mercy covers all sins.",
      "categoryEnglish": "Repentance"
    },
    {
      "id": 2,
      "titleBangla": "ধৈর্যের আয়াত",
      "surahName": "বাকারা",
      "surahNameArabic": "البقرة",
      "surahNumber": 2,
      "ayatNumber": "153",
      "arabicText": "يا أيها الذين آمنوا",
      "banglaTransliteration": "ইয়া আইয়ুহাল্লাজিনা আমানু",
      "banglaMeaning": "ধৈর্য ও নামাজের মাধ্যমে সাহায্য চাও।",
      "reference": "সূরা বাকারা ১৫৩",
      "category": "ধৈর্য",
      "displayOrder": 2,
      "titleEnglish": "Ayat of Patience",
      "surahNameEnglish": "Al-Baqarah",
      "englishTransliteration": "Ya ayyuha alladhina amanu",
      "englishMeaning": "Seek help through patience and prayer.",
      "categoryEnglish": "Patience"
    }
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> mockAsset(String key, String content) async {
    messenger.setMockMessageHandler('flutter/assets', (
      ByteData? message,
    ) async {
      if (message == null) {
        return null;
      }
      final bytes = message.buffer.asUint8List(
        message.offsetInBytes,
        message.lengthInBytes,
      );
      final requestedKey = utf8.decode(bytes);
      if (!requestedKey.endsWith(key)) {
        return null;
      }
      final encoded = Uint8List.fromList(utf8.encode(content));
      return ByteData.view(encoded.buffer);
    });
  }

  setUp(() {
    EbadatDataService().clearCache();
  });

  tearDown(() {
    messenger.setMockMessageHandler('flutter/assets', null);
    EbadatDataService().clearCache();
  });

  test('searchAyats finds English meaning in English locale', () async {
    await mockAsset('assets/data/ayats.json', _mockAyatsJson);

    final results = await EbadatDataService().searchAyats(
      'mercy',
      locale: const Locale('en'),
    );

    expect(results.map((item) => item.id).toList(), [1]);
  });

  test('searchAyats finds Bangla meaning in Bangla locale', () async {
    await mockAsset('assets/data/ayats.json', _mockAyatsJson);

    final results = await EbadatDataService().searchAyats(
      'রহমত',
      locale: const Locale('bn'),
    );

    expect(results.map((item) => item.id).toList(), [1]);
  });

  test(
    'getAyatCategories returns English category labels in English locale',
    () async {
      await mockAsset('assets/data/ayats.json', _mockAyatsJson);

      final categories = await EbadatDataService().getAyatCategories(
        locale: const Locale('en'),
      );

      expect(categories, ['Patience', 'Repentance']);
      expect(categories.contains('তাওবা'), isFalse);
      expect(categories.contains('ধৈর্য'), isFalse);
    },
  );
}
