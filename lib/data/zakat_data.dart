import '../models/worship_guide_model.dart';

/// Complete Zakat guide with authentic references
/// Based on Hanafi Madhab with Quran and Sahih Hadith references
const WorshipGuideModel zakatGuide = WorshipGuideModel(
  id: 8,
  titleBangla: 'যাকাত',
  titleArabic: 'الزكاة',
  titleEnglish: 'Zakat (Obligatory Charity)',
  introduction:
      'যাকাত ইসলামের তৃতীয় স্তম্ভ। নির্দিষ্ট পরিমাণ (নিসাব) সম্পদের মালিক হলে এবং এক চান্দ্র বছর পূর্ণ হলে যাকাত ফরজ হয়। যাকাত আদায়ে সম্পদ পবিত্র হয় এবং বরকত বৃদ্ধি পায়।',
  keyVerse:
      'خُذْ مِنْ أَمْوَالِهِمْ صَدَقَةً تُطَهِّرُهُمْ وَتُزَكِّيهِم بِهَا',
  keyVerseReference: 'সূরা আত-তাওবাহ ৯:১০৩',
  conditions: [
    'মুসলমান হওয়া',
    'স্বাধীন হওয়া (দাস না হওয়া)',
    'বালেগ হওয়া (হানাফি মতে)',
    'আকেল (সুস্থ মস্তিষ্ক) হওয়া (হানাফি মতে)',
    'নিসাব পরিমাণ সম্পদের মালিক হওয়া',
    'সম্পদের উপর এক চান্দ্র বছর (হাওল) অতিবাহিত হওয়া',
    'সম্পদ মৌলিক প্রয়োজনের অতিরিক্ত হওয়া',
    'ঋণমুক্ত থাকা বা ঋণ বাদ দিয়ে নিসাব থাকা',
  ],
  fardActs: [
    'নিসাব পরিমাণ সম্পদে ২.৫% যাকাত আদায় করা',
    'যাকাতের নিয়ত করা',
    'যাকাত প্রাপ্য ব্যক্তিদের হাতে পৌঁছানো',
  ],
  sunnahActs: [
    'রমজান মাসে যাকাত আদায় করা',
    'গোপনে যাকাত দেওয়া',
    'নিকটাত্মীয়দের অগ্রাধিকার দেওয়া (যদি তারা প্রাপ্য হয়)',
    'উত্তম ও হালাল সম্পদ থেকে যাকাত দেওয়া',
  ],
  steps: [
    WorshipStep(
      stepNumber: 1,
      titleBangla: 'নিসাব নির্ধারণ',
      instruction:
          '''যাকাত ফরজ হওয়ার জন্য নিসাব পরিমাণ সম্পদ থাকতে হবে:

• স্বর্ণ: ৮৭.৪৮ গ্রাম (৭.৫ তোলা/ভরি)
• রূপা: ৬১২.৩৬ গ্রাম (৫২.৫ তোলা/ভরি)
• নগদ টাকা: রূপার নিসাবের সমপরিমাণ মূল্য

বর্তমানে নগদ টাকার ক্ষেত্রে রূপার নিসাব অনুসরণ করা হয় কারণ এতে গরীবদের বেশি উপকার হয়।''',
      references: [
        Reference(source: 'আবু দাউদ', citation: '১৫৭৩', grading: 'সহীহ'),
      ],
      isFard: true,
    ),
    WorshipStep(
      stepNumber: 2,
      titleBangla: 'হাওল (এক বছর) গণনা',
      instruction:
          'নিসাব পরিমাণ সম্পদ এক চান্দ্র বছর (৩৫৪ দিন) স্থায়ী থাকলে যাকাত ফরজ হয়। বছরের শুরু ও শেষে নিসাব থাকলেই যথেষ্ট, মাঝে কমলেও সমস্যা নেই।',
      isFard: true,
    ),
    WorshipStep(
      stepNumber: 3,
      titleBangla: 'যাকাতযোগ্য সম্পদ হিসাব',
      instruction:
          '''যেসব সম্পদে যাকাত ফরজ:

• স্বর্ণ ও রূপা (অলংকার সহ)
• নগদ টাকা ও ব্যাংক ব্যালেন্স
• ব্যবসায়িক পণ্য (ক্রয়মূল্যে)
• শেয়ার ও বন্ড (বাজার মূল্যে)
• ভাড়ার আয় (যদি জমা থাকে)
• ঋণ (যা ফেরত পাওয়ার সম্ভাবনা আছে)''',
      isFard: true,
    ),
    WorshipStep(
      stepNumber: 4,
      titleBangla: 'যাকাত হিসাব (২.৫%)',
      instruction:
          '''যাকাতের হার:

• স্বর্ণ/রূপা/নগদ: ২.৫% (১/৪০ অংশ)
• কৃষি ফসল (বৃষ্টির পানিতে): ১০% (১/১০ অংশ)
• কৃষি ফসল (সেচের পানিতে): ৫% (১/২০ অংশ)
• খনিজ সম্পদ: ২০% (১/৫ অংশ)

হিসাব: মোট যাকাতযোগ্য সম্পদ × ০.০২৫ = যাকাতের পরিমাণ''',
      references: [
        Reference(source: 'বুখারী', citation: '১৪৫৪', grading: 'সহীহ'),
        Reference(source: 'মুসলিম', citation: '৯৭৯', grading: 'সহীহ'),
      ],
      isFard: true,
    ),
    WorshipStep(
      stepNumber: 5,
      titleBangla: 'যাকাত গ্রহীতা নির্বাচন',
      arabicText:
          'إِنَّمَا الصَّدَقَاتُ لِلْفُقَرَاءِ وَالْمَسَاكِينِ وَالْعَامِلِينَ عَلَيْهَا وَالْمُؤَلَّفَةِ قُلُوبُهُمْ وَفِي الرِّقَابِ وَالْغَارِمِينَ وَفِي سَبِيلِ اللَّهِ وَابْنِ السَّبِيلِ',
      transliteration:
          'ইন্নামাস সাদাকাতু লিলফুকারায়ি ওয়াল মাসাকীনি ওয়াল আমিলীনা আলাইহা ওয়াল মুআল্লাফাতি কুলূবুহুম ওয়া ফির রিকাবি ওয়াল গারিমীনা ওয়া ফী সাবীলিল্লাহি ওয়াবনিস সাবীল',
      meaning:
          'যাকাত কেবল ফকির, মিসকিন, যাকাত আদায়কারী, মন জয় করার জন্য, দাসমুক্তিতে, ঋণগ্রস্তদের, আল্লাহর পথে এবং মুসাফিরদের জন্য।',
      instruction:
          '''কুরআনে বর্ণিত ৮ প্রকার যাকাত গ্রহীতা:

১. ফকির (الفقراء) - যাদের কিছুই নেই
২. মিসকিন (المساكين) - যাদের আয় প্রয়োজনের তুলনায় কম
৩. আমিল (العاملين عليها) - যাকাত সংগ্রহকারী
৪. মুআল্লাফাতুল কুলূব (المؤلفة قلوبهم) - নওমুসলিম/ইসলামের প্রতি আকৃষ্ট
৫. রিকাব (في الرقاب) - দাসমুক্তির জন্য
৬. গারিমীন (الغارمين) - ঋণগ্রস্ত
৭. ফী সাবীলিল্লাহ (في سبيل الله) - আল্লাহর পথে জিহাদকারী
৮. ইবনুস সাবীল (ابن السبيل) - বিপদগ্রস্ত মুসাফির''',
      references: [
        Reference(source: 'সূরা তাওবাহ', citation: '৯:৬০'),
      ],
      isFard: true,
    ),
    WorshipStep(
      stepNumber: 6,
      titleBangla: 'যাকাত প্রদান',
      instruction:
          '''যাকাত আদায়ের নিয়ম:

• নিয়ত করে দিতে হবে (দেওয়ার সময় বা আলাদা রাখার সময়)
• সরাসরি প্রাপককে দেওয়া উত্তম
• বিশ্বস্ত প্রতিষ্ঠানের মাধ্যমেও দেওয়া যায়
• এক খাতে বা একাধিক খাতে দেওয়া যায়
• এক ব্যক্তি বা একাধিক ব্যক্তিকে দেওয়া যায়''',
      isFard: true,
    ),
  ],
  commonMistakes: [
    'অলংকারের যাকাত না দেওয়া - ব্যবহৃত অলংকারেও যাকাত ফরজ',
    'ঋণ বাদ না দিয়ে যাকাত হিসাব করা',
    'চান্দ্র বছরের বদলে সৌর বছর ধরা',
    'যাকাত নিজের পরিবারকে দেওয়া (যাদের ভরণপোষণ ওয়াজিব)',
    'সাইয়্যেদ বংশকে যাকাত দেওয়া',
    'ধনী ব্যক্তিকে যাকাত দেওয়া',
    'যাকাতের নিয়ত ছাড়া দান করা',
  ],
  specialRulings: [
    'অলংকারের যাকাত - হানাফি মতে ব্যবহৃত স্বর্ণ-রূপার অলংকারেও যাকাত ফরজ',
    'ব্যবসায়িক পণ্য - ক্রয়মূল্য বা বাজারমূল্য যেটা কম সেটাতে যাকাত',
    'বাড়ি/গাড়ি - ব্যক্তিগত ব্যবহারের জন্য হলে যাকাত নেই, ব্যবসার জন্য হলে আছে',
    'শেয়ার - বাজারমূল্যের উপর যাকাত',
    'প্রভিডেন্ট ফান্ড - হাতে পাওয়ার পর বিগত বছরগুলোর যাকাত দিতে হবে',
    'যে সম্পদ হাতে নেই - যেমন আটকে থাকা টাকা, হাতে পেলে যাকাত দিতে হবে',
  ],
  invalidators: [
    'নিসাবের কম সম্পদ হলে যাকাত ফরজ হয় না',
    'মৌলিক প্রয়োজনীয় সম্পদে যাকাত নেই (বাসস্থান, যানবাহন, কাপড়)',
    'এক বছর পূর্ণ না হলে যাকাত ফরজ হয় না',
  ],
  references: [
    Reference(
      source: 'সূরা তাওবাহ',
      citation: '৯:১০৩',
      fullText:
          'তাদের সম্পদ থেকে সদকা (যাকাত) নাও, যা তাদের পবিত্র করবে এবং পরিশুদ্ধ করবে।',
    ),
    Reference(
      source: 'বুখারী',
      citation: '৮',
      fullText:
          'ইসলাম পাঁচটি স্তম্ভের উপর প্রতিষ্ঠিত... তৃতীয়: যাকাত আদায় করা।',
      grading: 'সহীহ',
    ),
    Reference(
      source: 'বুখারী',
      citation: '১৪৫৪',
      fullText: 'রূপায় চল্লিশ ভাগের এক ভাগ যাকাত।',
      grading: 'সহীহ',
    ),
    Reference(
      source: 'মুসলিম',
      citation: '১০৭২',
      fullText:
          'সদকা (যাকাত) মুহাম্মাদ (সা.) ও তাঁর বংশধরদের জন্য হালাল নয়।',
      grading: 'সহীহ',
    ),
    Reference(
      source: 'সূরা তাওবাহ',
      citation: '৯:৬০',
      fullText: 'যাকাত কেবল ফকির, মিসকিন... এদের জন্য।',
    ),
  ],
);

