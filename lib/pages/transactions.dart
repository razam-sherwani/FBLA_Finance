import 'package:fbla_finance/backend/auth.dart';
import 'package:fbla_finance/backend/paragraph_pdf_api.dart';
import 'package:fbla_finance/backend/save_and_open_pdf.dart';
import 'package:fbla_finance/util/gradient_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
        _transactionsList.clear();
        _totalBalance = 0.0;
        querySnapshot.docs.forEach((doc) {
          var transaction = {
            'transactionId': doc.id,
            'amount': doc['amount'],
            'type': doc['type'],
            'category': doc['category'],
            'date': (doc['date'] as Timestamp).toDate(),
          };
          _transactionsList.add(transaction);
          if (transaction['type'] == 'Income') {
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
      color: Colors.grey[300],
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              transaction['category'],
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              "Type: ${transaction['type']} - Date: ${DateFormat('yyyy-MM-dd').format(transaction['date'])}",
              style: TextStyle(fontSize: 12, color: Colors.black),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2)
                  .format(transaction['amount']),
              style: TextStyle(
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
      ),
      body: StreamBuilder<LinearGradient>(
        stream:  docID.isNotEmpty
              ? GradientService(userId: docID).getGradientStream() : Stream.value(LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Colors.white],
                )),
        builder: (context, snapshot) {
          final gradient = snapshot.data ??
              LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Colors.white,
                ],
              );
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
                SizedBox(height: 15),
                Expanded(child: _buildTransactionList()),
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
          backgroundColor: Colors.grey[300],
          onPressed: sharePdfLink,
          child: Icon(Icons.share, color: Colors.black,),
        ),
        FloatingActionButton(
          backgroundColor: Colors.grey[300],
          onPressed: _promptAddTransaction,
          child: Icon(Icons.add, color: Colors.black), 
        ),
      ],
    ),
  ),
      
    );
  }
}