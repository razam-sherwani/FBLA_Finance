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
  double totalIncome = 5000.0; // You can make this dynamic if needed

  // Standard budget splits (excluding savings)
  final Map<String, double> categorySplits = {
    "Rent": 0.30,
    "Groceries": 0.15,
    "Transportation": 0.10,
    "Entertainment": 0.10,
    "Dining Out": 0.05,
    "Utilities": 0.05,
    "Miscellaneous": 0.25,
  };

  // Savings goals
  List<Map<String, dynamic>> savingsGoals = [];
  Map<String, double> spentPerCategory = {};

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
        setState(() {
          docID = snapshot.docs[0].id;
        });
        await _fetchCategoriesAndBudgets();
        await _fetchSavingsGoals();
        await _fetchSpentPerCategory();
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

    // Remove duplicates and sort
    final List<String> uniqueCategories = fetchedCategories.toList()..sort();

    // Load budgets from Firestore if they exist
    final budgetDoc = await _firestore.collection('users').doc(docID).collection('Budgets').doc('budgets').get();
    Map<String, dynamic> savedBudgets = budgetDoc.exists ? (budgetDoc.data()?['categories'] ?? {}) : {};

    setState(() {
      categories = uniqueCategories;
      for (var cat in categories) {
        budgets[cat] = (savedBudgets[cat]?.toDouble()) ??
            (totalIncome * (categorySplits[cat] ?? 0.05));
      }
    });
  }

  Future<void> _fetchSavingsGoals() async {
    final goalsSnapshot = await _firestore
        .collection('users')
        .doc(docID)
        .collection('SavingsGoals')
        .get();
    setState(() {
      savingsGoals = goalsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'],
          'target': (data['target'] as num).toDouble(),
          'saved': (data['saved'] as num).toDouble(),
        };
      }).toList();
    });
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
    setState(() {
      spentPerCategory = spent;
    });
  }

  void _updateBudget(String category, String value) {
    final amount = double.tryParse(value) ?? 0;
    setState(() {
      budgets[category] = amount;
    });
  }

  Future<void> _saveBudgets() async {
    await _firestore
        .collection('users')
        .doc(docID)
        .collection('Budgets')
        .doc('budgets')
        .set({'categories': budgets});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Budgets saved!')),
    );
    await _fetchSpentPerCategory();
  }

  void _addNewCategory(String categoryName) {
    if (categoryName.isEmpty || categories.contains(categoryName)) return;
    setState(() {
      categories.add(categoryName);
      budgets[categoryName] = totalIncome * 0.05;
    });
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

  void _showSavingsGoalsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SavingsGoalsSheet(
        docID: docID,
        onGoalAdded: () async {
          await _fetchSavingsGoals();
        },
        onGoalUpdated: () async {
          await _fetchSavingsGoals();
        },
      ),
    );
  }

  Color _progressColor(double percent) {
    // Red (0) -> Yellow (0.5) -> Green (1)
    if (percent < 0.5) {
      return Color.lerp(Colors.red, Colors.yellow, percent * 2)!;
    } else {
      return Color.lerp(Colors.yellow, Colors.green, (percent - 0.5) * 2)!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Budgets"),
        actions: [
          IconButton(
            icon: Icon(Icons.savings),
            tooltip: "Savings Goals",
            onPressed: _showSavingsGoalsSheet,
          ),
        ],
      ),
      body: docID.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final budget = budgets[category] ?? 0.0;
                        final spent = spentPerCategory[category] ?? 0.0;
                        final percent = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
                        return Card(
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
                                Text(
                                  "\$${spent.toStringAsFixed(2)} / \$${budget.toStringAsFixed(2)} spent",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextField(
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: "Budget Amount",
                                  ),
                                  onChanged: (value) =>
                                      _updateBudget(category, value),
                                  controller: TextEditingController(
                                    text: budgets[category]?.toStringAsFixed(2),
                                  ),
                                ),
                              ],
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
                      SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveBudgets,
                          child: const Text("Save Budgets"),
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

// Savings Goals Sheet Widget
class SavingsGoalsSheet extends StatefulWidget {
  final String docID;
  final VoidCallback onGoalAdded;
  final VoidCallback onGoalUpdated;

  const SavingsGoalsSheet({
    Key? key,
    required this.docID,
    required this.onGoalAdded,
    required this.onGoalUpdated,
  }) : super(key: key);

  @override
  State<SavingsGoalsSheet> createState() => _SavingsGoalsSheetState();
}

class _SavingsGoalsSheetState extends State<SavingsGoalsSheet> {
  List<Map<String, dynamic>> goals = [];

  @override
  void initState() {
    super.initState();
    _fetchGoalsAndUpdateSaved();
  }

  Future<void> _fetchGoalsAndUpdateSaved() async {
    final goalsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.docID)
        .collection('SavingsGoals')
        .get();

    final transactionsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.docID)
        .collection('Transactions')
        .get();

    List<Map<String, dynamic>> loadedGoals = [];
    for (var doc in goalsSnapshot.docs) {
      final data = doc.data();
      final goalName = data['name'];
      final target = (data['target'] as num).toDouble();
      // Sum all transactions with category == goalName
      double saved = 0.0;
      for (var t in transactionsSnapshot.docs) {
        final tData = t.data();
        if ((tData['category'] ?? '').toString().toLowerCase() == goalName.toString().toLowerCase()) {
          saved += (tData['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }
      // Update Firestore if needed
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.docID)
          .collection('SavingsGoals')
          .doc(doc.id)
          .update({'saved': saved});
      loadedGoals.add({'id': doc.id, 'name': goalName, 'target': target, 'saved': saved});
    }
    setState(() {
      goals = loadedGoals;
    });
  }

  void _addGoal(String name, double target) async {
    if (name.isEmpty || target <= 0) return;
    final docRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.docID)
        .collection('SavingsGoals')
        .add({'name': name, 'target': target, 'saved': 0.0});
    await _fetchGoalsAndUpdateSaved();
    widget.onGoalAdded();
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
            onPressed: () {
              final name = nameController.text.trim();
              final target = double.tryParse(targetController.text) ?? 0.0;
              _addGoal(name, target);
              Navigator.pop(context);
            },
            child: Text("Add"),
          ),
        ],
      ),
    );
  }

  Color _progressColor(double percent) {
    if (percent < 0.5) {
      return Color.lerp(Colors.red, Colors.yellow, percent * 2)!;
    } else {
      return Color.lerp(Colors.yellow, Colors.green, (percent - 0.5) * 2)!;
    }
  }

  void _updateSavedAmount(String goalId, double newSaved, double target) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.docID)
        .collection('SavingsGoals')
        .doc(goalId)
        .update({'saved': newSaved});
    await _fetchGoalsAndUpdateSaved();
    widget.onGoalUpdated();
    if (newSaved >= target) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Goal Completed!"),
            content: Text("Congratulations! You've reached your savings goal."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK"),
              ),
            ],
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Scaffold(
        appBar: AppBar(
          title: Text("Savings Goals"),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Icon(Icons.add),
              onPressed: _addGoalDialog,
            ),
          ],
        ),
        body: ListView.builder(
          controller: scrollController,
          itemCount: goals.length,
          itemBuilder: (context, index) {
            final goal = goals[index];
            final percent = (goal['target'] > 0)
                ? (goal['saved'] / goal['target']).clamp(0.0, 1.0)
                : 0.0;
            return Card(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                    Text(
                      "\$${goal['saved'].toStringAsFixed(2)} / \$${goal['target'].toStringAsFixed(2)}",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () {
                    final savedController = TextEditingController(
                        text: goal['saved'].toStringAsFixed(2));
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text("Update Saved Amount"),
                        content: TextField(
                          controller: savedController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: "Saved Amount"),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () {
                              final newSaved =
                                  double.tryParse(savedController.text) ?? 0.0;
                              _updateSavedAmount(
                                  goal['id'], newSaved, goal['target']);
                              Navigator.pop(context);
                            },
                            child: Text("Update"),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
