import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fbla_finance/pages/register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 🔵 Expanded dark blue header
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: BoxDecoration(
              color: Colors.blue.shade900,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "FinSafe",
                  style: GoogleFonts.barlow(
                    fontSize: 60,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 160 * 1.25,
                  width: 260 * 1.25,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFe7b8ff),
                        Color(0xFFb7e9ff),
                        Color(0xFFcaffbf),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Image.asset(
                      "assets/Logo.png",
                      height: 80 * 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              
            ),
          ),

          const SizedBox(height: 40),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  "Manage your money wisely",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.barlow(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Take control of your finances with FinSafe — the easiest and most powerful way to track your money.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.barlow(
                    fontSize: 24,
                    color: Colors.grey[900],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
            child: SizedBox(
              width: double.infinity,
              height: 66,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 5,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                child: Ink(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF72d1ff), Color(0xFF60efff)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                  child: Center(
                    child: Text(
                      'Get Started',
                      style: GoogleFonts.barlow(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
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
