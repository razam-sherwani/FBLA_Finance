import 'package:fbla_finance/backend/auth.dart';
import 'package:fbla_finance/backend/paragraph_pdf_api.dart';
import 'package:fbla_finance/backend/save_and_open_pdf.dart';
import 'package:fbla_finance/pages/transactions.dart';
import 'package:fbla_finance/util/gradient_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class SplitTransactions extends StatefulWidget {
  SplitTransactions({Key? key}) : super(key: key);

  @override
  _SplitTransactionsState createState() => _SplitTransactionsState();
}

class _SplitTransactionsState extends State<SplitTransactions> {
  final User? user = Auth().currentUser;
  String docID = "";
  List<Color> colors = [Color(0xffB8E8FF), Colors.blue.shade900];
  final List<Map<String, dynamic>> _transactionsList = [];
  Map<String, List<Map<String, dynamic>>> transactionsByCategory = {};
  Map<String, bool> expandedSections = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  double _totalBalance = 0.0;
  DateTime date = DateTime.now();
  double amt = 0;
  String? type1;
  String? categ;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchTransactions(); // Refresh data when returning to this page
  }

  Future<void> _initializeData() async {
    await fetchDocID();
    _fetchTransactions();
  }

  Future<void> fetchDocID() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          setState(() {
            docID = snapshot.docs[0].id;
          });
        } else {
          setState(() {
            docID = '';
          });
        }
      }).catchError((error) {
        print('Error fetching docID: $error');
        setState(() {
          docID = '';
        });
      });
    }
  }

  void _fetchTransactions() {
    if (docID.isEmpty) {
      print("Warning: docID is empty, skipping fetch");
      return;
    }

    _firestore
        .collection('users')
        .doc(docID)
        .collection('Transactions')
        .get()
        .then((querySnapshot) {
      if (!mounted) return;  // Check if widget is still mounted
      setState(() {
        transactionsByCategory.clear();
        _totalBalance = 0.0;

        for (var doc in querySnapshot.docs) {
          var transaction = {
            'transactionId': doc.id,
            'amount': doc['amount'] ?? 0.0,
            'type': doc['type'] ?? 'Unknown',
            'category': doc['category'] ?? 'Uncategorized',
            'date': (doc['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
          };

          String category = transaction['category'] ?? 'Uncategorized';
          if (!transactionsByCategory.containsKey(category)) {
            transactionsByCategory[category] = [];
          }
          transactionsByCategory[category]!.add(transaction);

          if (transaction['type'] == 'Income') {
            _totalBalance += transaction['amount'];
          } else {
            _totalBalance -= transaction['amount'];
          }
        }
        expandedSections = {
          for (var category in transactionsByCategory.keys) category: false
        };
      });
    }).catchError((error) {
      print("Error fetching transactions: $error");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch transactions')));
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(2015, 8),
        lastDate: DateTime(2101));
    if (picked != null && picked != date) {
      setState(() {
        date = picked;
      });
    }
  }

  // Method to add a transaction to Firestore and update the local transactions list
  void _addTransaction(double amount, String? type, String? category, DateTime date) {
    if (docID.isEmpty) {
      print("Warning: docID is empty, cannot add transaction");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add transaction: User not found')));
      return;
    }

    if (!amount.isNaN) {
      _firestore
          .collection('users')
          .doc(docID)
          .collection('Transactions')
          .add({
        'amount': amount,
        'type': type ?? 'Unknown',
        'category': category ?? 'Uncategorized',
        'date': date
      }).then((value) {
        setState(() {
          var transaction = {
            'transactionId': value.id,
            'amount': amount,
            'type': type ?? 'Unknown',
            'category': category ?? 'Uncategorized',
            'date': date
          };
          
          // Add to transactionsByCategory
          String categoryKey = category ?? 'Uncategorized';
          if (!transactionsByCategory.containsKey(categoryKey)) {
            transactionsByCategory[categoryKey] = [];
          }
          transactionsByCategory[categoryKey]!.add(transaction);
          
          // Update total balance
          if (type == 'Income') {
            _totalBalance += amount;
          } else {
            _totalBalance -= amount;
          }
        });
      }).catchError((error) {
        print("Error adding transaction: $error");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add transaction')));
      });
    }
  }

// Method to remove a transaction from Firestore and update the local transactions list
  void _removeTransaction(String transactionId) {
    if (docID.isEmpty) {
      print("Warning: docID is empty, cannot remove transaction");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove transaction: User not found')));
      return;
    }

    _firestore
        .collection('users')
        .doc(docID)
        .collection('Transactions')
        .doc(transactionId)
        .delete()
        .then((_) {
      setState(() {
        // Find the transaction before removing it to update the balance
        Map<String, dynamic>? removedTransaction;
        transactionsByCategory.forEach((category, transactions) {
          transactions.removeWhere((transaction) {
            if (transaction is Map<String, dynamic>) {
              String? id = transaction['transactionId'] as String?;
              if (id == transactionId) {
                removedTransaction = transaction;
                return true;
              }
            }
            return false;
          });
          if (transactions.isEmpty) {
            transactionsByCategory.remove(category);
          }
        });

        // Update total balance
        if (removedTransaction != null) {
          final type = removedTransaction?['type'] as String?;
          final amount = removedTransaction?['amount'] as double? ?? 0.0;
          if (type == 'Income') {
            _totalBalance -= amount;
          } else {
            _totalBalance += amount;
          }
        }
      });
    }).catchError((error) {
      print("Error deleting transaction: $error");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete transaction')));
    });
  }

  void _promptAddTransaction() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('New Transaction'),
              content: Container(
                height: 230,
                width: 250,
                child: Column(
                  children: [
                    SizedBox(
                      child: Center(
                        child: ToggleButtons(
                          selectedBorderColor: colors[0],
                          borderRadius: BorderRadius.circular(5),
                          fillColor: colors[0],
                          isSelected: [type1 == 'Expense', type1 == 'Income'],
                          onPressed: (int index) {
                            setState(() {
                              type1 = index == 0 ? 'Expense' : 'Income';
                            });
                          },
                          children: <Widget>[
                            Container(
                              width: 110,
                              child: Center(child: Text('Expense', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500))),
                            ),
                            Container(
                              width: 110,
                              child: Center(child: Text('Income', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500))),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 200,
                      child: TextField(
                        autofocus: true,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'Enter the amount'),
                        onChanged: (String? val) {
                          if (val != null && val.isNotEmpty) {
                            try {
                              amt = double.parse(val);
                            } catch (e) {
                              amt = 0;
                            }
                          } else {
                            amt = 0;
                          }
                        },
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      width: 200,
                      child: TextField(
                        decoration: InputDecoration(labelText: 'Enter the category'),
                        onChanged: (String? val) {
                          categ = val;
                        },
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: <Widget>[
                          const SizedBox(height: 30.0),
                          ElevatedButton(
                            onPressed: () async {
                              await _selectDate(context);
                              setState(() {});
                            },
                            child: Text("${date.toLocal()}".split(' ')[0]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      child: Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    TextButton(
                      child: Text('Enter'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _addTransaction(amt, type1, categ, date);
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> sharePdfLink() async {
    // Show dialog to select the name type
    String selectedName = 'General'; // Default value
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select PDF Type'),
          content: DropdownButton<String>(
            value: selectedName,
            items: ['General', 'Weekly', 'Monthly'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                selectedName = newValue;
                Navigator.pop(context); // Close dialog when a selection is made
              }
            },
          ),
        );
      },
    );

    // Generate the PDF with the selected name
    var paragraphPdf;
    if (selectedName == 'General') {
      paragraphPdf = await ParagraphPdfApi.generateParagraphPdf(docID);
    } else if (selectedName == 'Weekly') {
      paragraphPdf = await ParagraphPdfApi.generateWeeklyPdf(docID);
    } else if (selectedName == 'Monthly') {
      paragraphPdf = await ParagraphPdfApi.generateMonthlyPdf(docID);
    }
    final pdfFileName = selectedName + 'Report.pdf';
    final downloadUrl = await SaveAndOpenDocument.uploadPdfAndGetLink(
        paragraphPdf, pdfFileName);

    if (downloadUrl != null) {
      SaveAndOpenDocument.copyToClipboard(downloadUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF link copied to clipboard!')),
      );
      print('Download URL: $downloadUrl');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload PDF')),
      );
    }
  }

  void _updateTransaction(String transactionId, double amount, String type, String category, DateTime date) {
    if (docID.isEmpty) {
      print("Warning: docID is empty, cannot update transaction");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update transaction: User not found')));
      return;
    }

    _firestore.collection('users').doc(docID).collection('Transactions').doc(transactionId).update({
      'amount': amount,
      'type': type,
      'category': category,
      'date': date
    }).then((value) {
      setState(() {
        // Find and update the transaction in transactionsByCategory
        String oldCategory = '';
        Map<String, dynamic>? oldTransaction;
        Map<String, dynamic> updatedTransaction = {
          'transactionId': transactionId,
          'amount': amount,
          'type': type,
          'category': category,
          'date': date
        };
        
        transactionsByCategory.forEach((cat, transactions) {
          for (var i = 0; i < transactions.length; i++) {
            Map<String, dynamic>? trans = transactions[i] as Map<String, dynamic>?;
            if (trans != null) {
              String? id = trans['transactionId'] as String?;
              if (id == transactionId) {
                oldCategory = cat;
                oldTransaction = trans;
                transactions[i] = updatedTransaction;
                break;
              }
            }
          }
        });

        // Update total balance based on old and new values
        if (oldTransaction != null) {
          final oldType = oldTransaction?['type'] as String?;
          final oldAmount = oldTransaction?['amount'] as double? ?? 0.0;
          if (oldType == 'Income') {
            _totalBalance -= oldAmount;
          } else {
            _totalBalance += oldAmount;
          }
        }

        if (type == 'Income') {
          _totalBalance += amount;
        } else {
          _totalBalance -= amount;
        }

        // If category changed, move transaction to new category
        if (oldCategory != category) {
          // Remove from old category
          transactionsByCategory[oldCategory]?.removeWhere((t) {
            if (t is Map<String, dynamic>) {
              String? id = t['transactionId'] as String?;
              return id == transactionId;
            }
            return false;
          });
          if (transactionsByCategory[oldCategory]?.isEmpty ?? false) {
            transactionsByCategory.remove(oldCategory);
          }

          // Add to new category
          if (!transactionsByCategory.containsKey(category)) {
            transactionsByCategory[category] = [];
          }
          transactionsByCategory[category]!.add(updatedTransaction);
        }
      });
    }).catchError((error) {
      print("Failed to update transaction: $error");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update transaction')));
    });
  }

  void _promptEditTransaction(Map<String, dynamic> transaction, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String updatedCategory = transaction['category'] ?? 'Uncategorized';
        double updatedAmount = transaction['amount'] ?? 0.0;
        String updatedType = transaction['type'] ?? 'Unknown';
        DateTime updatedDate = transaction['date'] ?? DateTime.now();

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit Transaction'),
              content: Container(
                height: 230,
                width: 250,
                child: Column(
                  children: [
                    SizedBox(
                      child: Center(
                        child: ToggleButtons(
                          selectedBorderColor: colors[0],
                          borderRadius: BorderRadius.circular(5),
                          fillColor: colors[0],
                          isSelected: [updatedType == 'Expense', updatedType == 'Income'],
                          onPressed: (int index) {
                            setState(() {
                              updatedType = index == 0 ? 'Expense' : 'Income';
                            });
                          },
                          children: <Widget>[
                            Container(
                              width: 110,
                              child: Center(child: Text('Expense', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500))),
                            ),
                            Container(
                              width: 110,
                              child: Center(child: Text('Income', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500))),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 200,
                      child: TextField(
                        autofocus: true,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'Enter the amount'),
                        controller: TextEditingController(text: updatedAmount.toString()),
                        onChanged: (String? val) {
                          if (val != null && val.isNotEmpty) {
                            try {
                              updatedAmount = double.parse(val);
                            } catch (e) {
                              updatedAmount = 0;
                            }
                          } else {
                            updatedAmount = 0;
                          }
                        },
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      width: 200,
                      child: TextField(
                        decoration: InputDecoration(labelText: 'Enter the category'),
                        controller: TextEditingController(text: updatedCategory),
                        onChanged: (String? val) {
                          if (val != null) {
                            updatedCategory = val;
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: <Widget>[
                          const SizedBox(height: 30.0),
                          ElevatedButton(
                            onPressed: () async {
                              final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: updatedDate,
                                  firstDate: DateTime(2015, 8),
                                  lastDate: DateTime(2101));
                              if (picked != null && picked != updatedDate) {
                                setState(() {
                                  updatedDate = picked;
                                });
                              }
                            },
                            child: Text("${updatedDate.toLocal()}".split(' ')[0]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      child: Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    TextButton(
                      child: Text('Update'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _updateTransaction(transaction['transactionId'], updatedAmount, updatedType, updatedCategory, updatedDate);
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCategorySection(String category) {
    final transactions = transactionsByCategory[category] ?? [];
    final isExpanded = expandedSections[category] ?? false;
    
    return Card(
      color: colors[0],
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Column(
        children: [
          ListTile(
            title: Text(category,
                style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.bold)),
            trailing: Icon(isExpanded
                ? Icons.expand_less
                : Icons.expand_more),
            onTap: () {
              setState(() {
                expandedSections[category] = !(expandedSections[category] ?? false);
              });
            },
          ),
          if (isExpanded)
            Column(
              children: transactions
                  .map((transaction) => _buildTransactionItem(transaction, transactions.indexOf(transaction)))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction, int index) {
    return Dismissible(
      key: Key(transaction['transactionId']),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _removeTransaction(transaction['transactionId']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Transaction deleted. Add a NEW Transaction!',
            ),
          ),
        );
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        title: Text(
          "Type: ${transaction['type'] ?? 'Unknown'} - Date: ${DateFormat('yyyy-MM-dd').format(transaction['date'] ?? DateTime.now())}",
          style: GoogleFonts.ibmPlexSans(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2)
                  .format(transaction['amount'] ?? 0.0),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: (transaction['type'] ?? 'Unknown') == 'Expense' ? Colors.red : Colors.green,
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit, color: Colors.black, size: 30),
              onPressed: () {
                _promptEditTransaction(transaction, index);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Transactions',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        leading: IconButton(
    icon: Icon(Icons.arrow_back, color: Colors.white), // Set the color to white
    onPressed: () {
      Navigator.pop(context); // Pop to the previous screen
    },
        ),
        actions: [
    IconButton(
      icon: Icon(Icons.swap_horiz, color: Colors.white), // Swap icon
      onPressed: () {
        Navigator.pop(context);
      },
    ),
  ],
      ),
      body: StreamBuilder<List<Color>>(
            stream: docID.isNotEmpty
                ? GradientService(userId: docID).getGradientStream()
                : Stream.value([Color(0xffB8E8FF), Colors.blue.shade900]),
            builder: (context, snapshot) {
              colors = snapshot.data ??
                  [Color(0xffB8E8FF), Colors.blue.shade900];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 20,
                  ),
                  Container(
                    padding: EdgeInsets.all(15),
                    child: Text(
                      'Total Balance: ${NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2).format(_totalBalance)}',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color:
                              _totalBalance >= 0 ? Colors.green : Colors.red),
                    ),
                  ),
                  SizedBox(height: 15),
                  Expanded(
      child: SingleChildScrollView(
        child: Column(
          children: transactionsByCategory.keys
              .map((category) => _buildCategorySection(category))
              .toList(),
        ),
      ),
    ),
                ],
              ),
            );
          }),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        padding: EdgeInsets.symmetric(vertical: 0, horizontal: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            FloatingActionButton(
              heroTag: "split_share_btn",
              backgroundColor: colors[0],
              onPressed: sharePdfLink,
              child: Icon(
                Icons.share,
                color: Colors.black,
              ),
            ),
            FloatingActionButton(
              heroTag: "split_add_btn",
              backgroundColor: colors[0],
              onPressed: _promptAddTransaction,
              child: Icon(Icons.add, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
