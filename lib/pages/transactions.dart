// ignore_for_file: invalid_return_type_for_catch_error, avoid_print
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:fbla_finance/backend/auth.dart';
import 'package:fbla_finance/backend/paragraph_pdf_api.dart';
import 'package:fbla_finance/backend/save_and_open_pdf.dart';
import 'package:fbla_finance/pages/plaid_page.dart';
import 'package:fbla_finance/pages/split_transactions.dart';
import 'package:fbla_finance/pages/receipt_scanner_page.dart';
import 'package:fbla_finance/util/gradient_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

class Transactions extends StatefulWidget {
  Transactions({Key? key}) : super(key: key);

  @override
  _TransactionState createState() => _TransactionState();
}

class _TransactionState extends State<Transactions> {
  final User? user = Auth().currentUser;
  String docID = "";
  List<Color> colors = [Color(0xffB8E8FF), Colors.blue.shade900];
  final List<Map<String, dynamic>> _transactionsList = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  double _totalBalance = 0.0;
  DateTime date = DateTime.now();
  double amt = 0;
  String? type1;
  String? categ;
  final SearchController _searchController = SearchController();
  List<Map<String, dynamic>> _filteredTransactions = [];
  String? _linkToken;
  LinkTokenConfiguration? _configuration;
  List<Map<String, dynamic>> _plaidTransactions = [];
  bool _isDuplicateTransaction(Map<String, dynamic> txn) {
    return _transactionsList.any((existing) =>
        existing['amount'] == txn['amount'] &&
        existing['category'] == txn['name'] &&
        DateFormat('yyyy-MM-dd').format(existing['date']) ==
            DateFormat('yyyy-MM-dd').format(txn['date']));
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
    _searchController.addListener(_filterTransactions);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterTransactions() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTransactions = _transactionsList.where((transaction) {
        return transaction['category']
                .toString()
                .toLowerCase()
                .contains(query) ||
            transaction['type'].toString().toLowerCase().contains(query) ||
            transaction['amount'].toString().contains(query);
      }).toList();
    });
  }

  void _showPlaidTransactionPicker() {
    final Set<int> selectedIndexes = {};

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text('Select Transactions to Import'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: _plaidTransactions.length,
                itemBuilder: (context, index) {
                  final txn = _plaidTransactions[index];
                  final selected = selectedIndexes.contains(index);
                  return ListTile(
                    tileColor: selected ? Colors.blue[50] : null,
                    title: Text(txn['name']),
                    subtitle: Text(
                        "Amount: \$${txn['amount']} | Date: ${DateFormat('yyyy-MM-dd').format(txn['date'])}"),
                    trailing: Checkbox(
                      value: selected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            selectedIndexes.add(index);
                          } else {
                            selectedIndexes.remove(index);
                          }
                        });
                      },
                    ),
                    onTap: () {
                      setState(() {
                        if (selected) {
                          selectedIndexes.remove(index);
                        } else {
                          selectedIndexes.add(index);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: Text('Import Selected'),
                onPressed: () {
                  final selectedTxns = selectedIndexes
                      .map((i) => _plaidTransactions[i])
                      .toList();

                  for (var txn in selectedTxns) {
                    if (!_isDuplicateTransaction(txn)) {
                      _addTransaction(
                        (txn['amount'] as num).toDouble(),
                        'Expense',
                        txn['name'],
                        txn['date'],
                      );
                    } else {
                      print(
                          "🔁 Skipping duplicate: ${txn['name']} on ${txn['date']}");
                    }
                  }

                  Navigator.pop(context);
                },
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> fetchTransactions(String accessToken) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('getTransactions');
      final result = await callable.call({'access_token': accessToken});

      final transactions = result.data as List<dynamic>;
      _plaidTransactions.clear();

      for (var txn in transactions) {
        final rawAmount = txn['amount'].abs();

        _plaidTransactions.add({
          'amount': rawAmount is int
              ? rawAmount.toDouble()
              : rawAmount as double, // or (rawAmount as num).toDouble()
          'name': txn['name'] ?? 'Unnamed',
          'date': DateTime.tryParse(txn['date']) ?? DateTime.now(),
        });
      }

      _showPlaidTransactionPicker();
    } catch (e) {
      print('Failed to fetch transactions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load Plaid transactions")));
    }
  }

  Future<void> _launchPlaidFlow() async {
    // Show a loading dialog while getting link token
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );
    print("Current Firebase UID: ${FirebaseAuth.instance.currentUser?.uid}");
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('createLinkToken');
      final result = await callable.call();
      Navigator.pop(context); // close loading dialog

      _linkToken = result.data;
      if (_linkToken == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("No link token received")));
        return;
      }

      _configuration = LinkTokenConfiguration(token: _linkToken!);
      PlaidLink.create(configuration: _configuration!);

      // Listen to success
      PlaidLink.onSuccess.listen((LinkSuccess success) async {
        final publicToken = success.publicToken;
        print("✅ Public token: $publicToken");

        try {
          final callable =
              FirebaseFunctions.instance.httpsCallable('exchangePublicToken');
          final response = await callable.call({
            'public_token': publicToken,
            'uid': docID,
          });
          final accessToken = response.data;

          print("✅ Access token stored: $accessToken");

          // Optionally call fetchTransactions(accessToken);
          await fetchTransactions(accessToken);

          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Bank linked successfully!")));
        } catch (e) {
          print("❌ Error exchanging token: $e");
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Failed to link bank")));
        }
      });

      PlaidLink.open();
    } catch (e) {
      Navigator.pop(context); // close dialog
      print("❌ Error fetching link token: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Plaid init failed")));
    }
  }

  Future<void> _initializeData() async {
    await fetchDocID(); // Wait for fetchDocID to complete
    _fetchTransactions(); // Call _fetchTransactions after fetchDocID
  }

  Future<void> fetchDocID() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        setState(() {
          docID = doc.id;
        });

        final accessToken = doc.data()['plaidAccessToken'];
        if (accessToken != null) {
          print("✅ Found saved access token.");
          //await fetchTransactions(accessToken); // Auto-fetch transactions
        } else {
          print("ℹ️ No access token on file. Will need to launch Plaid.");
        }
      }
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
        _transactionsList.clear();
        _totalBalance = 0.0;
        querySnapshot.docs.forEach((doc) {
          var transaction = {
            'transactionId': doc.id,
            'amount': doc['amount'] ?? 0.0,
            'type': doc['type'] ?? 'Unknown',
            'category': doc['category'] ?? 'Uncategorized',
            'date': (doc['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
          };
          _transactionsList.add(transaction);
          if (transaction['type'] == 'Income') {
            _totalBalance += transaction['amount'];
          } else {
            _totalBalance -= transaction['amount'];
          }
        });
        _filterTransactions(); // Apply initial filter
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
    // Check if the amount is a valid number
    if (!amount.isNaN) {
      // Add transaction data to Firestore under the user's transactions collection
      _firestore.collection('users').doc(docID).collection('Transactions').add({
        'amount': amount,
        'type': type ?? 'Unknown',
        'category': category ?? 'Uncategorized',
        'date': date
      }).then((value) {
        // Once the transaction is successfully added to Firestore
        setState(() {
          // Add the transaction to the local transactions list with its generated ID
          _transactionsList.add({
            'transactionId': value.id,
            'amount': amount,
            'type': type ?? 'Unknown',
            'category': category ?? 'Uncategorized',
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
    _firestore
        .collection('users')
        .doc(docID)
        .collection('Transactions')
        .doc(transactionId)
        .delete()
        .then((value) {
      setState(() {
        // Remove the transaction from the local transactions list
        _transactionsList.removeAt(index);

        // Update the total balance based on transaction type
        if (transaction['type'] == 'Income') {
          _totalBalance -=
              transaction['amount']; // Deduct from balance if it was income
        } else {
          _totalBalance +=
              transaction['amount']; // Add back if it was an expense
        }
      });
    }).catchError((error) =>
            print("Failed to delete transaction: $error")); // Handle any errors
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
                height: 250,
                width: 230,
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
                              width: 110, // Adjust width as needed
                              child: Center(
                                  child: Text('Expense',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500))),
                            ),
                            Container(
                              width: 110, // Adjust width as needed
                              child: Center(
                                  child: Text('Income',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500))),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 200,
                      child: TextField(
                        autofocus: true,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        decoration:
                            InputDecoration(labelText: 'Enter the amount'),
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
                        decoration:
                            InputDecoration(labelText: 'Enter the category'),
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
    String? selectedName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select PDF Type'),
          content: DropdownButton<String>(
            value: 'General',
            items: ['General', 'Weekly', 'Monthly'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                Navigator.pop(context, newValue);
              }
            },
          ),
        );
      },
    );

    if (selectedName == null) {
      selectedName = 'General'; // Default value if dialog is dismissed
    }

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
                height: 250,
                width: 250,
                child: Column(
                  children: [
                    SizedBox(
                      child: Center(
                        child: ToggleButtons(
                          selectedBorderColor: colors[0],
                          borderRadius: BorderRadius.circular(5),
                          fillColor: colors[0],
                          isSelected: [
                            updatedType == 'Expense',
                            updatedType == 'Income'
                          ],
                          onPressed: (int index) {
                            setState(() {
                              updatedType = index == 0 ? 'Expense' : 'Income';
                            });
                          },
                          children: <Widget>[
                            Container(
                              width: 110, // Adjust width as needed
                              child: Center(
                                  child: Text('Expense',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500))),
                            ),
                            Container(
                              width: 110, // Adjust width as needed
                              child: Center(
                                  child: Text('Income',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500))),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 200,
                      child: TextField(
                        autofocus: true,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        decoration:
                            InputDecoration(labelText: 'Enter the amount'),
                        controller: TextEditingController(
                            text: updatedAmount.toString()),
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
                        decoration:
                            InputDecoration(labelText: 'Enter the category'),
                        controller:
                            TextEditingController(text: updatedCategory),
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
                            child:
                                Text("${updatedDate.toLocal()}".split(' ')[0]),
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
                        _updateTransaction(
                            transaction['transactionId'],
                            updatedAmount,
                            updatedType,
                            updatedCategory,
                            updatedDate,
                            index);
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

  // Update a transaction in Firestore
  void _updateTransaction(String transactionId, double amount, String type,
      String category, DateTime date, int index) {
    _firestore
        .collection('users')
        .doc(docID)
        .collection('Transactions')
        .doc(transactionId)
        .update({
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update transaction')));
    });
  }

  Widget _buildTransactionList() {
    final transactionsToShow = _searchController.text.isEmpty
        ? _transactionsList
        : _filteredTransactions;
    return ListView.builder(
      itemCount: transactionsToShow.length,
      itemBuilder: (context, index) {
        return _buildTransactionItem(transactionsToShow[index], index);
      },
    );
  }

  void _scanReceipt() async {
  final source = await showDialog<ImageSource>(
    context: context,
    builder: (context) => AlertDialog(
      alignment: Alignment.center,
      title: Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: Text('Take Photo'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: Text('Choose from Gallery'),
            ),
          ],
        ),
    ),
  );

  if (source == null) return;

  final picked = await ImagePicker().pickImage(source: source);
  if (picked == null) return;

  final file = File(picked.path);
  final inputImage = InputImage.fromFile(file);
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final recognizedText = await textRecognizer.processImage(inputImage);
  await textRecognizer.close();

  if (recognizedText.blocks.isNotEmpty) {
    List<TextLine> allLines = recognizedText.blocks.expand((b) => b.lines).toList();
    allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    String? foundMerchant;
    String? foundTotal;
    DateTime foundDate = DateTime.now();

    final keywordTotalRegex = RegExp(r'(total|amount due|subtotal)[^\d]*([\$€₺]?\s*\d+[.,]?\d*)', caseSensitive: false);
    final looseMoneyRegex = RegExp(r'[\$€₺]?\s*\d{1,5}[.,]\d{2}');
    final dateRegex = RegExp(
      r'\b\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}\b'
      r'|\b\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}\b'
      r'|\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},\s+\d{4}\b',
      caseSensitive: false,
    );
    final merchantRegex = RegExp(r'[A-Za-z]{2,}');

    for (int i = 0; i < allLines.length; i++) {
      final line = allLines[i].text.trim();

      if (foundMerchant == null && i < 6 && merchantRegex.hasMatch(line) && !RegExp(r'^\d+$').hasMatch(line)) {
        foundMerchant = line;
      }

      if (foundTotal == null && keywordTotalRegex.hasMatch(line)) {
        foundTotal = keywordTotalRegex.firstMatch(line)?.group(2)?.trim();
      }

      if (dateRegex.hasMatch(line)) {
  final rawDate = dateRegex.firstMatch(line)?.group(0)?.trim();
  try {
    if (rawDate != null) {
      // Try month name style
      if (RegExp(r'[A-Za-z]', caseSensitive: false).hasMatch(rawDate)) {
        foundDate = DateFormat('MMMM d, yyyy').parseStrict(rawDate);
      } else {
        // Try numeric formats
        foundDate = DateFormat.yMd().parseStrict(rawDate);
      }
    }
  } catch (e) {
    print("Date parse failed for: $rawDate");
    foundDate = DateTime.now();
  }
}

      print(foundDate);
    }

    if (foundTotal == null) {
      double maxValue = 0.0;
      for (var line in allLines) {
        final matches = looseMoneyRegex.allMatches(line.text);
        for (final match in matches) {
          final raw = match.group(0)?.replaceAll(RegExp(r'[^\d.,]'), '') ?? '';
          final cleaned = raw.replaceAll(',', '.');
          final value = double.tryParse(cleaned);
          if (value != null && value > maxValue) {
            maxValue = value;
            foundTotal = match.group(0)?.trim();
          }
        }
      }
    }

    final scannedAmount = double.tryParse(foundTotal?.replaceAll(RegExp(r'[^\d.]'), '') ?? '');
    final scannedCategory = foundMerchant ?? 'Scanned';

    setState(() {
      amt = scannedAmount ?? 0;
      date = foundDate;
      categ = scannedCategory;
      type1 = 'Expense';
    });

    _addTransaction(amt, type1, categ, date);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not read receipt')));
  }
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
        color: colors[0],
        elevation: 4,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: ListTile(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction['category'],
                style: GoogleFonts.ibmPlexSans(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                "Type: ${transaction['type']} - Date: ${DateFormat('yyyy-MM-dd').format(transaction['date'])}",
                style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    color: Colors.black,
                    fontWeight: FontWeight.w500),
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
                  color: transaction['type'] == 'Expense'
                      ? Colors.red
                      : Colors.green,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.edit,
                  color: Colors.black,
                  size: 30,
                ),
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

  void _showAddOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Transaction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                  child: ListTile(
                leading: Icon(Icons.add_circle_outline),
                title: Text('Manual Entry'),
                onTap: () {
                  Navigator.pop(context);
                  _promptAddTransaction();
                },
              )),
              Card(
                child: ListTile(
                  leading: Icon(Icons.camera_alt),
                  title: Text('Scan Receipt'),
                onTap: () {
                  Navigator.pop(context);
                  _scanReceipt();
                },
              ),
              ),
              Card(
                child: ListTile(
                  leading: Icon(Icons.attach_money),
                  title: Text('Get From Bank'),
                  onTap: () async {
                    Navigator.pop(context);
                    // Fetch latest user data in case access token was saved previously
                    final doc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(docID)
                        .get();
                    final accessToken = doc.data()?['plaidAccessToken'];

                    if (accessToken != null) {
                      print("🔁 Already linked. Fetching transactions...");
                      await fetchTransactions(accessToken);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text("Fetched transactions from saved account")));
                    } else {
                      print("➡️ Launching Plaid...");
                      await _launchPlaidFlow();
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
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
        actions: [
          IconButton(
            icon: Icon(Icons.swap_horiz, color: Colors.white),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SplitTransactions(),
                ),
              );
              _initializeData();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Color>>(
          stream: docID.isNotEmpty
              ? GradientService(userId: docID).getGradientStream()
              : Stream.value([Color(0xffB8E8FF), Colors.blue.shade900]),
          builder: (context, snapshot) {
            colors = snapshot.data ?? [Color(0xffB8E8FF), Colors.blue.shade900];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                children: [
                  SearchBar(
                    controller: _searchController,
                    hintText: 'Search transactions...',
                    leading: const Icon(Icons.search),
                    padding: const MaterialStatePropertyAll<EdgeInsets>(
                      EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    ),
                  ),
                  SizedBox(height: 20),
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
                  Expanded(child: _buildTransactionList()),
                  SizedBox(
                    height: 75,
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
              onPressed: _showAddOptions,
              child: Icon(Icons.add, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
