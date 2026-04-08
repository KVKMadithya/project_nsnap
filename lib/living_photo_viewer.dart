import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LivingPhotoViewer extends StatefulWidget {
  final String imageUrl;

  const LivingPhotoViewer({super.key, required this.imageUrl});

  @override
  State<LivingPhotoViewer> createState() => _LivingPhotoViewerState();
}

class _LivingPhotoViewerState extends State<LivingPhotoViewer> {
  double _xOffset = 0.0;
  double _yOffset = 0.0;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  // The absolute maximum pixels the image is allowed to shift.
  // Because we scale the image up by 20%, we have plenty of safe buffer.
  final double _maxPan = 30.0;

  @override
  void initState() {
    super.initState();
    // Listen to the phone's physical gyroscope/accelerometer
    _accelSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      if (mounted) {
        setState(() {
          // Clamp it hard so it never moves out of the safe zone
          // event.x is inverted (-) so it moves opposite to your tilt for a 3D effect
          _xOffset = (-event.x * 8).clamp(-_maxPan, _maxPan);
          _yOffset = (event.y * 8).clamp(-_maxPan, _maxPan);
        });
      }
    });
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get the EXACT screen dimensions from the device
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 2. Force the base container to match the screen exactly
          SizedBox(
            width: screenSize.width,
            height: screenSize.height,
            // 3. Scale it up by 20% to create an invisible buffer off-screen
            child: Transform.scale(
              scale: 1.2,
              // 4. Translate (shift) the scaled image using the sensor data
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(_xOffset, _yOffset, 0),
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl,
                  // 5. GUARANTEES the image stretches to fill the oversized box
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Color(0xFF6B9071))
                  ),
                  errorWidget: (context, url, error) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image, color: Colors.white54, size: 50),
                          SizedBox(height: 10),
                          Text("Failed to load the image", style: TextStyle(color: Colors.white54)),
                        ],
                      )
                  ),
                ),
              ),
            ),
          ),

          // BACK BUTTON
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}