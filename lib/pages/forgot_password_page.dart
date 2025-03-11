import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:fbla_finance/backend/auth.dart';

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
      body: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Stack(
            children: [
              Container(
              height: double.infinity,
              width: double.infinity,
              decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 14, 78, 174)),
              child: Padding(
                padding: EdgeInsets.only(top: 60.0, left: 22),
                child: Text(
                  'Forgot Your\nPassword?',
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
                  border: Border.all(color: const Color.fromARGB(255, 190, 190, 190), width: 4),
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40)),
                  color: Colors.white  ,
                ),
                height: double.infinity,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.only(left: 18.0, right: 18.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                              'Enter your email below and we will send you a reset link',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
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
                      SizedBox(height: 30,),
                      GestureDetector(
                        onTap: passwordReset,
                        child: Container(
                          height: 55,
                          width: 300,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              color: Colors.blue.shade400),
                          child: Center(
                            child: Text('SEND EMAIL',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Colors.white,
                                )),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ],
          ),
        ),)
    );
  }
}