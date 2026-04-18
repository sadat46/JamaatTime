import 'package:flutter/material.dart';
import '../../../core/locale_text.dart';
import '../tabs/ayat_tab.dart';

class AyatListScreen extends StatelessWidget {
  const AyatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(bn: 'আয়াত', en: 'Ayat'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const AyatTab(),
    );
  }
}
