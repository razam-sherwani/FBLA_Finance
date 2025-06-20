import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_finance/home_page_with_nav.dart';
import 'package:fbla_finance/pages/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fbla_finance/backend/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../util/profile_picture.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart'; // Import the dependency

const double kAppBarHeight = 75;
const Color kAppBarColor = Color(0xFF2A4288);
const TextStyle kAppBarTextStyle = TextStyle(
  fontFamily: 'Barlow',
  fontWeight: FontWeight.bold,
  fontSize: 28,
  color: Colors.white,
);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _recentTransactions = [];
  String docID = "";
  double _totalBalance = 0.0;

  // Define GlobalKeys for the elements you want to highlight
  final GlobalKey _welcomeBannerKey = GlobalKey();
  final GlobalKey _totalBalanceCardKey = GlobalKey();
  final GlobalKey _recentTransactionsTitleKey = GlobalKey();
  final GlobalKey _reportsShortcutKey = GlobalKey();
  final GlobalKey _chatFabKey = GlobalKey();

  TutorialCoachMark? tutorialCoachMark;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchDocIDAndTransactions();
    // No tutorial auto-start here, it's triggered by the info icon
  }

  @override
  void dispose() {
    tutorialCoachMark?.finish();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchDocIDAndTransactions() async {
    final user = Auth().currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .get();
      if (snapshot.docs.isNotEmpty) {
        docID = snapshot.docs.first.id;
        await fetchRecentTransactions();
        await fetchTotalBalance();
      }
    }
  }

  Future<void> fetchRecentTransactions() async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(docID)
        .collection('Transactions')
        .orderBy('date', descending: true)
        .limit(5)
        .get();

    setState(() {
      _recentTransactions = query.docs.map((doc) {
        final data = doc.data();
        return {
          'amount': data['amount'] ?? 0.0,
          'type': data['type'] ?? 'Unknown',
          'category': data['category'] ?? 'Uncategorized',
          'date': (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    });
  }

  Future<void> fetchTotalBalance() async {
    double total = 0.0;
    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(docID)
        .collection('Transactions')
        .get();
    for (var doc in query.docs) {
      final data = doc.data();
      if (data['type'] == 'Income') {
        total += (data['amount'] ?? 0.0);
      } else {
        total -= (data['amount'] ?? 0.0);
      }
    }
    setState(() {
      _totalBalance = total;
    });
  }

  void _navigateToReportsViaNavBar(BuildContext context) {
    final navState = context.findAncestorStateOfType<HomePageWithNavState>();
    if (navState != null) {
      navState.setSelectedIndex(4);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Navigation bar not found.'),
        ),
      );
    }
  }

  // Adjusted _buildTutorialContent to fit the new design (white background, colored text)
  Widget _buildTutorialContent({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, // White background for the tutorial bubble
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.13), // Lighter background for the icon
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.barlow(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: color, // Title text color matches the icon color
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: GoogleFonts.barlow(
                    fontSize: 16,
                    color: Colors.grey[800], // Description text color
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTutorial() {
    List<TargetFocus> targets = [
      TargetFocus(
        keyTarget: _welcomeBannerKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: _buildTutorialContent(
              icon: Icons.home_rounded,
              color: Colors.blueAccent,
              title: "Welcome Banner",
              description: "Welcome to your FBLA Finance Home! This banner greets you.",
            ),
          ),
        ],
      ),
      TargetFocus(
        keyTarget: _totalBalanceCardKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: _buildTutorialContent(
              icon: Icons.account_balance_wallet,
              color: Colors.green,
              title: "Quick Overview",
              description: "Here's your Quick Overview, showing your total balance, income, and expenses.",
            ),
          ),
        ],
      ),
      TargetFocus(
        keyTarget: _recentTransactionsTitleKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: _buildTutorialContent(
              icon: Icons.history,
              color: Colors.deepPurple,
              title: "Recent Transactions",
              description: "See your most recent transactions listed here.",
            ),
          ),
        ],
      ),

      TargetFocus(
        keyTarget: _chatFabKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: _buildTutorialContent(
              icon: Icons.chat_bubble_outline,
              color: Colors.blue,
              title: "AI Chat Assistant",
              description: "Need help? Tap this button to chat with our AI assistant for financial advice!",
            ),
          ),
        ],
      ),
    ];

    tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black.withOpacity(0.85),
      textSkip: "SKIP",
      paddingFocus: 12,
      opacityShadow: 0.85,
      hideSkip: false,
      onFinish: () {},
      onSkip: () => true,
    )..show(context: context);
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2A4288);
    const accentColor = Color(0xff39baf9);
    const bgColor = Colors.white;

    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? '';

    return Scaffold(
      backgroundColor: kAppBarColor,
      appBar: AppBar(
        toolbarHeight: kAppBarHeight,
        backgroundColor: kAppBarColor,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 10.0),
          child: GestureDetector(
            onTap: _showTutorial, // Trigger tutorial on tap
            child: Container(
              padding: const EdgeInsets.all(6),
              child: const Icon(
                Icons.info_outline,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(bottom: 15.0),
          child: Text(
            "Home",
            style: kAppBarTextStyle,
          ),
        ),
        actions: [
          if (userId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10.0, top: 8),
              child: ProfilePicture(userId: userId),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
          ),
        ),
        child: ListView(
          controller: _scrollController, // Attach the ScrollController
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            // Assign keys to the widgets you want to highlight
            _buildWelcomeBanner(key: _welcomeBannerKey),
            const SizedBox(height: 28),
            _buildTotalBalanceCard(key: _totalBalanceCardKey),
            const SizedBox(height: 28),
            _buildSectionTitle("Recent Transactions", primaryColor, key: _recentTransactionsTitleKey),
            const SizedBox(height: 10),
            _buildRecentTransactionsCard(),
            const SizedBox(height: 28),
            _buildSectionTitle("Reports", primaryColor),
            const SizedBox(height: 14),
            _buildReportShortcut(
              context,
              key: _reportsShortcutKey,
              icon: Icons.description_outlined,
              label: "View Reports",
              color: accentColor,
              onTap: () {
                _navigateToReportsViaNavBar(context);
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: _chatFabKey,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ChatScreen()),
          );
        },
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        child: const Icon(Icons.chat),
      ),
    );
  }

  // --- Helper Methods ---

  Widget _buildWelcomeBanner({Key? key}) {
    return Container(
      key: key, // Assign the key here
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromRGBO(132, 255, 201, 1),
            Color.fromRGBO(170, 178, 255, 1),
            Color.fromRGBO(255, 97, 246, 1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Welcome Back!",
            style: GoogleFonts.barlow(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Here's a quick overview of your finances.",
            style: GoogleFonts.barlow(
              fontSize: 16,
              color: Colors.white.withOpacity(0.95),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalBalanceCard({Key? key}) {
    double totalIncome = 0;
    double totalExpense = 0;
    for (var txn in _recentTransactions) {
      if (txn['type'] == 'Income') {
        totalIncome += txn['amount'] ?? 0.0;
      } else {
        totalExpense += txn['amount'] ?? 0.0;
      }
    }
    double net = totalIncome - totalExpense;

    return Container(
      key: key, // Assign the key here
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xff39baf9).withOpacity(0.10), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Quick Overview", style: GoogleFonts.barlow(fontSize: 17, color: Colors.grey[700], fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Balance", style: GoogleFonts.barlow(fontSize: 15, color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2).format(_totalBalance),
                      style: GoogleFonts.barlow(
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                        color: _totalBalance >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xff39baf9).withOpacity(0.13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Color(0xff39baf9),
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildOverviewStat(
                icon: Icons.arrow_upward,
                label: "Income",
                value: totalIncome,
                color: Colors.green,
              ),
              _buildOverviewStat(
                icon: Icons.arrow_downward,
                label: "Expense",
                value: totalExpense,
                color: Colors.red,
              ),
              _buildOverviewStat(
                icon: net >= 0 ? Icons.trending_up : Icons.trending_down,
                label: "Net",
                value: net,
                color: net >= 0 ? Colors.green : Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStat({required IconData icon, required String label, required double value, required Color color}) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.13),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.barlow(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          NumberFormat.compactCurrency(symbol: "\$", decimalDigits: 0).format(value),
          style: GoogleFonts.barlow(fontWeight: FontWeight.bold, color: color, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildQuickAction(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: color.withOpacity(0.13),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.10),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: color.withOpacity(0.18), width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.barlow(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportShortcut(BuildContext context,
      {Key? key, // Accept key parameter
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key, // Assign the key here
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
          decoration: BoxDecoration(
            color: color.withOpacity(0.13),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: color.withOpacity(0.18), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.barlow(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text, Color color, {Key? key}) {
    return Text(
      text,
      key: key, // Assign the key here
      style: GoogleFonts.barlow(
        fontWeight: FontWeight.bold,
        fontSize: 20,
        color: color,
      ),
    );
  }

  Widget _buildPlaceholderCard(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.barlow(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsCard() {
    if (_recentTransactions.isEmpty) {
      return _buildPlaceholderCard("No recent transactions.");
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: _recentTransactions.map((txn) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: txn['type'] == 'Income'
                        ? Colors.green.withOpacity(0.13)
                        : Colors.red.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    txn['type'] == 'Income'
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    color: txn['type'] == 'Income' ? Colors.green : Colors.red,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        txn['category'] ?? 'Uncategorized',
                        style: GoogleFonts.barlow(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        DateFormat('yyyy-MM-dd').format(txn['date']),
                        style: GoogleFonts.barlow(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2)
                      .format(txn['amount']),
                  style: GoogleFonts.barlow(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: txn['type'] == 'Income' ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}