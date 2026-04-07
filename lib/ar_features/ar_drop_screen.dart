import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Palette Reference
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class ARDropScreen extends StatefulWidget {
  const ARDropScreen({super.key});

  @override
  State<ARDropScreen> createState() => _ARDropScreenState();
}

class _ARDropScreenState extends State<ARDropScreen> {
  File? _selectedImage;
  bool _isProcessing = false;
  String _statusText = "Scan your surroundings...";

  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  Future<void> _getImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 70,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _statusText = "Ready to anchor this post.";
      });
    }
  }

  Future<void> _createARDrop() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _statusText = "Locking Spatial Coordinates...";
    });

    try {
      // 1. Get position AND heading
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation
      );

      setState(() => _statusText = "Pinning to AR Matrix...");

      String dropId = "AR_${DateTime.now().millisecondsSinceEpoch}";
      Reference storageRef = FirebaseStorage.instance.ref().child('ar_drops').child('$dropId.jpg');
      await storageRef.putFile(_selectedImage!);
      String downloadUrl = await storageRef.getDownloadURL();

      // 2. Save with 'heading' field
      await FirebaseFirestore.instance.collection('ar_drops').doc(dropId).set({
        'dropId': dropId,
        'userId': currentUserId,
        'imageUrl': downloadUrl,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'altitude': position.altitude,
        'heading': position.heading, // <--- NEW: Saves the direction user is facing
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() => _statusText = "POST ANCHORED SUCCESSFULLY!");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Drop Complete! Walk away to see it in AR."),
              backgroundColor: c3MediumSage,
            )
        );
      }

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);

    } catch (e) {
      setState(() {
        _statusText = "Interruption: $e";
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("AR Spacial Drop", style: TextStyle(color: c5CreamGreen, fontSize: 16)),
        iconTheme: const IconThemeData(color: c5CreamGreen),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _selectedImage != null ? c3MediumSage : c2DeepOlive, width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_selectedImage == null)
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.filter_center_focus, size: 80, color: c2DeepOlive),
                          SizedBox(height: 10),
                          Text("Position Frame", style: TextStyle(color: c4LightSage)),
                        ],
                      ),

                    if (_selectedImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                      ),

                    if (_selectedImage != null)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(30),
            decoration: const BoxDecoration(
              color: c1DeepForest,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_statusText, style: const TextStyle(color: c4LightSage, fontSize: 14)),
                const SizedBox(height: 20),

                if (_selectedImage == null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCircularButton(Icons.photo_library, "Gallery", () => _getImage(ImageSource.gallery)),
                      _buildCircularButton(Icons.camera_alt, "Camera", () => _getImage(ImageSource.camera)),
                    ],
                  )
                else
                  _isProcessing
                      ? const CircularProgressIndicator(color: c3MediumSage)
                      : SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _createARDrop,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c3MediumSage,
                        foregroundColor: c1DeepForest,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text("ANCHOR IN 3D SPACE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularButton(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c3MediumSage, width: 2),
              color: c2DeepOlive.withValues(alpha: 0.3),
            ),
            child: Icon(icon, color: c5CreamGreen, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: c4LightSage, fontSize: 12)),
      ],
    );
  }
}