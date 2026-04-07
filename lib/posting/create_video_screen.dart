import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Palette Reference
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class CreateVideoScreen extends StatefulWidget {
  const CreateVideoScreen({super.key});

  @override
  State<CreateVideoScreen> createState() => _CreateVideoScreenState();
}

class _CreateVideoScreenState extends State<CreateVideoScreen> {
  final TextEditingController _captionController = TextEditingController();

  File? _selectedVideo;
  VideoPlayerController? _videoController;
  bool _isUploading = false;

  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // --- NEW: CATEGORY SYSTEM ---
  List<String> _selectedCategories = [];

  // 40+ Categories tailored for Video, Edits, and Pop Culture!
  final List<String> _availableCategories = [
    "Cinematography", "Vlog", "Short Film", "Music Video", "Documentary",
    "Action", "Comedy", "Cosplay", "Anime", "TV Series", "Movies", "Gaming",
    "Tech/Setup", "Cars/Automotive", "Nature", "Lifestyle", "Tutorial",
    "Behind the Scenes", "Aesthetic", "Transitions", "Drone/Aerial",
    "Stop Motion", "Interview", "Review", "Animation", "AMV/Edits",
    "Fitness", "Dance", "Music Cover", "Art Process", "Skits", "Travel",
    "Sports", "Food/Cooking", "Fashion", "Makeup", "DIY/Crafts", "Education"
  ];

  // 1. Pick a Single Video
  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    // Opens the gallery but restricts the user to picking videos only
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      File videoFile = File(video.path);

      // Initialize the video player so they can preview what they selected
      _videoController = VideoPlayerController.file(videoFile)
        ..initialize().then((_) {
          setState(() {
            _selectedVideo = videoFile;
            _videoController!.setLooping(true);
            _videoController!.play();
          });
        });
    }
  }

  // 2. The Upload Logic
  Future<void> _uploadVideo() async {
    if (_selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a video.")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      // A. Fetch the real username & profile pic
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      String myUsername = "Nsnap Creator";
      String myProfilePic = "";
      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>;
        myUsername = userData['username'] ?? "Nsnap Creator";
        myProfilePic = userData['profilePicUrl'] ?? "";
      }

      String postId = DateTime.now().millisecondsSinceEpoch.toString();

      // B. Upload Video to Firebase Storage
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('videos')
          .child(currentUserId)
          .child('$postId.mp4');

      UploadTask uploadTask = storageRef.putFile(_selectedVideo!);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // C. Save the Post Data to Firestore
      await FirebaseFirestore.instance.collection('posts').doc(postId).set({
        'postId': postId,
        'userId': currentUserId,
        'username': myUsername,
        'profilePicUrl': myProfilePic, // Saving Profile Pic for the UI
        'caption': _captionController.text.trim(),
        'categories': _selectedCategories, // NEW: Saves the selected tags!
        'videoUrl': downloadUrl,
        'type': 'video',
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        'saves': [],
        'commentCount': 0,
      });

      // D. Clean up and go back
      if (mounted) Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to upload: $e")));
    }

    setState(() => _isUploading = false);
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest,
      appBar: AppBar(
        backgroundColor: c1DeepForest,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: c5CreamGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("New Video", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
        actions: [
          _isUploading
              ? const Center(child: Padding(padding: EdgeInsets.only(right: 16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: c3MediumSage, strokeWidth: 2))))
              : TextButton(
            onPressed: _uploadVideo,
            child: const Text("Post", style: TextStyle(color: c3MediumSage, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // VIDEO PREVIEW AREA
            if (_selectedVideo == null)
              GestureDetector(
                onTap: _pickVideo,
                child: Container(
                  height: 400,
                  width: double.infinity,
                  color: c2DeepOlive.withValues(alpha: 0.3),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_library_outlined, size: 60, color: c4LightSage),
                      SizedBox(height: 10),
                      Text("Tap to select a video", style: TextStyle(color: c4LightSage)),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 450,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_videoController != null && _videoController!.value.isInitialized)
                      SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _videoController!.value.size.width,
                            height: _videoController!.value.size.height,
                            child: VideoPlayer(_videoController!),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: IconButton(
                        onPressed: _pickVideo,
                        icon: const Icon(Icons.video_camera_back),
                        style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

            // CAPTION INPUT AREA
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _captionController,
                maxLines: 3, // Reduced slightly to make room for categories
                style: const TextStyle(color: c5CreamGreen),
                decoration: InputDecoration(
                  hintText: "Write a caption for your video...",
                  hintStyle: const TextStyle(color: c4LightSage),
                  filled: true,
                  fillColor: c1DeepForest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // --- NEW: CATEGORY SELECTOR UI ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                      "Categories",
                      style: TextStyle(color: c5CreamGreen, fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                  Text(
                      "${_selectedCategories.length} / 5 selected",
                      style: TextStyle(
                          color: _selectedCategories.length == 5 ? c3MediumSage : c4LightSage,
                          fontSize: 14
                      )
                  )
                ],
              ),
            ),

            const SizedBox(height: 10),

            // A bounded scrollable box for the chips
            Container(
              height: 200,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _availableCategories.map((category) {
                    bool isSelected = _selectedCategories.contains(category);
                    return FilterChip(
                      label: Text(category, style: TextStyle(
                        color: isSelected ? c5CreamGreen : c1DeepForest, // VERY DARK GREEN!
                        fontWeight: FontWeight.bold, // Made it bold for readability
                      )),
                      backgroundColor: c4LightSage, // Lighter background so dark text is readable
                      selectedColor: c1DeepForest, // Turns dark when selected
                      checkmarkColor: c5CreamGreen,
                      selected: isSelected,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? c3MediumSage : c2DeepOlive),
                      ),
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            if (_selectedCategories.length < 5) {
                              _selectedCategories.add(category);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("You can only select up to 5 categories.")),
                              );
                            }
                          } else {
                            _selectedCategories.remove(category);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 40), // Bottom padding
          ],
        ),
      ),
    );
  }
}