/// Nisab values (these should be updated with current prices)
class ZakatNisab {
  static const double goldGrams = 87.48; // 7.5 tola
  static const double silverGrams = 612.36; // 52.5 tola
  static const double zakatRate = 0.025; // 2.5%
}

/// Zakat calculator model
class ZakatCalculation {
  final double goldValue;
  final double silverValue;
  final double cashValue;
  final double businessValue;
  final double otherValue;
  final double debtsOwed;
  final double totalAssets;
  final double zakatableAmount;
  final double zakatDue;
  final bool isZakatRequired;

  ZakatCalculation({
    required this.goldValue,
    required this.silverValue,
    required this.cashValue,
    required this.businessValue,
    required this.otherValue,
    required this.debtsOwed,
  })  : totalAssets =
            goldValue + silverValue + cashValue + businessValue + otherValue,
        zakatableAmount = (goldValue +
                silverValue +
                cashValue +
                businessValue +
                otherValue -
                debtsOwed)
            .clamp(0, double.infinity),
        zakatDue = ((goldValue +
                        silverValue +
                        cashValue +
                        businessValue +
                        otherValue -
                        debtsOwed)
                    .clamp(0, double.infinity) *
                ZakatNisab.zakatRate),
        isZakatRequired = (goldValue +
                    silverValue +
                    cashValue +
                    businessValue +
                    otherValue -
                    debtsOwed) >
            0;
}

