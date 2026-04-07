import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // <--- SWAPPED to dotenv

// --- YOUR SCREEN IMPORTS ---
import 'login_screen.dart';
import 'home_screen.dart';

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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F2A1D),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF6B9071))),
          );
        }

        if (snapshot.hasData) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}