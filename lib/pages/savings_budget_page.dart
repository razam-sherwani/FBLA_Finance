import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  final Map<String, double> categorySplits = {
    "Rent": 0.30,
    "Groceries": 0.15,
    "Transportation": 0.10,
    "Entertainment": 0.10,
    "Dining Out": 0.05,
    "Utilities": 0.05,
    "Miscellaneous": 0.25,
  };
  Map<String, double> spentPerCategory = {};
  List<Map<String, dynamic>> savingsGoals = [];
  bool showBudgets = true;

  Map<String, bool> _expandedDropdowns = {};
  Map<String, String> aiCategoryCache = {};
  Map<String, List<Map<String, dynamic>>> transactionsByAICategory = {};

  final String gptApiKey = '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';

  @override
  void initState() {
    super.initState();
    _fetchDocIDAndData();
  }

  // =========== GPT AI Categorizer ===========
  Future<String> getAICategory(
      String transactionName, List<String> budgetCategories) async {
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
        final response =
            decoded["choices"][0]["message"]["content"].trim().replaceAll('\n', '');
        aiCategoryCache[cacheKey] = response;
        return response;
      } else {
        print("GPT Error: ${resp.body}");
        aiCategoryCache[cacheKey] = "Other";
        return "Other";
      }
    } catch (e) {
      print("GPT Exception: $e");
      aiCategoryCache[cacheKey] = "Other";
      return "Other";
    }
  }

  // =========== DATA FETCH & REBUILD ===========
  Future<void> _fetchDocIDAndData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        docID = 'no_user_logged_in';
      });
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: user.email)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          docID = 'no_user_found';
        });
        return;
      }

      docID = snapshot.docs[0].id;

      // -------- Get budget category list --------
      final budgetDoc = await _firestore
          .collection('users')
          .doc(docID)
          .collection('Budgets')
          .doc('budgets')
          .get();
      Map<String, dynamic> savedBudgets =
          budgetDoc.exists ? (budgetDoc.data()?['categories'] ?? {}) : {};

      // Keep the category list ALWAYS in sync with what's in Firestore
      List<String> currentBudgetCategories = [];
      if (savedBudgets.isNotEmpty) {
        currentBudgetCategories =
            savedBudgets.keys.map((e) => e.toString()).toList();
      }
      categories = currentBudgetCategories;
      budgets = {};
      for (var cat in categories) {
        budgets[cat] = (savedBudgets[cat]?.toDouble()) ??
            (totalIncome * (categorySplits[cat] ?? 0.05));
      }

      // -------- Get and AI-categorize all transactions (expenses only) --------
      final transactions = await _firestore
          .collection('users')
          .doc(docID)
          .collection('Transactions')
          .get();

      Map<String, double> spent = {};
      Map<String, List<Map<String, dynamic>>> txnsByCategory = {};
      Map<String, double> savingsMap = {};

      List<Map<String, dynamic>> txnList = [];
      for (var doc in transactions.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        txnList.add(data);
      }

      // AI categorize all expense transactions, using latest category list
      for (var data in txnList) {
        final txName = data['category'];
        final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final type = data['type'];
        if (type == 'Expense' && txName != null && categories.isNotEmpty) {
          final aiCategory =
              await getAICategory(txName, categories); // will return actual or 'Other'
          if (categories.contains(aiCategory) && aiCategory != "Other") {
            spent[aiCategory] = (spent[aiCategory] ?? 0) + amt;
            txnsByCategory.putIfAbsent(aiCategory, () => []).add(data);
          }
        }
        // For savings goals (all types)
        if (txName != null) {
          savingsMap[txName.toString().toLowerCase()] =
              (savingsMap[txName.toString().toLowerCase()] ?? 0) + amt;
        }
      }
      spentPerCategory = spent;
      transactionsByAICategory = txnsByCategory;

      // --------- Savings goals ---------
      final goalsSnapshot = await _firestore
          .collection('users')
          .doc(docID)
          .collection('SavingsGoals')
          .get();

      List<Map<String, dynamic>> loadedGoals = [];
      List<Future<void>> updateFutures = [];

      for (var doc in goalsSnapshot.docs) {
        final data = doc.data();
        final goalName = data['name'];
        final target = (data['target'] as num).toDouble();
        final saved = savingsMap[goalName.toString().toLowerCase()] ?? 0.0;

        updateFutures.add(_firestore
            .collection('users')
            .doc(docID)
            .collection('SavingsGoals')
            .doc(doc.id)
            .update({'saved': saved}));

        loadedGoals
            .add({'id': doc.id, 'name': goalName, 'target': target, 'saved': saved});
      }
      await Future.wait(updateFutures);

      setState(() {
        savingsGoals = loadedGoals;
        for (var cat in categories) {
          _expandedDropdowns.putIfAbsent(cat, () => false);
        }
      });
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  // =========== CATEGORY ADD / DELETE ===========

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Add New Category", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: "Category Name",
            hintText: "e.g., Education",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFADD8E6),
              foregroundColor: Colors.blueGrey[800],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

              // update Firestore
              await _firestore
                  .collection('users')
                  .doc(docID)
                  .collection('Budgets')
                  .doc('budgets')
                  .set({'categories': budgets}, SetOptions(merge: true));

              Navigator.pop(context);

              // re-run fetch to update everything including AI
              await _fetchDocIDAndData();
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBudget(String category) async {
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

  void _editBudgetAmount(String category) {
    final controller = TextEditingController(text: budgets[category]?.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Edit Budget Amount", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Budget Amount",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixText: "\$",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFADD8E6),
              foregroundColor: Colors.blueGrey[800],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _addGoalDialog() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Add Savings Goal", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Goal Name",
                hintText: "e.g., New Car Fund",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Target Amount",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixText: "\$",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFADD8E6),
              foregroundColor: Colors.blueGrey[800],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _editGoalAmount(Map<String, dynamic> goal) {
    final controller = TextEditingController(text: goal['target'].toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Edit Goal Amount", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Target Amount",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixText: "\$",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFADD8E6),
              foregroundColor: Colors.blueGrey[800],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            child: const Text("Save"),
          ),
        ],
      ),
    );
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

  Widget _buildSummaryHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 15, color: Colors.blueGrey[500])),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showBudgetAlert(String category, double percent) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Warning: You are within 90% of your budget for \"$category\"!",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.deepOrange.shade600,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: EdgeInsets.all(10),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryThemeBlue = const Color(0xFFADD8E6);
    final Color strongGreen = Colors.green.shade700;
    final Color warningOrange = Colors.orange.shade700;
    final Color dangerRed = const Color(0xFFFFAB91);
    final Color lightBackgroundStart = const Color(0xFFF5F5F5);
    final Color lightBackgroundEnd = Colors.blueGrey.shade50;
    final Color darkText = Colors.blueGrey[800]!;
    final Color mediumText = Colors.blueGrey[600]!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: lightBackgroundStart,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: showBudgets ? primaryThemeBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: showBudgets ? darkText : mediumText,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle:
                            const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => setState(() => showBudgets = true),
                      child: const Text("Budgets"),
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: !showBudgets ? primaryThemeBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: !showBudgets ? darkText : mediumText,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle:
                            const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => setState(() => showBudgets = false),
                      child: const Text("Savings Goals"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: docID.isEmpty
          ? Center(child: CircularProgressIndicator(color: primaryThemeBlue))
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [lightBackgroundStart, lightBackgroundEnd],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: showBudgets
                    ? Column(
                        children: [
                          _buildSummaryHeader(
                              "Your Budgets",
                              "Track your spending to stay on top of your finances."),
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
                                      final percent =
                                          budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
                                      final txns = transactionsByAICategory[category]
                                              ?.where((txn) =>
                                                  txn['type'] == 'Expense')
                                              .toList() ??
                                          [];

                                      if (percent >= 0.9 && percent < 1.0) {
                                        _showBudgetAlert(category, percent);
                                      }

                                      return Column(
                                        children: [
                                          Dismissible(
                                            key: Key(category),
                                            direction: DismissDirection.endToStart,
                                            background: Container(
                                              decoration: BoxDecoration(
                                                color: dangerRed,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              alignment: Alignment.centerRight,
                                              padding: const EdgeInsets.symmetric(horizontal: 20),
                                              margin: const EdgeInsets.symmetric(vertical: 8),
                                              child: const Icon(Icons.delete_forever,
                                                  color: Colors.white, size: 30),
                                            ),
                                            confirmDismiss: (direction) async {
                                              return await showDialog(
                                                context: context,
                                                builder: (BuildContext context) {
                                                  return AlertDialog(
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(15)),
                                                    title: const Text("Confirm Delete",
                                                        style: TextStyle(
                                                            fontWeight: FontWeight.bold)),
                                                    content: Text(
                                                        "Are you sure you want to delete the budget for '$category'?"),
                                                    actions: <Widget>[
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(context).pop(false),
                                                        child: Text("Cancel",
                                                            style: TextStyle(color: mediumText)),
                                                      ),
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: dangerRed,
                                                          foregroundColor: Colors.white,
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(10)),
                                                        ),
                                                        onPressed: () =>
                                                            Navigator.of(context).pop(true),
                                                        child: const Text("Delete"),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                            onDismissed: (_) => _deleteBudget(category),
                                            child: Card(
                                              margin: const EdgeInsets.symmetric(vertical: 8),
                                              elevation: 4,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12)),
                                              child: Padding(
                                                padding: const EdgeInsets.all(16.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Icon(Icons.category,
                                                            color: primaryThemeBlue, size: 28),
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
                                                          icon: Icon(Icons.edit,
                                                              size: 22, color: mediumText),
                                                          onPressed: () =>
                                                              _editBudgetAmount(category),
                                                          tooltip: "Edit budget",
                                                        ),
                                                        IconButton(
                                                          icon: Icon(
                                                            _expandedDropdowns[category] ?? false
                                                                ? Icons.keyboard_arrow_up
                                                                : Icons.keyboard_arrow_down,
                                                            color: mediumText,
                                                            size: 28,
                                                          ),
                                                          tooltip: "Show itemized transactions",
                                                          onPressed: () {
                                                            setState(() {
                                                              _expandedDropdowns[category] =
                                                                  !(_expandedDropdowns[category] ??
                                                                      false);
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    LinearProgressIndicator(
                                                      value: percent,
                                                      minHeight: 12,
                                                      backgroundColor: Colors.grey[300],
                                                      color: _progressColor(percent),
                                                      borderRadius:
                                                          BorderRadius.circular(6),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.spaceBetween,
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
                                                    Text(
                                                      "Remaining: \$${(budget - spent).toStringAsFixed(2)}",
                                                      style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w500,
                                                          color: strongGreen),
                                                    ),
                                                    if (_expandedDropdowns[category] ?? false)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 12.0),
                                                        child: txns.isEmpty
                                                            ? Text(
                                                                "No transactions in this category.",
                                                                style: TextStyle(
                                                                    fontSize: 14,
                                                                    color: mediumText),
                                                              )
                                                            : Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(
                                                                    "Transactions:",
                                                                    style: TextStyle(
                                                                        fontSize: 15,
                                                                        fontWeight: FontWeight.bold,
                                                                        color: darkText),
                                                                  ),
                                                                  const SizedBox(height: 8),
                                                                  ...txns.map((txn) {
                                                                    return Container(
                                                                      margin: const EdgeInsets.only(bottom: 8),
                                                                      padding: const EdgeInsets.all(12),
                                                                      decoration: BoxDecoration(
                                                                        color: Colors.blueGrey[50],
                                                                        borderRadius: BorderRadius.circular(10),
                                                                        boxShadow: [
                                                                          BoxShadow(
                                                                            color: Colors.grey.withOpacity(0.10),
                                                                            spreadRadius: 1,
                                                                            blurRadius: 6,
                                                                            offset: Offset(0, 3),
                                                                          ),
                                                                        ],
                                                                        border: Border.all(color: Colors.grey.shade200),
                                                                      ),
                                                                      child: Row(
                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                        children: [
                                                                          Column(
                                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                            children: [
                                                                              Text(
                                                                                txn['category'] ?? '',
                                                                                style: TextStyle(
                                                                                  fontSize: 15,
                                                                                  fontWeight: FontWeight.w600,
                                                                                  color: darkText,
                                                                                ),
                                                                              ),
                                                                              if (txn.containsKey('date'))
                                                                                Padding(
                                                                                  padding: const EdgeInsets.only(top: 2),
                                                                                  child: Text(
                                                                                    txn['date'].toString(),
                                                                                    style: TextStyle(
                                                                                      fontSize: 13,
                                                                                      color: mediumText,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                            ],
                                                                          ),
                                                                          Text(
                                                                            "- \$${(txn['amount'] as num?)?.toStringAsFixed(2) ?? ''}",
                                                                            style: TextStyle(
                                                                              fontSize: 16,
                                                                              fontWeight: FontWeight.bold,
                                                                              color: Colors.red[400],
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    );
                                                                  }).toList(),
                                                                ],
                                                              ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryThemeBlue,
                                foregroundColor: Colors.blueGrey[900],
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text("Add Category",
                                  style: TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.w600)),
                              onPressed: _showAddCategoryDialog,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildSummaryHeader("Savings Goals",
                              "Visualize your progress toward each savings target."),
                          Expanded(
                            child: savingsGoals.isEmpty
                                ? Center(
                                    child: Text(
                                      "No savings goals yet!\nTap 'Add Goal' to create one.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 16, color: mediumText),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: savingsGoals.length,
                                    itemBuilder: (context, index) {
                                      final goal = savingsGoals[index];
                                      final saved = goal['saved'] ?? 0.0;
                                      final target = goal['target'] ?? 1.0;
                                      final percent =
                                          target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;
                                      final color = percent >= 1.0
                                          ? strongGreen
                                          : _progressColor(percent);

                                      return Dismissible(
                                        key: Key(goal['id']),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          decoration: BoxDecoration(
                                            color: dangerRed,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.symmetric(horizontal: 20),
                                          margin: const EdgeInsets.symmetric(vertical: 8),
                                          child: const Icon(Icons.delete_forever,
                                              color: Colors.white, size: 30),
                                        ),
                                        confirmDismiss: (direction) async {
                                          return await showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(15)),
                                                title: const Text("Confirm Delete",
                                                    style: TextStyle(
                                                        fontWeight: FontWeight.bold)),
                                                content: Text(
                                                    "Are you sure you want to delete the goal \"${goal['name']}\"?"),
                                                actions: <Widget>[
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(context).pop(false),
                                                    child: Text("Cancel",
                                                        style:
                                                            TextStyle(color: mediumText)),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: dangerRed,
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(10)),
                                                    ),
                                                    onPressed: () =>
                                                        Navigator.of(context).pop(true),
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
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12)),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Icon(Icons.savings,
                                                        color: strongGreen, size: 28),
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
                                                      icon: Icon(Icons.edit,
                                                          size: 22, color: mediumText),
                                                      onPressed: () =>
                                                          _editGoalAmount(goal),
                                                      tooltip: "Edit target",
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                LinearProgressIndicator(
                                                  value: percent,
                                                  minHeight: 12,
                                                  backgroundColor: Colors.grey[300],
                                                  color: color,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                const SizedBox(height: 10),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      "Target: \$${target.toStringAsFixed(2)}",
                                                      style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w600,
                                                          color: mediumText),
                                                    ),
                                                    Text(
                                                      "Saved: \$${saved.toStringAsFixed(2)}",
                                                      style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w600,
                                                          color: mediumText),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  percent >= 1.0
                                                      ? "Goal Reached!"
                                                      : "Remaining: \$${(target - saved).toStringAsFixed(2)}",
                                                  style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w500,
                                                      color: percent >= 1.0
                                                          ? strongGreen
                                                          : warningOrange),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: strongGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text("Add Goal",
                                  style: TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.w600)),
                              onPressed: _addGoalDialog,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
    );
  }
}
