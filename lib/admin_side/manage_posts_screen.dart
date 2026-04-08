import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class ManagePostsScreen extends StatefulWidget {
  const ManagePostsScreen({super.key});

  @override
  State<ManagePostsScreen> createState() => _ManagePostsScreenState();
}

class _ManagePostsScreenState extends State<ManagePostsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- THE MODERATION ENGINE ---
  Future<void> _deleteContent(String postId, String ownerId, String type) async {
    try {
      // 1. Delete the post from the main database
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();

      // 2. Send the automated system warning to the user who posted it
      await FirebaseFirestore.instance.collection('users').doc(ownerId).collection('userNotifications').add({
        'type': 'achievement', // Reusing your golden system alert UI from earlier!
        'message': 'Your $type was removed by an administrator for violating community guidelines.',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Content deleted and warning sent to user."),
          backgroundColor: Colors.redAccent.shade400,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error deleting content: $e"),
          backgroundColor: Colors.redAccent.shade400,
        ));
      }
    }
  }

  // --- CONFIRMATION DIALOG ---
  void _showDeleteConfirmation(String postId, String ownerId, String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c1DeepForest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.redAccent)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("Delete Content?", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          "Are you certain you want to permanently delete this $type? The user will receive a community guidelines violation notice.",
          style: const TextStyle(color: c4LightSage, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: c4LightSage)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _deleteContent(postId, ownerId, type); // Execute the deletion
            },
            child: const Text("Yes, Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest,
      appBar: AppBar(
        backgroundColor: c1DeepForest,
        elevation: 0,
        iconTheme: const IconThemeData(color: c5CreamGreen),
        title: const Text("Content Moderation", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold, fontSize: 24)),
      ),
      body: Column(
        children: [
          // --- SEARCH BAR (Search by Username) ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              style: const TextStyle(color: c5CreamGreen),
              decoration: InputDecoration(
                hintText: "Search by uploader's username...",
                hintStyle: TextStyle(color: c4LightSage.withOpacity(0.6)),
                prefixIcon: const Icon(Icons.search, color: c3MediumSage),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
          ),

          // --- FEED LIST ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: c3MediumSage));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No content found.", style: TextStyle(color: c4LightSage)));
                }

                // Filter by username if the admin is typing in the search bar
                var filteredDocs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String username = (data['username'] ?? "").toLowerCase();
                  return username.contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  padding: const EdgeInsets.only(bottom: 100), // Padding for nav bar
                  itemBuilder: (context, index) {
                    var post = filteredDocs[index].data() as Map<String, dynamic>;
                    String docId = filteredDocs[index].id;
                    String ownerId = post['userId'] ?? "";
                    String type = post['type'] ?? 'image';
                    String username = post['username'] ?? "Unknown";
                    String caption = post['caption'] ?? "No caption provided.";

                    // Grab the thumbnail, or the first image in the array
                    String previewUrl = post['thumbnailUrl'] ?? ((post['imageUrls'] != null && (post['imageUrls'] as List).isNotEmpty) ? post['imageUrls'][0] : '');

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: c2DeepOlive.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c3MediumSage.withOpacity(0.1)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Thumbnail Image
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.black45,
                                image: previewUrl.isNotEmpty ? DecorationImage(image: CachedNetworkImageProvider(previewUrl), fit: BoxFit.cover) : null,
                              ),
                              child: type == 'video' ? const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 28)) : null,
                            ),
                            const SizedBox(width: 16),

                            // 2. Post Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(username, style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: c1DeepForest, borderRadius: BorderRadius.circular(4), border: Border.all(color: c4LightSage)),
                                        child: Text(type.toUpperCase(), style: const TextStyle(color: c4LightSage, fontSize: 10, fontWeight: FontWeight.bold)),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    caption,
                                    style: const TextStyle(color: c4LightSage, fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // 3. Delete Action
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
                              onPressed: () => _showDeleteConfirmation(docId, ownerId, type),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}