import 'package:flutter/material.dart';
import 'home_feed_screen.dart';
import 'explore_screen.dart';

class HomeSwipeWrapper extends StatelessWidget {
  const HomeSwipeWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // PageView automatically handles the horizontal swiping gesture!
    return PageView(
      children: const [
        HomeFeedScreen(), // Screen 1: The scrolling feed
        ExploreScreen(),  // Screen 2: Swipe left to see the search grid
      ],
    );
  }
}