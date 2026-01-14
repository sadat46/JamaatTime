import 'package:flutter/material.dart';
import '../tabs/dua_tab.dart';

/// Screen that wraps DuaTab for navigation from the grid dashboard
class DuaListScreen extends StatelessWidget {
  const DuaListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'দোয়া',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const DuaTab(),
    );
  }
}