/// Who cannot receive Zakat
const List<String> zakatIneligibleRecipients = [
  'নবী (সা.) এর বংশধর (বনু হাশিম) - মুসলিম ১০৭২',
  'ধনী ব্যক্তি (যার কাছে নিসাব পরিমাণ সম্পদ আছে)',
  'নিজের স্ত্রী, সন্তান, পিতা-মাতা, দাদা-দাদী (যাদের ভরণপোষণ ওয়াজিব)',
  'অমুসলিম (যাকাতের ক্ষেত্রে, সাধারণ দানে দেওয়া যায়)',
  'মসজিদ নির্মাণ বা ধর্মীয় প্রতিষ্ঠানে (সরাসরি, তবে দরিদ্র ছাত্রদের দেওয়া যায়)',
];

/// Zakat-exempt assets
const List<String> zakatExemptAssets = [
  'বসবাসের ঘর/বাড়ি',
  'ব্যক্তিগত ব্যবহারের যানবাহন',
  'পরিধেয় কাপড়-চোপড়',
  'গৃহস্থালি আসবাবপত্র',
  'পেশাগত যন্ত্রপাতি/সরঞ্জাম',
  'মূল্যবান পাথর (হীরা, পান্না - যদি ব্যবসার জন্য না হয়)',
];
