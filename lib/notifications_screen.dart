import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../posting/post_detail_screen.dart';
import 'view_profile_screen.dart'; // NEW: For viewing profiles

// Palette Reference
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // A handy helper to make timestamps look like "2h" or "5m"
  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return "Just now";
    Duration diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inDays > 0) return "${diff.inDays}d";
    if (diff.inHours > 0) return "${diff.inHours}h";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m";
    return "Just now";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest,
      appBar: AppBar(
        backgroundColor: c1DeepForest,
        elevation: 0,
        iconTheme: const IconThemeData(color: c5CreamGreen),
        title: const Text("Notifications", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('userNotifications')
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
                    Icon(Icons.notifications_off_outlined, size: 60, color: c3MediumSage.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    const Text("No new notifications.", style: TextStyle(color: c4LightSage, fontSize: 16)),
                  ],
                )
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 40),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var notification = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              return _buildNotificationCard(notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    String type = notification['type']; // 'like', 'comment', etc.
    String fromUserId = notification['fromUserId'];
    String postId = notification['postId'] ?? "";
    String timeAgo = _getTimeAgo(notification['createdAt'] as Timestamp?);

    // Set up visual indicators based on notification type
    IconData typeIcon = Icons.notifications;
    Color typeColor = c4LightSage;
    String actionText = "interacted with your post.";

    if (type == 'like') {
      typeIcon = Icons.favorite;
      typeColor = Colors.redAccent;
      actionText = "liked your post.";
    } else if (type == 'comment') {
      typeIcon = Icons.chat_bubble;
      typeColor = c3MediumSage;
      actionText = "commented on your post.";
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(fromUserId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const SizedBox.shrink();

        var userData = userSnapshot.data!.data() as Map<String, dynamic>;
        String username = userData['username'] ?? "Someone";
        String? profilePic = userData['profilePicUrl'];

        return GestureDetector(
          onTap: () async {
            if (postId.isNotEmpty) {
              // Show loading circle while fetching the post
              showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: c3MediumSage)));

              DocumentSnapshot postDoc = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
              if (mounted) Navigator.pop(context); // close loading

              if (postDoc.exists && mounted) {
                var postData = postDoc.data() as Map<String, dynamic>;

                // Safe routing so we don't crash on video posts!
                if (postData['type'] == 'image') {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(postData: postData)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Video viewer coming soon!")));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post may have been deleted.")));
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c2DeepOlive.withValues(alpha: 0.4), // Soft lighter background
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c3MediumSage.withValues(alpha: 0.3)), // Subtle border
            ),
            child: Row(
              children: [
                // CLICKABLE AVATAR WITH TYPE ICON BADGE
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewProfileScreen(targetUserId: fromUserId))),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: c1DeepForest,
                        backgroundImage: profilePic != null && profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
                        child: profilePic == null || profilePic.isEmpty ? const Icon(Icons.person, color: c4LightSage) : null,
                      ),
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: c1DeepForest,
                            shape: BoxShape.circle,
                            border: Border.all(color: c2DeepOlive, width: 2),
                          ),
                          child: Icon(typeIcon, size: 12, color: typeColor),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // NOTIFICATION TEXT & TIMESTAMP
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(color: c5CreamGreen, fontSize: 14, height: 1.4),
                          children: [
                            TextSpan(text: "$username ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            TextSpan(text: actionText, style: const TextStyle(color: c4LightSage)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(timeAgo, style: TextStyle(color: c3MediumSage.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                // ARROW INDICATOR
                const Icon(Icons.chevron_right, color: c3MediumSage),
              ],
            ),
          ),
        );
      },
    );
  }
}