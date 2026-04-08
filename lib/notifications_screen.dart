import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../posting/post_detail_screen.dart';
import '../posting/single_video_screen.dart';
import 'view_profile_screen.dart';

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

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return "Just now";
    Duration diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inDays > 0) return "${diff.inDays}d";
    if (diff.inHours > 0) return "${diff.inHours}h";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m";
    return "Just now";
  }

  void _deleteNotification(String docId) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('userNotifications')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest,
      appBar: AppBar(
        backgroundColor: c1DeepForest,
        elevation: 0,
        iconTheme: const IconThemeData(color: c5CreamGreen),
        title: const Text("Notifications", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold, fontSize: 22)),
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
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c2DeepOlive.withValues(alpha: 0.3),
                      ),
                      child: Icon(Icons.notifications_none_rounded, size: 60, color: c3MediumSage.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: 16),
                    const Text("No new notifications.", style: TextStyle(color: c4LightSage, fontSize: 16, fontWeight: FontWeight.w500)),
                  ],
                )
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 40),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              return _buildNotificationCard(doc);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(QueryDocumentSnapshot doc) {
    var notification = doc.data() as Map<String, dynamic>;
    String docId = doc.id;
    String type = notification['type'] ?? 'unknown';
    String? fromUserId = notification['fromUserId'];
    String postId = notification['postId'] ?? "";
    String timeAgo = _getTimeAgo(notification['createdAt'] as Timestamp?);
    String customMessage = notification['message'] ?? "";
    bool isRead = notification['isRead'] ?? true;
    String reportStatus = notification['reportStatus'] ?? "";

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.startToEnd,
      onDismissed: (direction) => _deleteNotification(docId),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        color: Colors.redAccent.withValues(alpha: 0.8),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
      ),
      child: _buildCardContent(type, customMessage, timeAgo, fromUserId, postId, isRead, reportStatus),
    );
  }

  Widget _buildCardContent(String type, String customMessage, String timeAgo, String? fromUserId, String postId, bool isRead, String reportStatus) {

    // --- 1. SYSTEM ALERTS (Achievements, Warnings, Reports) ---
    if (type == 'achievement' || type == 'warning' || type == 'report') {
      Color themeColor = Colors.amber;
      IconData themeIcon = Icons.star_rounded;
      String titleText = "System Update\n";

      if (type == 'warning') {
        themeColor = Colors.redAccent;
        themeIcon = Icons.gavel_rounded;
        titleText = "System Warning\n";
      } else if (type == 'report') {
        if (reportStatus == 'Pending') {
          themeColor = Colors.orange;
          themeIcon = Icons.hourglass_empty_rounded;
        } else if (reportStatus == 'Resolved') {
          themeColor = c3MediumSage;
          themeIcon = Icons.check_circle_outline_rounded;
        } else {
          themeColor = Colors.blueAccent;
          themeIcon = Icons.info_outline;
        }
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [themeColor.withValues(alpha: 0.15), themeColor.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: themeColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle),
              child: Icon(themeIcon, color: Colors.black, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: c5CreamGreen, fontSize: 14, height: 1.4),
                      children: [
                        TextSpan(text: titleText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: themeColor)),
                        TextSpan(text: customMessage, style: const TextStyle(color: c5CreamGreen)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(timeAgo, style: TextStyle(color: themeColor.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // --- 2. SOCIAL NOTIFICATIONS (Likes, Comments, Follows) ---
    IconData typeIcon = Icons.notifications;
    Color typeColor = c4LightSage;
    String actionText = "interacted with you.";

    if (type == 'like') {
      typeIcon = Icons.favorite_rounded;
      typeColor = Colors.redAccent;
      actionText = "liked your post.";
    } else if (type == 'comment') {
      typeIcon = Icons.chat_bubble_rounded;
      typeColor = c3MediumSage;
      actionText = "commented on your post.";
    } else if (type == 'follow') {
      typeIcon = Icons.person_add_rounded;
      typeColor = Colors.blueAccent;
      actionText = "started following you.";
    }

    if (fromUserId == null) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(fromUserId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const SizedBox.shrink();

        var userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        String username = userData['username'] ?? "Someone";
        String? profilePic = userData['profilePicUrl'];

        return InkWell(
          onTap: () async {
            if (type == 'follow') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ViewProfileScreen(targetUserId: fromUserId)));
              return;
            }
            if (postId.isNotEmpty) {
              showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: c3MediumSage)));
              DocumentSnapshot postDoc = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
              if (mounted) Navigator.pop(context);

              if (postDoc.exists && mounted) {
                var postData = postDoc.data() as Map<String, dynamic>;
                // --- FIXED: Passing both postData AND postId to the screens! ---
                if (postData['type'] == 'video') {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => SingleVideoScreen(postData: postData, postId: postId)));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(postData: postData, postId: postId)));
                }
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isRead ? Colors.transparent : c2DeepOlive.withValues(alpha: 0.15),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: c2DeepOlive,
                  backgroundImage: profilePic != null && profilePic.isNotEmpty ? CachedNetworkImageProvider(profilePic) : null,
                  child: profilePic == null || profilePic.isEmpty ? const Icon(Icons.person, color: c4LightSage) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(color: c5CreamGreen, fontSize: 14, height: 1.3),
                          children: [
                            TextSpan(text: "$username ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            TextSpan(text: actionText, style: const TextStyle(color: c4LightSage)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(timeAgo, style: TextStyle(color: c3MediumSage.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),

                if (type == 'follow')
                  OutlinedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewProfileScreen(targetUserId: fromUserId))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: c3MediumSage),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: const Text("View", style: TextStyle(color: c5CreamGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                else if (postId.isNotEmpty)
                  _buildPostThumbnail(postId)
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostThumbnail(String postId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('posts').doc(postId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();

        var post = snapshot.data!.data() as Map<String, dynamic>;
        String type = post['type'] ?? 'image';
        String previewUrl = post['thumbnailUrl'] ?? ((post['imageUrls'] != null && (post['imageUrls'] as List).isNotEmpty) ? post['imageUrls'][0] : '');

        if (previewUrl.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(left: 12),
          width: 48, height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(image: CachedNetworkImageProvider(previewUrl), fit: BoxFit.cover),
          ),
          child: type == 'video' ? const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 20)) : null,
        );
      },
    );
  }
}