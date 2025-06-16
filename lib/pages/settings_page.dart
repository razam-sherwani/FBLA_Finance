import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_finance/pages/chat_screen.dart';
import 'package:fbla_finance/pages/help_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fbla_finance/backend/auth.dart';
import 'package:fbla_finance/backend/read_data/get_user_name.dart';
import 'package:fbla_finance/pages/appearance_page.dart';
import 'package:fbla_finance/util/setting_item.dart';
import 'package:fbla_finance/util/setting_switch.dart';
import 'package:fbla_finance/pages/forward_button.dart';
import 'package:fbla_finance/pages/edit_screen.dart';

const double kAppBarHeight = 75;
const Color kAppBarColor = Color(0xFF2A4288);
const TextStyle kAppBarTextStyle = TextStyle(
  fontFamily: 'Barlow',
  fontWeight: FontWeight.bold,
  fontSize: 28,
  color: Colors.white,
);

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
    var currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: currentUser.email)
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

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            "Sign Out",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          content: const Text(
            "Are you sure you want to sign out?",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 18,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                "Sign Out",
                style: TextStyle(
                  color: Color(0xFF2A4288),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                signOut();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;

    return Scaffold(
      backgroundColor: kAppBarColor,
      appBar: AppBar(
        toolbarHeight: 40,
        backgroundColor: kAppBarColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            "Settings",
            style: kAppBarTextStyle,
            textAlign: TextAlign.center,
          ),
        ),
        actions: [
          if (photoUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 18.0, top: 8),
              child: CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(photoUrl),
                backgroundColor: Colors.white,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 18.0, top: 8),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: kAppBarColor),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Account",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 25),
                      SettingItem(
                        title: "Edit Profile",
                        icon: Icons.person,
                        bgColor: Colors.blue.shade100,
                        iconColor: Colors.blue,
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChangeAccountScreen(docID: docID),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 25),
                      const Text(
                        "Settings",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 25),
                      SettingItem(
                        title: "Notification",
                        icon: Icons.notifications,
                        bgColor: Colors.purple.shade100,
                        iconColor: Colors.purple,
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        onTap: () {
                          // Implement notification settings navigation
                        },
                      ),
                      const SizedBox(height: 25),
                      SettingItem(
                        title: "Currency",
                        icon: Icons.wallet,
                        bgColor: Colors.green.shade100,
                        iconColor: Colors.green,
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        onTap: () {
                          // Implement currency settings navigation
                        },
                      ),
                      const SizedBox(height: 25),
                      SettingItem(
                        title: 'Appearance',
                        icon: Icons.color_lens,
                        bgColor: Colors.orange.shade100,
                        iconColor: Colors.orange,
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AppearancePage(userId: docID)),
                          );
                        },
                      ),
                      const SizedBox(height: 25),
                      SettingItem(
                        title: "Help & Feedback",
                        icon: Icons.help_outline,
                        bgColor: Colors.red.shade100,
                        iconColor: Colors.red,
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => HelpPage()),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                      Center(
                        child: ElevatedButton(
                          onPressed: _showSignOutDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE0E7FF),
                            foregroundColor: const Color(0xFF2A4288),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Sign Out",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
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