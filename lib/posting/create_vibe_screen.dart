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

class CreateVibeScreen extends StatefulWidget {
  const CreateVibeScreen({super.key});

  @override
  State<CreateVibeScreen> createState() => _CreateVibeScreenState();
}

class _CreateVibeScreenState extends State<CreateVibeScreen> {
  File? _selectedImage;
  bool _isUploading = false;
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // 1. Pick a Single Image for the Vibe
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Slightly compressed for faster 24-hour loading
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  // 2. The Upload Logic
  Future<void> _uploadVibe() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select an image first.")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      // A. Fetch the user's data (Vibes need the profile pic for the top bar!)
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      String myUsername = "Nsnap Creator";
      String myProfilePicUrl = "";

      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>;
        myUsername = userData['username'] ?? myUsername;
        myProfilePicUrl = userData['profilePicUrl'] ?? "";
      }

      String vibeId = DateTime.now().millisecondsSinceEpoch.toString();

      // B. Upload Image to Firebase Storage in a dedicated 'vibes' folder
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('vibes')
          .child(currentUserId)
          .child('$vibeId.jpg');

      UploadTask uploadTask = storageRef.putFile(_selectedImage!);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // C. Save to the separate 'vibes' collection in Firestore
      await FirebaseFirestore.instance.collection('vibes').doc(vibeId).set({
        'vibeId': vibeId,
        'userId': currentUserId,
        'username': myUsername,
        'profilePicUrl': myProfilePicUrl, // So the Home Feed can show the avatar!
        'imageUrl': downloadUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [], // Array for vibe likes
        'viewers': [], // Who has seen this vibe
      });

      // D. Close the screen smoothly
      if (mounted) Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to upload Vibes: $e")));
    }

    setState(() => _isUploading = false);
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
        title: const Text("New Vibe", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
        actions: [
          _isUploading
              ? const Center(child: Padding(padding: EdgeInsets.only(right: 16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: c3MediumSage, strokeWidth: 2))))
              : TextButton(
            onPressed: _uploadVibe,
            child: const Text("Post to Vibes", style: TextStyle(color: c3MediumSage, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: Center(
        child: _selectedImage == null
        // EMPTY STATE
            ? GestureDetector(
          onTap: _pickImage,
          child: Container(
            margin: const EdgeInsets.all(24),
            width: double.infinity,
            // Forcing the 9:16 Story Aspect Ratio even when empty
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Container(
                decoration: BoxDecoration(
                  color: c2DeepOlive.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c2DeepOlive, width: 2),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 60, color: c4LightSage),
                    SizedBox(height: 16),
                    Text("Select a photo for your Vibe", style: TextStyle(color: c4LightSage, fontSize: 16)),
                  ],
                ),
              ),
            ),
          ),
        )
        // PREVIEW STATE
            : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          // This mathematically guarantees it crops properly to phone dimensions
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // The Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover, // Ensures no weird stretching
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                // Reselect Button Overlay
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    onPressed: _pickImage,
                    child: const Icon(Icons.refresh),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}