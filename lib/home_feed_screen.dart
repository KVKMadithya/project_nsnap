import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Ensure this is installed!
import '../posting/comments_screen.dart';
import '../posting/vibe_viewer_screen.dart';
import 'notifications_screen.dart';
import 'view_profile_screen.dart';
import '../posting/create_post_screen.dart';
import '../posting/create_video_screen.dart';
import '../posting/create_vibe_screen.dart';

// Palette Reference
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // --- LIKE LOGIC ---
  Future<void> _toggleLike(List currentLikes, String postId, String postOwnerId) async {
    bool isLiked = currentLikes.contains(currentUserId);
    if (isLiked) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'likes': FieldValue.arrayRemove([currentUserId])
      });
    } else {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'likes': FieldValue.arrayUnion([currentUserId])
      });

      if (currentUserId != postOwnerId) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(postOwnerId)
            .collection('userNotifications')
            .add({
          'type': 'like',
          'fromUserId': currentUserId,
          'postId': postId,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
    }
  }

  // --- SAVE LOGIC ---
  Future<void> _toggleSave(List currentSaves, String postId) async {
    bool isSaved = currentSaves.contains(currentUserId);
    if (isSaved) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'saves': FieldValue.arrayRemove([currentUserId])
      });
    } else {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'saves': FieldValue.arrayUnion([currentUserId])
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest,
      appBar: _buildAppBar(), // Now defined below!
      body: Column(
        children: [
          _buildVibesBar(),
          const Divider(color: c2DeepOlive, height: 1),
          Expanded(child: _buildPostFeed()),
        ],
      ),
    );
  }

  // =======================================================================
  // APP BAR (RESTORED)
  // =======================================================================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: c1DeepForest,
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
          if (value == 'post') Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePostScreen()));
          if (value == 'video') Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateVideoScreen()));
          if (value == 'vibes') Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateVibeScreen()));
        },
      ),
      centerTitle: true,
      title: const Text("Nsnap", style: TextStyle(color: c5CreamGreen, fontSize: 28, fontWeight: FontWeight.bold)),
      actions: [
        _buildNotificationIcon(),
        IconButton(
          icon: const Icon(Icons.send_outlined, color: c5CreamGreen),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("DMs coming soon!"))),
        ),
      ],
    );
  }

  Widget _buildNotificationIcon() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('userNotifications')
          .where('isRead', isEqualTo: false)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        bool hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.favorite_border, color: c5CreamGreen),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
                if (hasUnread) {
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUserId)
                      .collection('userNotifications')
                      .where('isRead', isEqualTo: false)
                      .get()
                      .then((q) {
                    for (var d in q.docs) { d.reference.update({'isRead': true}); }
                  });
                }
              },
            ),
            if (hasUnread)
              Positioned(
                top: 14, right: 14,
                child: Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                ),
              )
          ],
        );
      },
    );
  }

  // =======================================================================
  // VIBES BAR (WITH CACHING)
  // =======================================================================
  Widget _buildVibesBar() {
    DateTime twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
    return SizedBox(
      height: 130,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vibes')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(twentyFourHoursAgo))
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No new Vibes.", style: TextStyle(color: c4LightSage)));
          }
          Map<String, List<Map<String, dynamic>>> grouped = {};
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            grouped.putIfAbsent(data['userId'], () => []).add(data);
          }
          List<String> uids = grouped.keys.toList();

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: uids.length,
            itemBuilder: (context, index) {
              var userVibes = grouped[uids[index]]!;
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VibeViewerScreen(targetUserId: uids[index]))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c3MediumSage, width: 3)),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: c2DeepOlive,
                          backgroundImage: userVibes.first['profilePicUrl'] != ""
                              ? CachedNetworkImageProvider(userVibes.first['profilePicUrl'])
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(userVibes.first['username'] ?? "User", style: const TextStyle(color: c5CreamGreen, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // =======================================================================
  // POST FEED (WITH CACHING)
  // =======================================================================
  Widget _buildPostFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').where('type', isEqualTo: 'image').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: c3MediumSage));
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) => _buildPostCard(snapshot.data!.docs[index].data() as Map<String, dynamic>),
        );
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    String postId = post['postId'];
    String postOwnerId = post['userId'];
    List imageUrls = post['imageUrls'] ?? [];
    List likes = post['likes'] ?? [];
    bool isLikedByMe = likes.contains(currentUserId);
    List saves = post['saves'] ?? [];
    bool isSavedByMe = saves.contains(currentUserId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundImage: post['profilePicUrl'] != null ? CachedNetworkImageProvider(post['profilePicUrl']) : null,
          ),
          title: Text(post['username'] ?? "Nsnap", style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 400,
          child: PageView.builder(
            allowImplicitScrolling: true,
            itemCount: imageUrls.length,
            itemBuilder: (context, index) => CachedNetworkImage(
              imageUrl: imageUrls[index],
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: c2DeepOlive),
            ),
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(isLikedByMe ? Icons.favorite : Icons.favorite_border, color: isLikedByMe ? Colors.redAccent : c5CreamGreen),
              onPressed: () => _toggleLike(likes, postId, postOwnerId),
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: c5CreamGreen),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommentsScreen(postId: postId))),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(isSavedByMe ? Icons.bookmark : Icons.bookmark_border, color: c5CreamGreen),
              onPressed: () => _toggleSave(saves, postId),
            ),
          ],
        ),
        // Adding the rest of the padding code to ensure variables are used
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${likes.length} likes", style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(post['caption'] ?? "", style: const TextStyle(color: c5CreamGreen)),
              const SizedBox(height: 20),
            ],
          ),
        )
      ],
    );
  }
}