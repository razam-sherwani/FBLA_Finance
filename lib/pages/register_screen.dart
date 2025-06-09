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
      style: const TextStyle(fontSize: 19),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.blueGrey[200], fontWeight: FontWeight.w500),
        filled: true,
        fillColor: Colors.white.withOpacity(0.80),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blueGrey[100]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blueGrey[100]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blue.shade200, width: 2),
        ),
        suffixIcon: obscure
            ? IconButton(
                icon: Icon(
                  (isObscure ?? true) ? Icons.visibility_off : Icons.visibility,
                  color: Colors.blueGrey[300],
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
        height: 56,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            backgroundColor: bgColor ?? Colors.white,
            side: BorderSide(color: Colors.blueGrey[100]!),
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
              fontSize: 19,
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
    final blue = Colors.blue.shade900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xfffafdff),
              Color(0xffe6f0fb),
              Color(0xffe7ecfa),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 42),
                // App Logo at top
                Opacity(
                  opacity: 0.92,
                  child: Image.asset(
                    "assets/Logo.png",
                    height: 70,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Create Your Account",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.barlow(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: blue,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "Start your financial journey.\nIt's quick and easy.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.barlow(
                    fontSize: 19,
                    color: Colors.blueGrey[400],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 38),
                buildInputField(_controllerFirstName, "First Name"),
                const SizedBox(height: 20),
                buildInputField(_controllerLastName, "Last Name"),
                const SizedBox(height: 20),
                buildInputField(_controllerEmail, "Email", keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
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
                const SizedBox(height: 30),
                // Sign Up Button or Spinner
                SizedBox(
                  width: double.infinity,
                  height: 62,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      elevation: 5,
                      shadowColor: blue.withOpacity(0.12),
                    ),
                    onPressed: isLoading ? null : createUserWithEmailAndPassword,
                    child: isLoading
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : Text(
                            'Sign Up',
                            style: GoogleFonts.barlow(
                              fontSize: 22,
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 22),
                // Divider with 'or'
                Row(
                  children: [
                    const Expanded(child: Divider(thickness: 1.2)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: GoogleFonts.barlow(
                          color: Colors.blueGrey[300],
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(thickness: 1.2)),
                  ],
                ),
                const SizedBox(height: 18),
                // Social Login Buttons
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
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: GoogleFonts.barlow(
                        fontSize: 17,
                        color: Colors.blueGrey[500],
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
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
