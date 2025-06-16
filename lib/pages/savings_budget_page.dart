// Updated Budget & Savings Page with AI Categorization and Smart Budget Assignment
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../util/profile_picture.dart';

const double kAppBarHeight = 75;
const Color kAppBarColor = Color(0xFF2A4288);
const TextStyle kAppBarTextStyle = TextStyle(
  fontFamily: 'Barlow',
  fontWeight: FontWeight.bold,
  fontSize: 28,
  color: Colors.white,
);

const Color dangerRed = Color(0xFFD32F2F);
const Color strongGreen = Color(0xFF388E3C);
const Color warningOrange = Color(0xFFFFA726);

class BudgetSavingsPage extends StatefulWidget {
  const BudgetSavingsPage({Key? key}) : super(key: key);

  @override
  State<BudgetSavingsPage> createState() => _BudgetSavingsPageState();
}

class _BudgetSavingsPageState extends State<BudgetSavingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;
  String docID = '';
  Map<String, double> budgets = {};
  List<String> categories = [];
  double totalIncome = 5000.0;
  Map<String, double> spentPerCategory = {};
  List<Map<String, dynamic>> savingsGoals = [];
  bool showBudgets = true;
  Map<String, bool> _expandedDropdowns = {};
  Map<String, String> aiCategoryCache = {};
  Map<String, List<Map<String, dynamic>>> transactionsByAICategory = {};
  final String gptApiKey = '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';

  bool _showContent = true; // Add this flag

  @override
  void initState() {
    super.initState();
    _showContent = true; // Ensure content is visible on startup
    _fetchDocIDAndData();
  }

  Future<String> getAICategory(String transactionName, List<String> budgetCategories) async {
    final cacheKey = '$transactionName|${budgetCategories.join(",")}';
    if (aiCategoryCache.containsKey(cacheKey)) {
      return aiCategoryCache[cacheKey]!;
    }
    if (budgetCategories.isEmpty) return "Other";
    if (budgetCategories.length == 1) return budgetCategories[0];

    final url = Uri.parse("https://api.openai.com/v1/chat/completions");
    final prompt =
        "You are a financial assistant. Given this list of budget categories: ${budgetCategories.join(", ")} and a transaction called \"$transactionName\", which category does it belong to? Only respond with ONE category from the list. If none fit, respond with 'Other'.";

    final body = jsonEncode({
      "model": "gpt-3.5-turbo", // You might consider 'gpt-4' or 'gpt-4o' for better reasoning
      "messages": [
        {"role": "user", "content": prompt}
      ],
      "max_tokens": 8, // Keep this small as we expect a single word response
      "temperature": 0
    });

    try {
      final resp = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $gptApiKey",
          "Content-Type": "application/json"
        },
        body: body,
      );

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final response = decoded["choices"][0]["message"]["content"].trim().replaceAll('\n', '');
        // Ensure the response is one of the valid categories or "Other"
        if (budgetCategories.contains(response) || response == "Other") {
          aiCategoryCache[cacheKey] = response;
          return response;
        } else {
          // If AI hallucinates a category not in the list, default to "Other"
          aiCategoryCache[cacheKey] = "Other";
          return "Other";
        }
      } else {
        print("Error from OpenAI API (getAICategory): ${resp.statusCode} - ${resp.body}");
        aiCategoryCache[cacheKey] = "Other";
        return "Other";
      }
    } catch (e) {
      print("Exception in getAICategory: $e");
      aiCategoryCache[cacheKey] = "Other";
      return "Other";
    }
  }

  // New function to get AI to suggest categories and budget values
  Future<Map<String, double>> getAIBudgetSuggestions(double income, List<Map<String, dynamic>> expenseTransactions) async {
    if (expenseTransactions.isEmpty) return {};

    final url = Uri.parse("https://api.openai.com/v1/chat/completions");

    // Prepare a list of transaction names and amounts for the AI
    final transactionDescriptions = expenseTransactions.map((txn) =>
        "Transaction: \"${txn['category']}\", Amount: \$${(txn['amount'] as num).toDouble().toStringAsFixed(2)}"
    ).join("\n");

    final prompt = """
    You are a financial planning AI.
    Given a total monthly income of \$${income.toStringAsFixed(2)} and the following list of expense transactions:

    $transactionDescriptions

    Your task is to:
    1.  **Identify broad, common budget categories dont arent too specific or too random** that these transactions naturally fall into.
    2.  For each identified category, **suggest a reasonable monthly budget amount** based on the transactions and the total income and based on common budgeting rules.
    3.  Ensure the sum of all suggested budget amounts does not significantly exceed the total income, considering typical savings (e.g., aim for a total budget of around 70-90% of income, leaving room for savings/discretionary).
    4.  If a category doesn't explicitly appear but is common (e.g., "Savings"), you can include it with a suggested budget.
    5.  Respond ONLY with a JSON object. The keys should be the category names (strings), and the values should be the suggested budget amounts (numbers/doubles). Do not include any other text or explanation.

    Example desired output format:
    {
      "Housing": 1500.00,
      "Food": 600.00,
      "Transportation": 300.00,
      "Utilities": 200.00,
      "Entertainment": 400.00,
      "Savings": 500.00,
      "Other": 100.00
    }
    """;

    final body = jsonEncode({
      "model": "gpt-4o", // Use a more capable model for better reasoning and JSON output
      "messages": [
        {"role": "user", "content": prompt}
      ],
      "max_tokens": 1000, // Allow enough tokens for the JSON response
      "temperature": 0.2, // A bit of creativity can help with category naming, but keep it low for structure
      "response_format": {"type": "json_object"} // Explicitly request JSON
    });

    try {
      final resp = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $gptApiKey",
          "Content-Type": "application/json"
        },
        body: body,
      );

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final String jsonString = decoded["choices"][0]["message"]["content"].trim();
        print("AI Budget Suggestion Raw Response: $jsonString");

        try {
          final Map<String, dynamic> aiResponse = jsonDecode(jsonString);
          Map<String, double> suggestedBudgets = {};
          aiResponse.forEach((key, value) {
            if (value is num) {
              suggestedBudgets[key] = value.toDouble();
            }
          });
          return suggestedBudgets;
        } catch (e) {
          print("Failed to parse AI budget suggestion JSON: $e");
          return {}; // Return empty if parsing fails
        }
      } else {
        print("Error from OpenAI API (getAIBudgetSuggestions): ${resp.statusCode} - ${resp.body}");
        return {}; // Return empty on API error
      }
    } catch (e) {
      print("Exception in getAIBudgetSuggestions: $e");
      return {}; // Return empty on network/other error
    }
  }


  Future<void> _fetchDocIDAndData() async {
    if (user == null) return;

    final snapshot = await _firestore.collection('users').where('email', isEqualTo: user!.email).get();
    if (snapshot.docs.isEmpty) return;
    docID = snapshot.docs[0].id;

    final txnSnap = await _firestore.collection('users').doc(docID).collection('Transactions').get();

    double income = 0.0;
    List<Map<String, dynamic>> allExpenseTxns = []; // Only expenses for AI budget suggestions

    for (var doc in txnSnap.docs) {
      final data = doc.data();
      final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final type = data['type'];
      if (type == 'Income') {
        income += amt;
      } else if (type == 'Expense') {
        allExpenseTxns.add({...data, 'id': doc.id});
      }
    }
    totalIncome = income > 0 ? income : 5000.0; // Default income if none recorded

    // --- AI generates broad categories and budget suggestions ---
    final Map<String, double> aiSuggestedBudgets = await getAIBudgetSuggestions(totalIncome, allExpenseTxns);
    if (aiSuggestedBudgets.isEmpty) {
        // Fallback to default categories if AI fails to suggest any
        print("AI failed to suggest budgets. Falling back to default.");
        budgets = {
            "Housing": totalIncome * 0.30,
            "Food": totalIncome * 0.15,
            "Transportation": totalIncome * 0.10,
            "Entertainment": totalIncome * 0.10,
            "Utilities": totalIncome * 0.05,
            "Health": totalIncome * 0.05,
            "Other": totalIncome * 0.25,
        };
    } else {
        budgets = aiSuggestedBudgets;
    }
    // -------------------------------------------------------------

    // Get the list of categories identified by the AI (or fallback)
    final List<String> currentBudgetCategories = budgets.keys.toList();

    Map<String, List<Map<String, dynamic>>> categorized = {};
    Map<String, double> allocated = {};

    for (var txn in allExpenseTxns) { // Iterate through expenses to categorize them
      final name = txn['category']; // This is the detailed transaction description
      final amount = (txn['amount'] as num).toDouble();
      final category = await getAICategory(name, currentBudgetCategories); // Use AI-generated categories
      categorized.putIfAbsent(category, () => []).add(txn);
      allocated[category] = (allocated[category] ?? 0) + amount;
    }

    // --- Update Firestore with both budgets and spent balances ---
    await _firestore
        .collection('users')
        .doc(docID)
        .collection('Budgets')
        .doc('budgets')
        .set({
          'categories': budgets, // Now using AI-suggested budgets
          'spent': allocated, // Save spent per category for balance tracking
        }, SetOptions(merge: true));
    // ------------------------------------------------------------

    final goalsSnap = await _firestore.collection('users').doc(docID).collection('SavingsGoals').get();
    List<Map<String, dynamic>> loadedGoals = goalsSnap.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'],
        'target': (data['target'] as num?)?.toDouble() ?? 0.0,
        'saved': (data['saved'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();

    if (mounted) {
      setState(() {
        budgets = budgets; // The AI-generated budgets
        spentPerCategory = allocated;
        categories = budgets.keys.toList(); // Categories are now from AI-generated budgets
        savingsGoals = loadedGoals;
        transactionsByAICategory = categorized;
      });
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _progressColor(double percent) {
    if (percent < 0.5) {
      return Color.lerp(Colors.lightGreen.shade300, Colors.amber.shade300, percent * 2)!;
    } else if (percent < 0.9) {
      return Color.lerp(Colors.amber.shade300, Colors.deepOrange.shade300, (percent - 0.5) * 2)!;
    } else {
      return Color.lerp(Colors.deepOrange.shade300, Colors.red.shade400, (percent - 0.9) * 10)!;
    }
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Add New Budget Category",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: kAppBarColor,
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: "Category Name",
                  hintText: "e.g., Education",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: kAppBarColor, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: kAppBarColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAppBarColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () async {
                        final categoryName = controller.text.trim();
                        if (categoryName.isEmpty) {
                          _showErrorMessage("Category name cannot be empty.");
                          return;
                        }
                        if (categories.any((cat) =>
                            cat.toLowerCase() == categoryName.toLowerCase())) {
                          _showErrorMessage("Category '$categoryName' already exists.");
                          return;
                        }
                        budgets[categoryName] = totalIncome * 0.05;
                        categories.add(categoryName);
                        await _firestore
                            .collection('users')
                            .doc(docID)
                            .collection('Budgets')
                            .doc('budgets')
                            .set({'categories': budgets}, SetOptions(merge: true));
                        Navigator.pop(context);
                        await _fetchDocIDAndData();
                      },
                      child: const Text("Add", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editBudgetAmount(String category) {
    final controller = TextEditingController(text: budgets[category]?.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Edit Budget Amount",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: kAppBarColor,
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Budget Amount",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixText: "\$",
                  contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: kAppBarColor, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: kAppBarColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAppBarColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () async {
                        final value = double.tryParse(controller.text) ?? 0.0;
                        if (value < 0) {
                          _showErrorMessage("Budget cannot be negative.");
                          return;
                        }
                        budgets[category] = value;
                        await _firestore
                            .collection('users')
                            .doc(docID)
                            .collection('Budgets')
                            .doc('budgets')
                            .set({'categories': budgets}, SetOptions(merge: true));
                        Navigator.pop(context);
                        await _fetchDocIDAndData();
                      },
                      child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addGoalDialog() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Add Savings Goal",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: kAppBarColor,
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Goal Name",
                  hintText: "e.g., New Car Fund",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Target Amount",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixText: "\$",
                  contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: kAppBarColor, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: kAppBarColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAppBarColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final target = double.tryParse(targetController.text) ?? 0.0;
                        if (name.isEmpty) {
                          _showErrorMessage("Goal name cannot be empty.");
                          return;
                        }
                        if (target <= 0) {
                          _showErrorMessage("Target amount must be greater than zero.");
                          return;
                        }
                        await _firestore
                            .collection('users')
                            .doc(docID)
                            .collection('SavingsGoals')
                            .add({'name': name, 'target': target, 'saved': 0.0});
                        await _fetchDocIDAndData();
                        Navigator.pop(context);
                      },
                      child: const Text("Add", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteBudget(String category) async {
    budgets.remove(category);
    categories.remove(category);
    await _firestore
        .collection('users')
        .doc(docID)
        .collection('Budgets')
        .doc('budgets')
        .set({'categories': budgets}, SetOptions(merge: true));
    setState(() {});
    await _fetchDocIDAndData();
    _showSuccessMessage("Budget for '$category' deleted.");
  }

  Future<void> _deleteGoal(String goalId) async {
    await _firestore
        .collection('users')
        .doc(docID)
        .collection('SavingsGoals')
        .doc(goalId)
        .delete();
    await _fetchDocIDAndData();
    _showSuccessMessage("Savings goal deleted.");
  }

  String _formatDate(dynamic date) {
    if (date is DateTime) {
      return "${_monthAbbr(date.month)} ${date.day}, ${date.year}";
    }
    return date.toString();
  }

  String _monthAbbr(int month) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? '';

    // Always show the white container and appbar, even if loading
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
            "Budgets & Savings",
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: docID.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: showBudgets ? kAppBarColor : Colors.blueGrey[600],
                                backgroundColor: showBudgets ? Colors.white : Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: () => setState(() => showBudgets = true),
                              child: Text(
                                "Budgets",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: showBudgets ? kAppBarColor : Colors.blueGrey[600],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: !showBudgets ? kAppBarColor : Colors.blueGrey[600],
                                backgroundColor: !showBudgets ? Colors.white : Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: () => setState(() => showBudgets = false),
                              child: Text(
                                "Savings Goals",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: !showBudgets ? kAppBarColor : Colors.blueGrey[600],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: showBudgets
                          ? _buildBudgetsSection(context, Colors.blueGrey[900]!, Colors.blueGrey[600]!)
                          : _buildSavingsGoalsSection(context, Colors.blueGrey[900]!, Colors.blueGrey[600]!),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildBudgetsSection(BuildContext context, Color darkText, Color mediumText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Your Budgets",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: darkText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Track your spending to stay on top of your finances.",
          style: TextStyle(fontSize: 16, color: mediumText),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: categories.isEmpty
              ? Center(
                  child: Text(
                    "No budget categories set up yet!\nTap 'Add Category' to get started.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: mediumText),
                  ),
                )
              : ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final budget = budgets[category] ?? 0.0;
                    final spent = spentPerCategory[category] ?? 0.0;
                    final percent = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
                    final txns = transactionsByAICategory[category] ?? [];
                    final isExpanded = _expandedDropdowns[category] ?? false;

                    return Dismissible(
                      key: Key(category),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: const Icon(Icons.delete_forever, color: Colors.white, size: 30),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              title: const Text("Confirm Delete", style: TextStyle(fontWeight: FontWeight.bold)),
                              content: Text("Are you sure you want to delete the budget for '$category'?"),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: Text("Cancel", style: TextStyle(color: mediumText)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade200,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text("Delete"),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (_) async {
                        budgets.remove(category);
                        categories.remove(category);
                        await _firestore
                            .collection('users')
                            .doc(docID)
                            .collection('Budgets')
                            .doc('budgets')
                            .set({'categories': budgets}, SetOptions(merge: true));
                        setState(() {});
                        await _fetchDocIDAndData();
                        _showSuccessMessage("Budget for '$category' deleted.");
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  _expandedDropdowns[category] = !(isExpanded);
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.category, color: kAppBarColor, size: 28),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        category,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: darkText,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.edit, size: 22, color: mediumText),
                                      onPressed: () => _editBudgetAmount(category),
                                      tooltip: "Edit budget",
                                    ),
                                    Icon(
                                      isExpanded ? Icons.expand_less : Icons.expand_more,
                                      color: mediumText,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Column(
                                children: [
                                  LinearProgressIndicator(
                                    value: percent,
                                    minHeight: 12,
                                    backgroundColor: Colors.grey[300],
                                    color: _progressColor(percent),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Budget: \$${budget.toStringAsFixed(2)}",
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: mediumText),
                                      ),
                                      Text(
                                        "Spent: \$${spent.toStringAsFixed(2)}",
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: mediumText),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      "Remaining: \$${(budget - spent).toStringAsFixed(2)}",
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: (budget - spent) < 0 ? Colors.red : Colors.green,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                ],
                              ),
                            ),
                            if (isExpanded)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                child: txns.isNotEmpty
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 8),
                                          Text(
                                            "Transactions:",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: darkText,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          ...txns.map((txn) => ListTile(
                                                contentPadding: EdgeInsets.zero,
                                                leading: Icon(
                                                  txn['type'] == 'Income'
                                                      ? Icons.arrow_upward
                                                      : Icons.arrow_downward,
                                                  color: txn['type'] == 'Income'
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                                title: Text(
                                                  txn['category'] ?? '',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15,
                                                    color: darkText,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  // Format date as "MMM d, yyyy"
                                                  "${txn['type']} • ${DateFormat('yyyy-MM-dd').format((txn['date'] as Timestamp).toDate())}",
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                trailing: Text(
                                                  "\$${(txn['amount'] as num?)?.toStringAsFixed(2) ?? ''}",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: txn['type'] == 'Income'
                                                        ? Colors.green
                                                        : Colors.red,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              )),
                                        ],
                                      )
                                    : Text(
                                        "No transactions in this category.",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: mediumText,
                                        ),
                                      ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAppBarColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 5,
            ),
            icon: const Icon(Icons.add_circle_outline, size: 28),
            label: const Text(
              "Add New Budget Category",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onPressed: _showAddCategoryDialog,
          ),
        ),
      ],
    );
  }

  Widget _buildSavingsGoalsSection(BuildContext context, Color darkText, Color mediumText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Your Savings Goals",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: darkText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Save up for your dreams and financial milestones.",
          style: TextStyle(fontSize: 16, color: mediumText),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: savingsGoals.isEmpty
              ? Center(
                  child: Text(
                    "No savings goals set up yet!\nStart saving for your dreams by tapping 'Add Goal'.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: mediumText),
                  ),
                )
              : ListView.builder(
                  itemCount: savingsGoals.length,
                  itemBuilder: (context, index) {
                    final goal = savingsGoals[index];
                    final percent = (goal['target'] > 0)
                        ? (goal['saved'] / goal['target']).clamp(0.0, 1.0)
                        : 0.0;
                    final double remainingOrExcess = goal['target'] - goal['saved'];
                    String displayText;
                    Color textColor;
                    if (remainingOrExcess <= 0) {
                      displayText = "Goal Met! Excess: \$${(-remainingOrExcess).toStringAsFixed(2)}";
                      textColor = Colors.green;
                    } else {
                      displayText = "Remaining: \$${remainingOrExcess.toStringAsFixed(2)}";
                      textColor = Colors.orange.shade700;
                    }

                    return Dismissible(
                      key: Key(goal['id']),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: const Icon(Icons.delete_forever, color: Colors.white, size: 30),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              title: const Text("Confirm Delete", style: TextStyle(fontWeight: FontWeight.bold)),
                              content: Text("Are you sure you want to delete '${goal['name']}' goal?"),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: Text("Cancel", style: TextStyle(color: mediumText)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade200,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text("Delete"),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (_) async {
                        await _firestore
                            .collection('users')
                            .doc(docID)
                            .collection('SavingsGoals')
                            .doc(goal['id'])
                            .delete();
                        await _fetchDocIDAndData();
                        _showSuccessMessage("Savings goal deleted.");
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(Icons.savings, color: kAppBarColor, size: 28),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      goal['name'],
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: darkText,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.edit, size: 22, color: mediumText),
                                    onPressed: () {
                                      final controller = TextEditingController(text: goal['target'].toStringAsFixed(2));
                                      showDialog(
                                        context: context,
                                        builder: (context) => Dialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                          backgroundColor: Colors.white,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  "Edit Goal Amount",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 24,
                                                    color: kAppBarColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 22),
                                                TextField(
                                                  controller: controller,
                                                  keyboardType: TextInputType.number,
                                                  decoration: InputDecoration(
                                                    labelText: "Target Amount",
                                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                                    prefixText: "\$",
                                                    contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                                                  ),
                                                ),
                                                const SizedBox(height: 24),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: OutlinedButton(
                                                        onPressed: () => Navigator.pop(context),
                                                        style: OutlinedButton.styleFrom(
                                                          side: BorderSide(color: kAppBarColor, width: 1.5),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(14),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          "Cancel",
                                                          style: TextStyle(
                                                            color: kAppBarColor,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 12),
                                                    Expanded(
                                                      child: ElevatedButton(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: kAppBarColor,
                                                          foregroundColor: Colors.white,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(14),
                                                          ),
                                                          elevation: 2,
                                                        ),
                                                        onPressed: () async {
                                                          final value = double.tryParse(controller.text) ?? 0.0;
                                                          if (value <= 0) {
                                                            _showErrorMessage("Target amount must be greater than zero.");
                                                            return;
                                                          }
                                                          await _firestore
                                                              .collection('users')
                                                              .doc(docID)
                                                              .collection('SavingsGoals')
                                                              .doc(goal['id'])
                                                              .update({'target': value});
                                                          await _fetchDocIDAndData();
                                                          Navigator.pop(context);
                                                        },
                                                        child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    tooltip: "Edit goal target",
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                value: percent,
                                minHeight: 12,
                                backgroundColor: Colors.grey[300],
                                color: _progressColor(percent),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Target: \$${goal['target'].toStringAsFixed(2)}",
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: mediumText),
                                  ),
                                  Text(
                                    "Saved: \$${goal['saved'].toStringAsFixed(2)}",
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: mediumText),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                displayText,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAppBarColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 5,
            ),
            icon: const Icon(Icons.star_border, size: 28),
            label: const Text(
              "Add New Savings Goal",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onPressed: _addGoalDialog,
          ),
        ),
      ],
    );
  }
}