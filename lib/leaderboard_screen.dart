import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Palette Reference
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  // Toggles between: 'Posts', 'Users', 'Videos'
  String _activeTab = 'Posts';

  // --- THE DATA ENGINE ---
  // This grabs posts from the last 7 days and sorts them by who has the largest 'likes' array
  Future<List<Map<String, dynamic>>> _getRankings() async {
    DateTime oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

    // For now, we are wiring up the 'Posts' logic.
    // Later, you will build similar queries for 'Users' and 'Videos'.
    String typeFilter = _activeTab == 'Videos' ? 'video' : 'image';

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where('type', isEqualTo: typeFilter)
        .where('createdAt', isGreaterThanOrEqualTo: oneWeekAgo)
        .get();

    List<Map<String, dynamic>> items = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

    // Sort locally by the amount of likes!
    items.sort((a, b) {
      int likesA = (a['likes'] as List?)?.length ?? 0;
      int likesB = (b['likes'] as List?)?.length ?? 0;
      return likesB.compareTo(likesA); // Descending order
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest,
      appBar: AppBar(
        backgroundColor: c1DeepForest,
        elevation: 0,
        centerTitle: true,
        title: const Text("Weekly Leaderboard", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: Column(
        children: [
          // 1. THE INTERACTIVE TOGGLES
          _buildToggleBar(),
          const SizedBox(height: 20),

          // 2. THE DYNAMIC RANKING AREA
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _getRankings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: c3MediumSage));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text("No data for this week yet!", style: TextStyle(color: c4LightSage.withValues(alpha: 0.7), fontSize: 16)));
                }

                List<Map<String, dynamic>> rankedItems = snapshot.data!;

                return CustomScrollView(
                  slivers: [
                    // TOP 3 PODIUM
                    SliverToBoxAdapter(
                      child: _buildTopThreePodium(rankedItems),
                    ),

                    // RANKS 4 AND BELOW
                    if (rankedItems.length > 3)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              // We offset by 3 because 0, 1, and 2 are in the podium
                              int actualRank = index + 4;
                              var item = rankedItems[index + 3];
                              return _buildListRankItem(item, actualRank);
                            },
                            childCount: rankedItems.length - 3,
                          ),
                        ),
                      )
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildToggleBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: c2DeepOlive.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTabButton("Posts"),
            _buildTabButton("Users"),
            _buildTabButton("Videos"),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title) {
    bool isActive = _activeTab == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = title;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? c3MediumSage : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? c1DeepForest : c4LightSage,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTopThreePodium(List<Map<String, dynamic>> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end, // Aligns them to the bottom so the center is higher
        children: [
          // RANK 2 (Left)
          if (items.length > 1) _buildPodiumAvatar(items[1], 2, 70),

          // RANK 1 (Center)
          if (items.isNotEmpty) _buildPodiumAvatar(items[0], 1, 100),

          // RANK 3 (Right)
          if (items.length > 2) _buildPodiumAvatar(items[2], 3, 70),
        ],
      ),
    );
  }

  Widget _buildPodiumAvatar(Map<String, dynamic> item, int rank, double size) {
    String name = item['username'] ?? "Creator";
    String picUrl = item['profilePicUrl'] ?? "";
    int likes = (item['likes'] as List?)?.length ?? 0;

    return Column(
      children: [
        if (rank == 1) const Icon(Icons.workspace_premium, color: Colors.amber, size: 40), // Crown!
        if (rank != 1) Text("#$rank", style: const TextStyle(color: c4LightSage, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: rank == 1 ? Colors.amber : c3MediumSage, width: 3),
            image: picUrl.isNotEmpty ? DecorationImage(image: NetworkImage(picUrl), fit: BoxFit.cover) : null,
            color: c2DeepOlive,
          ),
          child: picUrl.isEmpty ? Icon(Icons.person, color: c4LightSage, size: size / 2) : null,
        ),
        const SizedBox(height: 12),
        Text(name, style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite, color: Colors.redAccent, size: 14),
            const SizedBox(width: 4),
            Text("$likes", style: const TextStyle(color: c4LightSage, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  Widget _buildListRankItem(Map<String, dynamic> item, int rank) {
    String name = item['username'] ?? "Creator";
    String picUrl = item['profilePicUrl'] ?? "";
    int likes = (item['likes'] as List?)?.length ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c5CreamGreen, // Light card on dark background
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Rank Number
          SizedBox(
            width: 30,
            child: Text("#$rank", style: const TextStyle(color: c1DeepForest, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          // Avatar
          CircleAvatar(
            backgroundColor: c2DeepOlive,
            backgroundImage: picUrl.isNotEmpty ? NetworkImage(picUrl) : null,
            child: picUrl.isEmpty ? const Icon(Icons.person, color: c4LightSage) : null,
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: c1DeepForest, fontWeight: FontWeight.bold, fontSize: 16)),
                Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.redAccent, size: 14),
                    const SizedBox(width: 4),
                    Text("$likes likes", style: const TextStyle(color: c2DeepOlive, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          // Interactive Action Button
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Followed $name!")));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: c1DeepForest,
              foregroundColor: c5CreamGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: const Text("Follow", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}