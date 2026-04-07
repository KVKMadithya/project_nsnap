import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';

// --- AESTHETIC CONFIGURATION (Educational Data from palette) ---
// Dark Forest Green (Scaffold Background)
const Color c1DeepForest = Color(0xFF0F2A1D);
// Deep Olive (Inactive borders, subtle text)
const Color c2DeepOlive = Color(0xFF375534);
// Medium Sage Green (Primary Buttons, Active elements)
const Color c3MediumSage = Color(0xFF6B9071);
// Light Sage/Gray (Inactive buttons, soft highlights)
const Color c4LightSage = Color(0xFFAEC3B0);
// Very Light Cream Green (Panel/Card Background, Light Text)
const Color c5CreamGreen = Color(0xFFE3EED4);
// --- ---

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

  // NEW: State variables to track if a field is missing
  bool _emailError = false;
  bool _passError = false;

  @override
  void dispose() {
    // Clean up controllers and focus nodes to prevent memory leaks!
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    // 1. Check if the fields are empty and remove any trailing spaces
    final emailText = _emailController.text.trim();
    final passText = _passwordController.text.trim();

    // 2. Update the error state to trigger the red glow if missing
    setState(() {
      _emailError = emailText.isEmpty;
      _passError = passText.isEmpty;
    });

    // 3. If either field is empty, show the SnackBar and STOP the login process
    if (_emailError || _passError) {
      String errorMessage = "Please enter your email and password.";
      if (_emailError && !_passError) errorMessage = "Please enter your university email.";
      if (!_emailError && _passError) errorMessage = "Please enter your password.";

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.redAccent.shade400));
      return; // This stops the code here so Firebase doesn't crash!
    }

    // 4. If fields are filled, proceed with Firebase Login
    setState(() => _isLoading = true);
    final result = await AuthService().login(emailText, passText);
    setState(() => _isLoading = false);

    if (result != "Success" && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result!),
          backgroundColor: Colors.redAccent.shade400));
    }
  }

  void _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    final result = await AuthService().signInWithGoogle();
    setState(() => _isLoading = false);
    if (result != "Success" && result != "Cancelled" && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result!),
          backgroundColor: Colors.redAccent.shade400));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest, // Foundation Color (Premium background)
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 50),
              // Logo/Aesthetic Header Area
              const Text("Nsnap",
                  style: TextStyle(
                      fontFamily: 'Modern Sans', // Example premium font, defaults if missing
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: c5CreamGreen)),
              const SizedBox(height: 10),
              const Text("Snap the Moment, Share your vibe",
                  style: TextStyle(fontSize: 18, color: c4LightSage)),
              const SizedBox(height: 60),

              // The Premium "Pill" Panel Layer
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: c5CreamGreen, // Light base panel against dark background
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

                    // Modern Input with Focus Animation & Error State
                    _buildAnimatedTextField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        label: "University Email",
                        keyboardType: TextInputType.emailAddress,
                        hasError: _emailError), // Pass the error state
                    const SizedBox(height: 16),
                    _buildAnimatedTextField(
                        controller: _passwordController,
                        focusNode: _passFocus,
                        label: "Password",
                        obscureText: true,
                        hasError: _passError), // Pass the error state
                    const SizedBox(height: 24),

                    // Primary Button with interactive scaling effect
                    _isLoading
                        ? _buildInteractiveLoader()
                        : _buildPremiumButton(
                      label: "Log In",
                      onPressed: _handleLogin,
                      primaryColor: c3MediumSage, // Palette Primary Green
                      textColor: c5CreamGreen,
                    ),
                    const SizedBox(height: 20),
                    const Text("OR", style: TextStyle(color: c4LightSage)),
                    const SizedBox(height: 20),

                    // Modern Social Button
                    _buildPremiumButton(
                      label: "Sign in with Google",
                      icon: Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                          height: 24),
                      onPressed: _isLoading ? null : _handleGoogleLogin,
                      primaryColor: c4LightSage, // Palette Accent Gray
                      textColor: c1DeepForest,
                    ),
                    const SizedBox(height: 24),

                    // Interactively highlighted Register Link
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

  // Builds a premium input field with focus animation & error integration
  Widget _buildAnimatedTextField(
      {required TextEditingController controller,
        required FocusNode focusNode,
        required String label,
        bool obscureText = false,
        TextInputType keyboardType = TextInputType.text,
        bool hasError = false}) { // Added hasError parameter

    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) {
        bool hasFocus = focusNode.hasFocus;

        // Dynamic colors: If error is true, it overrides the normal colors to red
        Color labelColor = hasError ? Colors.redAccent.shade400 : (hasFocus ? c3MediumSage : c2DeepOlive);
        Color enabledLineColor = hasError ? Colors.redAccent.shade400 : c2DeepOlive;
        Color focusedLineColor = hasError ? Colors.redAccent.shade400 : c3MediumSage;

        return TextField(
          controller: controller,
          focusNode: focusNode,
          // When the user starts typing again, we want to clear the error visually (optional but good UX)
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

  // A custom animated loader that oscillates palette colors
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

  // A premium looking button style
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

  // An animated link
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