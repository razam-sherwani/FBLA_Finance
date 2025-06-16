import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:fbla_finance/backend/auth.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _controllerEmail = TextEditingController();

  @override
  void dispose(){
    _controllerEmail.dispose();
    super.dispose();
  }

  Future passwordReset() async{
    try {
      await Auth().sendPasswordResetEmail(email: _controllerEmail.text.trim());
    } on FirebaseAuthException catch(e) {
      showErrorMessage(e.message.toString());
    }
  }

  void showErrorMessage(String message) {
    showDialog(
        context: context,
        builder: (context) {
          return  AlertDialog(
            title: Text(message,
              style: TextStyle(color: Colors.black),
            ),
          );
        });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A4288),
      appBar: AppBar(
        toolbarHeight: 75,
        backgroundColor: const Color(0xFF2A4288),
        elevation: 0,
        centerTitle: true,
        title: Padding(
          padding: const EdgeInsets.only(bottom: 15.0),
          child: Text(
            "Forgot Password",
            style: GoogleFonts.barlow(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        leading: IconButton(
          iconSize: 30,
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Stack(
            children: [
            Container(
              decoration: BoxDecoration(
                // Removed border, added subtle shadow and rounded corners
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40)),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              height: double.infinity,
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.only(left: 18.0, right: 18.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 60), // Move content down from the top
                    Text(
                      'Enter your email below and we will send you a reset link',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 24),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 44),
                    TextField(
                      controller: _controllerEmail,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.email_outlined, color: Colors.blueGrey),
                        labelText: 'Email',
                        labelStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: passwordReset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2A4288),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'SEND EMAIL',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
    );
  }
}