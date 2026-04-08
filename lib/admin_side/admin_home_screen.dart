import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

// --- THE ACTUAL ADMIN SCREENS ---
import 'admin_dashboard_screen.dart';
import 'manage_users_screen.dart';
import 'manage_posts_screen.dart';
import 'admin_settings_screen.dart';

// Palette
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _pageIndex = 0;

  // A GlobalKey is required by the curved_navigation_bar to control its state
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();

  // --- CONNECTED: The list of screens the admin can navigate to ---
  final List<Widget> _adminPages = const [
    AdminDashboardScreen(),
    ManageUsersScreen(),
    ManagePostsScreen(),
    AdminSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest,

      // The body displays the currently selected page
      body: _adminPages[_pageIndex],

      // The custom curved navigation bar
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          iconTheme: const IconThemeData(color: c5CreamGreen),
        ),
        child: CurvedNavigationBar(
          key: _bottomNavigationKey,
          index: _pageIndex,
          // --- UPDATED: Increased height to the maximum comfortable size (75.0) ---
          height: 75.0,

          // --- STYLING ---
          backgroundColor: c1DeepForest,
          color: Colors.black,
          buttonBackgroundColor: c3MediumSage,
          animationDuration: const Duration(milliseconds: 300),

          // --- ICONS ---
          items: <Widget>[
            Icon(Icons.dashboard_rounded, size: 30, color: _pageIndex == 0 ? Colors.black : c5CreamGreen),
            Icon(Icons.people_outline, size: 30, color: _pageIndex == 1 ? Colors.black : c5CreamGreen),
            Icon(Icons.dynamic_feed, size: 30, color: _pageIndex == 2 ? Colors.black : c5CreamGreen),
            Icon(Icons.settings_outlined, size: 30, color: _pageIndex == 3 ? Colors.black : c5CreamGreen),
          ],

          // Action when an icon is tapped
          onTap: (index) {
            setState(() {
              _pageIndex = index;
            });
          },
        ),
      ),
    );
  }
}