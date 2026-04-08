import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// --- YOUR SCREEN IMPORTS ---
import 'login_screen.dart';
import 'home_screen.dart'; // Adjust if your main screen is called HomeFeedScreen
import 'admin_side/admin_home_screen.dart'; // <--- FIXED: Pointing to the Nav Bar Shell!

void main() async {
  // 1. Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. THE NEW WAKE-UP CALL
  // This reads your .env file without touching those broken Android files.
  try {
    await dotenv.load(fileName: ".env");
    print("✅ .env file loaded successfully");
  } catch (e) {
    print("❌ Could not load .env file: $e");
  }

  // 3. Initialize Firebase
  await Firebase.initializeApp();

  runApp(const NsnapApp());
}

class NsnapApp extends StatelessWidget {
  const NsnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nsnap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Using your "Deep Forest" and "Medium Sage" aesthetic
        primaryColor: const Color(0xFF6B9071),
        scaffoldBackgroundColor: const Color(0xFF0F2A1D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B9071),
          brightness: Brightness.dark,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Loading Auth State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F2A1D),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF6B9071))),
          );
        }

        // 2. User is Logged In -> NOW CHECK THEIR ROLE
        if (snapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, roleSnapshot) {

              // Show a spinner while we check the database for their role
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFF0F2A1D),
                  body: Center(child: CircularProgressIndicator(color: Color(0xFF6B9071))),
                );
              }

              // Check if they have the 'admin' tag
              if (roleSnapshot.hasData && roleSnapshot.data!.exists) {
                var data = roleSnapshot.data!.data() as Map<String, dynamic>?;
                String role = data != null && data.containsKey('role') ? data['role'] : 'user';

                if (role == 'admin') {
                  // FIXED: Route them to the Nav Bar Shell so they can switch tabs!
                  return const AdminHomeScreen();
                }
              }

              // If not an admin, or if something went wrong, send to normal app
              return const HomeScreen();
            },
          );
        }

        // 3. User is NOT Logged In
        return const LoginScreen();
      },
    );
  }
}