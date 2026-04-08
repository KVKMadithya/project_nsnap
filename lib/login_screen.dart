import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';

// --- NEW IMPORTS FOR ROUTING ---
import 'home_feed_screen.dart'; // Ensure this points to your actual main app screen
import '../admin_side/admin_home_screen.dart'; // <--- UPDATED: Pointing to the Nav Bar Shell!

// --- AESTHETIC CONFIGURATION (Educational Data from palette) ---
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();

  bool _isLoading = false;
  bool _emailError = false;
  bool _passError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  // ===========================================================================
  // THE GATEKEEPER: Checks Firestore for the "admin" role before routing
  // ===========================================================================
  Future<void> _routeUserAfterLogin() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        // Fetch their specific profile from the database
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          // Look for the role field. If it doesn't exist, default to 'user'
          String role = (userDoc.data() as Map<String, dynamic>)['role'] ?? 'user';

          if (mounted) {
            if (role == 'admin') {
              // ACCESS GRANTED: Send to Admin Nav Bar Shell
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminHomeScreen())); // <--- UPDATED!
            } else {
              // STANDARD USER: Send to the Main App
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeFeedScreen()));
            }
          }
        } else {
          // Failsafe: If they don't have a Firestore doc yet, send them to the normal app
          if (mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeFeedScreen()));
          }
        }
      } catch (e) {
        // Failsafe: If the database check fails, default to normal user routing
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeFeedScreen()));
        }
      }
    }
  }

  void _handleLogin() async {
    final emailText = _emailController.text.trim();
    final passText = _passwordController.text.trim();

    setState(() {
      _emailError = emailText.isEmpty;
      _passError = passText.isEmpty;
    });

    if (_emailError || _passError) {
      String errorMessage = "Please enter your email and password.";
      if (_emailError && !_passError) errorMessage = "Please enter your university email.";
      if (!_emailError && _passError) errorMessage = "Please enter your password.";

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.redAccent.shade400));
      return;
    }

    setState(() => _isLoading = true);
    final result = await AuthService().login(emailText, passText);

    if (result == "Success") {
      // Login worked! Now check their role and route them.
      await _routeUserAfterLogin();
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result!),
            backgroundColor: Colors.redAccent.shade400));
      }
    }
  }

  void _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    final result = await AuthService().signInWithGoogle();

    if (result == "Success") {
      // Google Login worked! Check their role and route them.
      await _routeUserAfterLogin();
    } else {
      setState(() => _isLoading = false);
      if (result != "Cancelled" && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result!),
            backgroundColor: Colors.redAccent.shade400));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 50),
              const Text("Nsnap",
                  style: TextStyle(
                      fontFamily: 'Modern Sans',
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: c5CreamGreen)),
              const SizedBox(height: 10),
              const Text("Snap the Moment, Share your vibe",
                  style: TextStyle(fontSize: 18, color: c4LightSage)),
              const SizedBox(height: 60),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: c5CreamGreen,
                  borderRadius:
                  const BorderRadius.all(Radius.circular(30.0)),
                  boxShadow: [
                    BoxShadow(
                      color: c1DeepForest.withValues(alpha: 0.3),
                      spreadRadius: 2,
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    const Text("Log In",
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: c1DeepForest)),
                    const SizedBox(height: 10),
                    const Text("Welcome Back to Nsnap",
                        style: TextStyle(fontSize: 16, color: c2DeepOlive)),
                    const SizedBox(height: 40),

                    _buildAnimatedTextField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        label: "University Email",
                        keyboardType: TextInputType.emailAddress,
                        hasError: _emailError),
                    const SizedBox(height: 16),
                    _buildAnimatedTextField(
                        controller: _passwordController,
                        focusNode: _passFocus,
                        label: "Password",
                        obscureText: true,
                        hasError: _passError),
                    const SizedBox(height: 24),

                    _isLoading
                        ? _buildInteractiveLoader()
                        : _buildPremiumButton(
                      label: "Log In",
                      onPressed: _handleLogin,
                      primaryColor: c3MediumSage,
                      textColor: c5CreamGreen,
                    ),
                    const SizedBox(height: 20),
                    const Text("OR", style: TextStyle(color: c4LightSage)),
                    const SizedBox(height: 20),

                    _buildPremiumButton(
                      label: "Sign in with Google",
                      icon: Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                          height: 24),
                      onPressed: _isLoading ? null : _handleGoogleLogin,
                      primaryColor: c4LightSage,
                      textColor: c1DeepForest,
                    ),
                    const SizedBox(height: 24),

                    _buildInteractiveLink(
                        label: "Don't have an account? Register",
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const SignupScreen()));
                        }),
                  ],
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // --- INTERACTIVE UI WIDGET BUILDERS ---

  Widget _buildAnimatedTextField(
      {required TextEditingController controller,
        required FocusNode focusNode,
        required String label,
        bool obscureText = false,
        TextInputType keyboardType = TextInputType.text,
        bool hasError = false}) {

    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) {
        bool hasFocus = focusNode.hasFocus;

        Color labelColor = hasError ? Colors.redAccent.shade400 : (hasFocus ? c3MediumSage : c2DeepOlive);
        Color enabledLineColor = hasError ? Colors.redAccent.shade400 : c2DeepOlive;
        Color focusedLineColor = hasError ? Colors.redAccent.shade400 : c3MediumSage;

        return TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (value) {
            if (hasError) {
              setState(() {
                if (controller == _emailController) _emailError = false;
                if (controller == _passwordController) _passError = false;
              });
            }
          },
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: labelColor),
            border: const UnderlineInputBorder(),
            focusedBorder:
            UnderlineInputBorder(borderSide: BorderSide(color: focusedLineColor, width: 2)),
            enabledBorder:
            UnderlineInputBorder(borderSide: BorderSide(color: enabledLineColor)),
          ),
          style: const TextStyle(color: c1DeepForest),
          obscureText: obscureText,
          keyboardType: keyboardType,
        );
      },
    );
  }

  Widget _buildInteractiveLoader() {
    return SizedBox(
      height: 50,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: const TextStyle(color: c3MediumSage, fontSize: 18),
          child: const Text("Authenticating..."),
        ),
      ),
    );
  }

  Widget _buildPremiumButton(
      {required String label,
        required VoidCallback? onPressed,
        required Color primaryColor,
        required Color textColor,
        Widget? icon}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        icon: icon ?? const SizedBox.shrink(),
        label: Text(label, style: const TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: textColor,
            elevation: 0,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(25)))),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildInteractiveLink(
      {required String label, required VoidCallback onPressed}) {
    return TextButton(
      onPressed: onPressed,
      child: Text(label,
          style: const TextStyle(
              color: c3MediumSage, fontWeight: FontWeight.bold)),
    );
  }
}