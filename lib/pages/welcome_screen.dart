import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fbla_finance/pages/register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue.shade900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xfffafdff),
              Color(0xffe6f0fb),
              Color(0xffe7ecfa),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              // Logo
              Image.asset(
                "assets/Logo.png",
                height: 200,
              ),
              const SizedBox(height: 48),
              Text(
                "Welcome to FinSafe",
                textAlign: TextAlign.center,
                style: GoogleFonts.barlow(
                  fontSize: 44, // Bigger headline
                  fontWeight: FontWeight.w900,
                  color: blue,
                  letterSpacing: -1.3,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                "Manage your money wisely",
                textAlign: TextAlign.center,
                style: GoogleFonts.barlow(
                  fontSize: 28, // Bigger tagline
                  color: Colors.blueGrey[400],
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Take control of your finances with FinSafe — the easiest and most powerful way to track your money.",
                textAlign: TextAlign.center,
                style: GoogleFonts.barlow(
                  fontSize: 20, // Bigger description
                  color: Colors.blueGrey[300],
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 60), // Button is now higher up
                child: SizedBox(
                  width: double.infinity,
                  height: 68,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 5,
                      shadowColor: blue.withOpacity(0.18),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Get Started',
                      style: GoogleFonts.barlow(
                        fontSize: 25, // Bigger button text
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
