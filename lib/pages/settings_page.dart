import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fbla_finance/backend/auth.dart';
import 'package:fbla_finance/backend/read_data/get_user_name.dart';
import 'package:fbla_finance/pages/appearance_page.dart';
import 'package:fbla_finance/pages/chatbot.dart';
import 'package:fbla_finance/util/profile_picture.dart';
import 'package:fbla_finance/util/setting_item.dart';
import 'package:fbla_finance/util/setting_switch.dart';
import 'package:fbla_finance/pages/forward_button.dart';
import 'package:fbla_finance/pages/edit_screen.dart';



class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final User? user = Auth().currentUser;

  String docID = "";

  @override
  void initState() {
    super.initState();
    fetchDocID();
  }

  Future<void> fetchDocID() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          setState(() {
            docID = snapshot.docs[0].id;
          });
        } else {
          setState(() {
            docID = '';
          });
        }
      }).catchError((error) {
        print('Error fetching docID: $error');
        setState(() {
          docID = '';
        });
      });
    }
  }

  
  Future<void> signOut() async {
    await Auth().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10,),
              const Text(
                "Settings",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                "Account",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    ProfilePicture(userId: docID),
                    const SizedBox(width: 20),
                     Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<String>(
                              future: GetUserName(documentId: docID)
                                  .getUserName(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Text('Loading...',
                                      style: TextStyle(color: Colors.white));
                                } else if (snapshot.hasError) {
                                  print(snapshot.error);
                                  return Text('Error',
                                      style: TextStyle(color: Colors.white));
                                } else if (snapshot.hasData &&
                                    snapshot.data != null) {
                                  String userName = snapshot.data!;
                                  return Text(
                                    "Hi $userName!",
                                    style: TextStyle(
                                      
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                } else {
                                  return Text('Username not available',
                                      style: TextStyle(color: Colors.white));
                                }
                              },
                            ),
                        SizedBox(height: 10),
                        Text(
                          "Your Profile",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                        )
                      ],
                    ),
                    const Spacer(),
                    ForwardButton(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>  ChangeAccountScreen(docID: docID,),
                          ),
                        );
                      },
                    )
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                "Settings",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              SettingItem(
                title: "Help",
                icon: Icons.help,
                bgColor: Colors.red.shade100,
                iconColor: Colors.red,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AdvancedChatbot()),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              SettingItem(
                title: "Appearance",
                icon: Icons.color_lens,
                bgColor: Colors.blue.shade100,
                iconColor: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AppearancePage(userId: docID,)),
                  );
                },
              ),
              const SizedBox(height: 20),
              SettingItem(
                title: "Sign Out",
                icon: Icons.logout,
                bgColor: Colors.pink.shade100,
                iconColor: Colors.pink,
                onTap: signOut
                ,
              ),
            ],
          ),
        ),
      ),
    );
  }
}