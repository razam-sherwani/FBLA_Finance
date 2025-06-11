// ignore_for_file: invalid_return_type_for_catch_error, avoid_print
import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

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
  List<Color> colors = [Color(0xffB8E8FF), Colors.blue.shade900];

  final List<Map<String, dynamic>> _transactionsList = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  Map<String, List<Map<String, dynamic>>> _groupedTransactions = {};
  Map<String, bool> _expandedSections = {};
  double _totalBalance = 0.0;
  String _searchQuery = '';

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

      final matchesType = _selectedType == null || transaction['type'] == _selectedType;
      final matchesCategory = _selectedCategory == null ||
          (transaction['category'] as String?)
              ?.toLowerCase()
              .contains(_selectedCategory!.toLowerCase()) ==
              true;

      final matchesDate = _startDate == null ||
          (transaction['date'].isAfter(_startDate!) &&
              (_endDate == null || transaction['date'].isBefore(_endDate!.add(Duration(days: 1)))));

      final amount = transaction['amount'] as double;
      final matchesAmount = (_minAmount == null || amount >= _minAmount!) &&
          (_maxAmount == null || amount <= _maxAmount!);

      return matchesSearch && matchesType && matchesCategory && matchesDate && matchesAmount;
    }).toList();

    filtered.sort((a, b) => b['date'].compareTo(a['date']));

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
                    onChanged: (val) => setStateInDialog(() => _selectedType = val),
                  ),
                  TextField(
                    decoration: InputDecoration(labelText: 'Category'),
                    onChanged: (val) => _selectedCategory = val.isEmpty ? null : val,
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
                      setStateInDialog(() {}); // Update dialog after date selection
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
      });
    }
  }

  Future<void> sharePdfLink() async {
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

    selectedName ??= 'General';

    var paragraphPdf;
    if (selectedName == 'General') {
      paragraphPdf = await ParagraphPdfApi.generateParagraphPdf(docID);
    } else if (selectedName == 'Weekly') {
      paragraphPdf = await ParagraphPdfApi.generateWeeklyPdf(docID);
    } else {
      paragraphPdf = await ParagraphPdfApi.generateMonthlyPdf(docID);
    }
    final pdfFileName = '$selectedName-Report.pdf';
    final downloadUrl =
        await SaveAndOpenDocument.uploadPdfAndGetLink(paragraphPdf, pdfFileName);

    if (downloadUrl != null) {
      SaveAndOpenDocument.copyToClipboard(downloadUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF link copied to clipboard!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload PDF')),
      );
    }
  }

  void _searchTransactions(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterTransactions(); // Apply filters immediately after search query changes
  }

  void _showAddManualTransactionDialog() {
    double? amount;
    String? type;
    String? category;
    DateTime date = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add New Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => amount = double.tryParse(val),
                ),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: 'Type'),
                  value: type,
                  items: ['Income', 'Expense']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) => type = val,
                ),
                TextField(
                  decoration: InputDecoration(labelText: 'Category'),
                  onChanged: (val) => category = val,
                ),
                ListTile(
                  title: Text("Date: ${DateFormat('yyyy-MM-dd').format(date)}"),
                  trailing: Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => date = picked);
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
                if (amount != null && type != null && category != null) {
                  _addTransaction(amount!, type!, category!, date);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please fill all fields')),
                  );
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _scanReceipt() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = GoogleMlKit.vision.textRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

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
      final dateRegex = RegExp(r'\d{2}[-/]\d{2}[-/]\d{4}|\d{4}[-/]\d{2}[-/]\d{2}');
      final dateMatch = dateRegex.firstMatch(rawText);
      if (dateMatch != null) {
        try {
          scannedDate = DateFormat('MM/dd/yyyy').parse(dateMatch.group(0)!) ; // Adjust format as needed
        } catch (e) {
          try {
            scannedDate = DateFormat('yyyy-MM-dd').parse(dateMatch.group(0)!) ; // Adjust format as needed
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
                    controller: TextEditingController(text: scannedAmount?.toStringAsFixed(2) ?? ''),
                    onChanged: (val) => scannedAmount = double.tryParse(val),
                  ),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Type'),
                    value: 'Expense', // Assume expense for receipts, or let user pick
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
                    title: Text("Date: ${scannedDate != null ? DateFormat('yyyy-MM-dd').format(scannedDate!) : 'Select Date'}"),
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
                  if (scannedAmount != null && type1 != null && scannedCategory != null && scannedDate != null) {
                    _addTransaction(scannedAmount!, type1!, scannedCategory!, scannedDate!);
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please verify all scanned details')),
                    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No image selected.')),
      );
    }
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
                    _showAddManualTransactionDialog();
                  },
                ),
              ),
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: TextEditingController(text: _searchQuery), // Set initial value
              onChanged: _searchTransactions,
              style: TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.black54),
                        onPressed: () {
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
                _filterTransactions(); // Re-filter to apply grouping
              });
            },
            tooltip: 'Group by Category',
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction, int index) {
    return Container(
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
                color: colors[1],
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
          trailing: Container(
            constraints: BoxConstraints(minWidth: 70),
            child: Text(
              NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2)
                  .format(transaction['amount'] ?? 0.0),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: (transaction['type'] ?? 'Unknown') == 'Expense'
                    ? Colors.red
                    : Colors.green,
              ),
              overflow: TextOverflow.ellipsis,
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                return _buildTransactionItem(transaction, transactionsInCategory.indexOf(transaction));
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
          : Stream.value([Color(0xffB8E8FF), Colors.blue.shade900]),
      builder: (context, snapshot) {
        colors = snapshot.data ?? colors;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              "Transactions",
              style: GoogleFonts.barlow(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 42,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.blue.shade900.withOpacity(0.8),
            elevation: 0,
          ),
          body: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xffB8E8FF), Colors.white],
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
                    _buildSearchAndFilterBar(),
                    Expanded(child: _buildTransactionList()),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                FloatingActionButton(
                  backgroundColor: colors[0],
                  onPressed: sharePdfLink,
                  child: Icon(Icons.share, color: Colors.black),
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
      },
    );
  }
}