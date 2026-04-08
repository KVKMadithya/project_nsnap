import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../posting/post_detail_screen.dart';
import '../posting/single_video_screen.dart'; // <--- ADDED IMPORT

const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class ViewProfileScreen extends StatefulWidget {
  final String targetUserId;
  const ViewProfileScreen({super.key, required this.targetUserId});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _isLoadingFollow = false;

  // --- REAL FOLLOW LOGIC ---
  Future<void> _toggleFollow(bool isCurrentlyFollowing) async {
    setState(() => _isLoadingFollow = true);

    try {
      final targetUserRef = FirebaseFirestore.instance.collection('users').doc(widget.targetUserId);
      final myUserRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);

      if (isCurrentlyFollowing) {
        await targetUserRef.update({'followers': FieldValue.arrayRemove([currentUserId])});
        await myUserRef.update({'following': FieldValue.arrayRemove([widget.targetUserId])});
      } else {
        await targetUserRef.update({'followers': FieldValue.arrayUnion([currentUserId])});
        await myUserRef.update({'following': FieldValue.arrayUnion([widget.targetUserId])});

        await targetUserRef.collection('userNotifications').add({
          'type': 'follow',
          'fromUserId': currentUserId,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoadingFollow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMyProfile = currentUserId == widget.targetUserId;

    return Scaffold(
        backgroundColor: c1DeepForest,
        appBar: AppBar(
          backgroundColor: c1DeepForest,
          elevation: 0,
          iconTheme: const IconThemeData(color: c5CreamGreen),
          title: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).snapshots(),
              builder: (context, snapshot) {
                String username = "Loading...";
                if (snapshot.hasData && snapshot.data!.exists) {
                  username = snapshot.data!.get('username') ?? "User";
                }
                return Text(username, style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold));
              }
          ),
          centerTitle: true,
        ),
        body: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: c3MediumSage));

              var userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
              List followers = userData['followers'] ?? [];
              List following = userData['following'] ?? [];
              bool isFollowing = followers.contains(currentUserId);

              return Column(
                children: [
                  const SizedBox(height: 10),
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: c2DeepOlive,
                    backgroundImage: (userData['profilePicUrl'] != null && userData['profilePicUrl'].toString().isNotEmpty)
                        ? CachedNetworkImageProvider(userData['profilePicUrl'])
                        : null,
                    child: (userData['profilePicUrl'] == null || userData['profilePicUrl'].toString().isEmpty)
                        ? const Icon(Icons.person, size: 40, color: c4LightSage)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text("@${userData['username'] ?? 'user'}", style: const TextStyle(color: c5CreamGreen, fontSize: 18, fontWeight: FontWeight.bold)),
                  if (userData['bio'] != null && userData['bio'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 20, right: 20),
                      child: Text(userData['bio'], textAlign: TextAlign.center, style: const TextStyle(color: c4LightSage, fontSize: 14)),
                    ),
                  const SizedBox(height: 20),
                  StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('posts').where('userId', isEqualTo: widget.targetUserId).snapshots(),
                      builder: (context, postSnapshot) {
                        int postCount = 0;
                        int totalLikes = 0;
                        if (postSnapshot.hasData) {
                          postCount = postSnapshot.data!.docs.length;
                          for (var doc in postSnapshot.data!.docs) {
                            var postData = doc.data() as Map<String, dynamic>;
                            totalLikes += (postData['likes'] as List?)?.length ?? 0;
                          }
                        }
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatColumn("Following", following.length),
                            _buildStatColumn("Followers", followers.length),
                            _buildStatColumn("Likes", totalLikes),
                            _buildStatColumn("Posts", postCount),
                          ],
                        );
                      }
                  ),
                  const SizedBox(height: 20),
                  if (!isMyProfile)
                    SizedBox(
                      width: 150,
                      height: 40,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing ? c1DeepForest : c3MediumSage,
                          foregroundColor: isFollowing ? c5CreamGreen : c1DeepForest,
                          side: BorderSide(color: isFollowing ? c3MediumSage : Colors.transparent, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isLoadingFollow ? null : () => _toggleFollow(isFollowing),
                        child: _isLoadingFollow
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(isFollowing ? "Following" : "Follow", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Divider(color: c2DeepOlive, height: 1),
                  Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('posts')
                              .where('userId', isEqualTo: widget.targetUserId)
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (context, postSnapshot) {
                            if (postSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: c3MediumSage));
                            }
                            if (!postSnapshot.hasData || postSnapshot.data!.docs.isEmpty) {
                              return const Center(child: Text("No posts yet.", style: TextStyle(color: c4LightSage)));
                            }

                            return GridView.builder(
                              padding: const EdgeInsets.all(2),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 2,
                                  mainAxisSpacing: 2
                              ),
                              itemCount: postSnapshot.data!.docs.length,
                              itemBuilder: (context, index) {
                                // --- UPDATED: Extraction of Doc ID ---
                                var doc = postSnapshot.data!.docs[index];
                                var post = doc.data() as Map<String, dynamic>;
                                String docId = doc.id;

                                String previewUrl = '';
                                if (post['thumbnailUrl'] != null && post['thumbnailUrl'].toString().isNotEmpty) {
                                  previewUrl = post['thumbnailUrl'];
                                } else if (post['imageUrls'] != null && (post['imageUrls'] as List).isNotEmpty) {
                                  previewUrl = post['imageUrls'][0];
                                }

                                return GestureDetector(
                                  onTap: () {
                                    // --- UPDATED: Smart Routing with postId ---
                                    if (post['type'] == 'video') {
                                      Navigator.push(context, MaterialPageRoute(
                                          builder: (_) => SingleVideoScreen(postData: post, postId: docId)
                                      ));
                                    } else {
                                      Navigator.push(context, MaterialPageRoute(
                                          builder: (_) => PostDetailScreen(postData: post, postId: docId)
                                      ));
                                    }
                                  },
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Container(
                                        color: c2DeepOlive,
                                        child: previewUrl.isNotEmpty
                                            ? CachedNetworkImage(
                                          imageUrl: previewUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(color: c2DeepOlive),
                                        )
                                            : const Icon(Icons.broken_image, color: c4LightSage),
                                      ),
                                      if (post['type'] == 'video')
                                        const Positioned(
                                          top: 5, right: 5,
                                          child: Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }
                      )
                  )
                ],
              );
            }
        )
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count.toString(), style: const TextStyle(color: c5CreamGreen, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: c4LightSage, fontSize: 13)),
      ],
    );
  }
}