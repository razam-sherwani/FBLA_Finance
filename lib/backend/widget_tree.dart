import 'package:flutter/material.dart';
import 'package:fbla_finance/backend/auth.dart';
import 'package:fbla_finance/pages/welcome_screen.dart';
import 'package:fbla_finance/home_page_with_nav.dart'; // import this new file

class WidgetTree extends StatefulWidget {
  const WidgetTree({super.key});

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Auth().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          // User is logged in
          return HomePageWithNav();
        } else {
          // User is not logged in
          return const WelcomeScreen();
        }
      },
    );
  }
}
