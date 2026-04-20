import 'package:flutter/material.dart';
import '../../../core/locale_text.dart';
import '../tabs/umrah_tab.dart';

class UmrahListScreen extends StatelessWidget {
  const UmrahListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(bn: 'ওমরাহ', en: 'Umrah'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: UmrahTab(),
    );
  }
}
