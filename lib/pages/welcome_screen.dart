import 'dart:io';

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
              gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  stops: [
                    0.3,
                    0.6,
                    0.9
                  ],
                  colors: [
                Color(0xff56018D),
                
                Color(0xff8B139C),
                Colors.pink,
              ])),
          child: Column(
            children: [
              Padding(
                  padding: const EdgeInsets.only(top: 200.0),
                  child: Image.asset("assets/Logo.png",),
                  
                  ),
              SizedBox(
                height: 50,
              ),
              Text(
                'Welcome Back',
                style: TextStyle(fontSize: 30, color: Colors.white),
              ),
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
                  width: 320,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white),
                  ),
                  child: Center(
                      child: Text(
                    'SIGN IN',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
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
                  width: 320,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white),
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
              Spacer(),
              Text(
                'Login with Social Media',
                style: TextStyle(fontSize: 17, color: Colors.white),
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
