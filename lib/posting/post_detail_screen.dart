import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'comments_screen.dart';
import '../living_photo_viewer.dart';

// Palette Reference
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> postData;
  final String postId; // <--- MANDATORY: Passed from Feed/Profile/Explore

  const PostDetailScreen({super.key, required this.postData, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  int _currentImageIndex = 0;

  // --- LIKE LOGIC ---
  Future<void> _toggleLike(List currentLikes, String postId) async {
    bool isLiked = currentLikes.contains(currentUserId);
    if (isLiked) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'likes': FieldValue.arrayRemove([currentUserId])
      });
    } else {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'likes': FieldValue.arrayUnion([currentUserId])
      });
    }
  }

  // --- EDIT CAPTION LOGIC ---
  Future<void> _editCaption(String postId, String currentCaption) async {
    TextEditingController editController = TextEditingController(text: currentCaption);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c1DeepForest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Caption", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: editController,
          maxLines: 3,
          style: const TextStyle(color: c5CreamGreen),
          decoration: InputDecoration(
            filled: true,
            fillColor: c2DeepOlive.withValues(alpha: 0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            ),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('posts').doc(postId).update({
                'caption': editController.text.trim()
              });
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // --- DELETE POST LOGIC (Storage Cleanup included) ---
  Future<void> _deletePost(String postId, Map<String, dynamic> post) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c1DeepForest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Post?", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text("This will permanently remove the media and post data.", style: TextStyle(color: c4LightSage)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: c4LightSage))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          )
        ],
      ),
    );

    if (confirm != true) return;

    // 1. Storage Cleanup (Images or Video)
    String type = post['type'] ?? 'image';
    try {
      if (type == 'video' && post['videoUrl'] != null) {
        await FirebaseStorage.instance.refFromURL(post['videoUrl']).delete();
      } else {
        List imageUrls = post['imageUrls'] ?? [];
        for (var url in imageUrls) {
          await FirebaseStorage.instance.refFromURL(url).delete();
        }
      }
    } catch (e) {
      debugPrint("Storage cleanup warning: $e");
    }

    // 2. Database Cleanup
    await FirebaseFirestore.instance.collection('posts').doc(postId).delete();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Relying on the constructor ID for stability
    final String postId = widget.postId;

    return Scaffold(
      backgroundColor: c1DeepForest,
      appBar: AppBar(
        backgroundColor: c1DeepForest,
        elevation: 0,
        iconTheme: const IconThemeData(color: c5CreamGreen),
        title: const Text("Post Details", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('posts').doc(postId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: c3MediumSage));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text("This post is no longer available.", style: TextStyle(color: c4LightSage)));
            }

            var post = snapshot.data!.data() as Map<String, dynamic>;
            String type = post['type'] ?? 'image';
            List imageUrls = post['imageUrls'] ?? [];
            List likes = post['likes'] ?? [];
            bool isLikedByMe = likes.contains(currentUserId);
            bool isMyPost = post['userId'] == currentUserId;
            String displayUsername = post['username'] ?? "Nsnap User";

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ---
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: c2DeepOlive,
                      child: Icon(Icons.person, color: c4LightSage),
                    ),
                    title: Text(displayUsername, style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
                    trailing: isMyPost ? PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: c5CreamGreen),
                      color: c2DeepOlive,
                      onSelected: (value) {
                        if (value == 'edit') _editCaption(postId, post['caption'] ?? "");
                        if (value == 'delete') _deletePost(postId, post);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text("Edit Caption", style: TextStyle(color: c5CreamGreen))),
                        const PopupMenuItem(value: 'delete', child: Text("Delete Post", style: TextStyle(color: Colors.redAccent))),
                      ],
                    ) : null,
                  ),

                  // --- MEDIA SECTION ---
                  GestureDetector(
                    onDoubleTap: () => _toggleLike(likes, postId),
                    child: SizedBox(
                      height: type == 'video' ? 500 : 400,
                      child: type == 'video'
                          ? DetailVideoPlayer(videoUrl: post['videoUrl'] ?? "")
                          : PageView.builder(
                        itemCount: imageUrls.length,
                        onPageChanged: (index) => setState(() => _currentImageIndex = index),
                        itemBuilder: (context, index) {
                          String url = imageUrls[index];
                          return GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LivingPhotoViewer(imageUrl: url))),
                            child: CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (context, url) => Container(color: c2DeepOlive),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // --- ACTIONS ---
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(isLikedByMe ? Icons.favorite : Icons.favorite_border, color: isLikedByMe ? Colors.redAccent : c5CreamGreen, size: 28),
                        onPressed: () => _toggleLike(likes, postId),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: c5CreamGreen, size: 26),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommentsScreen(postId: postId))),
                      ),
                      const Spacer(),
                      if (type == 'image' && imageUrls.length > 1)
                        Row(
                          children: List.generate(imageUrls.length, (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 6, height: 6,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: _currentImageIndex == index ? c3MediumSage : c2DeepOlive),
                          )),
                        ),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.bookmark_border, color: c5CreamGreen, size: 28), onPressed: () {}),
                    ],
                  ),

                  // --- CAPTION & STATS ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${likes.length} likes", style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(color: c5CreamGreen, fontSize: 15),
                            children: [
                              TextSpan(text: "$displayUsername ", style: const TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: post['caption'] ?? ""),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: c2DeepOlive),
                        const SizedBox(height: 10),
                      ],
                    ),
                  )
                ],
              ),
            );
          }
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// INLINE VIDEO PLAYER
// ----------------------------------------------------------------------------
class DetailVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const DetailVideoPlayer({super.key, required this.videoUrl});

  @override
  State<DetailVideoPlayer> createState() => _DetailVideoPlayerState();
}

class _DetailVideoPlayerState extends State<DetailVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _controller.setLooping(true);
            _controller.play();
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator(color: c3MediumSage));
    }
    return GestureDetector(
      onTap: () => setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play()),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller)),
          if (!_controller.value.isPlaying)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow, size: 50, color: Colors.white),
            ),
        ],
      ),
    );
  }
}