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
              fontSize: 24, // Increased size
            ),
          ),
          content: const Text(
            "Are you sure you want to sign out?",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18, // Increased size
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 18, // Increased size
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
                  fontSize: 18, // Increased size
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
    return Scaffold(
      backgroundColor: const Color(0xFF2A4288),
      appBar: AppBar(
  backgroundColor: const Color(0xFF2A4288),
  elevation: 0,
  automaticallyImplyLeading: false,
  title: Container(
    padding: const EdgeInsets.only(top: 10), // Add bottom padding to lower the text
    child: const Text(
      "Settings",
      style: TextStyle(
        color: Colors.white,
        fontSize: 40,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
  centerTitle: true,
  toolbarHeight: 80, // Increase toolbar height to accommodate larger text
),
      body: Column(
        children: [
          // Added space between header and white box
          const SizedBox(height: 30),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Account Section Header
                      const Text(
                        "Account",
                        style: TextStyle(
                          fontSize: 24, // Increased size
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 25), // Increased spacing

                      // Edit Profile Setting Item
                      SettingItem(
                        title: "Edit Profile",
                        icon: Icons.person,
                        bgColor: Colors.blue.shade100,
                        iconColor: Colors.blue,
                        textStyle: const TextStyle(
                          fontSize: 18, // Increased size
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
                      const SizedBox(height: 25), // Increased spacing

                      // Settings Section Header
                      const Text(
                        "Settings",
                        style: TextStyle(
                          fontSize: 24, // Increased size
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 25), // Increased spacing

                      // Notification Setting Item
                      SettingItem(
                        title: "Notification",
                        icon: Icons.notifications,
                        bgColor: Colors.purple.shade100,
                        iconColor: Colors.purple,
                        textStyle: const TextStyle(
                          fontSize: 18, // Increased size
                          fontWeight: FontWeight.w500,
                        ),
                        onTap: () {
                          print("Navigate to Notification settings");
                        },
                      ),
                      const SizedBox(height: 25), // Increased spacing

                      // Currency Setting Item
                      SettingItem(
                        title: "Currency",
                        icon: Icons.wallet,
                        bgColor: Colors.green.shade100,
                        iconColor: Colors.green,
                        textStyle: const TextStyle(
                          fontSize: 18, // Increased size
                          fontWeight: FontWeight.w500,
                        ),
                        onTap: () {
                          print("Navigate to Currency settings");
                        },
                      ),
                      const SizedBox(height: 25), // Increased spacing

                      // Appearance Setting Item
                      SettingItem(
                        title: 'Appearance',
                        icon: Icons.color_lens,
                        bgColor: Colors.orange.shade100,
                        iconColor: Colors.orange,
                        textStyle: const TextStyle(
                          fontSize: 18, // Increased size
                          fontWeight: FontWeight.w500,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AppearancePage(userId: docID)),
                          );
                        },
                      ),
                      const SizedBox(height: 25), // Increased spacing

                      // Help & Feedback Setting Item
                      SettingItem(
                        title: "Help & Feedback",
                        icon: Icons.help_outline,
                        bgColor: Colors.red.shade100,
                        iconColor: Colors.red,
                        textStyle: const TextStyle(
                          fontSize: 18, // Increased size
                          fontWeight: FontWeight.w500,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => HelpPage()),
                          );
                        },
                      ),
                      const SizedBox(height: 40), // Increased spacing

                      // Sign Out Button
                      Center(
                        child: ElevatedButton(
                          onPressed: _showSignOutDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE0E7FF),
                            foregroundColor: const Color(0xFF2A4288),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18), // Increased padding
                            elevation: 0,
                          ),
                          child: const Text(
                            "Sign Out",
                            style: TextStyle(
                              fontSize: 20, // Increased size
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30), // Increased spacing
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