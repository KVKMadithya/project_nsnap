import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import '../posting/comments_screen.dart';
import 'view_profile_screen.dart';

// Palette Reference
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class VideoFeedScreen extends StatefulWidget {
  final bool isActive;

  const VideoFeedScreen({super.key, required this.isActive});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  int _currentPageIndex = 0;

  // FIX 1: Define the Stream and Controller outside the build method
  late final Stream<QuerySnapshot> _videoStream;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    // Initialize the controller to remember scroll position
    _pageController = PageController(initialPage: 0);

    // Initialize the stream ONCE so it doesn't reset when swiping
    _videoStream = FirebaseFirestore.instance
        .collection('posts')
        .where('type', isEqualTo: 'video')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    // Always dispose controllers to prevent memory leaks!
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<QuerySnapshot>(
        stream: _videoStream, // Use the cached stream here
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: c3MediumSage));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No videos yet. Be the first to post!", style: TextStyle(color: c4LightSage, fontSize: 16)),
            );
          }

          return PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController, // FIX 2: Attach the controller
            itemCount: snapshot.data!.docs.length,
            onPageChanged: (index) {
              setState(() {
                _currentPageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              var post = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              bool isPlaying = (index == _currentPageIndex) && widget.isActive;

              return VideoPlayerItem(
                  key: ValueKey(post['postId']),
                  postData: post,
                  isPlaying: isPlaying
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// THE INDIVIDUAL VIDEO PLAYER WIDGET
// ============================================================================
class VideoPlayerItem extends StatefulWidget {
  final Map<String, dynamic> postData;
  final bool isPlaying;

  const VideoPlayerItem({super.key, required this.postData, required this.isPlaying});

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;
  bool _showHeartAnimation = false;

  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.postData['videoUrl']))
      ..initialize().then((_) {
        // Prevent setting state if the widget was removed from the tree during init
        if (!mounted) return;
        setState(() {
          _isInitialized = true;
          _videoController.setLooping(true);
          if (widget.isPlaying) {
            _videoController.play();
          }
        });
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isInitialized) {
      if (widget.isPlaying && !oldWidget.isPlaying) {
        _videoController.play();
      } else if (!widget.isPlaying && oldWidget.isPlaying) {
        _videoController.pause();
      }
    }
  }

  Future<void> _toggleLike(List currentLikes, String postId, String postOwnerId) async {
    bool isLiked = currentLikes.contains(currentUserId);
    if (isLiked) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({'likes': FieldValue.arrayRemove([currentUserId])});
    } else {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({'likes': FieldValue.arrayUnion([currentUserId])});

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
        });
      }
    }
  }

  void _handleDoubleTap(List currentLikes, String postId, String postOwnerId) {
    bool isLiked = currentLikes.contains(currentUserId);

    if (!isLiked) {
      _toggleLike(currentLikes, postId, postOwnerId);
    }

    setState(() {
      _showHeartAnimation = true;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showHeartAnimation = false;
        });
      }
    });
  }

  Future<void> _toggleSave(List currentSaves, String postId) async {
    bool isSaved = currentSaves.contains(currentUserId);
    if (isSaved) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({'saves': FieldValue.arrayRemove([currentUserId])});
    } else {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({'saves': FieldValue.arrayUnion([currentUserId])});
    }
  }

  @override
  Widget build(BuildContext context) {
    String postId = widget.postData['postId'];
    String postOwnerId = widget.postData['userId'];

    List likes = widget.postData['likes'] ?? [];
    bool isLikedByMe = likes.contains(currentUserId);

    List saves = widget.postData['saves'] ?? [];
    bool isSavedByMe = saves.contains(currentUserId);

    String displayUsername = widget.postData['username'] ?? "Nsnap Creator";
    String? profilePicUrl = widget.postData['profilePicUrl'];

    return Stack(
      fit: StackFit.expand,
      children: [
        _isInitialized
            ? GestureDetector(
          onTap: () {
            setState(() {
              _videoController.value.isPlaying ? _videoController.pause() : _videoController.play();
            });
          },
          onDoubleTap: () => _handleDoubleTap(likes, postId, postOwnerId),
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController.value.size.width,
                height: _videoController.value.size.height,
                child: VideoPlayer(_videoController),
              ),
            ),
          ),
        )
            : const Center(child: CircularProgressIndicator(color: c3MediumSage)),

        if (_isInitialized && !_videoController.value.isPlaying)
          const Center(
            child: Icon(Icons.play_arrow, size: 80, color: Colors.white54),
          ),

        if (_showHeartAnimation)
          Center(
            child: TweenAnimationBuilder(
              duration: const Duration(milliseconds: 500),
              tween: Tween<double>(begin: 0.5, end: 1.5),
              builder: (context, double scale, child) {
                return Opacity(
                  opacity: 1.0 - ((scale - 0.5) / 1.0).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: const Icon(Icons.favorite, color: Colors.redAccent, size: 100),
                  ),
                );
              },
            ),
          ),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 300,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
              ),
            ),
          ),
        ),

        Positioned(
          bottom: 150,
          left: 16,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewProfileScreen(targetUserId: postOwnerId))),
                child: Text(
                  "@$displayUsername",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.postData['caption'] ?? "",
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        Positioned(
          bottom: 150,
          right: 8,
          child: Column(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewProfileScreen(targetUserId: postOwnerId))),
                child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                        radius: 20,
                        backgroundColor: c2DeepOlive,
                        backgroundImage: profilePicUrl != null && profilePicUrl.isNotEmpty ? NetworkImage(profilePicUrl) : null,
                        child: profilePicUrl == null || profilePicUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null
                    )
                ),
              ),
              const SizedBox(height: 20),

              IconButton(
                icon: Icon(isLikedByMe ? Icons.favorite : Icons.favorite_border, color: isLikedByMe ? Colors.redAccent : Colors.white, size: 35),
                onPressed: () => _toggleLike(likes, postId, postOwnerId),
              ),
              Text("${likes.length}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 35),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CommentsScreen(postId: postId)));
                },
              ),
              Text("${widget.postData['commentCount'] ?? 0}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              IconButton(
                icon: Icon(isSavedByMe ? Icons.bookmark : Icons.bookmark_border, color: Colors.white, size: 35),
                onPressed: () => _toggleSave(saves, postId),
              ),
            ],
          ),
        ),
      ],
    );
  }
}