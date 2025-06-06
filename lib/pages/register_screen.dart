// lib/pages/register_screen.dart

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

    try {
      // Create user in FirebaseAuth
      await Auth().createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Add user details to Firestore
      await FirebaseFirestore.instance.collection('users').add({
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'budget': 1000,
      });

      // Navigate into the main app
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyApp()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
      showErrorMessage(errorMessage!);
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    // Total screen height (should be ~926 logical pixels)
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SizedBox(
          height: screenHeight,
          width: double.infinity,
          child: Column(
            children: [
              // ==== TOP: Logo + Title + Motto + Heading ====

              // 1) Top blank gap (to push content down a bit)
              const SizedBox(height: 20), // 20 px

              // 2) Logo image (80 px tall)
              Image.asset(
                'assets/Logo.png',
                height: 80,
                fit: BoxFit.contain,
              ),

              // 3) Gap: 8 px
              const SizedBox(height: 8),

              // 4) “FinSafe” Title (fontSize 40 => ~40 px)
              Text(
                'FinSafe',
                style: GoogleFonts.barlow(
                  textStyle: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),

              // 5) Gap: 4 px
              const SizedBox(height: 4),

              // 6) Motto (fontSize 16 => ~20 px tall)
              Text(
                'Secure. Strategic. Seamless.',
                style: GoogleFonts.barlow(
                  textStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                    letterSpacing: 0.5,
                  ),
                ),
                textAlign: TextAlign.center,
              ),

              // 7) Gap before heading: 16 px
              const SizedBox(height: 16),

              // 8) “Create an account” heading (fontSize 20 => ~24 px tall)
              Text(
                'Create an account',
                style: GoogleFonts.barlow(
                  textStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),

              // 9) Gap: 2 px
              const SizedBox(height: 2),

              // 10) Subtitle (fontSize 14 => ~18 px tall)
              Text(
                'Enter your email to sign up for this app',
                style: GoogleFonts.barlow(
                  textStyle: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                textAlign: TextAlign.center,
              ),

              // 11) SMALL SPACER to push the form block down
              const Spacer(flex: 1),

              // ==== MIDDLE: Form Fields & Continue Button ====

              // 12) First Name Field (50 px tall)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  height: 50,
                  child: TextField(
                    controller: _controllerFirstName,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'First Name',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),

              // 13) Gap: 8 px
              const SizedBox(height: 8),

              // 14) Last Name Field (50 px)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  height: 50,
                  child: TextField(
                    controller: _controllerLastName,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Last Name',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),

              // 15) Gap: 8 px
              const SizedBox(height: 8),

              // 16) Email Field (50 px)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  height: 50,
                  child: TextField(
                    controller: _controllerEmail,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'email@domain.com',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),

              // 17) Gap: 8 px
              const SizedBox(height: 8),

              // 18) Password Field (50 px)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  height: 50,
                  child: TextField(
                    controller: _controllerPassword,
                    obscureText: true,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: const Icon(
                        Icons.visibility_off,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),

              // 19) Gap: 8 px
              const SizedBox(height: 8),

              // 20) Confirm Password Field (50 px)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  height: 50,
                  child: TextField(
                    controller: _controllerConfirmPassword,
                    obscureText: true,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Confirm Password',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: const Icon(
                        Icons.visibility_off,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),

              // 21) Gap: 16 px before Continue button
              const SizedBox(height: 16),

              // 22) Continue Button (48 px tall)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade900,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: createUserWithEmailAndPassword,
                    child: Text(
                      'Continue',
                      style: GoogleFonts.barlow(
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 23) Gap: 12 px before “Log in” link
              const SizedBox(height: 12),

              // 24) “Already have an account? Log in” (16 px tall)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: Text(
                  'Already have an account? Log in',
                  style: GoogleFonts.barlow(
                    textStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ),

              // 25) Gap: 16 px before divider
              const SizedBox(height: 16),

              // 26) Divider with “or” (approx 14 px tall)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  children: const [
                    Expanded(
                      child: Divider(color: Colors.grey, thickness: 0.5),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'or',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: Colors.grey, thickness: 0.5),
                    ),
                  ],
                ),
              ),

              // 27) Gap: 16 px before social buttons
              const SizedBox(height: 16),

              // 28) “Continue with Google” Button (48 px tall)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: Image.asset(
                      'assets/google.png',
                      height: 24,
                      width: 24,
                    ),
                    label: Text(
                      'Continue with Google',
                      style: GoogleFonts.barlow(
                        textStyle: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    onPressed: () {
                      // TODO: Hook up Google Sign-In logic here
                    },
                  ),
                ),
              ),

              // 29) Gap: 8 px between social buttons
              const SizedBox(height: 8),

              // 30) “Continue with Apple” Button (48 px tall)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(
                      Icons.apple,
                      size: 24,
                      color: Colors.black,
                    ),
                    label: Text(
                      'Continue with Apple',
                      style: GoogleFonts.barlow(
                        textStyle: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    onPressed: () {
                      // TODO: Hook up Sign-In with Apple logic here
                    },
                  ),
                ),
              ),

              // 31) Final spacer to absorb any extra space
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
