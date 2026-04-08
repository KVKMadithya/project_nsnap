import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

import '../services/auth_service.dart';
import 'edit_profile_screen.dart';
import '../posting/create_post_screen.dart';
import '../posting/post_detail_screen.dart';
import '../posting/single_video_screen.dart';
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

  final List<int> _milestones = [10, 100, 1000, 10000, 100000];

  String _formatMilestone(int num) {
    if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(0)}K';
    }
    return num.toString();
  }

  void _showSendReportDialog() {
    final TextEditingController reportController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c1DeepForest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
          side: BorderSide(color: c3MediumSage.withValues(alpha: 0.5)),
        ),
        title: const Row(
          children: [
            Icon(Icons.support_agent_rounded, color: c3MediumSage),
            SizedBox(width: 10),
            Text("Send Report", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Describe your issue or report a bug to our admin team.",
                style: TextStyle(color: c4LightSage, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: reportController,
              maxLines: 4,
              style: const TextStyle(color: c5CreamGreen),
              decoration: InputDecoration(
                hintText: "Enter details here...",
                hintStyle: TextStyle(color: c4LightSage.withValues(alpha: 0.5)),
                fillColor: c2DeepOlive.withValues(alpha: 0.3),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: c4LightSage)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c3MediumSage,
              foregroundColor: c1DeepForest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final text = reportController.text.trim();
              if (text.isEmpty) return;

              Navigator.pop(context);

              var userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
              String username = userDoc.data()?['username'] ?? "Nsnap User";

              await FirebaseFirestore.instance.collection('reports').add({
                'userId': currentUserId,
                'username': username,
                'description': text,
                'status': 'New',
                'createdAt': FieldValue.serverTimestamp(),
              });

              await FirebaseFirestore.instance.collection('users').doc(currentUserId).collection('userNotifications').add({
                'type': 'achievement',
                'message': 'Your report has been successfully sent to the admins. We will review it shortly!',
                'createdAt': FieldValue.serverTimestamp(),
                'isRead': false,
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Report sent successfully!"),
                  backgroundColor: c3MediumSage,
                ));
              }
            },
            child: const Text("Submit", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c1DeepForest,
        title: const Text("Log Out", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to log out of Nsnap?", style: TextStyle(color: c4LightSage)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("No", style: TextStyle(color: c4LightSage))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: c3MediumSage, foregroundColor: c1DeepForest),
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().auth.signOut();
              await AuthService().googleSignIn.signOut();
            },
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c1DeepForest,
        title: const Text("Delete Account", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text("Are you completely sure? This will permanently delete your profile data.", style: TextStyle(color: c4LightSage)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: c4LightSage))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance.collection('users').doc(currentUserId).delete();
                await FirebaseAuth.instance.currentUser!.delete();
                await AuthService().googleSignIn.signOut();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Requires recent login to delete account.")));
                }
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest,
      body: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                backgroundColor: c1DeepForest,
                pinned: true,
                elevation: 0,
                leading: PopupMenuButton<String>(
                  icon: const Icon(Icons.add_box_outlined, color: c5CreamGreen, size: 28),
                  color: c2DeepOlive,
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'post', child: Text("Post")),
                    const PopupMenuItem(value: 'video', child: Text("Video")),
                    const PopupMenuItem(value: 'vibes', child: Text("Vibes")),
                  ],
                  onSelected: (value) {
                    if (value == 'post') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
                    } else if (value == 'video') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateVideoScreen()));
                    } else if (value == 'vibes') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateVibeScreen()));
                    }
                  },
                ),
                title: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
                    builder: (context, snapshot) {
                      String username = "My Profile";
                      if (snapshot.hasData && snapshot.data!.exists) {
                        var data = snapshot.data!.data() as Map<String, dynamic>;
                        username = data['username'] ?? "My Profile";
                      }
                      return Text(username, style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold, fontSize: 20));
                    }
                ),
                centerTitle: true,
                actions: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.menu, color: c5CreamGreen, size: 28),
                    color: c2DeepOlive,
                    onSelected: (value) {
                      if (value == 'logout') {
                        _showLogoutDialog();
                      } else if (value == 'delete') {
                        _showDeleteAccountDialog();
                      } else if (value == 'report') {
                        _showSendReportDialog();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'report', child: Text("Send Report")),
                      PopupMenuItem(value: 'logout', child: Text("Log out")),
                      PopupMenuItem(value: 'delete', child: Text("Delete Account", style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) return const SizedBox.shrink();
                      var data = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};

                      String name = data['name'] ?? "Nsnap User";
                      String bio = data['bio'] ?? "Set up your profile!";
                      String pronouns = data['pronouns'] ?? "";
                      String? profilePicUrl = data['profilePicUrl'];
                      int followersCount = (data['followers'] as List?)?.length ?? 0;
                      int followingCount = (data['following'] as List?)?.length ?? 0;
                      List<dynamic> earnedBadges = data['earnedBadges'] ?? [];

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('posts').where('userId', isEqualTo: currentUserId).snapshots(),
                            builder: (context, postSnapshot) {
                              int postCount = postSnapshot.hasData ? postSnapshot.data!.docs.length : 0;
                              int totalLikes = 0;
                              if (postSnapshot.hasData) {
                                for (var doc in postSnapshot.data!.docs) {
                                  totalLikes += ((doc.data() as Map<String, dynamic>)['likes'] as List?)?.length ?? 0;
                                }
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildProfileAvatar(profilePicUrl),
                                      _buildStatColumn(postCount.toString(), "posts"),
                                      _buildStatColumn(followersCount.toString(), "followers"),
                                      _buildStatColumn(followingCount.toString(), "following"),
                                      _buildStatColumn(totalLikes.toString(), "likes"),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(name, style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                                  if (pronouns.isNotEmpty) Text(pronouns, style: const TextStyle(color: c4LightSage, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(bio, style: const TextStyle(color: c5CreamGreen)),
                                  const SizedBox(height: 16),
                                  _buildActionButtons(name),
                                  const SizedBox(height: 20),

                                  // --- UPDATED: Pass the dynamic stats to the badge builder ---
                                  _buildBadgeList(earnedBadges, totalLikes, followersCount),

                                  const SizedBox(height: 10),
                                ],
                              );
                            }
                        ),
                      );
                    }
                ),
              ),
              SliverPersistentHeader(pinned: true, delegate: _SliverAppBarDelegate(const TabBar(indicatorColor: c5CreamGreen, tabs: [Tab(icon: Icon(Icons.grid_on)), Tab(icon: Icon(Icons.play_arrow_outlined)), Tab(icon: Icon(Icons.bookmark_border))]))),
            ];
          },
          body: TabBarView(children: [_buildPostGrid('image'), _buildPostGrid('video'), _buildSavedGrid()]),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(String? profilePicUrl) {
    return CircleAvatar(
      radius: 40,
      backgroundColor: c2DeepOlive,
      backgroundImage: profilePicUrl != null && profilePicUrl.isNotEmpty ? CachedNetworkImageProvider(profilePicUrl) : null,
      child: profilePicUrl == null || profilePicUrl.isEmpty ? const Icon(Icons.person, size: 40, color: c4LightSage) : null,
    );
  }

  // --- UPDATED BADGE SYSTEM ---
  Widget _buildBadgeList(List<dynamic> earnedBadges, int totalLikes, int followersCount) {
    return SizedBox(
        height: 70,
        child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _milestones.length,
            itemBuilder: (context, index) {
              int milestone = _milestones[index];

              // --- THE MAGIC: Dynamic Unlocking ---
              // It glows if it's in the database OR if your current likes/followers hit the milestone!
              bool isUnlocked = earnedBadges.contains(milestone) || totalLikes >= milestone || followersCount >= milestone;

              return Padding(
                padding: const EdgeInsets.only(right: 18.0),
                child: Column(children: [
                  Container(
                      width: 45, height: 45,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: isUnlocked ? Colors.amber : c2DeepOlive, width: 2),
                          color: isUnlocked ? Colors.amber.withValues(alpha: 0.15) : c1DeepForest
                      ),
                      child: Icon(Icons.star, color: isUnlocked ? Colors.amber : c2DeepOlive, size: 26)
                  ),
                  const SizedBox(height: 6),
                  Text(_formatMilestone(milestone), style: TextStyle(color: isUnlocked ? Colors.amber : c2DeepOlive, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              );
            }
        )
    );
  }

  Widget _buildActionButtons(String username) {
    return Row(children: [
      Expanded(
          child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
              style: ElevatedButton.styleFrom(backgroundColor: c2DeepOlive),
              child: const Text("Edit profile")
          )
      ),
      const SizedBox(width: 8),
      Expanded(
          child: ElevatedButton(
              onPressed: () => Share.share("Check out $username on Nsnap!"),
              style: ElevatedButton.styleFrom(backgroundColor: c2DeepOlive),
              child: const Text("Share profile")
          )
      ),
    ]);
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(children: [Text(count, style: const TextStyle(color: c5CreamGreen, fontSize: 18, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(color: c5CreamGreen, fontSize: 14))]);
  }

  Widget _buildPostGrid(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').where('userId', isEqualTo: currentUserId).where('type', isEqualTo: type).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var post = doc.data() as Map<String, dynamic>;

            String previewUrl = '';
            if (post['thumbnailUrl'] != null && post['thumbnailUrl'].toString().isNotEmpty) {
              previewUrl = post['thumbnailUrl'];
            } else if (post['imageUrls'] != null && (post['imageUrls'] as List).isNotEmpty) {
              previewUrl = post['imageUrls'][0];
            }

            return GestureDetector(
              onTap: () {
                if (type == 'video') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SingleVideoScreen(postData: post, postId: doc.id)));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postData: post, postId: doc.id)));
                }
              },
              child: Container(
                color: c2DeepOlive,
                child: previewUrl.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: previewUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: c2DeepOlive),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: c4LightSage),
                )
                    : const Icon(Icons.broken_image, color: c4LightSage),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSavedGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').where('saves', arrayContains: currentUserId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var post = doc.data() as Map<String, dynamic>;

            String previewUrl = '';
            if (post['thumbnailUrl'] != null && post['thumbnailUrl'].toString().isNotEmpty) {
              previewUrl = post['thumbnailUrl'];
            } else if (post['imageUrls'] != null && (post['imageUrls'] as List).isNotEmpty) {
              previewUrl = post['imageUrls'][0];
            }

            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postData: post, postId: doc.id))),
              child: Container(
                color: c2DeepOlive,
                child: previewUrl.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: previewUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: c2DeepOlive),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: c4LightSage),
                )
                    : const Icon(Icons.broken_image, color: c4LightSage),
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
  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: c1DeepForest, child: _tabBar);
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}