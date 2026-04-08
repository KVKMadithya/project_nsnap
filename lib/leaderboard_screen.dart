import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- NEW IMPORTS FOR PROPER ROUTING ---
import '../posting/post_detail_screen.dart';
import '../posting/single_video_screen.dart';
import 'view_profile_screen.dart';

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

  // --- THE COMPLETELY REBUILT DATA ENGINE ---
  Future<List<Map<String, dynamic>>> _getRankings() async {
    // 1. Fetch the LATEST user data first.
    QuerySnapshot userSnapshot = await FirebaseFirestore.instance.collection('users').get();
    Map<String, Map<String, dynamic>> latestUsersMap = {};
    for (var doc in userSnapshot.docs) {
      latestUsersMap[doc.id] = doc.data() as Map<String, dynamic>;
    }

    // 2. USERS TAB: Rank by TOTAL LIKES across all their posts
    if (_activeTab == 'Users') {
      QuerySnapshot allPosts = await FirebaseFirestore.instance.collection('posts').get();

      // Calculate total likes per user safely
      Map<String, int> userTotalLikes = {};
      for (var doc in allPosts.docs) {
        var pData = doc.data() as Map<String, dynamic>;
        String uid = pData['userId'];
        // Safely extract the length of the likes array
        int likes = (pData['likes'] as List?)?.length ?? 0;
        userTotalLikes[uid] = (userTotalLikes[uid] ?? 0) + likes;
      }

      // Build the list using the latest user profiles
      List<Map<String, dynamic>> items = [];
      userTotalLikes.forEach((uid, totalLikes) {
        if (latestUsersMap.containsKey(uid)) {
          var user = latestUsersMap[uid]!;
          items.add({
            'userId': uid,
            'username': user['username'] ?? "Nsnap User",
            'profilePicUrl': user['profilePicUrl'] ?? "",
            'statCount': totalLikes,
          });
        }
      });

      // Sort by highest total likes
      items.sort((a, b) => b['statCount'].compareTo(a['statCount']));
      return items;
    }

    // 3. POSTS or VIDEOS TAB: Rank by highest likes on a SINGLE post
    else {
      String typeFilter = _activeTab == 'Videos' ? 'video' : 'image';

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('type', isEqualTo: typeFilter)
          .get();

      List<Map<String, dynamic>> items = [];
      for (var doc in snapshot.docs) {
        var postData = doc.data() as Map<String, dynamic>;
        String uid = postData['userId'];

        // OVERRIDE the post's cached username/pic with the LATEST data from our map
        if (latestUsersMap.containsKey(uid)) {
          postData['username'] = latestUsersMap[uid]!['username'];
          postData['profilePicUrl'] = latestUsersMap[uid]!['profilePicUrl'];
        }

        // --- EXTRACT POST MEDIA FOR UI ---
        String previewUrl = '';
        if (postData['thumbnailUrl'] != null && postData['thumbnailUrl'].toString().isNotEmpty) {
          previewUrl = postData['thumbnailUrl'];
        } else if (postData['imageUrls'] != null && (postData['imageUrls'] as List).isNotEmpty) {
          previewUrl = postData['imageUrls'][0];
        }
        postData['mediaUrl'] = previewUrl;
        postData['postId'] = doc.id; // Needed for routing

        // Save the like count explicitly
        postData['statCount'] = (postData['likes'] as List?)?.length ?? 0;
        items.add(postData);
      }

      // Sort by highest likes on that specific post
      items.sort((a, b) => b['statCount'].compareTo(a['statCount']));
      return items;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest,
      appBar: AppBar(
        backgroundColor: c1DeepForest,
        elevation: 0,
        centerTitle: true,
        title: const Text("Top Rankings", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold, fontSize: 20)),
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
                  return Center(child: Text("No data available yet!", style: TextStyle(color: c4LightSage.withValues(alpha: 0.7), fontSize: 16)));
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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (items.length > 1) _buildPodiumItem(items[1], 2, 70),
          if (items.isNotEmpty) _buildPodiumItem(items[0], 1, 100),
          if (items.length > 2) _buildPodiumItem(items[2], 3, 70),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(Map<String, dynamic> item, int rank, double size) {
    bool isUserTab = _activeTab == 'Users';
    String name = item['username'] ?? "Creator";
    String picUrl = item['profilePicUrl'] ?? "";
    String mediaUrl = item['mediaUrl'] ?? "";
    int statCount = item['statCount'] ?? 0;

    // Use profile pic for Users tab, use post thumbnail for Posts/Videos tabs
    String displayImage = isUserTab ? picUrl : mediaUrl;

    return Column(
      children: [
        if (rank == 1) const Icon(Icons.workspace_premium, color: Colors.amber, size: 40),
        if (rank != 1) Text("#$rank", style: const TextStyle(color: c4LightSage, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            // Circle for users, rounded square for posts
            shape: isUserTab ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isUserTab ? null : BorderRadius.circular(16),
            border: Border.all(color: rank == 1 ? Colors.amber : c3MediumSage, width: 3),
            color: c2DeepOlive,
            image: displayImage.isNotEmpty
                ? DecorationImage(image: CachedNetworkImageProvider(displayImage), fit: BoxFit.cover)
                : null,
          ),
          child: displayImage.isEmpty
              ? Icon(isUserTab ? Icons.person : Icons.image, color: c4LightSage, size: size / 2)
              : null,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: size + 20,
          child: Text(
            name,
            style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite, color: Colors.redAccent, size: 14),
            const SizedBox(width: 4),
            Text("$statCount", style: const TextStyle(color: c4LightSage, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  Widget _buildListRankItem(Map<String, dynamic> item, int rank) {
    bool isUserTab = _activeTab == 'Users';
    String name = item['username'] ?? "Creator";
    String picUrl = item['profilePicUrl'] ?? "";
    String mediaUrl = item['mediaUrl'] ?? "";
    int statCount = item['statCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c5CreamGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text("#$rank", style: const TextStyle(color: c1DeepForest, fontWeight: FontWeight.bold, fontSize: 16)),
          ),

          // Show Avatar for Users, Thumbnail for Posts
          isUserTab
              ? CircleAvatar(
            backgroundColor: c2DeepOlive,
            backgroundImage: picUrl.isNotEmpty ? CachedNetworkImageProvider(picUrl) : null,
            child: picUrl.isEmpty ? const Icon(Icons.person, color: c4LightSage) : null,
          )
              : Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: c2DeepOlive,
              borderRadius: BorderRadius.circular(8),
              image: mediaUrl.isNotEmpty ? DecorationImage(image: CachedNetworkImageProvider(mediaUrl), fit: BoxFit.cover) : null,
            ),
            child: mediaUrl.isEmpty ? const Icon(Icons.image, color: c4LightSage, size: 20) : null,
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: c1DeepForest, fontWeight: FontWeight.bold, fontSize: 16)),
                Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.redAccent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                        isUserTab ? "$statCount total likes" : "$statCount likes",
                        style: const TextStyle(color: c2DeepOlive, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // --- SMART ROUTING CONNECTED ---
              if (isUserTab) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ViewProfileScreen(targetUserId: item['userId'])));
              } else {
                if (item['type'] == 'video') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SingleVideoScreen(postData: item, postId: item['postId'])));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postData: item, postId: item['postId'])));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: c1DeepForest,
              foregroundColor: c5CreamGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: Text(isUserTab ? "Profile" : "View", style: const TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}