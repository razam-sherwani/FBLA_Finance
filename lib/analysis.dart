import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fbla_finance/pages/chat_screen.dart';

class AiAnalysisPage extends StatefulWidget {
  const AiAnalysisPage({Key? key}) : super(key: key);

  @override
  State<AiAnalysisPage> createState() => _AiAnalysisPageState();
}

class _AiAnalysisPageState extends State<AiAnalysisPage> {
  List<Color> colors = [Color(0xffB8E8FF), Colors.white];
  bool _loading = true;
  bool _showAnalysisButton = true; // Controls visibility of the "Get AI Analysis" button
  String? _userName;
  double _currentBalance = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _savingsGoals = []; 
  Map<String, double> _budgets = {}; 
  Map<String, dynamic>? _aiParsedResponse; // Changed to store parsed JSON
  Map<String, double> _categorySpending = {};
  String? _mostSpentCategory;
  String? _leastSpentCategory;
  double _mostSpentAmount = 0.0;
  double _leastSpentAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  /// Fetches user data, transactions, and calculates spending by category.
  /// Also determines the most and least spent categories.
  Future<void> _fetchAllData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final userSnap = await firestore
          .collection('users')
          .where('email', isEqualTo: user.email)
          .get();

      if (userSnap.docs.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final docID = userSnap.docs.first.id;
      final userData = userSnap.docs.first.data();
      
      // Set user name
      _userName = '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}';

      // Fetch transactions
      final txSnap = await firestore
          .collection('users')
          .doc(docID)
          .collection('Transactions')
          .get();
      
      _transactions = txSnap.docs.map((doc) {
        final data = doc.data();
        return {
          'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'type': data['type'] ?? '',
          'category': data['category'] ?? '',
          'date': (data['date'] as Timestamp?)?.toDate(),
        };
      }).toList();

      // Calculate category spending
      _categorySpending = {};
      _currentBalance = 0.0;
      for (var tx in _transactions) {
        if (tx['type'] == 'Income') {
          _currentBalance += tx['amount'];
        } else {
          _currentBalance -= tx['amount'];
          String category = tx['category'] ?? 'Uncategorized';
          _categorySpending[category] = (_categorySpending[category] ?? 0) + tx['amount'];
        }
      }

      // Determine most and least spent categories
      if (_categorySpending.isNotEmpty) {
        // Sort entries to find most and least spent
        var sortedEntries = _categorySpending.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value)); // Sort ascending

        _leastSpentCategory = sortedEntries.first.key;
        _leastSpentAmount = sortedEntries.first.value;

