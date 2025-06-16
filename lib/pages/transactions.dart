// ignore_for_file: invalid_return_type_for_catch_error, avoid_print
import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

import '../backend/paragraph_pdf_api.dart';
import '../backend/save_and_open_pdf.dart';
import '../util/gradient_service.dart';
import '../util/profile_picture.dart';

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

  final GlobalKey<ExpandableFabState> _fabKey = GlobalKey<ExpandableFabState>();

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
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.13),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.08),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: StatefulBuilder(builder: (context, setStateInDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Filter Transactions",
                    style: GoogleFonts.ibmPlexSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Color(0xFF2A4288),
                    ),
                  ),
                  const SizedBox(height: 22),
                  // Improved Select Type Dropdown
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white, // Make the field white
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Color(0xFF2A4288).withOpacity(0.18), width: 1.2),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedType,
                        hint: Text("Select Type", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
                        isExpanded: true,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF2A4288)),
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 16,
                          color: Color(0xFF2A4288),
                          fontWeight: FontWeight.w600,
                        ),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        items: ['Income', 'Expense']
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Row(
                                    children: [
                                      Icon(
                                        type == 'Income' ? Icons.arrow_upward : Icons.arrow_downward,
                                        color: type == 'Income' ? Colors.green : Colors.red,
                                        size: 20,
                                      ),
                                      SizedBox(width: 10),
                                      Text(type,
                                          style: TextStyle(
                                            color: type == 'Income' ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.w600,
                                          )),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) => setStateInDialog(() => _selectedType = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    ),
                    onChanged: (val) =>
                        _selectedCategory = val.isEmpty ? null : val,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Min Amount',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => _minAmount = double.tryParse(val),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Max Amount',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => _maxAmount = double.tryParse(val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    tileColor: Colors.grey[100],
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    title: Text(
                      _startDate == null && _endDate == null
                          ? "Select Date Range"
                          : "${_startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : ''} - ${_endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : ''}",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: Icon(Icons.calendar_today, color: Color(0xFF2A4288)),
                    onTap: () async {
                      await _selectDateRange();
                      setStateInDialog(() {});
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _clearFilters();
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Color(0xFF2A4288), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            "Clear Filters",
                            style: TextStyle(
                              color: Color(0xFF2A4288),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _filterTransactions();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF2A4288),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            "Apply",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),
        );
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

  void _showModalManualEntry() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final double width = MediaQuery.of(context).size.width * 0.92;
        final double height = MediaQuery.of(context).size.height * 0.52;
        // Local state for modal fields
        double localAmt = 0;
        String? localType = type1;
        String? localCateg = categ;
        DateTime localDate = date;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Container(
            width: width,
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: StatefulBuilder(
              builder: (context, setStateModal) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "New Transaction",
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Color(0xFF2A4288),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: ToggleButtons(
                        borderRadius: BorderRadius.circular(14),
                        fillColor: Colors.blueAccent,
                        selectedColor: Colors.white,
                        color: Colors.black,
                        constraints: const BoxConstraints(minHeight: 44, minWidth: 120),
                        isSelected: [localType == 'Expense', localType == 'Income'],
                        onPressed: (index) {
                          setStateModal(() {
                            localType = index == 0 ? 'Expense' : 'Income';
                          });
                        },
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Expense',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Income',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        labelStyle: TextStyle(fontWeight: FontWeight.w500),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                      ),
                      onChanged: (val) {
                        setStateModal(() {
                          localAmt = double.tryParse(val) ?? 0;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(fontWeight: FontWeight.w500),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                      ),
                      onChanged: (val) {
                        setStateModal(() {
                          localCateg = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        "Date: ${DateFormat('yyyy-MM-dd').format(localDate)}",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: Icon(Icons.calendar_today, color: Color(0xFF2A4288)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: localDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setStateModal(() => localDate = picked);
                        }
                      },
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          // Only add if all required fields are filled
                          if (localAmt > 0 && localType != null && localCateg != null && localCateg!.trim().isNotEmpty) {
                            Navigator.pop(context);
                            setState(() {
                              amt = localAmt;
                              type1 = localType;
                              categ = localCateg;
                              date = localDate;
                            });
                            _addTransaction(localAmt, localType, localCateg, localDate);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Please fill all fields')),
                            );
                          }
                        },
                        child: Text(
                          "Add Transaction",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2A4288),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
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
  String? selected = await showModalBottomSheet<String>(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    backgroundColor: Colors.white,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select the type of report to share',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16),
              ...['General', 'Weekly', 'Monthly'].map((option) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    onTap: () => Navigator.pop(context, option),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf_outlined, color: Colors.blue.shade700),
                          SizedBox(width: 12),
                          Text(
                            option,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      );
    },
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
  final downloadUrl = await SaveAndOpenDocument.uploadPdfAndGetLink(paragraphPdf, pdfFileName);

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
                    decoration: InputDecoration(labelText: 'Name'),
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
        _totalBalance = 0;
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
          // 1. Wrap the TextField with a Container
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              // 2. Add the boxShadow property
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
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
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                // 3. Remove fill properties from InputDecoration as the Container handles it
                // filled: true,
                // fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                // 4. Ensure the TextField's border is transparent to see the container's shape
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.black54),
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
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.filter_alt_outlined, color: Colors.black87),
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
          tooltip: 'Group by Name',
        ),
      ],
    ),
  );
}

  void _promptEditTransaction(Map<String, dynamic> transaction, int index) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final double width = MediaQuery.of(context).size.width * 0.92;
        final double height = MediaQuery.of(context).size.height * 0.52;
        String updatedCategory = transaction['category'];
        double updatedAmount = transaction['amount'];
        String updatedType = transaction['type'];
        DateTime updatedDate = transaction['date'];

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Container(
            width: width,
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Edit Transaction",
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Color(0xFF2A4288),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: ToggleButtons(
                        borderRadius: BorderRadius.circular(14),
                        fillColor: Colors.blueAccent,
                        selectedColor: Colors.white,
                        color: Colors.black,
                        constraints: const BoxConstraints(minHeight: 44, minWidth: 120),
                        isSelected: [updatedType == 'Expense', updatedType == 'Income'],
                        onPressed: (idx) {
                          setState(() {
                            updatedType = idx == 0 ? 'Expense' : 'Income';
                          });
                        },
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Expense',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Income',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      autofocus: true,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        labelStyle: TextStyle(fontWeight: FontWeight.w500),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                      ),
                      controller: TextEditingController(text: updatedAmount.toString()),
                      onChanged: (val) {
                        updatedAmount = double.tryParse(val) ?? 0;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(fontWeight: FontWeight.w500),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                      ),
                      controller: TextEditingController(text: updatedCategory),
                      onChanged: (val) {
                        updatedCategory = val;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        "Date: ${DateFormat('yyyy-MM-dd').format(updatedDate)}",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: Icon(Icons.calendar_today, color: Color(0xFF2A4288)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: updatedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => updatedDate = picked);
                      },
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _updateTransaction(
                            transaction['transactionId'],
                            updatedAmount,
                            updatedType,
                            updatedCategory,
                            updatedDate,
                            index,
                          );
                        },
                        child: Text(
                          "Update Transaction",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2A4288),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
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
          margin: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
              BoxShadow(
                color: colors[0].withOpacity(0.10),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: colors[0].withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: Card(
            color: Colors.transparent,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: colors[1].withOpacity(0.18),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                  color: transaction['type'] != 'Income'
                      ? Colors.red.withOpacity(0.12)
                      : Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    transaction['type'] != 'Income'
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    color: transaction['type'] != 'Income'
                        ? Colors.red
                        : Colors.green,
                    size: 22,
                  ),
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction['category'] ?? 'Uncategorized',
                    style: GoogleFonts.barlow(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  SizedBox(height: 4),
                  Text(
                    "${DateFormat('yyyy-MM-dd').format(transaction['date'] ?? DateTime.now())}",
                    style: GoogleFonts.barlow(
                      fontSize: 12,
                      color: Colors.grey[700],
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
                      style: GoogleFonts.barlow(
                        fontSize: 17,
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
                      color: Colors.grey[800],
                      size: 28,
                    ),
                    onPressed: () {
                      _promptEditTransaction(transaction, index);
                    },
                  ),
                ],
              ),
            ),
          ),
        ));
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
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            elevation: 2,
            color: const Color(0xffB8E8FF), // Light blue throughout the card
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                unselectedWidgetColor: Colors.black,
              ),
              child: ExpansionTile(
                title: Text(
                  category,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black, // Black text for light blue card
                  ),
                ),
                trailing: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.black,
                ),
                onExpansionChanged: (bool expanded) {
                  setState(() {
                    _expandedSections[category] = expanded;
                  });
                },
                initiallyExpanded: isExpanded,
                children: transactionsInCategory.map((transaction) {
                  return Container(
                    color: Colors.white,
                    child: _buildTransactionItem(
                      transaction,
                      transactionsInCategory.indexOf(transaction),
                    ),
                  );
                }).toList(),
              ),
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
    final Color primaryColor = const Color(0xFF2A4288);
    final Color secondaryColor = colors.length > 1 ? colors[1] : Colors.blue.shade900;
    final Color bgColor = Colors.white;

    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? '';

    return Scaffold(
      backgroundColor: primaryColor,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        toolbarHeight: 75,
        title: Padding(
          padding: const EdgeInsets.only(bottom: 15.0),
          child: Text(
            "Transactions",
            style: GoogleFonts.barlow(
              fontWeight: FontWeight.bold,
              fontSize: 28,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (userId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10.0, top: 8),
              child: ProfilePicture(userId: userId),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 18),
            _buildSearchAndFilterBar(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Total Balance:',
                    style: GoogleFonts.barlow(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: secondaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2).format(_totalBalance)}',
                    style: GoogleFonts.barlow(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                // Add padding and background for better contrast
                padding: const EdgeInsets.only(top: 0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.97),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                ),
                child: _buildTransactionList(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButton: ExpandableFab(
        type: ExpandableFabType.up,
        childrenAnimation: ExpandableFabAnimation.none,
        distance: 70,
        overlayStyle: ExpandableFabOverlayStyle(
          color: Colors.transparent,
        ),
        openButtonBuilder: DefaultFloatingActionButtonBuilder(
          child: Icon(Icons.add),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        closeButtonBuilder: DefaultFloatingActionButtonBuilder(
          child: Icon(Icons.close),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 10.0),
                    child: Text(
                      'Manual Entry',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton.small(
                    heroTag: 'manual',
                    backgroundColor: primaryColor,
                    child: const Icon(Icons.edit, color: Colors.white),
                    onPressed: _showModalManualEntry,
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 14.0),
                    child: Row(
                      children: [
                        SizedBox(width: 8),
                        Text(
                          'Scan Receipt',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton.small(
                    heroTag: 'scan',
                    backgroundColor: primaryColor,
                    child: const Icon(Icons.camera_alt, color: Colors.white),
                    onPressed: _showModalScanReceipt,
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 14.0),
                    child: Row(
                      children: [
                        SizedBox(width: 8),
                        Text(
                          'Get From Bank',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton.small(
                    heroTag: 'plaid',
                    backgroundColor: primaryColor,
                    child: const Icon(Icons.account_balance, color: Colors.white),
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
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 10.0),
                    child: Text(
                      'Generate Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton.small(
                    heroTag: 'share',
                    backgroundColor: primaryColor,
                    child: const Icon(Icons.share, color: Colors.white),
                    onPressed: sharePdfLink,
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
                    onPressed: sharePdfLink,
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
