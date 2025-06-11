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
  double totalIncome = 5000.0; // Assuming a default total income for initial budget splits
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

  // Fetches user's document ID, transactions, budgets, and savings goals in a single pass.
  Future<void> _fetchDocIDAndData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Fetch user document to get docID
        final snapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: user.email)
            .get();

        if (snapshot.docs.isNotEmpty) {
          docID = snapshot.docs[0].id;

          // Fetch all transactions for the user
          final transactions = await _firestore
              .collection('users')
              .doc(docID)
              .collection('Transactions')
              .get();

          final Set<String> fetchedCategories = {};
          Map<String, double> spent = {};
          Map<String, double> savingsMap = {};

          // Process transactions to get spent amounts and savings for goals
          for (var doc in transactions.docs) {
            final data = doc.data();
            final cat = data['category'];
            final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final type = data['type'];

            if (cat != null) {
              // Exclude 'Savings' category from general budget tracking
              if (cat.toLowerCase() != 'savings') {
                fetchedCategories.add(cat);
                if (type == 'Expense') {
                  spent[cat] = (spent[cat] ?? 0) + amt;
                }
              }
              // For savings goals, accumulate by category name (case-insensitive)
              savingsMap[cat.toString().toLowerCase()] =
                  (savingsMap[cat.toString().toLowerCase()] ?? 0) + amt;
            }
          }

          final List<String> uniqueCategories = fetchedCategories.toList()..sort();

          // Fetch existing budget settings
          final budgetDoc = await _firestore
              .collection('users')
              .doc(docID)
              .collection('Budgets')
              .doc('budgets')
              .get();
          Map<String, dynamic> savedBudgets =
              budgetDoc.exists ? (budgetDoc.data()?['categories'] ?? {}) : {};

          // Fetch savings goals and update their 'saved' value in Firestore
          final goalsSnapshot = await _firestore
              .collection('users')
              .doc(docID)
              .collection('SavingsGoals')
              .get();

          List<Map<String, dynamic>> loadedGoals = [];
          List<Future<void>> updateFutures = []; // To hold Firestore update promises

          for (var doc in goalsSnapshot.docs) {
            final data = doc.data();
            final goalName = data['name'];
            final target = (data['target'] as num).toDouble();
            final saved = savingsMap[goalName.toString().toLowerCase()] ?? 0.0;

            // Add update promise to list
            updateFutures.add(_firestore
                .collection('users')
                .doc(docID)
                .collection('SavingsGoals')
                .doc(doc.id)
                .update({'saved': saved}));

            loadedGoals.add({'id': doc.id, 'name': goalName, 'target': target, 'saved': saved});
          }
          await Future.wait(updateFutures); // Wait for all updates to complete

          // Update UI state with all fetched and calculated data
          setState(() {
            categories = uniqueCategories;
            for (var cat in categories) {
              budgets[cat] = (savedBudgets[cat]?.toDouble()) ??
                  (totalIncome * (categorySplits[cat] ?? 0.05));
            }
            spentPerCategory = spent;
            savingsGoals = loadedGoals;
          });
        } else {
          // Handle case where user document doesn't exist
          print("User document not found for email: ${user.email}");
          setState(() {
            docID = 'no_user_found'; // Indicate that docID couldn't be fetched
          });
        }
      } catch (e) {
        print("Error fetching data: $e");
        // Optionally show an error message to the user
      }
    } else {
      print("User is not logged in.");
      setState(() {
        docID = 'no_user_logged_in'; // Indicate no user is logged in
      });
    }
  }

  // Determines the color of the progress indicator based on percentage.
  Color _progressColor(double percent) {
    // Adjusted colors to match a more pastel/muted theme
    if (percent < 0.5) {
      return Color.lerp(Colors.lightGreen.shade300, Colors.amber.shade300, percent * 2)!;
    } else if (percent < 0.9) {
      return Color.lerp(Colors.amber.shade300, Colors.deepOrange.shade300, (percent - 0.5) * 2)!;
    } else {
      return Color.lerp(Colors.deepOrange.shade300, Colors.red.shade400, (percent - 0.9) * 10)!;
    }
  }

  // Shows a Snackbar alert for budget warnings.
  void _showBudgetAlert(String category, double percent) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { // Ensure the widget is still mounted before showing SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Warning: You are within 90% of your budget for \"$category\"!",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.deepOrange.shade600, // Adjusted color
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating, // Make it float for better visibility
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: EdgeInsets.all(10),
          ),
        );
      }
    });
  }

  // Dialog to edit a budget amount for a given category.
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
              backgroundColor: Color(0xFFADD8E6), // Light blue for action button
              foregroundColor: Colors.blueGrey[800],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final value = double.tryParse(controller.text) ?? 0.0;
              if (value < 0) {
                // Prevent negative budgets
                _showErrorMessage("Budget cannot be negative.");
                return;
              }
              setState(() {
                budgets[category] = value;
              });
              await _firestore
                  .collection('users')
                  .doc(docID)
                  .collection('Budgets')
                  .doc('budgets')
                  .set({'categories': budgets}, SetOptions(merge: true)); // Use merge to avoid overwriting other fields
              Navigator.pop(context);
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }

  // Dialog to edit a savings goal's target amount.
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
              backgroundColor: Color(0xFFADD8E6), // Light blue for action button
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
              await _fetchDocIDAndData(); // Re-fetch all data to update UI
              Navigator.pop(context);
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }

  // Adds a new budget category.
  void _addNewCategory(String categoryName) async {
    if (categoryName.isEmpty) {
      _showErrorMessage("Category name cannot be empty.");
      return;
    }
    if (categories.any((cat) => cat.toLowerCase() == categoryName.toLowerCase())) {
      _showErrorMessage("Category '$categoryName' already exists.");
      return;
    }
    setState(() {
      categories.add(categoryName);
      budgets[categoryName] = totalIncome * 0.05; // Default split for new category
    });
    await _firestore
        .collection('users')
        .doc(docID)
        .collection('Budgets')
        .doc('budgets')
        .set({'categories': budgets}, SetOptions(merge: true));
  }

  // Dialog to add a new budget category.
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
              backgroundColor: Color(0xFFADD8E6), // Light blue for action button
              foregroundColor: Colors.blueGrey[800],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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

  // Dialog to add a new savings goal.
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
            SizedBox(height: 15),
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
              backgroundColor: Color(0xFFADD8E6), // Light blue for action button
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
                  .add({'name': name, 'target': target, 'saved': 0.0}); // Initialize saved to 0
              await _fetchDocIDAndData(); // Re-fetch all data to update UI
              Navigator.pop(context);
            },
            child: Text("Add"),
          ),
        ],
      ),
    );
  }

  // Deletes a budget category.
  Future<void> _deleteBudget(String category) async {
    setState(() {
      budgets.remove(category);
      categories.remove(category);
    });
    // Update Firestore to remove the category from the budgets map
    await _firestore
        .collection('users')
        .doc(docID)
        .collection('Budgets')
        .doc('budgets')
        .set({'categories': budgets}, SetOptions(merge: true));
    _showSuccessMessage("Budget for '$category' deleted.");
  }

  // Deletes a savings goal.
  Future<void> _deleteGoal(String goalId) async {
    await _firestore
        .collection('users')
        .doc(docID)
        .collection('SavingsGoals')
        .doc(goalId)
        .delete();
    await _fetchDocIDAndData(); // Re-fetch all data to update UI
    _showSuccessMessage("Savings goal deleted.");
  }

  // Helper for showing error messages via SnackBar
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Helper for showing success messages via SnackBar
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green.shade700,
        duration: Duration(seconds: 2),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Define primary and accent colors for the app, matching the UI theme
    final Color primaryThemeBlue = Color(0xFFADD8E6); // A softer light blue from the theme
    final Color strongGreen = Colors.green.shade700; // Darker green for readable "Remaining" text
    final Color warningOrange = Color.fromARGB(255, 197, 123, 12); // Softer orange for warnings
    final Color dangerRed = Color(0xFFFFAB91); // Softer red for danger
    final Color lightBackground = Color(0xFFF5F5F5); // Very light grey for backgrounds
    final Color darkText = Colors.blueGrey[800]!;
    final Color mediumText = Colors.blueGrey[600]!;

    return Scaffold(
      backgroundColor: lightBackground, // Light background for the whole page
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2, // Subtle shadow for the app bar
        titleSpacing: 0, // Remove default title spacing
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: lightBackground, // Match tab bar background to page background
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300) // Subtle border
            ),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: showBudgets ? primaryThemeBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: showBudgets ? darkText : mediumText, // Text color changes with selection
                        padding: EdgeInsets.symmetric(vertical: 12),
                        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => setState(() => showBudgets = true),
                      child: Text("Budgets"),
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: !showBudgets ? primaryThemeBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: !showBudgets ? darkText : mediumText, // Text color changes with selection
                        padding: EdgeInsets.symmetric(vertical: 12),
                        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => setState(() => showBudgets = false),
                      child: Text("Savings Goals"),
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
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: showBudgets
                  ? Column(
                      children: [
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

                                    // Show alert if within 90% of budget and not over
                                    if (percent >= 0.9 && percent < 1.0) {
                                      _showBudgetAlert(category, percent);
                                    }

                                    return Dismissible(
                                      key: Key(category),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        decoration: BoxDecoration(
                                          color: dangerRed, // Use softer red for swipe background
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        alignment: Alignment.centerRight,
                                        padding: EdgeInsets.symmetric(horizontal: 20),
                                        margin: EdgeInsets.symmetric(vertical: 8),
                                        child: Icon(Icons.delete_forever, color: Colors.white, size: 30),
                                      ),
                                      confirmDismiss: (direction) async {
                                        return await showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                              title: Text("Confirm Delete", style: TextStyle(fontWeight: FontWeight.bold)),
                                              content: Text("Are you sure you want to delete the budget for '$category'?"),
                                              actions: <Widget>[
                                                TextButton(
                                                  onPressed: () => Navigator.of(context).pop(false),
                                                  child: Text("Cancel", style: TextStyle(color: mediumText)),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: dangerRed,
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  ),
                                                  onPressed: () => Navigator.of(context).pop(true),
                                                  child: Text("Delete"),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                      onDismissed: (_) => _deleteBudget(category),
                                      child: Card(
                                        margin: EdgeInsets.symmetric(vertical: 8),
                                        elevation: 4, // Add shadow
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    "Category: $category",
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: darkText,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: Icon(Icons.edit, size: 22, color: mediumText),
                                                    onPressed: () => _editBudgetAmount(category),
                                                    tooltip: "Edit budget",
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 10),
                                              LinearProgressIndicator(
                                                value: percent,
                                                minHeight: 12,
                                                backgroundColor: Colors.grey[300],
                                                color: _progressColor(percent),
                                                borderRadius: BorderRadius.circular(6), // Rounded progress bar
                                              ),
                                              SizedBox(height: 10),
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
                                              SizedBox(height: 5),
                                              Text(
                                                "Remaining: \$${(budget - spent).toStringAsFixed(2)}",
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    color: (budget - spent) < 0 ? dangerRed : strongGreen, // Use strongGreen for readable text
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
                        SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryThemeBlue, // Use theme primary
                              foregroundColor: darkText, // Darker text for button
                              padding: EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                            ),
                            icon: Icon(Icons.add_circle_outline, size: 28),
                            label: Text(
                              "Add New Budget Category",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            onPressed: _showAddCategoryDialog,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
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

                                    // Logic for remaining/excess display
                                    final double remainingOrExcess = goal['target'] - goal['saved'];
                                    String displayText;
                                    Color textColor;

                                    if (remainingOrExcess <= 0) {
                                      displayText = "Goal Met! Excess: \$${(-remainingOrExcess).toStringAsFixed(2)}";
                                      textColor = strongGreen; // Darker green for readable text
                                    } else {
                                      displayText = "Remaining: \$${remainingOrExcess.toStringAsFixed(2)}";
                                      textColor = warningOrange;
                                    }

                                    return Dismissible(
                                      key: Key(goal['id']),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        decoration: BoxDecoration(
                                          color: dangerRed, // Use softer red for swipe background
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        alignment: Alignment.centerRight,
                                        padding: EdgeInsets.symmetric(horizontal: 20),
                                        margin: EdgeInsets.symmetric(vertical: 8),
                                        child: Icon(Icons.delete_forever, color: Colors.white, size: 30),
                                      ),
                                      confirmDismiss: (direction) async {
                                        return await showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                              title: Text("Confirm Delete", style: TextStyle(fontWeight: FontWeight.bold)),
                                              content: Text("Are you sure you want to delete '${goal['name']}' goal?"),
                                              actions: <Widget>[
                                                TextButton(
                                                  onPressed: () => Navigator.of(context).pop(false),
                                                  child: Text("Cancel", style: TextStyle(color: mediumText)),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: dangerRed,
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  ),
                                                  onPressed: () => Navigator.of(context).pop(true),
                                                  child: Text("Delete"),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                      onDismissed: (_) => _deleteGoal(goal['id']),
                                      child: Card(
                                        margin: EdgeInsets.symmetric(vertical: 8),
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
                                                  Text(
                                                    goal['name'],
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: darkText,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: Icon(Icons.edit, size: 22, color: mediumText),
                                                    onPressed: () => _editGoalAmount(goal),
                                                    tooltip: "Edit goal target",
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 10),
                                              LinearProgressIndicator(
                                                value: percent,
                                                minHeight: 12,
                                                backgroundColor: Colors.grey[300],
                                                color: _progressColor(percent),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              SizedBox(height: 10),
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
                                              SizedBox(height: 5),
                                              Text(
                                                displayText, // Display text from logic
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    color: textColor, // Color from logic
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
                        SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryThemeBlue, // Use theme primary
                              foregroundColor: darkText, // Darker text for button
                              padding: EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                            ),
                            icon: Icon(Icons.star_border, size: 28),
                            label: Text(
                              "Add New Savings Goal",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            onPressed: _addGoalDialog,
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}
