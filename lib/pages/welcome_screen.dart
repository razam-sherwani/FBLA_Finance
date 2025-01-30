import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fbla_finance/backend/auth.dart';
import 'package:fbla_finance/main.dart';
import 'package:fbla_finance/pages/login_screen.dart';
import 'package:fbla_finance/pages/register_screen.dart';
import 'package:fbla_finance/util/square_tile.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String? errorMessage;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
          height: double.infinity,
          width: double.infinity,
          decoration: BoxDecoration(
              color: const Color.fromARGB(255, 230, 230, 230),),
          child: Column(
            children: [
              SizedBox(height: 80,),
              Text("FinSafe", style: GoogleFonts.barlow(textStyle: TextStyle(fontSize: 75, fontWeight: FontWeight.bold, color: Colors.blue.shade900))),
              Padding(
                  padding: const EdgeInsets.only(top: 25.0),
                  child: Image.asset("assets/Logo.png", height: 1428*0.125,),
                  ),
              SizedBox(
                height: 40,
              ),
              Text("Secure. Strategic. Seamless.", style: GoogleFonts.barlow(textStyle: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.blue.shade900))),
              SizedBox(height: 50,),
              SizedBox(
                height: 30,
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => LoginScreen()));
                },
                child: Container(
                  height: 53,
                  width: 270,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade300,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.black),
                  ),
                  child: Center(
                      child: Text(
                    'LOG IN',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  )),
                ),
              ),
              SizedBox(
                height: 30,
              ),
              GestureDetector(
                onTap:() {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => RegisterScreen()));
                },
                child: Container(
                  height: 53,
                  width: 270,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade300,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.black),
                  ),
                  child: Center(
                      child: Text(
                    'SIGN UP',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  )),
                ),
              ),
              SizedBox(height: 30,),
              Text(
                'Login with Social Media',
                style: TextStyle(fontSize: 17, color: Colors.blue.shade900),
              ),
              SizedBox(
                height: 5,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children:  [
                  // google button
                  GestureDetector(
                    child: SquareTile(imagePath: 'assets/google.png'),
                    onTap: signInWithGoogle,  
                  ),

                  SizedBox(width: 25),

                  // apple button
                  SquareTile(imagePath: 'assets/apple.png'),

                   SizedBox(width: 25),

                  // apple button
                  SquareTile(imagePath: 'assets/facebook.png')
                ],
              ),
              SizedBox(
                height: 10,
              ),
            ],
          )),
    );
  }

  Future<void> signInWithGoogle() async {
    try {
      await Auth().signInWithGoogle();
       Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => MyApp()));
    } on FirebaseAuthException catch(e){
      setState(() {
        errorMessage = e.message;
      });
      showErrorMessage(errorMessage!);
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
}
