import 'package:flutter/material.dart';
import '../tabs/umrah_tab.dart';

/// Screen that wraps UmrahTab for navigation from the grid dashboard
class UmrahListScreen extends StatelessWidget {
  const UmrahListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ওমরাহ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const UmrahTab(),
    );
  }
}
