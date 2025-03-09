import 'dart:math';

import 'package:fbla_finance/util/gradient_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class FilterByAmountPage extends StatefulWidget {
  final String userId;
  // Constructor to receive the userId
  FilterByAmountPage({Key? key, required this.userId}) : super(key: key);

  @override
  _FilterByAmountPageState createState() => _FilterByAmountPageState();
}

class _FilterByAmountPageState extends State<FilterByAmountPage> {
  double _currentMin = 0;
  double _currentMax = 0;
  double _sliderMax = 0;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];

  @override
  void initState() {
    super.initState();
    _fetchTransactions(); // Fetch transactions when the page initializes
  }

  void _fetchTransactions() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('Transactions')
          .get();

      setState(() {
        _transactions = querySnapshot.docs.map((doc) {
          return {
            'transactionId': doc.id,
            'amount': doc['amount'],
            'category': doc['category'],
            'type': doc['type'],
            'date': (doc['date'] as Timestamp).toDate(),
          };
        }).toList();
        _filteredTransactions = [..._transactions];
        _sliderMax = _transactions.map((transaction) => transaction['amount'] as double)
                          .reduce((value, element) => value > element ? value : element);
        _currentMax = _sliderMax;
      });
    } catch (e) {
      print('Error fetching transactions: $e');
    }
  }

  // Function to filter transactions based on user input
  void _filterTransactions() {
    setState(() {
      _filteredTransactions = _transactions.where((transaction) {
        final double amount = transaction['amount'];
        return amount >= _currentMin && amount <= _currentMax;
      }).toList();
    });
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      itemCount: _filteredTransactions.length,
      itemBuilder: (context, index) {
        final transaction = _filteredTransactions[index];
        return Card(
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
            style: GoogleFonts.ibmPlexSans(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w500),
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
        ],
      ),
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
            'Filter by Amount Range',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: StreamBuilder<LinearGradient>(
            stream: widget.userId.isNotEmpty
                ? GradientService(userId: widget.userId).getGradientStream()
                : Stream.value(LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Colors.white],
                  )),
            builder: (context, snapshot) {
              final gradient = snapshot.data ??
                  LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Colors.white],
                  );
              return Container(
                decoration: BoxDecoration(color: Colors.white),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          SizedBox(height: 16),
                          Text(
                            "Amount Range: \$${_currentMin.toStringAsFixed(2)} - \$${_currentMax.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[300],
                            ),
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.grey,
                              thumbColor: Colors.blue,
                              overlayColor: Colors.cyan.withAlpha(32),
                              valueIndicatorColor: Colors.black,
                            ),
                            child: RangeSlider(
                              inactiveColor: Colors.grey,
                              activeColor: Colors.blue[300],
                              min: 0,
                              max: _sliderMax,
                              divisions: 100,
                              values: RangeValues(_currentMin, _currentMax),
                              onChanged: (RangeValues values) {
                                setState(() {
                                  _currentMin = values.start;
                                  _currentMax = values.end;
                                });
                              },
                              onChangeEnd: (RangeValues values) {
                                _filterTransactions();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _filteredTransactions.isEmpty
                          ? Center(child: Text('No transactions found'))
                          : _buildTransactionList(),
                    ),
                  ],
                ),
              );
            }));
  }
}
