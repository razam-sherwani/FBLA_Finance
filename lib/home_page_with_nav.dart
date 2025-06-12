import 'package:fbla_finance/pages/plaid_page.dart';
import 'package:fbla_finance/pages/receipt_scanner_page.dart';
import 'package:fbla_finance/pages/savings_budget_page.dart';
import 'package:fbla_finance/pages/split_transactions.dart';
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
import 'package:fbla_finance/pages/reports.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'dart:io';
import 'package:fbla_finance/pages/spending_habit.dart';

class HomePageWithNav extends StatefulWidget {
  @override
  HomePageWithNavState createState() => HomePageWithNavState();
}
class HomePageWithNavState extends State<HomePageWithNav> {
  int _selectedIndex = 0;
  bool _isInitialized = false; // Add initialization flag

    final List<Widget Function()> _pageBuilders = [
  () => HomePage(),
  () => Transactions(),
  () => SettingsPage(),
  () => BudgetSavingsPage(),
  () => Reports(),
  () => SpendingHabitPage(),
  () => HomePage()
];


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _isInitialized = true;
      });
    });
  }

    void onItemTapped(int index) {
    if (index >= 0 && index < _pageBuilders.length) {
      if (index == 3) { // "More" tab selected
        _showMoreMenu(context);
        return;
      }
      setState(() {
        _selectedIndex = index;
      });
    }
  }
  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Colors.black,
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.savings, color: Colors.white),
              title: Text('Savings', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 3);
              },
            ),
            ListTile(
              leading: Icon(Icons.summarize, color: Colors.white),
              title: Text('Reports', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 4);
              },
            ),
            ListTile(
              leading: Icon(Icons.query_stats, color: Colors.white),
              title: Text('Analysis', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 5);
              },
            ),
            ListTile(
              leading: Icon(Icons.emoji_events, color: Colors.white),
              title: Text('Awards', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 6);
              },
            ),
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      body: _pageBuilders[_selectedIndex](),
      bottomNavigationBar: CustomNavBar(
        selectedIndex: _selectedIndex,
        onTabChange: onItemTapped,
      ),
    );
  }
}
// class HomePageWithNavState extends State<HomePageWithNav> {
//   int _selectedIndex = 0;

  // static List<Widget> _pages = <Widget>[
  //   HomePage(),
  //   Transactions(),
  //   SettingsPage(),
  //   BudgetSavingsPage(),
  //   Reports(),
  //   SpendingHabitPage(),
  //   HomePage() // Your 7th page
  // ];

//   void onItemTapped(int index) {
//     if (index == 3) { // "More" tab selected
//       _showMoreMenu(context);
//       return;
//     }
//     setState(() {
//       _selectedIndex = index;
//     });
//   }

//   void _showMoreMenu(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => Container(
//         color: Colors.black,
//         child: Wrap(
//           children: [
//             ListTile(
//               leading: Icon(Icons.savings, color: Colors.white),
//               title: Text('Savings', style: TextStyle(color: Colors.white)),
//               onTap: () {
//                 Navigator.pop(context);
//                 setState(() => _selectedIndex = 3);
//               },
//             ),
//             ListTile(
//               leading: Icon(Icons.summarize, color: Colors.white),
//               title: Text('Reports', style: TextStyle(color: Colors.white)),
//               onTap: () {
//                 Navigator.pop(context);
//                 setState(() => _selectedIndex = 4);
//               },
//             ),
//             ListTile(
//               leading: Icon(Icons.query_stats, color: Colors.white),
//               title: Text('Analysis', style: TextStyle(color: Colors.white)),
//               onTap: () {
//                 Navigator.pop(context);
//                 setState(() => _selectedIndex = 5);
//               },
//             ),
//             ListTile(
//               leading: Icon(Icons.emoji_events, color: Colors.white),
//               title: Text('Awards', style: TextStyle(color: Colors.white)),
//               onTap: () {
//                 Navigator.pop(context);
//                 setState(() => _selectedIndex = 6);
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: _pages[_selectedIndex],
//       bottomNavigationBar: CustomNavBar(
//         selectedIndex: _selectedIndex,
//         onTabChange: onItemTapped,
//       ),
//     );
//   }
// }