import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Help & Support", style: GoogleFonts.barlow(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),),
        centerTitle: true,
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Frequently Asked Questions",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildFaqItem("How do I track my expenses?",
                "Navigate to the 'Transactions' tab to view and categorize your expenses."),
            _buildFaqItem("Can I save this data as a PDF?",
                "Yes! Go to 'Transactions' and got to the bottom left corner or the Analysis page and follow the instructions."),
            _buildFaqItem("Is my financial data secure?",
                "Yes, we use industry-standard encryption to protect your data."),
                _buildFaqItem("How do you filter through the transactions",
                "You can filter through your transactions using the filter types listed in the home page."),
            const SizedBox(height: 20),
            const Text(
              "Need Further Assistance?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "If you need additional help, feel free to contact us.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.email, color: Colors.blue),
              title: const Text("finsafeinc@gmail.com"),
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text("+1-470-926-1419"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return ExpansionTile(
      title: Text(question, style: const TextStyle(fontWeight: FontWeight.bold)),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(answer, style: const TextStyle(fontSize: 16)),
        )
      ],
    );
  }
}
