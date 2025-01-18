import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

class CustomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabChange;

  CustomNavBar({required this.selectedIndex, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20),
        child: GNav(
          selectedIndex: selectedIndex,
          onTabChange: (index) {
            onTabChange(index);
          },
          backgroundColor: Colors.black,
          color: Colors.white,
          activeColor: Colors.white,
          tabBackgroundColor: Colors.grey.shade800,
          padding: EdgeInsets.all(16),
          gap: 8,
          tabs: [
            GButton(
              icon: Icons.home,
              text: "Home",
            ),
            GButton(
              icon: Icons.group,
              text: "Social",
            ),
            GButton(icon:Icons.note_alt,text: "To-Do",),
            GButton(icon: Icons.school_sharp,text: "Scores",),
            GButton(
              icon: Icons.settings,
              text: "Settings",
            ),
          ],
        ),
      ),
    );
  }
}
