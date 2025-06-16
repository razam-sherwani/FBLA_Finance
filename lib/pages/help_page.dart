import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Color and style constants for consistency
const double kAppBarHeight = 75;
const Color kAppBarColor = Color(0xFF2A4288);
const TextStyle kAppBarTextStyle = TextStyle(
  fontFamily: 'Barlow',
  fontWeight: FontWeight.bold,
  fontSize: 28,
  color: Colors.white,
);

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBarColor,
      appBar: AppBar(
        toolbarHeight: kAppBarHeight,
        backgroundColor: kAppBarColor,
        elevation: 0,
        centerTitle: true,
        title: Padding(
          padding: const EdgeInsets.only(bottom: 15.0),
          child: Text(
            "Help & Support",
            style: kAppBarTextStyle,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20),
                // FAQ Section
                Row(
                  children: [
                    Icon(Icons.help_outline, color: kAppBarColor, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      "Frequently Asked Questions",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(thickness: 1.2, color: Colors.blueGrey[100]),
                _buildFaqItem(
                  "How do I track my expenses?",
                  "Navigate to the 'Transactions' tab to view and categorize your expenses.",
                ),
                _buildFaqItem(
                  "Can I save this data as a PDF?",
                  "Yes! Go to 'Transactions' and go to the bottom left corner or the Analysis page and follow the instructions.",
                ),
                _buildFaqItem(
                  "Is my financial data secure?",
                  "Yes, we use industry-standard encryption to protect your data.",
                ),
                _buildFaqItem(
                  "How do you filter through the transactions",
                  "You can filter through your transactions using the filter types listed in the home page.",
                ),
                const SizedBox(height: 24),
                // Contact Section
                Row(
                  children: [
                    Icon(Icons.support_agent, color: kAppBarColor, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      "Need Further Assistance?",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(thickness: 1.2, color: Colors.blueGrey[100]),
                Text(
                  "If you need additional help, feel free to contact us.",
                  style: TextStyle(fontSize: 16, color: Colors.blueGrey[700]),
                ),
                const SizedBox(height: 10),
                Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: const Icon(Icons.email, color: Colors.blue),
                    title: const Text("finsafeinc@gmail.com"),
                  ),
                ),
                Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: const Icon(Icons.phone, color: Colors.green),
                    title: const Text("+1-470-926-1419"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}
