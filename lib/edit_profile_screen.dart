import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

// Palette Reference
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _pronounsController = TextEditingController();
  final _bioController = TextEditingController();

  bool _isLoading = false;
  bool _isUploadingPic = false; // Tracks just the picture upload
  String? _profilePicUrl; // Holds the current or new profile pic URL

  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  // Fetch existing data so the text boxes aren't empty when you open the screen
  Future<void> _loadCurrentData() async {
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    if (doc.exists) {
      Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
      if (data != null) {
        setState(() {
          _nameController.text = data['name'] ?? '';
          _usernameController.text = data['username'] ?? '';
          _pronounsController.text = data['pronouns'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _profilePicUrl = data['profilePicUrl'];
        });
      }
    }
  }

  // --- THE NEW IMAGE UPLOAD LOGIC ---
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    // 1. Open the gallery
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50); // Quality 50 compresses it nicely

    if (image == null) return; // User canceled

    setState(() => _isUploadingPic = true);

    try {
      File file = File(image.path);

      // 2. Create a folder in Firebase Storage called 'profile_pics'
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pics')
          .child('$currentUserId.jpg');

      // 3. Upload the file
      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot snapshot = await uploadTask;

      // 4. Get the download link
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // 5. Save the link to Firestore immediately
      await FirebaseFirestore.instance.collection('users').doc(currentUserId).set({
        'profilePicUrl': downloadUrl,
      }, SetOptions(merge: true));

      // 6. Update the UI
      setState(() {
        _profilePicUrl = downloadUrl;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e"), backgroundColor: Colors.redAccent));
    }

    setState(() => _isUploadingPic = false);
  }

  // Save text data to Firestore
  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUserId).set({
        'name': _nameController.text,
        'username': _usernameController.text,
        'pronouns': _pronounsController.text,
        'bio': _bioController.text,
      }, SetOptions(merge: true));

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving: $e")));
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _pronounsController.dispose();
    _bioController.dispose();
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
        title: const Text("Edit profile", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
        actions: [
          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.only(right: 16.0), child: CircularProgressIndicator(color: c3MediumSage)))
              : IconButton(
            icon: const Icon(Icons.check, color: c3MediumSage, size: 30),
            onPressed: _saveProfile,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Updated Profile Picture Section
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: c2DeepOlive,
                  // If we have a URL, show the image. Otherwise, show the default icon.
                  backgroundImage: _profilePicUrl != null ? NetworkImage(_profilePicUrl!) : null,
                  child: _profilePicUrl == null ? const Icon(Icons.person, size: 50, color: c4LightSage) : null,
                ),
                if (_isUploadingPic)
                  const CircularProgressIndicator(color: c3MediumSage), // Loading spinner over the image
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isUploadingPic ? null : _pickAndUploadImage,
              child: const Text("Edit picture or avatar", style: TextStyle(color: c3MediumSage, fontSize: 16)),
            ),
            const SizedBox(height: 24),

            // Form Fields
            _buildCustomTextField("Name", _nameController),
            _buildCustomTextField("Username", _usernameController),
            _buildCustomTextField("Pronouns", _pronounsController),
            _buildCustomTextField("Bio", _bioController, maxLines: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: c5CreamGreen),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: c4LightSage),
          filled: true,
          fillColor: c1DeepForest.withValues(alpha: 0.5),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: c2DeepOlive, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: c3MediumSage, width: 2),
          ),
        ),
      ),
    );
  }
}