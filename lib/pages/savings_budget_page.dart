// Updated Budget & Savings Page with AI Categorization and Smart Budget Assignment
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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
      "model": "gpt-3.5-turbo",
      "messages": [
        {"role": "user", "content": prompt}
      ],
      "max_tokens": 8,
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
        aiCategoryCache[cacheKey] = response;
        return response;
      } else {
        aiCategoryCache[cacheKey] = "Other";
        return "Other";
      }
    } catch (_) {
      aiCategoryCache[cacheKey] = "Other";
      return "Other";
    }
  }

  Future<void> _fetchDocIDAndData() async {
    if (user == null) return;

    final snapshot = await _firestore.collection('users').where('email', isEqualTo: user!.email).get();
    if (snapshot.docs.isEmpty) return;
    docID = snapshot.docs[0].id;

    final txnSnap = await _firestore.collection('users').doc(docID).collection('Transactions').get();

    double income = 0.0;
    Map<String, double> spent = {};
    List<Map<String, dynamic>> allTxns = [];

    for (var doc in txnSnap.docs) {
      final data = doc.data();
      final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final type = data['type'];
      final cat = data['category'];
      if (type == 'Income') income += amt;
      if (type == 'Expense' && cat != null) {
        allTxns.add({...data, 'id': doc.id});
      }
    }
    totalIncome = income > 0 ? income : 5000.0;

    final broadCategories = ["Housing", "Food", "Transportation", "Utilities", "Lifestyle", "Other"];
    Map<String, List<Map<String, dynamic>>> categorized = {};
    Map<String, double> allocated = {};

    for (var txn in allTxns) {
      final name = txn['category'];
      final amount = (txn['amount'] as num).toDouble();
      final category = await getAICategory(name, broadCategories);
      categorized.putIfAbsent(category, () => []).add(txn);
      allocated[category] = (allocated[category] ?? 0) + amount;
    }

    Map<String, double> ruleBasedBudgets = {
      "Housing": totalIncome * 0.30,
      "Food": totalIncome * 0.15,
      "Transportation": totalIncome * 0.10,
      "Entertainment": totalIncome * 0.10,
      "Utilities": totalIncome * 0.05,
      "Health": totalIncome * 0.05,
      "Other": totalIncome * 0.25,
    };

    await _firestore
        .collection('users')
        .doc(docID)
        .collection('Budgets')
        .doc('budgets')
        .set({'categories': ruleBasedBudgets});

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

    setState(() {
      budgets = ruleBasedBudgets;
      spentPerCategory = allocated;
      categories = budgets.keys.toList();
      savingsGoals = loadedGoals;
      transactionsByAICategory = categorized;
    });
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

  void _deleteBudget(String category) {
    budgets.remove(category);
    categories.remove(category);
    _firestore
        .collection('users')
        .doc(docID)
        .collection('Budgets')
        .doc('budgets')
        .set({'categories': budgets}, SetOptions(merge: true));
    setState(() {});
    _fetchDocIDAndData();
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

  @override
  Widget build(BuildContext context) {
    final Color primaryThemeBlue = kAppBarColor;
    final Color bgColor = Colors.white;
    final Color darkText = Colors.blueGrey[900]!;
    final Color mediumText = Colors.blueGrey[600]!;

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
      ),
      body: Container(
        decoration: BoxDecoration(
          color: bgColor,
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
                                foregroundColor: showBudgets ? kAppBarColor : mediumText,
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
                                  color: showBudgets ? kAppBarColor : mediumText,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: !showBudgets ? kAppBarColor : mediumText,
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
                                  color: !showBudgets ? kAppBarColor : mediumText,
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
                          ? _buildBudgetsSection(context, darkText, mediumText)
                          : _buildSavingsGoalsSection(context, darkText, mediumText),
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

                    return Card(
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
                      onDismissed: (_) => _deleteGoal(goal['id']),
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