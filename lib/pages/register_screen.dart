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
              fontSize: 17,
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Blue curved header using ClipPath
          SizedBox(
            width: double.infinity,
            height: 220,
            child: ClipPath(
              clipper: _HeaderCurveClipper(),
              child: Container(
                color: const Color(0xFF2A4288),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      "FinSafe",
                      style: GoogleFonts.barlow(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Sign Up",
                      style: GoogleFonts.barlow(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // White card content
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(top: 140, bottom: 0),
                child: Center(
                  child: Container(
                    width: 400,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueGrey.withOpacity(0.06),
                          spreadRadius: 8,
                          blurRadius: 26,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2A4288),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 2,
                              ),
                              onPressed: isLoading ? null : createUserWithEmailAndPassword,
                              child: isLoading
                                  ? const CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    )
                                  : Text(
                                      'Sign Up',
                                      style: GoogleFonts.barlow(
                                        fontSize: 19,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Expanded(child: Divider(thickness: 1.1)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'or',
                                  style: GoogleFonts.barlow(
                                    color: Colors.blueGrey[200],
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider(thickness: 1.1)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          buildSocialButton(
                            label: "Continue with Google",
                            asset: 'assets/google.png',
                            onTap: () {
                              // TODO: Add your Google sign-in logic here
                            },
                          ),
                          buildSocialButton(
                            label: "Continue with Apple",
                            asset: 'assets/apple.png',
                            onTap: () {
                              // TODO: Add your Apple sign-in logic here
                            },
                            bgColor: Colors.black,
                            textColor: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account? ",
                                style: GoogleFonts.barlow(
                                  fontSize: 15,
                                  color: Colors.blueGrey[400],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Log in',
                                  style: GoogleFonts.barlow(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF2A4288),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
