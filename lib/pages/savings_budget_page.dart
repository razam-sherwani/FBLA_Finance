import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchDocIDAndData();
  }

  Future<void> _fetchDocIDAndData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: user.email)
          .get();
      if (snapshot.docs.isNotEmpty) {
        docID = snapshot.docs[0].id;
        // Fetch transactions once and reuse for all calculations
        final transactions = await _firestore
            .collection('users')
            .doc(docID)
            .collection('Transactions')
            .get();

        // Prepare data for budgets and savings in one pass
        final Set<String> fetchedCategories = {};
        Map<String, double> spent = {};
        Map<String, double> savingsMap = {};
        for (var doc in transactions.docs) {
          final data = doc.data();
          final cat = data['category'];
          final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final type = data['type'];
          if (cat != null && cat.toLowerCase() != 'savings') {
            fetchedCategories.add(cat);
            if (type == 'Expense') {
              spent[cat] = (spent[cat] ?? 0) + amt;
            }
          }
          // For savings goals, accumulate by category name
          if (cat != null) {
            savingsMap[cat.toString().toLowerCase()] =
                (savingsMap[cat.toString().toLowerCase()] ?? 0) + amt;
          }
        }
        final List<String> uniqueCategories = fetchedCategories.toList()..sort();
        final budgetDoc = await _firestore
            .collection('users')
            .doc(docID)
            .collection('Budgets')
            .doc('budgets')
            .get();
        Map<String, dynamic> savedBudgets = budgetDoc.exists ? (budgetDoc.data()?['categories'] ?? {}) : {};

        // Fetch savings goals and update their saved values in parallel
        final goalsSnapshot = await _firestore
            .collection('users')
            .doc(docID)
            .collection('SavingsGoals')
            .get();

        List<Map<String, dynamic>> loadedGoals = [];
        List<Future> updateFutures = [];
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
          loadedGoals.add({'id': doc.id, 'name': goalName, 'target': target, 'saved': saved});
        }
        await Future.wait(updateFutures);

        // Single setState after all data is ready
        setState(() {
          categories = uniqueCategories;
          for (var cat in categories) {
            budgets[cat] = (savedBudgets[cat]?.toDouble()) ?? (totalIncome * (categorySplits[cat] ?? 0.05));
          }
          spentPerCategory = spent;
          savingsGoals = loadedGoals;
        });
      }
    }
  }

  Future<void> _fetchCategoriesAndBudgets() async {
    final transactions = await _firestore
        .collection('users')
        .doc(docID)
        .collection('Transactions')
        .get();

    final Set<String> fetchedCategories = {};
    for (var doc in transactions.docs) {
      if (doc.data().containsKey('category')) {
        String cat = doc['category'];
        if (cat.toLowerCase() != 'savings') {
          fetchedCategories.add(cat);
        }
      }
    }
    final List<String> uniqueCategories = fetchedCategories.toList()..sort();
    final budgetDoc = await _firestore
        .collection('users')
        .doc(docID)
        .collection('Budgets')
        .doc('budgets')
        .get();
    Map<String, dynamic> savedBudgets = budgetDoc.exists ? (budgetDoc.data()?['categories'] ?? {}) : {};

    categories = uniqueCategories;
    for (var cat in categories) {
      budgets[cat] = (savedBudgets[cat]?.toDouble()) ?? (totalIncome * (categorySplits[cat] ?? 0.05));
    }
  }

  Future<void> _fetchSpentPerCategory() async {
    if (docID.isEmpty) return;
    final transactions = await _firestore
        .collection('users')
        .doc(docID)
        .collection('Transactions')
        .get();

    Map<String, double> spent = {};
    for (var doc in transactions.docs) {
      final data = doc.data();
      final cat = data['category'];
      final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final type = data['type'];
      if (cat != null && type == 'Expense') {
        spent[cat] = (spent[cat] ?? 0) + amt;
      }
    }
    spentPerCategory = spent;
  }

  Future<void> _fetchSavingsGoals() async {
    final goalsSnapshot = await _firestore
        .collection('users')
        .doc(docID)
        .collection('SavingsGoals')
        .get();
    final transactionsSnapshot = await _firestore
        .collection('users')
        .doc(docID)
        .collection('Transactions')
        .get();

    List<Map<String, dynamic>> loadedGoals = [];
    for (var doc in goalsSnapshot.docs) {
      final data = doc.data();
      final goalName = data['name'];
      final target = (data['target'] as num).toDouble();
      double saved = 0.0;
      for (var t in transactionsSnapshot.docs) {
        final tData = t.data();
        if ((tData['category'] ?? '').toString().toLowerCase() == goalName.toString().toLowerCase()) {
          saved += (tData['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }
      await _firestore
          .collection('users')
          .doc(docID)
          .collection('SavingsGoals')
          .doc(doc.id)
          .update({'saved': saved});
      loadedGoals.add({'id': doc.id, 'name': goalName, 'target': target, 'saved': saved});
    }
    savingsGoals = loadedGoals;
  }

  Color _progressColor(double percent) {
    // Green (0) -> Yellow (0.5) -> Red (1)
    if (percent < 0.5) {
      return Color.lerp(Colors.green, Colors.yellow, percent * 2)!;
    } else {
      return Color.lerp(Colors.yellow, Colors.red, (percent - 0.5) * 2)!;
    }
  }

  void _checkBudgetAlerts() {
    for (final category in categories) {
      final budget = budgets[category] ?? 0.0;
      final spent = spentPerCategory[category] ?? 0.0;
      if (budget > 0) {
        final percent = spent / budget;
        if (percent >= 0.9 && percent < 1.0) {
          // Show alert if not already shown for this category in this session
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Warning: You are within 90% of your budget for \"$category\"!",
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.redAccent,
                duration: Duration(seconds: 4),
              ),
            );
          });
        }
      }
    }
  }

  void _editBudgetAmount(String category) {
    final controller = TextEditingController(text: budgets[category]?.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Budget Amount"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: "Budget Amount"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final value = double.tryParse(controller.text) ?? 0.0;
              setState(() {
                budgets[category] = value;
              });
              await _firestore
                  .collection('users')
                  .doc(docID)
                  .collection('Budgets')
                  .doc('budgets')
                  .set({'categories': budgets});
              Navigator.pop(context);
            },
            child: Text("Save"),
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
        title: Text("Edit Goal Amount"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: "Goal Amount"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final value = double.tryParse(controller.text) ?? 0.0;
              await _firestore
                  .collection('users')
                  .doc(docID)
                  .collection('SavingsGoals')
                  .doc(goal['id'])
                  .update({'target': value});
              await _fetchSavingsGoals();
              Navigator.pop(context);
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }

  void _addNewCategory(String categoryName) async {
    if (categoryName.isEmpty || categories.contains(categoryName)) return;
    setState(() {
      categories.add(categoryName);
      budgets[categoryName] = totalIncome * 0.05;
    });
    await _firestore
        .collection('users')
        .doc(docID)
        .collection('Budgets')
        .doc('budgets')
        .set({'categories': budgets});
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add New Category"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: "Category Name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              _addNewCategory(controller.text.trim());
              Navigator.pop(context);
            },
            child: Text("Add"),
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
        title: Text("Add Savings Goal"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: "Goal Name"),
            ),
            TextField(
              controller: targetController,
              decoration: InputDecoration(labelText: "Target Amount"),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final target = double.tryParse(targetController.text) ?? 0.0;
              if (name.isNotEmpty && target > 0) {
                await _firestore
                    .collection('users')
                    .doc(docID)
                    .collection('SavingsGoals')
                    .add({'name': name, 'target': target, 'saved': 0.0});
                await _fetchSavingsGoals();
              }
              Navigator.pop(context);
            },
            child: Text("Add"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBudget(String category) async {
    setState(() {
      budgets.remove(category);
      categories.remove(category);
    });
    await _firestore
        .collection('users')
        .doc(docID)
        .collection('Budgets')
        .doc('budgets')
        .set({'categories': budgets});
  }

  Future<void> _deleteGoal(String goalId) async {
    await _firestore
        .collection('users')
        .doc(docID)
        .collection('SavingsGoals')
        .doc(goalId)
        .delete();
    await _fetchSavingsGoals();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: showBudgets ? Colors.blue : Colors.grey[300],
                  foregroundColor: showBudgets ? Colors.white : Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => setState(() => showBudgets = true),
                child: Text("Budgets"),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: !showBudgets ? Colors.blue : Colors.grey[300],
                  foregroundColor: !showBudgets ? Colors.white : Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => setState(() => showBudgets = false),
                child: Text("Savings Goals"),
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: docID.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: showBudgets
                  ? Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              final budget = budgets[category] ?? 0.0;
                              final spent = spentPerCategory[category] ?? 0.0;
                              final percent = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
                              // Alert if within 90% of budget
                              if (percent >= 0.9 && percent < 1.0) {
                                // Only show one alert per build for this category
                                Future.delayed(Duration.zero, _checkBudgetAlerts);
                              }
                              return Dismissible(
                                key: Key(category),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerRight,
                                  padding: EdgeInsets.symmetric(horizontal: 20),
                                  child: Icon(Icons.delete, color: Colors.white),
                                ),
                                onDismissed: (_) => _deleteBudget(category),
                                child: Card(
                                  child: ListTile(
                                    title: Text(category),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        LinearProgressIndicator(
                                          value: percent,
                                          minHeight: 10,
                                          backgroundColor: Colors.grey[300],
                                          color: _progressColor(percent),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Text(
                                              "\$${budget.toStringAsFixed(2)}",
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.edit, size: 20),
                                              onPressed: () => _editBudgetAmount(category),
                                            ),
                                            Spacer(),
                                            Text(
                                              "\$${spent.toStringAsFixed(2)} spent",
                                              style: TextStyle(color: Colors.grey[700]),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.add),
                                label: Text("Add Category"),
                                onPressed: _showAddCategoryDialog,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: savingsGoals.length,
                            itemBuilder: (context, index) {
                              final goal = savingsGoals[index];
                              final percent = (goal['target'] > 0)
                                  ? (goal['saved'] / goal['target']).clamp(0.0, 1.0)
                                  : 0.0;
                              return Dismissible(
                                key: Key(goal['id']),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerRight,
                                  padding: EdgeInsets.symmetric(horizontal: 20),
                                  child: Icon(Icons.delete, color: Colors.white),
                                ),
                                onDismissed: (_) => _deleteGoal(goal['id']),
                                child: Card(
                                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                                  child: ListTile(
                                    title: Text(goal['name']),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        LinearProgressIndicator(
                                          value: percent,
                                          minHeight: 10,
                                          backgroundColor: Colors.grey[300],
                                          color: _progressColor(percent),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Text(
                                              "\$${goal['target'].toStringAsFixed(2)}",
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.edit, size: 20),
                                              onPressed: () => _editGoalAmount(goal),
                                            ),
                                            Spacer(),
                                            Text(
                                              "\$${goal['saved'].toStringAsFixed(2)} saved",
                                              style: TextStyle(color: Colors.grey[700]),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.add),
                                label: Text("Add Goal"),
                                onPressed: _addGoalDialog,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
    );
  }
}
