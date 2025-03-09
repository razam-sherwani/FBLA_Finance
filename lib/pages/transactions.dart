// ignore_for_file: invalid_return_type_for_catch_error, avoid_print

import 'package:fbla_finance/backend/auth.dart';
import 'package:fbla_finance/backend/paragraph_pdf_api.dart';
import 'package:fbla_finance/backend/save_and_open_pdf.dart';
import 'package:fbla_finance/pages/split_transactions.dart';
import 'package:fbla_finance/util/gradient_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class BudgetProgressRing extends StatefulWidget {
  final double currentBudget;
  final double maxBudget;

  const BudgetProgressRing({
    Key? key,
    required this.currentBudget,
    required this.maxBudget,
  }) : super(key: key);

  @override
  State<BudgetProgressRing> createState() => _BudgetProgressRingState();
}

class _BudgetProgressRingState extends State<BudgetProgressRing> {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(150, 150), // Adjusted size
      painter: RingPainter(
        currentBudget: widget.currentBudget,
        maxBudget: widget.maxBudget,
      ),
    );
  }
}

class RingPainter extends CustomPainter {
  final double currentBudget;
  final double maxBudget;

  RingPainter({required this.currentBudget, required this.maxBudget});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 10;
    final ringWidth = 20.0;

    // Background ring (grey)
    final backgroundPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = ringWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress ring (colored)
    final progressPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final progressAngle = (currentBudget / maxBudget) * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      progressAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class Transactions extends StatefulWidget {

  Transactions({Key? key}) : super(key: key);

  @override
  _TransactionState createState() => _TransactionState();
}

class _TransactionState extends State<Transactions> {
  final User? user = Auth().currentUser;
  String docID = "";
  final List<Map<String, dynamic>> _transactionsList = [];
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
  await fetchDocID();  // Wait for fetchDocID to complete
  _fetchTransactions();  // Call _fetchTransactions after fetchDocID
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
    _firestore.collection('users').doc(docID).collection('Transactions').get().then((querySnapshot) {
      setState(() {
        _transactionsList.clear(); //_transactionsList is a List of Maps that store Clearing it is important to remove leftovers.
        _totalBalance = 0.0;
        querySnapshot.docs.forEach((doc) { //fetches transactions from firebase.
          var transaction = {
            'transactionId': doc.id,
            'amount': doc['amount'],
            'type': doc['type'],
            'category': doc['category'],
            'date': (doc['date'] as Timestamp).toDate(),
          };
          _transactionsList.add(transaction);
          if (transaction['type'] == 'Income') { //Based on the type of transaction, balance is added or deducted from.
            _totalBalance += transaction['amount'];
          } else {
            _totalBalance -= transaction['amount'];
          }
        });
      });
    }).catchError((error) {
      print("Error fetching transactions: $error");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch transactions')));
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
    // Check if the amount is a valid number
    if (!amount.isNaN) {
      // Add transaction data to Firestore under the user's transactions collection
      _firestore
          .collection('users')
          .doc(docID)
          .collection('Transactions')
          .add({
        'amount': amount,
        'type': type,
        'category': category,
        'date': date
      }).then((value) { // Once the transaction is successfully added to Firestore
        setState(() {
          // Add the transaction to the local transactions list with its generated ID
          _transactionsList.add({
            'transactionId': value.id,
            'amount': amount,
            'type': type,
            'category': category,
            'date': date
          });

          // Update the total balance based on transaction type
          if (type == 'Income') {
            _totalBalance += amount; // Increase balance for income
          } else {
            _totalBalance -= amount; // Decrease balance for expenses
          }
        });
      });
    }
}

// Method to remove a transaction from Firestore and update the local transactions list
void _removeTransaction(String transactionId, int index) {
    // Retrieve the transaction data from the local list
    var transaction = _transactionsList[index];

    // Delete the transaction document from Firestore
    _firestore.collection('users').doc(docID).collection('Transactions').doc(transactionId).delete().then((value) {
      setState(() {
        // Remove the transaction from the local transactions list
        _transactionsList.removeAt(index);

        // Update the total balance based on transaction type
        if (transaction['type'] == 'Income') {
          _totalBalance -= transaction['amount']; // Deduct from balance if it was income
        } else {
          _totalBalance += transaction['amount']; // Add back if it was an expense
        }
      });
    }).catchError((error) => print("Failed to delete transaction: $error")); // Handle any errors
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
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Enter the amount'),
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
                        items: <String>['Expense', 'Income'].map((String value) {
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
                        items: (type1 == 'Income' ? <String>['Work', 'Stocks', 'Other'] : <String>['Food', 'Entertainment', 'Utilities', 'Other']).map((String value) {
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

  void _promptEditTransaction(Map<String, dynamic> transaction, int index) {
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
                    _updateTransaction(transaction['transactionId'], updatedAmount, updatedType, updatedCategory, updatedDate, index);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Update a transaction in Firestore
  void _updateTransaction(String transactionId, double amount, String type, String category, DateTime date, int index) {
    _firestore.collection('users').doc(docID).collection('Transactions').doc(transactionId).update({
      'amount': amount,
      'type': type,
      'category': category,
      'date': date
    }).then((value) {
      setState(() {
        _transactionsList[index] = {
          'transactionId': transactionId,
          'amount': amount,
          'type': type,
          'category': category,
          'date': date
        };
        // Recalculate total balance
        _totalBalance = 0.0;
        _transactionsList.forEach((transaction) {
          if (transaction['type'] == 'Income') {
            _totalBalance += transaction['amount'];
          } else {
            _totalBalance -= transaction['amount'];
          }
        });
      });
    }).catchError((error) {
      print("Failed to update transaction: $error");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update transaction')));
    });
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      itemCount: _transactionsList.length,
      itemBuilder: (context, index) {
        return _buildTransactionItem(_transactionsList[index], index);
      },
    );
  }

  //here
  Widget _buildTransactionItem(Map<String, dynamic> transaction, int index) {
  return Dismissible(
    key: Key(transaction['transactionId']),
    direction: DismissDirection.endToStart,
    onDismissed: (direction) {
      _removeTransaction(transaction['transactionId'], index);
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
    child: Card(
      color: Colors.blue[100],
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            transaction['category'],
            style: GoogleFonts.ibmPlexSans(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            "Type: ${transaction['type']} - Date: ${DateFormat('yyyy-MM-dd').format(transaction['date'])}",
            style: GoogleFonts.ibmPlexSans(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w500),
          ),
        ],
      ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
            NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2)
                .format(transaction['amount']),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: transaction['type'] == 'Expense' ? Colors.red : Colors.green,
            ),
          ),
            IconButton(
              icon: Icon(Icons.edit, color: Colors.black,size: 30,),
              onPressed: () {
                _promptEditTransaction(transaction, index);
              },
            ),
          ],
        ),
      ),
    ),
  );
  
}





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),),
        centerTitle: true,
        backgroundColor: Colors.black,
        actions: [
    IconButton(
      icon: Icon(Icons.swap_horiz, color: Colors.white), // Swap icon
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SplitTransactions(),
          ),
        );
      },
    ),
  ],
      ),
      body: StreamBuilder<List<Color>>(
            stream: docID.isNotEmpty
                ? GradientService(userId: docID).getGradientStream()
                : Stream.value([Color(0xffB8E8FF), Colors.blue.shade900]),
            builder: (context, snapshot) {
              final colors = snapshot.data ??
                  [Color(0xffB8E8FF), Colors.blue.shade900];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              children: [
                SizedBox(height: 20,),
                Container(
                  padding: EdgeInsets.all(15),
                  child: Text(
                    'Total Balance: ${NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2).format(_totalBalance)}',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _totalBalance >= 0 ? Colors.green : Colors.red),
                  ), 
                ),

                //MY UPDATES STUFF.
                Container(
                  width: 150, // Adjust size as needed
                  height: 150,
                  margin: EdgeInsets.only(top: 20, bottom: 20), // Adjust size as needed
                  child: Center(
                    child: BudgetProgressRing(
                      currentBudget: 600,
                      maxBudget: 1000, // Set your desired max budget
                    ),
                  ),
                ),

                //MY updates end
                SizedBox(height: 15),
                Expanded(child: _buildTransactionList()),
                SizedBox(height: 75,),
              ],
            ),
          );
        }
      ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
  floatingActionButton: Container(
    padding: EdgeInsets.symmetric(vertical: 0, horizontal: 10.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        FloatingActionButton(
          backgroundColor: Colors.blue[100],
          onPressed: sharePdfLink,
          child: Icon(Icons.share, color: Colors.black,),
        ),
        FloatingActionButton(
          backgroundColor: Colors.blue[100],
          onPressed: _promptAddTransaction,
          child: Icon(Icons.add, color: Colors.black), 
        ),
      ],
    ),
  ),
      
    );
  }
}