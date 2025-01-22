import 'package:fbla_finance/pages/transactions.dart';
import 'package:fbla_finance/util/custom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fbla_finance/backend/widget_tree.dart';
import 'package:fbla_finance/pages/awards_page.dart';
import 'package:fbla_finance/pages/home_page.dart';
import 'package:fbla_finance/pages/scholarships.dart';
import 'package:fbla_finance/pages/settings_page.dart';
import 'package:fbla_finance/pages/to_do.dart';
import 'package:fbla_finance/pages/welcome_screen.dart';
import 'package:fbla_finance/backend/widget_tree.dart';
import 'package:fbla_finance/firebase_options.dart';
import 'package:fbla_finance/pages/social_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'dart:io';

class HomePageWithNav extends StatefulWidget {
  @override
  _HomePageWithNavState createState() => _HomePageWithNavState();
}

// HomePageWithNav

class _HomePageWithNavState extends State<HomePageWithNav> {
  int _selectedIndex = 0;

  static List<Widget> _pages = <Widget>[
    HomePage(),
    SocialPage(),
    ToDoList1(),
    ScholarshipFinder(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: CustomNavBar(
        selectedIndex: _selectedIndex,
        onTabChange: (index) {
          _onItemTapped(index);
        },
      ),
    );
  }
}
