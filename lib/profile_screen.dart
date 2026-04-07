import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'edit_profile_screen.dart';
import '../posting/create_post_screen.dart';
import '../posting/post_detail_screen.dart';
import '../posting/create_video_screen.dart';
import '../posting/create_vibe_screen.dart';
import '../posting/vibe_viewer_screen.dart';

// Palette
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest,
      body: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              // 1. The App Bar
              SliverAppBar(
                backgroundColor: c1DeepForest,
                pinned: true,
                elevation: 0,
                leading: PopupMenuButton<String>(
                  icon: const Icon(Icons.add_box_outlined, color: c5CreamGreen, size: 28),
                  color: c2DeepOlive,
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'post', child: Text("Post", style: TextStyle(color: c5CreamGreen))),
                    const PopupMenuItem(value: 'video', child: Text("Video", style: TextStyle(color: c5CreamGreen))),
                    const PopupMenuItem(value: 'vibes', child: Text("Vibes", style: TextStyle(color: c5CreamGreen))),
                  ],
                  onSelected: (value) {
                    if (value == 'post') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePostScreen()));
                    } else if (value == 'video') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateVideoScreen()));
                    } else if (value == 'vibes') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateVibeScreen()));
                    }
                  },
                ),
                title: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
                    builder: (context, snapshot) {
                      String username = "My Profile";
                      if (snapshot.hasData && snapshot.data!.exists) {
                        var data = snapshot.data!.data() as Map<String, dynamic>;
                        if (data['username'] != null && data['username'].toString().isNotEmpty) {
                          username = data['username'];
                        }
                      }
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline, color: c5CreamGreen, size: 16),
                          const SizedBox(width: 4),
                          Text(username, style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold, fontSize: 20)),
                        ],
                      );
                    }
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: c5CreamGreen, size: 28),
                    onPressed: () async {
                      await AuthService().auth.signOut();
                      await AuthService().googleSignIn.signOut();
                    },
                  )
                ],
              ),

              // 2. The Profile Info Section
              SliverToBoxAdapter(
                child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
                    builder: (context, userSnapshot) {
                      String name = "Loading...";
                      String bio = "Set up your profile!";
                      String pronouns = "";
                      String? profilePicUrl;

                      int followersCount = 0;
                      int followingCount = 0;

                      if (userSnapshot.hasData && userSnapshot.data!.exists) {
                        var data = userSnapshot.data!.data() as Map<String, dynamic>;
                        name = data['name'] ?? name;
                        bio = data['bio'] ?? bio;
                        pronouns = data['pronouns'] ?? "";
                        profilePicUrl = data['profilePicUrl'];

                        followersCount = (data['followers'] as List?)?.length ?? 0;
                        followingCount = (data['following'] as List?)?.length ?? 0;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // DYNAMIC STATS ROW
                            StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('posts')
                                    .where('userId', isEqualTo: currentUserId)
                                    .snapshots(),
                                builder: (context, postSnapshot) {
                                  int postCount = 0;
                                  int totalLikes = 0;

                                  if (postSnapshot.hasData) {
                                    postCount = postSnapshot.data!.docs.length;
                                    for (var doc in postSnapshot.data!.docs) {
                                      var postData = doc.data() as Map<String, dynamic>;
                                      List likesArray = postData['likes'] ?? [];
                                      totalLikes += likesArray.length;
                                    }
                                  }

                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // --- ACTIVE VIBE RING LOGIC ---
                                      StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('vibes')
                                              .where('userId', isEqualTo: currentUserId)
                                              .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24))))
                                              .snapshots(),
                                          builder: (context, vibeSnapshot) {
                                            bool hasActiveVibes = vibeSnapshot.hasData && vibeSnapshot.data!.docs.isNotEmpty;

                                            return GestureDetector(
                                              onTap: () {
                                                if (hasActiveVibes) {
                                                  Navigator.push(context, MaterialPageRoute(
                                                      builder: (context) => VibeViewerScreen(targetUserId: currentUserId)
                                                  ));
                                                } else {
                                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateVibeScreen()));
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: hasActiveVibes ? c3MediumSage : Colors.transparent, width: 3),
                                                ),
                                                child: CircleAvatar(
                                                  radius: 40,
                                                  backgroundColor: c2DeepOlive,
                                                  backgroundImage: profilePicUrl != null ? NetworkImage(profilePicUrl) : null,
                                                  child: profilePicUrl == null ? const Icon(Icons.person, size: 40, color: c4LightSage) : null,
                                                ),
                                              ),
                                            );
                                          }
                                      ),
                                      _buildStatColumn(postCount.toString(), "posts"),
                                      _buildStatColumn(followersCount.toString(), "followers"),
                                      _buildStatColumn(followingCount.toString(), "following"),
                                      _buildStatColumn(totalLikes.toString(), "likes"),
                                    ],
                                  );
                                }
                            ),
                            const SizedBox(height: 12),
                            // Bio Section
                            Row(
                              children: [
                                Text(name, style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                                if (pronouns.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(pronouns, style: const TextStyle(color: c4LightSage, fontSize: 14)),
                                ]
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(bio, style: const TextStyle(color: c5CreamGreen)),
                            const SizedBox(height: 16),

                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: c2DeepOlive,
                                      foregroundColor: c5CreamGreen,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text("Edit profile"),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: c2DeepOlive,
                                      foregroundColor: c5CreamGreen,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text("Share profile"),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // GAMIFICATION BADGES
                            const Text("Badges", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 80,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: 4,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 16.0),
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: c3MediumSage, width: 2),
                                        color: c1DeepForest,
                                      ),
                                      child: const Icon(Icons.star, color: c3MediumSage),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      );
                    }
                ),
              ),

              // 3. The Sticky Tab Bar
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    indicatorColor: c5CreamGreen,
                    unselectedLabelColor: c2DeepOlive,
                    labelColor: c5CreamGreen,
                    tabs: const [
                      Tab(icon: Icon(Icons.grid_on)),
                      Tab(icon: Icon(Icons.play_arrow_outlined)),
                      Tab(icon: Icon(Icons.bookmark_border)),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildPostGrid('image'),
              _buildPostGrid('video'),
              _buildSavedGrid(), // Now linked to real database!
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(count, style: const TextStyle(color: c5CreamGreen, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: c5CreamGreen, fontSize: 14)),
      ],
    );
  }

  // --- THE GRID ---
  Widget _buildPostGrid(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: currentUserId)
          .where('type', isEqualTo: type)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: c3MediumSage));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(type == 'image' ? Icons.camera_alt_outlined : Icons.videocam_outlined,
                    size: 60, color: c2DeepOlive),
                const SizedBox(height: 16),
                Text("No ${type}s yet", style: const TextStyle(color: c4LightSage, fontSize: 18)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var post = snapshot.data!.docs[index].data() as Map<String, dynamic>;

            return GestureDetector(
              onTap: () {
                // Safe Routing based on Post Type!
                if (type == 'image') {
                  Navigator.push(context, MaterialPageRoute(
                      builder: (context) => PostDetailScreen(postData: post)
                  ));
                } else if (type == 'video') {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Video details page coming soon!")));
                  // TODO: Route to a Single Video Viewer Screen here later.
                }
              },
              child: Container(
                color: c2DeepOlive,
                child: type == 'video'
                    ? const Center(child: Icon(Icons.play_circle_fill, color: c4LightSage, size: 40))
                    : (post['thumbnailUrl'] != null
                    ? Image.network(post['thumbnailUrl'], fit: BoxFit.cover)
                    : const Icon(Icons.image, color: c4LightSage)),
              ),
            );
          },
        );
      },
    );
  }

  // --- NEW: THE SAVED GRID ---
  Widget _buildSavedGrid() {
    return StreamBuilder<QuerySnapshot>(
      // Find all posts where MY user ID is inside the saves array
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('saves', arrayContains: currentUserId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: c3MediumSage));

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.bookmark_border, size: 60, color: c2DeepOlive), SizedBox(height: 16),
            Text("No saved posts", style: TextStyle(color: c4LightSage, fontSize: 18)),
          ]));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var post = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return GestureDetector(
              onTap: () {
                if (post['type'] == 'image') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postData: post)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Video details page coming soon!")));
                }
              },
              child: Container(
                color: c2DeepOlive,
                child: post['type'] == 'video'
                    ? const Center(child: Icon(Icons.play_circle_fill, color: c4LightSage, size: 40))
                    : Image.network(post['thumbnailUrl'] ?? '', fit: BoxFit.cover),
              ),
            );
          },
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: c1DeepForest,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}