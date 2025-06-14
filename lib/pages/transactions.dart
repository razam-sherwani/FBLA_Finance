// ignore_for_file: invalid_return_type_for_catch_error, avoid_print
import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

import '../backend/paragraph_pdf_api.dart';
import '../backend/save_and_open_pdf.dart';
import '../util/gradient_service.dart';

class Transactions extends StatefulWidget {
  const Transactions({super.key});

  @override
  State<Transactions> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<Transactions> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String docID = '';
  List<Color> colors = [Color(0xffB8E8FF), Colors.white];

  final List<Map<String, dynamic>> _transactionsList = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  Map<String, List<Map<String, dynamic>>> _groupedTransactions = {};
  Map<String, bool> _expandedSections = {};
  double _totalBalance = 0.0;
  String _searchQuery = '';
  String? _linkToken;
  LinkTokenConfiguration? _configuration;
  List<Map<String, dynamic>> _plaidTransactions = [];
  DateTime date = DateTime.now();
  double amt = 0;
  String? type1;
  String? categ;

  String? _selectedType;
  String? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minAmount;
  double? _maxAmount;
  bool _groupByCategory = false;

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
  }

  Future<void> _initializeData() async {
    await fetchDocID();
    _fetchTransactions();
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
      }
    }
  }

  void _fetchTransactions() {
    _firestore
        .collection('users')
        .doc(docID)
        .collection('Transactions')
        .orderBy('date', descending: true)
        .get()
        .then((querySnapshot) {
      if (!mounted) return; // Prevent setState after dispose
      setState(() {
        _transactionsList.clear();
        _totalBalance = 0.0;
        for (var doc in querySnapshot.docs) {
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
        }
        _filterTransactions();
      });
    });
  }

  void _filterTransactions() {
    final filtered = _transactionsList.where((transaction) {
      final matchesSearch = transaction['category']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          transaction['type']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          transaction['amount'].toString().contains(_searchQuery);

      final matchesType =
          _selectedType == null || transaction['type'] == _selectedType;
      final matchesCategory = _selectedCategory == null ||
          (transaction['category'] as String?)
                  ?.toLowerCase()
                  .contains(_selectedCategory!.toLowerCase()) ==
              true;

      final matchesDate = _startDate == null ||
          (transaction['date'].isAfter(_startDate!) &&
              (_endDate == null ||
                  transaction['date']
                      .isBefore(_endDate!.add(Duration(days: 1)))));

      final amount = transaction['amount'] as double;
      final matchesAmount = (_minAmount == null || amount >= _minAmount!) &&
          (_maxAmount == null || amount <= _maxAmount!);

      return matchesSearch &&
          matchesType &&
          matchesCategory &&
          matchesDate &&
          matchesAmount;
    }).toList();

    filtered.sort((a, b) => b['date'].compareTo(a['date']));

    if (!mounted) return; // Prevent setState after dispose
    setState(() {
      _filteredTransactions = filtered;
      if (_groupByCategory) {
        _groupedTransactions = {};
        for (var transaction in _filteredTransactions) {
          String category = transaction['category'] ?? 'Uncategorized';
          if (!_groupedTransactions.containsKey(category)) {
            _groupedTransactions[category] = [];
            _expandedSections[category] = false; // Initialize expanded state
          }
          _groupedTransactions[category]!.add(transaction);
        }
      } else {
        _groupedTransactions = {}; // Clear grouped transactions if not grouping
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedType = null;
      _selectedCategory = null;
      _startDate = null;
      _endDate = null;
      _minAmount = null;
      _maxAmount = null;
      _searchQuery = ''; // Clear search query as well
    });
    _filterTransactions();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateInDialog) {
          return AlertDialog(
            title: Text("Filter Transactions"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    hint: Text("Select Type"),
                    items: ['Income', 'Expense']
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (val) =>
                        setStateInDialog(() => _selectedType = val),
                  ),
                  TextField(
                    decoration: InputDecoration(labelText: 'Category'),
                    onChanged: (val) =>
                        _selectedCategory = val.isEmpty ? null : val,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(labelText: 'Min Amount'),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => _minAmount = double.tryParse(val),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(labelText: 'Max Amount'),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => _maxAmount = double.tryParse(val),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  ListTile(
                    title: Text("Date Range"),
                    subtitle: Text(
                      _startDate == null && _endDate == null
                          ? "Select"
                          : "${_startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : ''} - ${_endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : ''}",
                    ),
                    trailing: Icon(Icons.calendar_today),
                    onTap: () async {
                      await _selectDateRange();
                      setStateInDialog(
                          () {}); // Update dialog after date selection
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  _clearFilters();
                  Navigator.pop(context);
                },
                child: Text("Clear Filters"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _filterTransactions();
                },
                child: Text("Apply"),
              )
            ],
          );
        });
      },
    );
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

  SpeedDial _buildAnimatedFAB() {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: colors[0],
      foregroundColor: Colors.black,
      overlayOpacity: 0.3,
      elevation: 10,
      spacing: 12,
      spaceBetweenChildren: 8,
      buttonSize: Size(60, 60), // Standard FAB size for a circle
      childrenButtonSize: Size(52, 52),
      animatedIconTheme: IconThemeData(size: 28),
      shape: const CircleBorder(), // Make the main button a circle
      children: [
        SpeedDialChild(
          child: Icon(Icons.edit),
          label: 'Manual Entry',
          onTap: () => _showModalManualEntry(),
        ),
        SpeedDialChild(
          child: Icon(Icons.receipt_long),
          label: 'Scan Receipt',
          onTap: () => _showModalScanReceipt(),
        ),
        SpeedDialChild(
          child: Icon(Icons.account_balance),
          label: 'Get From Bank',
          onTap: () async {
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(docID)
                .get();
            final accessToken = doc.data()?['plaidAccessToken'];
            if (accessToken != null) {
              await fetchTransactions(accessToken);
            } else {
              await _launchPlaidFlow();
            }
          },
        ),
        SpeedDialChild(
          child: Icon(Icons.picture_as_pdf),
          label: 'Generate Report',
          onTap: () async {
            await sharePdfLink();
          },
        ),
      ],
    );
  }

  void _showModalManualEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Wrap(
            children: [
              Center(
                child: Text("New Transaction",
                    style: GoogleFonts.ibmPlexSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    )),
              ),
              SizedBox(height: 16),
              ToggleButtons(
                borderRadius: BorderRadius.circular(10),
                fillColor: colors[0],
                isSelected: [type1 == 'Expense', type1 == 'Income'],
                onPressed: (index) {
                  setState(() => type1 = index == 0 ? 'Expense' : 'Income');
                },
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('Expense'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('Income'),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Amount'),
                onChanged: (val) => amt = double.tryParse(val) ?? 0,
              ),
              TextField(
                decoration: InputDecoration(labelText: 'Category'),
                onChanged: (val) => categ = val,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("Date: ${DateFormat('yyyy-MM-dd').format(date)}"),
                trailing: Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => date = picked);
                },
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _addTransaction(amt, type1, categ, date);
                },
                child: Text("Add Transaction"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors[0],
                  foregroundColor: Colors.black,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showModalScanReceipt() async {
    await _scanReceipt();
  }

  Future<void> _updateTotalBalanceInFirestore() async {
    await _firestore.collection('users').doc(docID).update({
      'totalBalance': _totalBalance,
    });
  }

  void _addTransaction(
      double amount, String? type, String? category, DateTime date) {
    if (!amount.isNaN) {
      _firestore.collection('users').doc(docID).collection('Transactions').add({
        'amount': amount,
        'type': type ?? 'Unknown',
        'category': category ?? 'Uncategorized',
        'date': date
      }).then((value) {
        setState(() {
          _transactionsList.add({
            'transactionId': value.id,
            'amount': amount,
            'type': type ?? 'Unknown',
            'category': category ?? 'Uncategorized',
            'date': date
          });
          if (type == 'Income') {
            _totalBalance += amount;
          } else {
            _totalBalance -= amount;
          }
          _filterTransactions();
        });
        _updateTotalBalanceInFirestore();
      });
    }
  }

  void _removeTransaction(String transactionId) {
    _firestore
        .collection('users')
        .doc(docID)
        .collection('Transactions')
        .doc(transactionId)
        .delete()
        .then((_) {
      if (!mounted) return;
      setState(() {
        _transactionsList
            .removeWhere((t) => t['transactionId'] == transactionId);
        _filteredTransactions
            .removeWhere((t) => t['transactionId'] == transactionId);

        _totalBalance = 0.0;
        for (var t in _transactionsList) {
          _totalBalance += t['type'] == 'Income' ? t['amount'] : -t['amount'];
        }
      });
      _updateTotalBalanceInFirestore();
    });
  }

  Future<void> sharePdfLink() async {
  final RenderBox button = context.findRenderObject() as RenderBox;
  final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final Offset offset = button.localToGlobal(Offset.zero, ancestor: overlay);

  String? selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      offset.dx + 10,
      offset.dy - 10,
      overlay.size.width - offset.dx,
      overlay.size.height - offset.dy,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    items: ['General', 'Weekly', 'Monthly'].map((option) {
      return PopupMenuItem<String>(
        value: option,
        child: Text(option),
      );
    }).toList(),
  );

  selected ??= 'General';

  var paragraphPdf;
  if (selected == 'General') {
    paragraphPdf = await ParagraphPdfApi.generateParagraphPdf(docID);
  } else if (selected == 'Weekly') {
    paragraphPdf = await ParagraphPdfApi.generateWeeklyPdf(docID);
  } else {
    paragraphPdf = await ParagraphPdfApi.generateMonthlyPdf(docID);
  }

  final pdfFileName = '$selected-Report.pdf';
  final downloadUrl =
      await SaveAndOpenDocument.uploadPdfAndGetLink(paragraphPdf, pdfFileName);

  if (downloadUrl != null) {
    SaveAndOpenDocument.copyToClipboard(downloadUrl);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$selected PDF link copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to upload $selected report.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}


  void _searchTransactions(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterTransactions(); // Apply filters immediately after search query changes
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

  Future<void> _scanReceipt() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = GoogleMlKit.vision.textRecognizer();
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      String rawText = recognizedText.text;
      print('Recognized Text: $rawText'); // For debugging

      // Implement your logic to parse amount, type, category, and date from rawText
      // For demonstration, let's assume simple parsing or just showing the raw text
      double? scannedAmount;
      String? scannedCategory;
      DateTime? scannedDate;

      // Simple regex to find a dollar amount (e.g., $12.34 or 12.34)
      final amountRegex = RegExp(r'\d+\.\d{2}');
      final amountMatch = amountRegex.firstMatch(rawText);
      if (amountMatch != null) {
        scannedAmount = double.tryParse(amountMatch.group(0)!);
      }

      // Simple regex to find a date (e.g., MM/DD/YYYY or YYYY-MM-DD)
      final dateRegex =
          RegExp(r'\d{2}[-/]\d{2}[-/]\d{4}|\d{4}[-/]\d{2}[-/]\d{2}');
      final dateMatch = dateRegex.firstMatch(rawText);
      if (dateMatch != null) {
        try {
          scannedDate = DateFormat('MM/dd/yyyy')
              .parse(dateMatch.group(0)!); // Adjust format as needed
        } catch (e) {
          try {
            scannedDate = DateFormat('yyyy-MM-dd')
                .parse(dateMatch.group(0)!); // Adjust format as needed
          } catch (e) {
            print("Could not parse date: $e");
          }
        }
      }

      // For category, you'd need more sophisticated NLP or keyword matching
      // For now, let's just use a placeholder
      scannedCategory = "Scanned Item";

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Scanned Transaction'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Raw Text: $rawText'),
                  SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(
                        text: scannedAmount?.toStringAsFixed(2) ?? ''),
                    onChanged: (val) => scannedAmount = double.tryParse(val),
                  ),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Type'),
                    value:
                        'Expense', // Assume expense for receipts, or let user pick
                    items: ['Income', 'Expense']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) => type1 = val,
                  ),
                  TextField(
                    decoration: InputDecoration(labelText: 'Category'),
                    controller: TextEditingController(text: scannedCategory),
                    onChanged: (val) => scannedCategory = val,
                  ),
                  ListTile(
                    title: Text(
                        "Date: ${scannedDate != null ? DateFormat('yyyy-MM-dd').format(scannedDate!) : 'Select Date'}"),
                    trailing: Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: scannedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => scannedDate = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (scannedAmount != null &&
                      type1 != null &&
                      scannedCategory != null &&
                      scannedDate != null) {
                    _addTransaction(
                        scannedAmount!, type1!, scannedCategory!, scannedDate!);
                    Navigator.pop(context);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Please verify all scanned details')),
                      );
                    }
                  }
                },
                child: Text('Add Scanned'),
              ),
            ],
          );
        },
      );
      textRecognizer.close();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No image selected.')),
        );
      }
    }
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

      if (mounted) {
        _showPlaidTransactionPicker();
      }
    } catch (e) {
      print('Failed to fetch transactions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to load Plaid transactions")));
      }
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


Widget _buildAddOptionTile(IconData icon, String title, VoidCallback onTap) {
  return ListTile(
    leading: Icon(icon, color: Colors.black),
    title: Text(
      title,
      style: GoogleFonts.ibmPlexSans(
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
    ),
    onTap: () {
      Navigator.pop(context);
      onTap();
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
      if (!mounted) return;
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
        _filterTransactions(); // <-- Ensure UI updates with new values
      });
    }).catchError((error) {
      print("Failed to update transaction: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update transaction')));
      }
    });
    _updateTotalBalanceInFirestore();
  }

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: TextEditingController.fromValue(
                TextEditingValue(
                  text: _searchQuery,
                  selection:
                      TextSelection.collapsed(offset: _searchQuery.length),
                ),
              ),
              onChanged: (query) {
                setState(() {
                  _searchQuery = query;
                });
                _searchTransactions(query);
              },
              style: TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.black54),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                          _searchTransactions('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.filter_alt_outlined, color: Colors.black87),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: Icon(
              _groupByCategory ? Icons.folder_open : Icons.folder,
              color: Colors.black87,
            ),
            onPressed: () {
              setState(() {
                _groupByCategory = !_groupByCategory;
                _filterTransactions(); // Ensure this uses the search query
              });
            },
            tooltip: 'Group by Category',
          ),
        ],
      ),
    );
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

  Widget _buildTransactionItem(Map<String, dynamic> transaction, int index) {
    return Dismissible(
      key: Key(transaction['transactionId']),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _removeTransaction(transaction['transactionId']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction deleted. Add a NEW Transaction!'),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.7),
              colors[0].withOpacity(0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors[1].withOpacity(0.25),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Card(
          color: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: colors[1].withOpacity(0.5),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  transaction['type'] != 'Income'
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color: transaction['type'] != 'Income'
                      ? Colors.red
                      : Colors.green,
                  size: 20,
                ),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['category'] ?? 'Uncategorized',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                SizedBox(height: 4),
                Text(
                  "${DateFormat('yyyy-MM-dd').format(transaction['date'] ?? DateTime.now())}",
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 10,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: BoxConstraints(minWidth: 70),
                  child: Text(
                    NumberFormat.simpleCurrency(
                            locale: 'en_US', decimalDigits: 2)
                        .format(transaction['amount'] ?? 0.0),
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: transaction['type'] != 'Income'
                          ? Colors.red
                          : Colors.green,
                    ),
                    overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_filteredTransactions.isEmpty) {
      return Center(
        child: Text(
          'No transactions found with the current filters.',
          style: GoogleFonts.ibmPlexSans(fontSize: 18, color: Colors.black54),
        ),
      );
    }

    if (_groupByCategory) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _groupedTransactions.keys.length,
        itemBuilder: (context, index) {
          final category = _groupedTransactions.keys.elementAt(index);
          final transactionsInCategory = _groupedTransactions[category]!;
          final isExpanded = _expandedSections[category] ?? false;

          return Card(
            margin: EdgeInsets.symmetric(vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: ExpansionTile(
              title: Text(
                category,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: colors[1],
              ),
              onExpansionChanged: (bool expanded) {
                setState(() {
                  _expandedSections[category] = expanded;
                });
              },
              initiallyExpanded: isExpanded,
              children: transactionsInCategory.map((transaction) {
                return _buildTransactionItem(
                    transaction, transactionsInCategory.indexOf(transaction));
              }).toList(),
            ),
          );
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredTransactions.length,
        itemBuilder: (context, index) {
          return _buildTransactionItem(_filteredTransactions[index], index);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Color>>(
      stream: docID.isNotEmpty
          ? GradientService(userId: docID).getGradientStream()
          : Stream.value([Color(0xffB8E8FF), Colors.white]),
      builder: (context, snapshot) {
        colors = snapshot.data ?? colors;
        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xffB8E8FF), Colors.white],
                  ),
                ),
              ),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(color: Colors.white.withOpacity(0.05)),
              ),
              SafeArea(
                child: Column(
                  children: [
                    SizedBox(height: 20),
                    Row(
                      children: [
                        SizedBox(width: 25),
                        Text(
                          'Transactions',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.30),
                                offset: Offset(2, 2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    _buildSearchAndFilterBar(),
                    SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        '${NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2).format(_totalBalance)}',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Expanded(child: _buildTransactionList()),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: ExpandableFab(
          type: ExpandableFabType.up,
          openButtonBuilder: RotateFloatingActionButtonBuilder(
            child: const Icon(Icons.add),
            fabSize: ExpandableFabSize.regular,
            shape: const CircleBorder(),
          ),
          children: [
            FloatingActionButton.small(
              heroTag: 'manual',
              backgroundColor: colors[0],
              child: const Icon(Icons.edit, color: Colors.black),
              onPressed: _showModalManualEntry,
            ),
            FloatingActionButton.small(
              heroTag: 'scan',
              backgroundColor: colors[0],
              child: const Icon(Icons.receipt, color: Colors.black),
              onPressed: _showModalScanReceipt,
            ),
            FloatingActionButton.small(
              heroTag: 'plaid',
              backgroundColor: colors[0],
              child: const Icon(Icons.account_balance, color: Colors.black),
              onPressed: () async {
                final doc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(docID)
                    .get();
                final accessToken = doc.data()?['plaidAccessToken'];
                if (accessToken != null) {
                  await fetchTransactions(accessToken);
                } else {
                  await _launchPlaidFlow();
                }
              },
            ),
            FloatingActionButton.small(
              heroTag: 'share',
              backgroundColor: colors[0],
              child: const Icon(Icons.share, color: Colors.black),
              onPressed: sharePdfLink,
            ),
          ],
        ),
        floatingActionButtonLocation: ExpandableFab.location,
      );
    },
  );
  }
}