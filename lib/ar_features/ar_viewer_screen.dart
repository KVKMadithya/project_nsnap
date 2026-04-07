import 'dart:math'; // <--- NEW: Required for the Sin/Cos math
import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin_flutterflow/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_flutterflow/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_flutterflow/models/ar_node.dart';
import 'package:ar_flutter_plugin_flutterflow/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_flutterflow/managers/ar_object_manager.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

// Palette Reference
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c5CreamGreen = Color(0xFFE3EED4);

class ARViewerScreen extends StatefulWidget {
  final Map<String, dynamic> dropData;
  const ARViewerScreen({super.key, required this.dropData});

  @override
  State<ARViewerScreen> createState() => _ARViewerScreenState();
}

class _ARViewerScreenState extends State<ARViewerScreen> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: c1DeepForest,
        title: const Text("AR Discovery",
            style: TextStyle(color: c5CreamGreen, fontSize: 16)),
        iconTheme: const IconThemeData(color: c5CreamGreen),
      ),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: c1DeepForest.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: c3MediumSage, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.explore_outlined, color: c3MediumSage),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Look around to find the anchored post. It's locked to a specific direction!",
                      style: TextStyle(color: c5CreamGreen.withValues(alpha: 0.9), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void onARViewCreated(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      dynamic arAnchorManager,
      dynamic arLocationManager) {

    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;

    this.arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      showWorldOrigin: false,
    );
    this.arObjectManager!.onInitialize();

    // Small delay to allow ARCore/ARKit to initialize tracking
    Future.delayed(const Duration(seconds: 2), () {
      _spawnARImage();
    });
  }

  Future<void> _spawnARImage() async {
    // 1. Get the saved heading (compass direction) from Firestore
    double heading = widget.dropData['heading'] ?? 0.0;

    // 2. THE SPATIAL MATH
    // We convert the heading into X and Z coordinates so the image
    // stays in one spot even if the user turns around.
    const double distance = 2.0; // Fixed distance from the anchor point
    final double x = distance * sin(heading * pi / 180);
    final double z = -distance * cos(heading * pi / 180);

    final transformation = vector.Matrix4.identity();
    // Y=0.5 keeps it roughly at eye level
    transformation.setTranslationRaw(x, 0.5, z);

    final newNode = ARNode(
      type: NodeType.webGLB,
      uri: widget.dropData['imageUrl'],
      transformation: transformation,
    );

    bool? didAdd = await arObjectManager!.addNode(newNode);

    if (didAdd == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Point your camera at the ground to calibrate...")),
      );
    }
  }
}