import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart'; // NEW IMPORT
import 'comments_screen.dart';

// Palette Reference
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> postData;

  const PostDetailScreen({super.key, required this.postData});

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
        title: const Text("Edit Caption", style: TextStyle(color: c5CreamGreen)),
        content: TextField(
          controller: editController,
          maxLines: 3,
          style: const TextStyle(color: c5CreamGreen),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: c2DeepOlive)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: c3MediumSage)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: c4LightSage)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: c3MediumSage, foregroundColor: c5CreamGreen),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('posts').doc(postId).update({
                'caption': editController.text.trim()
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  // --- DELETE POST LOGIC (Updated to handle both Images & Videos) ---
  Future<void> _deletePost(String postId, Map<String, dynamic> post) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c1DeepForest,
        title: const Text("Delete Post?", style: TextStyle(color: Colors.redAccent)),
        content: const Text("This cannot be undone.", style: TextStyle(color: c5CreamGreen)),
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

    // 1. Check the type and delete the correct files from Storage
    String type = post['type'] ?? 'image';

    if (type == 'video' && post['videoUrl'] != null) {
      try {
        await FirebaseStorage.instance.refFromURL(post['videoUrl']).delete();
      } catch (e) {
        print("Error deleting video: $e");
      }
    } else {
      List imageUrls = post['imageUrls'] ?? [];
      for (String url in imageUrls) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (e) {
          print("Error deleting image: $e");
        }
      }
    }

    // 2. Delete the document from Firestore
    await FirebaseFirestore.instance.collection('posts').doc(postId).delete();

    // 3. Go back
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    String postId = widget.postData['postId'];

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
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text("Post deleted.", style: TextStyle(color: c4LightSage)));
            }

            var post = snapshot.data!.data() as Map<String, dynamic>;

            // Extract core data
            String type = post['type'] ?? 'image';
            List imageUrls = post['imageUrls'] ?? [];
            List likes = post['likes'] ?? [];
            bool isLikedByMe = likes.contains(currentUserId);
            bool isMyPost = post['userId'] == currentUserId;
            String displayUsername = post['username'] ?? "Nsnap Creator";

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- POST HEADER ---
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: c2DeepOlive,
                      child: Icon(Icons.person, color: c4LightSage),
                    ),
                    title: Text(displayUsername, style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),

                    // THREE DOTS MENU
                    trailing: isMyPost ? PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: c5CreamGreen),
                      color: c2DeepOlive,
                      onSelected: (value) {
                        if (value == 'edit') _editCaption(postId, post['caption']);
                        if (value == 'delete') _deletePost(postId, post); // Pass the whole post to know if it's a video
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text("Edit Caption", style: TextStyle(color: c5CreamGreen))),
                        const PopupMenuItem(value: 'delete', child: Text("Delete Post", style: TextStyle(color: Colors.redAccent))),
                      ],
                    ) : null,
                  ),

                  // --- MEDIA RENDERER (IMAGE OR VIDEO) ---
                  SizedBox(
                    height: type == 'video' ? 500 : 400, // Videos look better a little taller
                    child: type == 'video'
                        ? DetailVideoPlayer(videoUrl: post['videoUrl']) // The new video player widget!
                        : PageView.builder(
                      itemCount: imageUrls.length,
                      onPageChanged: (index) {
                        setState(() => _currentImageIndex = index);
                      },
                      itemBuilder: (context, index) {
                        return Image.network(
                          imageUrls[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                        );
                      },
                    ),
                  ),

                  // --- INTERACTION BAR ---
                  Row(
                    children: [
                      // LIKE
                      IconButton(
                        icon: Icon(
                          isLikedByMe ? Icons.favorite : Icons.favorite_border,
                          color: isLikedByMe ? Colors.redAccent : c5CreamGreen,
                          size: 28,
                        ),
                        onPressed: () => _toggleLike(likes, postId),
                      ),

                      // COMMENT
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: c5CreamGreen, size: 26),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(
                              builder: (context) => CommentsScreen(postId: postId)
                          ));
                        },
                      ),

                      const Spacer(),

                      // SWIPE INDICATORS (Only show if it's an image post with > 1 image)
                      if (type == 'image' && imageUrls.length > 1)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(imageUrls.length, (index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentImageIndex == index ? c3MediumSage : c2DeepOlive,
                              ),
                            );
                          }),
                        ),

                      const Spacer(),

                      // SAVE
                      IconButton(
                        icon: const Icon(Icons.bookmark_border, color: c5CreamGreen, size: 28),
                        onPressed: () {},
                      ),
                    ],
                  ),

                  // --- LIKES & CAPTION ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${likes.length} likes", style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(color: c5CreamGreen, fontSize: 14),
                            children: [
                              TextSpan(text: "$displayUsername ", style: const TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: post['caption'] ?? ""),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => CommentsScreen(postId: postId)));
                          },
                          child: Text("View all ${post['commentCount'] ?? 0} comments", style: const TextStyle(color: c4LightSage, fontSize: 14)),
                        ),
                        const SizedBox(height: 20),
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

// ============================================================================
// DEDICATED INLINE VIDEO PLAYER WIDGET
// We put this in a separate widget to manage memory correctly when pausing/playing
// ============================================================================
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
            _controller.play(); // Auto-play when opened
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose(); // Kills the video to save RAM when you go back to profile
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator(color: c3MediumSage));
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying ? _controller.pause() : _controller.play();
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
          if (!_controller.value.isPlaying)
            const Icon(Icons.play_arrow, size: 80, color: Colors.white54),
        ],
      ),
    );
  }
}