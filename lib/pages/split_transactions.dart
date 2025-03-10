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

  Future<void> _initializeData() async {
    await fetchDocID(); // Wait for fetchDocID to complete
    _fetchTransactions(); // Call _fetchTransactions after fetchDocID
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
    _firestore
        .collection('users')
        .doc(docID)
        .collection('Transactions')
        .get()
        .then((querySnapshot) {
      setState(() {
        transactionsByCategory.clear();
        _totalBalance = 0.0;

        for (var doc in querySnapshot.docs) {
          var transaction = {
            'transactionId': doc.id,
            'amount': doc['amount'],
            'type': doc['type'],
            'category': doc['category'],
            'date': (doc['date'] as Timestamp).toDate(),
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
  void _addTransaction(
      double amount, String? type, String? category, DateTime date) {
    Map<String, dynamic> transaction = {
      'amount': amount,
      'type': type,
      'category': category,
      'date': date
    };
    _firestore
        .collection('users')
        .doc(docID)
        .collection('Transactions')
        .add(transaction)
        .then((docRef) {
      setState(() {
        transaction['transactionId'] = docRef.id;
        if (!transactionsByCategory.containsKey(category)) {
          transactionsByCategory[category!] = [];
        }
        transactionsByCategory[category]!.add(transaction);
        if (transaction['type'] == 'Income') {
          _totalBalance += transaction['amount'];
        } else {
          _totalBalance -= transaction['amount'];
        }
      });
    }).catchError((error) {
      print("Error adding transaction: $error");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to add transaction')));
    });
  }

// Method to remove a transaction from Firestore and update the local transactions list
  void _removeTransaction(Map<String, dynamic> transaction) {
    _firestore
        .collection('users')
        .doc(docID)
        .collection('Transactions')
        .doc(transaction['transactionId'])
        .delete()
        .then((_) {
      setState(() {
        transactionsByCategory[transaction['category']]?.remove(transaction);
        if (transactionsByCategory[transaction['category']]?.isEmpty ?? false) {
          transactionsByCategory.remove(transaction['category']);
        }
        if (transaction['type'] == 'Income') {
          _totalBalance -= transaction['amount'];
        } else {
          _totalBalance += transaction['amount'];
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
                    TextField(
                      autofocus: true,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          InputDecoration(labelText: 'Enter the amount'),
                      onChanged: (String? val) {
                        amt = double.parse(val!);
                      },
                    ),
                    Container(
                      width: 200,
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: type1,
                        hint: Text('Select type'),
                        items:
                            <String>['Expense', 'Income'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            type1 = newValue!;
                          });
                        },
                      ),
                    ),
                    Container(
                      width: 200,
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: categ,
                        hint: Text('Select category'),
                        menuMaxHeight: 200,
                        items: (type1 == 'Income'
                                ? <String>['Work', 'Stocks', 'Other']
                                : <String>[
                                    'Food',
                                    'Entertainment',
                                    'Utilities',
                                    'Other'
                                  ])
                            .map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newCateg) {
                          setState(() {
                            categ = newCateg!;
                          });
                        },
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      children: <Widget>[
                        const SizedBox(height: 20.0),
                        ElevatedButton(
                          onPressed: () async {
                            await _selectDate(context);
                            setState(() {});
                          },
                          child: Text("${date.toLocal()}".split(' ')[0]),
                        ),
                      ],
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

  void _promptEditTransaction(Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String updatedCategory = transaction['category'];
        double updatedAmount = transaction['amount'];
        String updatedType = transaction['type'];
        DateTime updatedDate = transaction['date'];

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit Transaction'),
              content: Container(
                height: 230,
                width: 250,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Enter the amount'),
                      controller: TextEditingController(text: updatedAmount.toString()),
                      onChanged: (String? val) {
                        updatedAmount = double.parse(val!);
                      },
                    ),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: updatedType,
                      hint: Text('Select type'),
                      items: <String>['Expense', 'Income'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          updatedType = newValue!;
                        });
                      },
                    ),
                    Container(
                      width: 200,
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: categ,
                        hint: Text('Select category'),
                        menuMaxHeight: 200,
                        items: <String>['Work', 'Food', 'Entertainment','Other'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (updatedCateg) {
                          setState(() {
                            updatedCategory = updatedCateg!;
                          });
                        },
                      ),
                    ),
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
              actions: <Widget>[
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
            );
          },
        );
      },
    );
  }

  void _updateTransaction(String transactionId, double amount, String type, String category, DateTime date) {
  _firestore.collection('users').doc(docID).collection('Transactions').doc(transactionId).update({
    'amount': amount,
    'type': type,
    'category': category,
    'date': date
  }).then((_) {
    _fetchTransactions();  // Refresh all transactions after updating
  }).catchError((error) {
    print("Failed to update transaction: $error");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update transaction')));
  });
}


  Widget _buildCategorySection(String category) {
    return Card(
      color: colors[0],
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Column(
        children: [
          ListTile(
            title: Text(category,
                style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.bold)),
            trailing: Icon(expandedSections[category]!
                ? Icons.expand_less
                : Icons.expand_more),
            onTap: () {
              setState(() {
                expandedSections[category] = !expandedSections[category]!;
              });
            },
          ),
          if (expandedSections[category]!)
            Column(
              children: transactionsByCategory[category]!
                  .map((transaction) => _buildTransactionItem(transaction))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        color: Colors.red,
        child: Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        setState(() {
          _removeTransaction(transaction);
        });
      },
      child: ListTile(
        title: Text(
          "Type: ${transaction['type']} - Date: ${DateFormat('yyyy-MM-dd').format(transaction['date'])}",
          style: GoogleFonts.ibmPlexSans(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w500),
        ),
        
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${transaction['amount'].toStringAsFixed(2)}',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: transaction['type'] == 'Income' ? Colors.green : Colors.red,
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit, color: Colors.black,size: 30,),
              onPressed: () {
                _promptEditTransaction(transaction);
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
              backgroundColor: colors[0],
              onPressed: sharePdfLink,
              child: Icon(
                Icons.share,
                color: Colors.black,
              ),
            ),
            FloatingActionButton(
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
