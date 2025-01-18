import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fbla_finance/backend/auth.dart';
import 'package:fbla_finance/pages/forgot_password_page.dart';
import 'package:fbla_finance/pages/register_screen.dart';
import 'package:fbla_finance/main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? errorMessage = '';

  final TextEditingController _controllerEmail = TextEditingController();
  final TextEditingController _controllerPassword = TextEditingController();

  Future<void> signInWithEmailAndPassword() async {
    try {
      await Auth().signInWithEmailAndPassword(email: _controllerEmail.text, password: _controllerPassword.text);
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
  Widget _errorMessage(){
    return Text(errorMessage=='' ? '': 'Humm ? $errorMessage');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SingleChildScrollView(
      child: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Stack(
          children: [
            Container(
              height: double.infinity,
              width: double.infinity,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  stops: [
                    0.1,
                    0.2,
                    0.3
                  ],
                  colors: [
                Color(0xff56018D),
                
                Color(0xff8B139C),
                Colors.pink,
              ])),
              child: Padding(
                padding: EdgeInsets.only(top: 60.0, left: 22),
                child: Text(
                  'Hello\nSign in!',
                  style: TextStyle(
                      fontSize: 30,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 200.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40)),
                  color: Colors.white,
                ),
                height: double.infinity,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.only(left: 18.0, right: 18.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextField(
                        controller: _controllerEmail,
                        decoration: InputDecoration(
                            suffixIcon: Icon(Icons.check, color: Colors.grey),
                            label: Text(
                              'Email',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            )),
                      ),
                      TextField(
                        obscureText: true,
                        controller: _controllerPassword,
                        decoration: InputDecoration(
                            suffixIcon:
                                Icon(Icons.visibility_off, color: Colors.grey),
                            label: Text(
                              'Password',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            )),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: (){
                            Navigator.push(context,MaterialPageRoute(builder: (context){
                              return ForgotPasswordPage();
                            }));
                          },
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: Color(0xff281537)),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 70,
                      ),
                      GestureDetector(
                        onTap:signInWithEmailAndPassword,
                        child: Container(
                          height: 55,
                          width: 300,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
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
                          child: Center(
                            child: Text('SIGN IN',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Colors.white,
                                )),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 150,
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Don't have an account?",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            RegisterScreen()));
                              },
                              child: Text(
                                "Sign up",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: Colors.black,
                                ),
                              ),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
