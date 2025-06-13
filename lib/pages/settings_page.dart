import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_finance/pages/chat_screen.dart';
import 'package:fbla_finance/pages/help_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fbla_finance/backend/auth.dart';
import 'package:fbla_finance/backend/read_data/get_user_name.dart';
import 'package:fbla_finance/pages/appearance_page.dart';
import 'package:fbla_finance/util/setting_item.dart';
import 'package:fbla_finance/util/setting_switch.dart'; // Keep if used elsewhere
import 'package:fbla_finance/pages/forward_button.dart'; // Keep this as SettingItem uses it
import 'package:fbla_finance/pages/edit_screen.dart'; // Assuming ChangeAccountScreen is here

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
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Are you sure you want to sign out?",
            style: TextStyle(color: Colors.black87),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Sign Out", style: TextStyle(color: Color(0xFF2A4288), fontWeight: FontWeight.bold)),
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
      backgroundColor: const Color(0xFF2A4288), // Dark blue background for the entire screen
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A4288), // Dark blue app bar
        elevation: 0,
        automaticallyImplyLeading: false, // THIS REMOVES THE BACK ARROW
        title: const Text(
          "Settings",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        // The main content area with white background and rounded top corners
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),

                // Edit Profile Setting Item
                SettingItem(
                  title: "Edit Profile",
                  icon: Icons.person,
                  bgColor: Colors.blue.shade100, // Example color, adjust as needed
                  iconColor: Colors.blue, // Example color, adjust as needed
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChangeAccountScreen(docID: docID),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),

                // Settings Section Header
                const Text(
                  "Settings",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),

                // Notification Setting Item
                SettingItem(
                  title: "Notification",
                  icon: Icons.notifications,
                  bgColor: Colors.purple.shade100, // Example color
                  iconColor: Colors.purple, // Example color
                  onTap: () {
                    print("Navigate to Notification settings");
                    // Implement actual navigation to your notification settings page here
                  },
                ),
                const SizedBox(height: 20),

                // Currency Setting Item
                SettingItem(
                  title: "Currency",
                  icon: Icons.wallet,
                  bgColor: Colors.green.shade100, // Example color
                  iconColor: Colors.green, // Example color
                  onTap: () {
                    print("Navigate to Currency settings");
                    // Implement actual navigation to your currency settings page here
                  },
                ),
                const SizedBox(height: 20),

                // Appearance Setting Item
                SettingItem(
                  title: 'Appearance',
                  icon: Icons.color_lens,
                  bgColor: Colors.orange.shade100, // Example color
                  iconColor: Colors.orange, // Example color
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AppearancePage(userId: docID)),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Help & Feedback Setting Item
                SettingItem(
                  title: "Help & Feedback",
                  icon: Icons.help_outline,
                  bgColor: Colors.red.shade100, // Example color
                  iconColor: Colors.red, // Example color
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => HelpPage()),
                    );
                  },
                ),
                const SizedBox(height: 30), // Added some extra space before the button

                // Sign Out Button (restyled to be solid light blue fill with dark blue text)
                Center(
                  child: ElevatedButton(
                    onPressed: _showSignOutDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE0E7FF), // Solid light blue background
                      foregroundColor: const Color(0xFF2A4288), // Dark blue text/icon color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // Slightly rounded corners
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), // Larger padding
                      elevation: 0, // No shadow for a flatter look
                    ),
                    child: const Text(
                      "Sign Out",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30), // Space at the bottom
              ],
            ),
          ),
        ),
      ),
      // No BottomAppBar as requested
    );
  }
}