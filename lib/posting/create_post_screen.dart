import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Palette Reference
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _captionController = TextEditingController();
  List<XFile> _selectedImages = [];
  bool _isUploading = false;

  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // --- NEW: CATEGORY SYSTEM ---
  List<String> _selectedCategories = [];

  // 40+ Categories combining Photography, Aesthetics, and Pop Culture!
  final List<String> _availableCategories = [
    "Portrait", "Landscape", "Street", "Macro", "Night", "Astrophotography",
    "Fashion", "Food", "Architecture", "Wildlife", "Black & White", "Film/Analog",
    "Minimalist", "Fine Art", "Drone/Aerial", "Sports", "Abstract", "Concert",
    "Wedding", "Product", "Cinematic", "Vintage", "Cyberpunk", "Neon", "Travel",
    "Cosplay", "Anime", "TV Series", "Movies", "Gaming", "Tech/Setup",
    "Cars/Automotive", "Nature", "Lifestyle", "Documentary", "Surrealism",
    "Concept Art", "Pets/Animals", "Underwater", "Light Painting", "35mm",
    "Action", "Editing/Retouching", "OOTD", "Behind the Scenes"
  ];

  // 1. Pick Multiple Images
  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    List<XFile> images = await picker.pickMultiImage(imageQuality: 60);

    if (images.isNotEmpty) {
      setState(() {
        if (images.length > 10) {
          _selectedImages = images.sublist(0, 10);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Limit reached: Only the first 10 images were selected.")),
          );
        } else {
          _selectedImages = images;
        }
      });
    }
  }

  // 2. The Upload Logic
  Future<void> _uploadPost() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please make sure to select at least one image.")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      List<String> uploadedImageUrls = [];
      String postId = DateTime.now().millisecondsSinceEpoch.toString();

      // A. Loop through all selected images and upload them
      for (int i = 0; i < _selectedImages.length; i++) {
        File file = File(_selectedImages[i].path);
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('posts')
            .child(currentUserId)
            .child('${postId}_$i.jpg');

        UploadTask uploadTask = storageRef.putFile(file);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        uploadedImageUrls.add(downloadUrl);
      }

      // B. Fetch Username & Profile Pic to attach to the post
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      String username = "Creator";
      String profilePicUrl = "";
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        username = data['username'] ?? "Creator";
        profilePicUrl = data['profilePicUrl'] ?? "";
      }

      // C. Save the Post Data to Firestore
      await FirebaseFirestore.instance.collection('posts').doc(postId).set({
        'postId': postId,
        'userId': currentUserId,
        'username': username, // Added username for feed display!
        'profilePicUrl': profilePicUrl, // Added profile pic for feed display!
        'caption': _captionController.text.trim(),
        'categories': _selectedCategories, // NEW: Saves the selected tags!
        'imageUrls': uploadedImageUrls,
        'thumbnailUrl': uploadedImageUrls.first,
        'type': 'image',
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        'saves': [],
        'commentCount': 0,
      });

      if (mounted) Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to upload: $e")));
    }

    setState(() => _isUploading = false);
  }

  @override
  void dispose() {
    _captionController.dispose();
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
        title: const Text("New Post", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
        actions: [
          _isUploading
              ? const Center(child: Padding(padding: EdgeInsets.only(right: 16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: c3MediumSage, strokeWidth: 2))))
              : TextButton(
            onPressed: _uploadPost,
            child: const Text("Share", style: TextStyle(color: c3MediumSage, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE PREVIEW AREA
            if (_selectedImages.isEmpty)
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  height: 300,
                  width: double.infinity,
                  color: c2DeepOlive.withValues(alpha: 0.3),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 60, color: c4LightSage),
                      SizedBox(height: 10),
                      Text("Tap to select up to 10 images", style: TextStyle(color: c4LightSage)),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 350,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    PageView.builder(
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Image.file(
                          File(_selectedImages[index].path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        );
                      },
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: IconButton(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.photo_library),
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
                maxLines: 3,
                style: const TextStyle(color: c5CreamGreen),
                decoration: InputDecoration(
                  hintText: "Write a caption...",
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

            // A bounded scrollable box for the 45+ chips so it doesn't stretch the screen forever
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
                        color: isSelected ? c5CreamGreen : c1DeepForest,
                        fontWeight: FontWeight.bold,
                      )),
                      backgroundColor: c4LightSage,
                      selectedColor: c1DeepForest,
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