import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:fbla_finance/backend/auth.dart';
import 'package:fbla_finance/pages/login_screen.dart';
import 'package:fbla_finance/main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String? errorMessage = '';
  bool isLoading = false;
  bool isPasswordObscure = true;
  bool isConfirmObscure = true;

  final TextEditingController _controllerFirstName = TextEditingController();
  final TextEditingController _controllerLastName = TextEditingController();
  final TextEditingController _controllerEmail = TextEditingController();
  final TextEditingController _controllerPassword = TextEditingController();
  final TextEditingController _controllerConfirmPassword = TextEditingController();

  @override
  void dispose() {
    _controllerFirstName.dispose();
    _controllerLastName.dispose();
    _controllerEmail.dispose();
    _controllerPassword.dispose();
    _controllerConfirmPassword.dispose();
    super.dispose();
  }

  Future<void> createUserWithEmailAndPassword() async {
    final firstName = _controllerFirstName.text.trim();
    final lastName = _controllerLastName.text.trim();
    final email = _controllerEmail.text.trim();
    final password = _controllerPassword.text;
    final confirm = _controllerConfirmPassword.text;

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirm.isEmpty) {
      showErrorMessage('Please fill out all fields.');
      return;
    }

    if (password != confirm) {
      showErrorMessage("Passwords don't match.");
      return;
    }

    setState(() => isLoading = true);

    try {
      await Auth().createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await FirebaseFirestore.instance.collection('users').add({
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'budget': 1000,
      });

      setState(() => isLoading = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyApp()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
        isLoading = false;
      });
      showErrorMessage(errorMessage!);
    } catch (e) {
      setState(() => isLoading = false);
      showErrorMessage(e.toString());
    }
  }

  void showErrorMessage(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            message,
            style: const TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "OK",
                style: TextStyle(color: Colors.blue),
              ),
            )
          ],
        );
      },
    );
  }

  Widget buildInputField(TextEditingController controller, String hint,
      {bool obscure = false, TextInputType? keyboardType, VoidCallback? onToggle, bool? isObscure}) {
    return TextField(
      controller: controller,
      obscureText: obscure && (isObscure ?? true),
      keyboardType: keyboardType,
      style: GoogleFonts.barlow(fontSize: 18),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        suffixIcon: obscure
            ? IconButton(
                icon: Icon(
                  (isObscure ?? true) ? Icons.visibility_off : Icons.visibility,
                  color: Colors.blueGrey[200],
                ),
                onPressed: onToggle,
              )
            : null,
      ),
    );
  }

  Widget buildSocialButton({
    required String label,
    required String asset,
    required VoidCallback onTap,
    Color? bgColor,
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            backgroundColor: bgColor ?? Colors.white,
            side: BorderSide(color: Colors.grey[200]!),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          onPressed: onTap,
          icon: Image.asset(asset, height: 26, width: 26),
          label: Text(
            label,
            style: GoogleFonts.barlow(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor ?? Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color deepBlue = const Color(0xff133164);
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 8, 42, 93),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 80, bottom: 40),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 8, 42, 93),
            ),
            child: Column(
              children: [
                Text(
                  'FinSafe',
                  style: GoogleFonts.barlow(
                    fontSize: 60,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color.fromARGB(255, 8, 42, 93)),
                borderRadius: BorderRadius.circular(32),
              ),
              width: double.infinity,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sign Up',
                      style: GoogleFonts.barlow(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 8, 42, 93),
                      ),
                    ),
                    const SizedBox(height: 20),
                    buildInputField(_controllerFirstName, "First Name"),
                    const SizedBox(height: 16),
                    buildInputField(_controllerLastName, "Last Name"),
                    const SizedBox(height: 16),
                    buildInputField(_controllerEmail, "Email", keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    buildInputField(
                      _controllerPassword,
                      "Password",
                      obscure: true,
                      onToggle: () {
                        setState(() {
                          isPasswordObscure = !isPasswordObscure;
                        });
                      },
                      isObscure: isPasswordObscure,
                    ),
                    const SizedBox(height: 16),
                    buildInputField(
                      _controllerConfirmPassword,
                      "Confirm Password",
                      obscure: true,
                      onToggle: () {
                        setState(() {
                          isConfirmObscure = !isConfirmObscure;
                        });
                      },
                      isObscure: isConfirmObscure,
                    ),
                    const SizedBox(height: 24),
                    _buildGradientButton('Sign Up', isLoading ? null : createUserWithEmailAndPassword, isLoading: isLoading),
                    const SizedBox(height: 12),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account?",
                            style: GoogleFonts.barlow(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              );
                            },
                            child: Text(
                              'Log in',
                              style: GoogleFonts.barlow(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 8, 42, 93),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            "or",
                            style: GoogleFonts.barlow(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildImageSocialButton(
                      imagePath: 'assets/google.png',
                      label: "Continue with Google",
                      color: Colors.grey.shade100,
                      textColor: Colors.black,
                      borderColor: Colors.grey[300],
                      onTap: () {
                        // TODO: Implement Google sign up
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSocialButton(
                      icon: Icons.apple,
                      label: "Continue with Apple",
                      color: Colors.black,
                      textColor: Colors.white,
                      borderColor: Colors.black,
                      onTap: () {
                        // TODO: Implement Apple sign up
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGradientButton(String label, VoidCallback? onTap, {bool isLoading = false}) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff55e6c1), Color(0xff39baf9)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextButton(
        onPressed: onTap,
        child: isLoading
            ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
            : Text(
                label,
                style: GoogleFonts.barlow(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 30,
                ),
              ),
      ),
      );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: OutlinedButton.icon(
        icon: Icon(icon, color: textColor, size: 24),
        label: Text(
          label,
          style: GoogleFonts.barlow(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: color,
          side: BorderSide(color: borderColor ?? Colors.transparent, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildImageSocialButton({
    required String imagePath,
    required String label,
    required Color color,
    required Color textColor,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: color,
          side: BorderSide(color: borderColor ?? Colors.transparent, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, height: 24, width: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.barlow(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom clipper for the blue header curve
class _HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(
      size.width / 2, size.height,
      size.width, size.height - 60,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
