import 'package:flutter/material.dart';
import 'tabs/umrah_tab.dart';
import 'tabs/ayat_tab.dart';
import 'tabs/dua_tab.dart';
import '../../services/bookmark_service.dart';

class EbadatScreen extends StatefulWidget {
  const EbadatScreen({super.key});

  @override
  State<EbadatScreen> createState() => _EbadatScreenState();
}

class _EbadatScreenState extends State<EbadatScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize BookmarkService to load user's bookmarks
    BookmarkService().initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        title: const Text('ইবাদত'),
        centerTitle: true,
        backgroundColor: const Color(0xFF388E3C),
        foregroundColor: Colors.white,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              text: 'ওমরাহ',
              icon: Icon(Icons.flight_takeoff),
            ),
            Tab(
              text: 'আয়াত',
              icon: Icon(Icons.menu_book),
            ),
            Tab(
              text: 'দোয়া',
              icon: Icon(Icons.pan_tool),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          UmrahTab(),
          AyatTab(),
          DuaTab(),
        ],
      ),
    );
  }
}
