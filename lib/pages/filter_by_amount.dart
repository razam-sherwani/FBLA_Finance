import 'package:fbla_finance/util/gradient_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FilterByAmountPage extends StatefulWidget {
  final String userId;

  FilterByAmountPage({Key? key, required this.userId}) : super(key: key);

  @override
  _FilterByAmountPageState createState() => _FilterByAmountPageState();
}

class _FilterByAmountPageState extends State<FilterByAmountPage> {
  final TextEditingController _minController = TextEditingController();
  final TextEditingController _maxController = TextEditingController();
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
    final double min = double.tryParse(_minController.text) ?? 0;
    final double max = double.tryParse(_maxController.text) ?? double.infinity;

    setState(() {
      _filteredTransactions = _transactions.where((transaction) {
        final double amount = transaction['amount'];
        return amount >= min && amount <= max;
      }).toList();
    });
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
                color: transaction['type'] == 'Expense'
                    ? Colors.red
                    : Colors.green,
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
        appBar: AppBar(
          title: Text(
            'Filter by Amount Range',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: Icon(Icons.arrow_back,
                color: Colors.white), // Set the color to white
            onPressed: () {
              Navigator.pop(context); // Pop to the previous screen
            },
          ),
        ),
        body: StreamBuilder<LinearGradient>(
            stream: widget.userId.isNotEmpty
                ? GradientService(userId: widget.userId).getGradientStream()
                : Stream.value(LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Colors.cyan, Colors.teal],
                  )),
            builder: (context, snapshot) {
              final gradient = snapshot.data ??
                  LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.cyan,
                      Colors.teal,
                    ],
                  );
              return Container(
                decoration: BoxDecoration(gradient: gradient),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        padding: EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _minController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                    labelText: 'Min Amount',
                                    border: OutlineInputBorder(),
                                    fillColor: Colors.white,
                                    filled: true),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _maxController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                    labelText: 'Max Amount',
                                    border: OutlineInputBorder(),
                                    fillColor: Colors.white,
                                    filled: true),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ElevatedButton(
                        onPressed: _filterTransactions, child: Text('Filter')),
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
