import 'package:flutter/material.dart';
import '../tabs/ayat_tab.dart';

/// Screen that wraps AyatTab for navigation from the grid dashboard
class AyatListScreen extends StatelessWidget {
  const AyatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'আয়াত',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const AyatTab(),
    );
  }
}
