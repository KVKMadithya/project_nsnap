import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  // FIX: Removed the underscores so these are public and accessible from the HomeScreen
  final FirebaseAuth auth = FirebaseAuth.instance;
  final GoogleSignIn googleSignIn = GoogleSignIn.instance;

  // --- 1. SIGN UP (With Email Verification) ---
  Future<String?> signUp(String email, String password) async {
    try {
      UserCredential result = await auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password
      );

      // Send the verification email immediately
      await result.user?.sendEmailVerification();

      // Sign them out immediately so they can't bypass the lock
      await auth.signOut();

      return "Success";
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return "An unknown error occurred.";
    }
  }

  // --- 2. LOGIN (With Verification Check) ---
  Future<String?> login(String email, String password) async {
    try {
      UserCredential result = await auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password
      );

      // Check if they clicked the link in their email
      if (!result.user!.emailVerified) {
        await auth.signOut();
        return "Please verify your email before logging in.";
      }
      return "Success";
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return "An unknown error occurred.";
    }
  }

  // --- 3. GOOGLE SIGN IN (Updated for v7+) ---
  Future<String?> signInWithGoogle() async {
    try {
      // You MUST initialize the plugin first now
      await googleSignIn.initialize();

      // 'signIn()' is now 'authenticate()'
      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();
      if (googleUser == null) return "Cancelled";

      // 'authentication' is synchronous now, so NO 'await'
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Firebase only requires the idToken now
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await auth.signInWithCredential(credential);
      return "Success";
    } catch (e) {
      print("Google Sign-In Error: $e");
      return "Error during Google Sign-In.";
    }
  }
}