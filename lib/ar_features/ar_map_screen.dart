import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart'; // <--- NEW: Essential for distance math
import 'ar_viewer_screen.dart';

// Palette Reference
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class ARMapScreen extends StatefulWidget {
  const ARMapScreen({super.key});

  @override
  State<ARMapScreen> createState() => _ARMapScreenState();
}

class _ARMapScreenState extends State<ARMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  // NSBM Green University Coordinates (approximate center)
  final LatLng _campusCenter = const LatLng(6.8213, 80.0416);

  // 1. Fetch drops and convert them to Map Markers
  void _loadMarkers() {
    FirebaseFirestore.instance.collection('ar_drops').snapshots().listen((snapshot) {
      Set<Marker> newMarkers = {};
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        newMarkers.add(
          Marker(
            markerId: MarkerId(data['dropId']),
            position: LatLng(data['latitude'], data['longitude']),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: "AR Drop Found!",
              snippet: "Tap to unlock 3D View",
              onTap: () async {
                // --- THE DISTANCE LOCK LOGIC ---

                // 1. Get user's current live position
                Position userPos = await Geolocator.getCurrentPosition(
                    desiredAccuracy: LocationAccuracy.best
                );

                // 2. Calculate distance between user and the pin (in meters)
                double distanceInMeters = Geolocator.distanceBetween(
                    userPos.latitude, userPos.longitude,
                    data['latitude'], data['longitude']
                );

                // 3. Check if user is within the 20m "Unlock Zone"
                if (distanceInMeters <= 20) {
                  if (mounted) {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (context) => ARViewerScreen(dropData: data)
                    ));
                  }
                } else {
                  // If too far, show a helpful message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Too far! Walk ${ (distanceInMeters - 20).round() }m closer to unlock this drop.",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: Colors.orangeAccent,
                          behavior: SnackBarBehavior.floating,
                        )
                    );
                  }
                }
              },
            ),
          ),
        );
      }
      if (mounted) {
        setState(() => _markers = newMarkers);
      }
    });
  }

  // 2. Custom Dark Map Style
  final String _darkMapStyle = '''
  [
    { "elementType": "geometry", "stylers": [ { "color": "#0F2A1D" } ] },
    { "elementType": "labels.text.fill", "stylers": [ { "color": "#AEC3B0" } ] },
    { "featureType": "road", "elementType": "geometry", "stylers": [ { "color": "#375534" } ] }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest,
      appBar: AppBar(
        backgroundColor: c1DeepForest,
        elevation: 0,
        title: const Text("Discovery Map", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: c5CreamGreen),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _campusCenter,
              zoom: 16,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _mapController!.setMapStyle(_darkMapStyle);
            },
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
          ),

          // Radar Overlay UI
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: c1DeepForest.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: c3MediumSage, width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.radar, color: c3MediumSage),
                  SizedBox(width: 12),
                  Text("Scanning for nearby drops...", style: TextStyle(color: c4LightSage, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}