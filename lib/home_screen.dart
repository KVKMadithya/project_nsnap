import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'home_swipe_wrapper.dart';
import 'video_feed_screen.dart';
import 'leaderboard_screen.dart';
import '../ar_features/ar_drop_screen.dart';

// Palette
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  List<Widget> get _screens => [
    const HomeSwipeWrapper(),
    VideoFeedScreen(isActive: _currentIndex == 1),
    const SizedBox(), // Placeholder for the AR Camera trigger
    const LeaderboardScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final navBarWidth = screenWidth - 48;
    final tabWidth = navBarWidth / 5;

    return Scaffold(
      backgroundColor: c1DeepForest,
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // THE FLOATING NAV BAR
          Positioned(
            bottom: 45,
            left: 24,
            right: 24,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: (_currentIndex == 1 || _currentIndex == 2)
                    ? c2DeepOlive.withValues(alpha: 0.6)
                    : c2DeepOlive,
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    left: tabWidth * _currentIndex,
                    top: 0,
                    bottom: 0,
                    child: SizedBox(
                      width: tabWidth,
                      child: Column(
                        children: [
                          Container(
                            width: 35,
                            height: 4,
                            decoration: BoxDecoration(
                                color: c5CreamGreen,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: c5CreamGreen.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ]
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    c5CreamGreen.withValues(alpha: 0.15),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(Icons.home_filled, Icons.home_outlined, 0),
                      _buildNavItem(Icons.play_circle_fill, Icons.play_circle_outline, 1),
                      _buildNavItem(Icons.camera_alt, Icons.camera_alt_outlined, 2),
                      _buildNavItem(Icons.emoji_events, Icons.emoji_events_outlined, 3),
                      _buildNavItem(Icons.person, Icons.person_outline, 4),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData activeIcon, IconData inactiveIcon, int index) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (index == 2) {
          // Open AR Camera full-screen
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (context) => const ARDropScreen(),
            ),
          );
        } else {
          // Normal tab switching
          setState(() => _currentIndex = index);
        }
      },
      child: SizedBox(
        width: (MediaQuery.of(context).size.width - 48) / 5,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              isSelected ? activeIcon : inactiveIcon,
              key: ValueKey<int>(_currentIndex == index ? 1 : 0),
              size: isSelected ? 30 : 26,
              color: isSelected ? c5CreamGreen : c4LightSage.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}