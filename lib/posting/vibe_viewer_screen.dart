import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Palette Reference
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class VibeViewerScreen extends StatefulWidget {
  final String targetUserId; // Whose vibes are we watching?

  const VibeViewerScreen({super.key, required this.targetUserId});

  @override
  State<VibeViewerScreen> createState() => _VibeViewerScreenState();
}

class _VibeViewerScreenState extends State<VibeViewerScreen> with SingleTickerProviderStateMixin {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  late PageController _pageController;
  late AnimationController _animController;

  List<Map<String, dynamic>> _vibes = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 5));

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextVibe(); // Auto-advance when the 5 seconds are up!
      }
    });

    _fetchVibes();
  }

  // 1. Fetch exactly the valid 24-hour vibes for this specific user
  Future<void> _fetchVibes() async {
    DateTime twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));

    var snapshot = await FirebaseFirestore.instance
        .collection('vibes')
        .where('userId', isEqualTo: widget.targetUserId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(twentyFourHoursAgo))
        .orderBy('createdAt', descending: false) // Oldest first, just like real stories!
        .get();

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        _vibes = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        _isLoading = false;
      });
      _animController.forward(); // Start the timer for the first vibe
    } else {
      // If somehow they have no vibes, just pop back
      if (mounted) Navigator.pop(context);
    }
  }

  void _nextVibe() {
    if (_currentIndex < _vibes.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      _animController.reset();
      _animController.forward();
    } else {
      // Close the viewer if it's the last vibe
      Navigator.pop(context);
    }
  }

  void _previousVibe() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      _animController.reset();
      _animController.forward();
    }
  }

  // --- LIKE & COMMENT LOGIC ---
  Future<void> _toggleLike(String vibeId, List currentLikes) async {
    bool isLiked = currentLikes.contains(currentUserId);
    if (isLiked) {
      await FirebaseFirestore.instance.collection('vibes').doc(vibeId).update({'likes': FieldValue.arrayRemove([currentUserId])});
    } else {
      await FirebaseFirestore.instance.collection('vibes').doc(vibeId).update({'likes': FieldValue.arrayUnion([currentUserId])});
    }
  }

  Future<void> _postComment(String vibeId) async {
    if (_commentController.text.trim().isEmpty) return;

    // Fetch my username to attach to the comment
    DocumentSnapshot myDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    String myName = (myDoc.data() as Map<String, dynamic>)['username'] ?? "User";

    await FirebaseFirestore.instance.collection('vibes').doc(vibeId).collection('comments').add({
      'userId': currentUserId,
      'username': myName,
      'text': _commentController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    _commentController.clear();
    // Briefly pause animation while typing so they don't lose the page
    _animController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: c3MediumSage)));
    }

    var currentVibe = _vibes[_currentIndex];
    String vibeId = currentVibe['vibeId'];
    List likes = currentVibe['likes'] ?? [];
    bool isLikedByMe = likes.contains(currentUserId);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // HOLD TO PAUSE
        onTapDown: (_) => _animController.stop(),
        onTapUp: (_) => _animController.forward(),
        child: Stack(
          children: [
            // 1. THE IMAGE (Page View allows swiping)
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // We handle taps manually!
              itemCount: _vibes.length,
              itemBuilder: (context, index) {
                return Image.network(_vibes[index]['imageUrl'], fit: BoxFit.cover);
              },
            ),

            // 2. TAP ZONES (Left 30% goes back, Right 70% goes forward)
            Row(
              children: [
                Expanded(flex: 3, child: GestureDetector(onTap: _previousVibe, child: Container(color: Colors.transparent))),
                Expanded(flex: 7, child: GestureDetector(onTap: _nextVibe, child: Container(color: Colors.transparent))),
              ],
            ),

            // 3. TOP UI OVERLAY (Progress Bar + User Info)
            Positioned(
              top: 50, left: 16, right: 16,
              child: Column(
                children: [
                  // Progress Bar
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: _animController.value,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 3,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // User Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(currentVibe['profilePicUrl'] ?? ''),
                        backgroundColor: c2DeepOlive,
                      ),
                      const SizedBox(width: 8),
                      Text(currentVibe['username'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                ],
              ),
            ),

            // 4. BOTTOM UI (Live Comments & Like Button)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.only(top: 40, bottom: 20, left: 16, right: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LIVE COMMENTS STREAM
                    SizedBox(
                      height: 120, // Space for a few recent comments
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('vibes').doc(vibeId).collection('comments')
                            .orderBy('createdAt', descending: true)
                            .limit(5) // Only show the latest 5
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          return ListView.builder(
                            reverse: true, // Newest at the bottom
                            itemCount: snapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              var comment = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    children: [
                                      TextSpan(text: "${comment['username']}: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                                      TextSpan(text: comment['text']),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // INPUT & LIKE ROW
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 45,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: Colors.white.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _commentController,
                                    style: const TextStyle(color: Colors.white),
                                    onTap: () => _animController.stop(), // Pause story while typing
                                    onSubmitted: (_) {
                                      _postComment(vibeId);
                                      FocusScope.of(context).unfocus(); // Hide keyboard
                                    },
                                    decoration: const InputDecoration(
                                      hintText: "Send a message...",
                                      hintStyle: TextStyle(color: Colors.white70),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                                  onPressed: () {
                                    _postComment(vibeId);
                                    FocusScope.of(context).unfocus();
                                  },
                                )
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // LIKE BUTTON
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(isLikedByMe ? Icons.favorite : Icons.favorite_border, color: isLikedByMe ? Colors.redAccent : Colors.white, size: 30),
                              onPressed: () => _toggleLike(vibeId, likes),
                            ),
                            Text("${likes.length}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
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