        _mostSpentCategory = sortedEntries.last.key;
        _mostSpentAmount = sortedEntries.last.value;
      }

      // Fetch savings goals
      final goalsSnap = await firestore
          .collection('users')
          .doc(docID)
          .collection('SavingsGoals')
          .get();
      
      _savingsGoals = goalsSnap.docs.map((doc) {
        final data = doc.data();
        return {
          'name': data['name'] ?? '',
          'target': (data['target'] as num?)?.toDouble() ?? 0.0,
          'saved': (data['saved'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();

      // Fetch budgets
      final budgetsSnap = await firestore
          .collection('users')
          .doc(docID)
          .collection('Budgets')
          .doc('budgets')
          .get();
      
      if (budgetsSnap.exists) {
        final data = budgetsSnap.data();
        if (data != null && data['categories'] != null) {
          _budgets = Map<String, double>.from(
            (data['categories'] as Map).map(
              (k, v) => MapEntry(k as String, (v as num).toDouble())
            ),
          );
        }
      }

      setState(() => _loading = false);
    } catch (e) {
      // Log the error for debugging purposes
      print("Error fetching data: $e");
      setState(() => _loading = false);
    }
  }

  /// Sends financial data to the AI model for analysis.
  Future<void> _runAnalysis() async {
    setState(() {
      _aiParsedResponse = null; // Clear previous response
      _loading = true;
      _showAnalysisButton = false; // Hide button immediately when analysis starts
    });

    try {
      String txList = _transactions.map((tx) {
        return "- ${tx['date'] != null ? (tx['date'] as DateTime).toIso8601String().split('T').first : ''}: "
               "${tx['type']} \$${tx['amount']} [${tx['category']}]";
      }).join('\n');

      String savingsList = _savingsGoals.map((goal) =>
        "- ${goal['name']}: Saved \$${goal['saved']} / Target \$${goal['target']}").join('\n');

      String budgetList = _budgets.entries.map((e) =>
        "- ${e.key}: \$${e.value.toStringAsFixed(2)}").join('\n');

      // Updated prompt to explicitly request JSON format and include most/least spent categories
      String prompt = """
You are Fineas, a financial assistant. Analyze the user's financial data below and provide a concise, actionable summary with feedback and suggestions.
Format your response STRICTLY as a JSON object with the following keys. DO NOT include any text outside the JSON.
- "overallSummary": A general financial overview (max 70 words).
- "spendingTip": A specific tip to improve spending habits (max 30 words).
- "savingsComment": A comment on their savings goals (max 30 words).
- "budgetComment": A comment on their budget goals (max 30 words).
- "patternsAdvice": Any other notable patterns or advice (max 40 words).

User Name: ${_userName ?? 'User'}
Current Balance: \$${_currentBalance.toStringAsFixed(2)}

Transactions List:
$txList

Savings Goals:
$savingsList

Budgets:
$budgetList
""";

      const String openAIApiKey = "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"; 

      if (openAIApiKey.isEmpty || openAIApiKey == "YOUR_API_KEY") {
        setState(() {
          _aiParsedResponse = {"overallSummary": "Error: OpenAI API key is not set. Please replace 'YOUR_API_KEY' with your actual API key in the code."};
          _loading = false;
        });
        return;
      }

      final response = await http.post(
        // CORRECTED URL: Removed Markdown link formatting
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $openAIApiKey", 
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "gpt-4o",
          "messages": [
            {"role": "system", "content": prompt},
            {"role": "user", "content": "Please analyze my finances and give me feedback. Make sure you are directing your advice to the user, so its like your instead of the user's actual name. Also make the advices more personalized and actionable. Give them examples of what they can do with their current situation."},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        String content = jsonResponse["choices"][0]["message"]["content"];
        
        // Strip markdown code block fences if present
        if (content.startsWith('```json') && content.endsWith('```')) {
          content = content.substring(7, content.length - 3).trim();
        } else if (content.startsWith('```') && content.endsWith('```')) {
          content = content.substring(3, content.length - 3).trim();
        }
        
        try {
          _aiParsedResponse = jsonDecode(content); // Parse the AI's JSON string
        } catch (e) {
          print("Error parsing AI response JSON: $e. Content was: $content");
          _aiParsedResponse = {"overallSummary": "Error: Could not parse AI analysis. Please try again. Raw: $content"};
        }

        setState(() {
          _loading = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _aiParsedResponse = {"overallSummary": "Failed to get analysis. Status code: 401 (Unauthorized). Please check your OpenAI API key."};
          _loading = false;
        });
      } else {
        setState(() {
          _aiParsedResponse = {"overallSummary": "Failed to get analysis. Please try again. Status code: ${response.statusCode}. Response: ${response.body}"};
          _loading = false;
        });
      }
    } catch (e) {
      print("Error running AI analysis: $e");
      setState(() {
        _aiParsedResponse = {"overallSummary": "Failed to get analysis. Please try again. Error: $e"};
        _loading = false;
      });
    }
  }

  /// Builds a financial statistics card.
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.barlow(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.barlow(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the "Spending by Category" section with a progress bar for each category.
  Widget _buildCategorySpending() {
    if (_categorySpending.isEmpty) return Container();

    var sortedCategories = _categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Sort descending by amount

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Spending by Category",
            style: GoogleFonts.barlow(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          const SizedBox(height: 12),
          ...sortedCategories.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.key,
                    style: GoogleFonts.barlow(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: LinearProgressIndicator(
                    // Progress based on the highest spending to show relative comparison
                    value: sortedCategories.first.value > 0 ? entry.value / sortedCategories.first.value : 0.0,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      entry.key == _mostSpentCategory 
                          ? Colors.red[400]! // Highlight most spent category
                          : (entry.key == _leastSpentCategory ? Colors.green[400]! : Colors.blue[400]!), // Highlight least spent
                    ),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "\$${entry.value.toStringAsFixed(2)}",
                  style: GoogleFonts.barlow(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  /// Builds the AI analysis response section with distinct boxes for most/least spent categories.
  Widget _buildAnalysisResponse() {
    if (_aiParsedResponse == null) return Container();

    return AnimatedOpacity(
      opacity: _aiParsedResponse != null ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Column(
        children: [
          _buildAnalysisSectionCard(
            title: "Overall Summary",
            content: _aiParsedResponse!["overallSummary"] ?? "No summary available.",
            icon: Icons.info_outline,
            color: Colors.blue[700]!,
          ),
          const SizedBox(height: 16),
          // Moved Most/Least Spent Categories here
          if (_mostSpentCategory != null)
            _buildInfoBox(
              "Most Spent Category",
              "${_mostSpentCategory!}: \$${_mostSpentAmount.toStringAsFixed(2)}",
              Colors.red[700]!,
              Icons.trending_up,
            ),
          const SizedBox(height: 12), 
          if (_leastSpentCategory != null)
            _buildInfoBox(
              "Least Spent Category",
              "${_leastSpentCategory!}: \$${_leastSpentAmount.toStringAsFixed(2)}",
              Colors.green[700]!,
              Icons.trending_down,
            ),
          const SizedBox(height: 16), // Added spacing after least spent category

          _buildAnalysisSectionCard(
            title: "Spending Tip",
            content: _aiParsedResponse!["spendingTip"] ?? "No spending tip available.",
            icon: Icons.lightbulb_outline,
            color: Colors.orange[700]!,
          ),
          const SizedBox(height: 16),
          _buildAnalysisSectionCard(
            title: "Savings Comment",
            content: _aiParsedResponse!["savingsComment"] ?? "No savings comment available.",
            icon: Icons.savings,
            color: Colors.purple[700]!,
          ),
          const SizedBox(height: 16),
          _buildAnalysisSectionCard(
            title: "Budget Comment",
            content: _aiParsedResponse!["budgetComment"] ?? "No budget comment available.",
            icon: Icons.pie_chart_outline,
            color: Colors.teal[700]!,
          ),
          const SizedBox(height: 16),
          _buildAnalysisSectionCard(
            title: "Other Patterns & Advice",
            content: _aiParsedResponse!["patternsAdvice"] ?? "No additional patterns or advice available.",
            icon: Icons.insights,
            color: Colors.brown[700]!,
          ),
        ],
      ),
    );
  }

  /// Helper widget to build stylish information boxes for most/least spent.
  Widget _buildInfoBox(String title, String content, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.barlow(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: GoogleFonts.barlow(
                    fontSize: 15,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// New helper widget to build structured analysis sections.
  Widget _buildAnalysisSectionCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero, // No external margin, use SizedBox for spacing
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.barlow(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              content,
              style: GoogleFonts.barlow(
                fontSize: 15,
                height: 1.4,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Use the same color scheme as spending habits/settings
    final Color primaryColor = const Color(0xFF2A4288);
    final Color secondaryColor = colors.length > 1 ? colors[1] : Colors.blue.shade900;
    final Color bgColor = Colors.white;

    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        toolbarHeight: 75,
        title: Padding(
          padding: const EdgeInsets.only(bottom: 15.0),
          child: Text(
            "Financial Analysis",
            style: GoogleFonts.barlow(
              fontWeight: FontWeight.bold,
              fontSize: 28,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (photoUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 18.0, top: 8),
              child: CircleAvatar(
                radius: 22,
                backgroundImage: NetworkImage(photoUrl),
                backgroundColor: Colors.white,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 18.0, top: 8),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: primaryColor),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
              ),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Always show greeting and subtitle
                        Text(
                          "Hello, ${_userName ?? 'User'}!",
                          style: GoogleFonts.barlow(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: secondaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Here's your financial overview",
                          style: GoogleFonts.barlow(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Stats Row (now includes Transactions)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildStatCard(
                                "Balance",
                                "\$${_currentBalance.toStringAsFixed(2)}",
                                Icons.account_balance_wallet,
                                Colors.green,
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                "Transactions",
                                _transactions.length.toString(),
                                Icons.list_alt,
                                Colors.redAccent,
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                "Savings Goals",
                                _savingsGoals.length.toString(),
                                Icons.savings,
                                Colors.purple,
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                "Budgets",
                                _budgets.length.toString(),
                                Icons.pie_chart,
                                Colors.orange,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Spending by Category section
                        _buildCategorySpending(),
                        const SizedBox(height: 24),
                        // "Get AI Analysis" button, styled like spending habits, but darker
                        if (_showAnalysisButton) ...[
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                child: AnimatedContainer(
                                  duration: Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.22),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.35),
                                      width: 1.8,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.10),
                                        blurRadius: 16,
                                        offset: Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(22),
                                      onTap: _runAnalysis,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.insights, color: primaryColor, size: 26),
                                            const SizedBox(width: 12),
                                            Text(
                                              "Get AI Analysis",
                                              style: GoogleFonts.barlow(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: primaryColor,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        // AI Analysis Response section, conditional visibility with animation
                        if (_aiParsedResponse != null) _buildAnalysisResponse(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                  if (_loading)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(50),
                          topRight: Radius.circular(50),
                        ),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            ),
            
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatScreen()),
        );
      },
      child: const Icon(Icons.chat),
      backgroundColor: Colors.blue.shade900,
      foregroundColor: Colors.white,
    ),
    );
  }
}
