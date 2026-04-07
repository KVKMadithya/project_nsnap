import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart'; // Reuse the config colors

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // 1. Added the new controllers
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // 2. Added the new focus nodes
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  bool _isLoading = false;

  // Error tracking states
  bool _emailError = false;
  bool _usernameError = false;
  bool _addressError = false;
  bool _passError = false;
  bool _confirmError = false;

  @override
  void dispose() {
    // Clean up ALL controllers and focus nodes to prevent memory leaks!
    _emailController.dispose();
    _usernameController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    _emailFocus.dispose();
    _usernameFocus.dispose();
    _addressFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _handleSignUp() async {
    final emailText = _emailController.text.trim();
    final usernameText = _usernameController.text.trim();
    final addressText = _addressController.text.trim();
    final passText = _passwordController.text;
    final confirmText = _confirmPasswordController.text;

    // Validate empty fields
    setState(() {
      _emailError = emailText.isEmpty;
      _usernameError = usernameText.isEmpty;
      _addressError = addressText.isEmpty;
      _passError = passText.isEmpty;
      _confirmError = confirmText.isEmpty || passText != confirmText;
    });

    if (_emailError || _usernameError || _addressError || _passError || _confirmError) {
      String errorMessage = "Please fill in all fields.";
      if (passText != confirmText && passText.isNotEmpty && confirmText.isNotEmpty) {
        errorMessage = "Passwords do not match!";
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.redAccent.shade400));
      return;
    }

    setState(() => _isLoading = true);

    // NOTE: Right now this just creates the Auth account.
    // We will need to update AuthService soon to save the Username and Address to Firestore!
    final result = await AuthService().signUp(
      emailText,
      passText,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result == "Success") {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: c5CreamGreen,
          title: const Text("Verify Your Email", style: TextStyle(color: c1DeepForest)),
          content: const Text(
              "We've sent a verification link to your inbox. Click the link to activate your Nsnap account.",
              style: TextStyle(color: c2DeepOlive)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to Login Screen
              },
              child: const Text("OK", style: TextStyle(color: c3MediumSage, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result!), backgroundColor: Colors.redAccent.shade400));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest, // Foundation background
      appBar: AppBar(
        title: const Text("Create Account"),
        backgroundColor: Colors.transparent, // Maintain background flow
        elevation: 0,
        foregroundColor: c5CreamGreen,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Floating Premium Panel
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: c5CreamGreen,
                  borderRadius: const BorderRadius.all(Radius.circular(30.0)),
                  boxShadow: [
                    BoxShadow(
                        color: c1DeepForest.withValues(alpha: 0.3),
                        spreadRadius: 2,
                        blurRadius: 15,
                        offset: const Offset(0, 10))
                  ],
                ),
                child: Column(
                  children: [
                    const Text("Join Nsnap",
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: c1DeepForest)),
                    const SizedBox(height: 10),
                    const Text("Start Showcasing Your Talent",
                        style: TextStyle(fontSize: 16, color: c2DeepOlive)),
                    const SizedBox(height: 30),

                    // Updated Input Fields with error states
                    _buildAnimatedTextField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        label: "Email",
                        keyboardType: TextInputType.emailAddress,
                        hasError: _emailError),
                    const SizedBox(height: 16),

                    _buildAnimatedTextField(
                        controller: _usernameController,
                        focusNode: _usernameFocus,
                        label: "Username",
                        hasError: _usernameError),
                    const SizedBox(height: 16),

                    _buildAnimatedTextField(
                        controller: _addressController,
                        focusNode: _addressFocus,
                        label: "Address",
                        hasError: _addressError),
                    const SizedBox(height: 16),

                    _buildAnimatedTextField(
                        controller: _passwordController,
                        focusNode: _passFocus,
                        label: "Password",
                        obscureText: true,
                        hasError: _passError),
                    const SizedBox(height: 16),

                    _buildAnimatedTextField(
                        controller: _confirmPasswordController,
                        focusNode: _confirmFocus,
                        label: "Confirm Password",
                        obscureText: true,
                        hasError: _confirmError),
                    const SizedBox(height: 32),

                    // Premium button and interaction state reuse
                    _isLoading
                        ? const SizedBox(height: 50, child: Center(child: Text("Creating Account...", style: TextStyle(color: c3MediumSage))))
                        : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _handleSignUp,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: c3MediumSage, // Active palette green
                            foregroundColor: c5CreamGreen,
                            elevation: 0,
                            shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(25)))),
                        child: const Text("Sign Up", style: TextStyle(fontSize: 16)),
                      ),
                    ),
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

  // Uses the exact same error-handling builder from the Login Screen
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
                if (controller == _usernameController) _usernameError = false;
                if (controller == _addressController) _addressError = false;
                if (controller == _passwordController) _passError = false;
                if (controller == _confirmPasswordController) _confirmError = false;
              });
            }
          },
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: labelColor),
            border: const UnderlineInputBorder(),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: focusedLineColor, width: 2)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: enabledLineColor)),
          ),
          style: const TextStyle(color: c1DeepForest),
          obscureText: obscureText,
          keyboardType: keyboardType,
        );
      },
    );
  }
}