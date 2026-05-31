import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'closet/closet_screen.dart';
import 'outfits/outfits_screen.dart';
import 'stylist/stylist_screen.dart';
import 'discover/discover_screen.dart';
import 'profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    NotificationService.tabNotifier.addListener(_onNotificationTab);
  }

  @override
  void dispose() {
    NotificationService.tabNotifier.removeListener(_onNotificationTab);
    super.dispose();
  }

  void _onNotificationTab() {
    final tab = NotificationService.tabNotifier.value;
    if (tab != null && mounted) {
      setState(() => _currentIndex = tab);
      NotificationService.tabNotifier.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          ClosetScreen(),
          OutfitsScreen(),
          StylistScreen(),
          DiscoverScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: DresserBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
