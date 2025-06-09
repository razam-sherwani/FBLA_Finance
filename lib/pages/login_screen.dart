import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fbla_finance/pages/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Simulate log in for now
  void _login() {/* TODO: Login logic here */}

  @override
  Widget build(BuildContext context) {
    final Color deepBlue = const Color(0xff133164);
    final Color bgColor = const Color(0xfffafdff);

    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Blue header background with custom curve
          SizedBox(
            width: screenWidth,
            height: screenHeight * 0.36,
            child: CustomPaint(
              painter: _HeaderPainter(),
            ),
          ),
          // "FinSafe" in header
          Positioned(
            top: 64,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "FinSafe",
                style: GoogleFonts.barlow(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 38,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
          // White card overlay
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: EdgeInsets.only(top: screenHeight * 0.18),
              width: screenWidth * 0.91,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 18,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Large headline
                    Text(
                      "Log in or sign up",
                      style: GoogleFonts.barlow(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: deepBlue,
                        letterSpacing: -0.2,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 24),
                    // Email field
                    _buildField(_emailController, "Email", false),
                    const SizedBox(height: 15),
                    // Password field
                    _buildField(_passwordController, "Password", true),
                    const SizedBox(height: 24),
                    // Log In button (gradient)
                    SizedBox(
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xff55e6c1), Color(0xff39baf9)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            "Log in",
                            style: GoogleFonts.barlow(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    // Divider with "Or"
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey[200], thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            "Or",
                            style: GoogleFonts.barlow(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey[200], thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Don't have an account? Sign up
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: GoogleFonts.barlow(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[400],
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 7),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            );
                          },
                          child: Text(
                            "Sign up",
                            style: GoogleFonts.barlow(
                              fontWeight: FontWeight.w900,
                              color: deepBlue,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Navy Sign up button
                    SizedBox(
                      height: 45,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: deepBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          "Sign up",
                          style: GoogleFonts.barlow(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Custom TextField builder
  Widget _buildField(TextEditingController controller, String hint, bool isPassword) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: GoogleFonts.barlow(fontSize: 16, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// Custom painter for the blue curved header
class _HeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xff133164);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height * 0.86)
      ..quadraticBezierTo(
        size.width / 2, size.height,
        size.width, size.height * 0.86,
      )
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
