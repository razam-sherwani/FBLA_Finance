import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FilterByDatePage extends StatefulWidget {
  final String userId;

  FilterByDatePage({Key? key, required this.userId}) : super(key: key);

  @override
  _FilterByDatePageState createState() => _FilterByDatePageState();
}

class _FilterByDatePageState extends State<FilterByDatePage> {
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
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
      });
    } catch (e) {
      print('Error fetching transactions: $e');
    }
  }

  void _filterTransactions() {
    setState(() {
      if (_startDate != null && _endDate != null) {
        _filteredTransactions = _transactions.where((transaction) {
          final DateTime date = transaction['date'];
          return date.isAfter(_startDate!) && date.isBefore(_endDate!);
        }).toList();
      }
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _filterTransactions();
      });
    }
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      itemCount: _filteredTransactions.length,
      itemBuilder: (context, index) {
        final transaction = _filteredTransactions[index];
        return Card(
          elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              transaction['category'],
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "Type: ${transaction['type']} - Date: ${DateFormat('yyyy-MM-dd').format(transaction['date'])}",
              style: TextStyle(fontSize: 14, color: Colors.black),
            ),
          ],
        ),
        trailing: Text(
          NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2)
              .format(transaction['amount']),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: transaction['type'] == 'Expense' ? Colors.red : Colors.green,
          ),
        ),
      ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Filter by Date Range')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () => _selectDateRange(context),
              child: Text('Select Date Range'),
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
  }
}
