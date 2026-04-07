import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Palette Reference
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class CommentsScreen extends StatefulWidget {
  final String postId;

  const CommentsScreen({super.key, required this.postId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  String? myUsername;
  String? myProfilePicUrl;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _fetchMyUserData();
  }

  Future<void> _fetchMyUserData() async {
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    if (doc.exists) {
      var data = doc.data() as Map<String, dynamic>;
      setState(() {
        myUsername = data['username'] ?? 'User';
        myProfilePicUrl = data['profilePicUrl'];
      });
    }
  }

  Future<void> _postComment() async {
    String text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);

    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'userId': currentUserId,
        'username': myUsername,
        'profilePicUrl': myProfilePicUrl,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('posts').doc(widget.postId).update({
        'commentCount': FieldValue.increment(1),
      });

      _commentController.clear();
      FocusScope.of(context).unfocus(); // Drops the keyboard after sending
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => _isPosting = false);
  }

  // --- NEW: DELETE LOGIC ---
  Future<void> _deleteComment(String commentId) async {
    try {
      // 1. Delete the comment document
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .delete();

      // 2. Safely decrease the comment count
      await FirebaseFirestore.instance.collection('posts').doc(widget.postId).update({
        'commentCount': FieldValue.increment(-1),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
    }
  }

  // --- NEW: TIME FORMATTER ---
  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return "Just now"; // Accounts for local latency before server sync
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inDays > 0) return "${diff.inDays}d";
    if (diff.inHours > 0) return "${diff.inHours}h";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m";
    return "Just now";
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest,
      appBar: AppBar(
        backgroundColor: c1DeepForest,
        title: const Text("Comments", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: c5CreamGreen),
        elevation: 0,
      ),
      // NEW: GestureDetector allows tapping anywhere to close the keyboard
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: c3MediumSage));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text("No comments yet. Start the conversation!", style: TextStyle(color: c4LightSage)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index];
                      var comment = doc.data() as Map<String, dynamic>;
                      String profilePic = comment['profilePicUrl'] ?? '';
                      bool isMyComment = comment['userId'] == currentUserId;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: c2DeepOlive,
                              backgroundImage: profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
                              child: profilePic.isEmpty ? const Icon(Icons.person, size: 20, color: c4LightSage) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(color: c5CreamGreen, fontSize: 14),
                                      children: [
                                        TextSpan(text: "${comment['username']} ", style: const TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: comment['text']),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // NEW: Timestamp and Delete Button Row
                                  Row(
                                    children: [
                                      Text(
                                        _timeAgo(comment['createdAt'] as Timestamp?),
                                        style: const TextStyle(color: c4LightSage, fontSize: 12),
                                      ),
                                      const SizedBox(width: 16),
                                      if (isMyComment)
                                        GestureDetector(
                                          onTap: () => _deleteComment(doc.id),
                                          child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                        )
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: c2DeepOlive.withValues(alpha: 0.3),
                  border: const Border(top: BorderSide(color: c2DeepOlive)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: c2DeepOlive,
                      backgroundImage: myProfilePicUrl != null ? NetworkImage(myProfilePicUrl!) : null,
                      child: myProfilePicUrl == null ? const Icon(Icons.person, size: 20, color: c4LightSage) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(color: c5CreamGreen),
                        decoration: const InputDecoration(
                          hintText: "Add a comment...",
                          hintStyle: TextStyle(color: c4LightSage),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    _isPosting
                        ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: c3MediumSage, strokeWidth: 2)))
                        : IconButton(
                      icon: const Icon(Icons.send, color: c3MediumSage),
                      onPressed: _postComment,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}