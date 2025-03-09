import 'package:fbla_finance/util/gradient_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class TransactionsByCategory extends StatefulWidget {
  final String userId;

  TransactionsByCategory({Key? key, required this.userId}) : super(key: key);

  @override
  _TransactionsByCategoryState createState() => _TransactionsByCategoryState();
}

class _TransactionsByCategoryState extends State<TransactionsByCategory> {
  final List<Map<String, dynamic>> _transactionsList = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<Map<String, dynamic>> _filteredTransactions = [];
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _fetchAllTransactions();
  }

  void _fetchAllTransactions() {
    _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('Transactions')
        .get()
        .then((querySnapshot) {
      setState(() {
        _transactionsList.clear();
        _filteredTransactions.clear();
        querySnapshot.docs.forEach((doc) {
          // Add null checks for all fields
          var data = doc.data();
          var transaction = {
            'transactionId': doc.id,
            'amount': data['amount'] ?? 0.0, // Default to 0 if missing
            'type':
                data['type'] ?? 'Unknown', // Default to 'Unknown' if missing
            'category': data['category'] ?? 'Uncategorized', // Default category
            'date': (data['date'] != null)
                ? (data['date'] as Timestamp).toDate()
                : DateTime.now(), // Default to current date
          };
          _transactionsList.add(transaction);
        });
        // Initially, show all transactions
        _filteredTransactions.addAll(_transactionsList);
      });
    }).catchError((error) {
      print("Error fetching transactions: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch transactions')),
      );
    });
  }

  void _filterTransactionsByCategory(String? category) {
    setState(() {
      if (category == null || category.isEmpty) {
        _filteredTransactions.clear();
        _filteredTransactions.addAll(_transactionsList);
      } else {
        _filteredTransactions.clear();
        _filteredTransactions.addAll(
          _transactionsList
              .where((transaction) => transaction['category'] == category),
        );
      }
    });
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      itemCount: _filteredTransactions.length,
      itemBuilder: (context, index) {
        return _buildTransactionItem(_filteredTransactions[index]);
      },
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Filter Transactions by Category',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
      body: StreamBuilder<List<Color>>(
            stream: widget.userId.isNotEmpty
                ? GradientService(userId: widget.userId).getGradientStream()
                : Stream.value([Color(0xffB8E8FF), Colors.blue.shade900]),
            builder: (context, snapshot) {
              final colors = snapshot.data ??
                  [Color(0xffB8E8FF), Colors.blue.shade900];
          return Container(
            decoration: BoxDecoration(color: Colors.white),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.0)),
                    child: DropdownButton<String>(
                      borderRadius: BorderRadius.circular(20),
                      iconEnabledColor: Colors.black,
                      iconDisabledColor: Colors.grey,
                      alignment: Alignment.center,
                      elevation: 30,
                      menuWidth: 600,
                      autofocus: true,
                      padding: EdgeInsets.all(10),
                      isExpanded: true,
                      value: _selectedCategory,
                      hint: Text('Select a category to filter',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          )),
                      items: <String>[
                        'All',
                        'Work',
                        'Stocks',
                        'Food',
                        'Entertainment',
                        'Utilities',
                        'Other'
                      ].map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newCategory) {
                        setState(() {
                          _selectedCategory =
                              newCategory == 'All' ? null : newCategory;
                          _filterTransactionsByCategory(_selectedCategory);
                        });
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredTransactions.isEmpty
                      ? Center(
                          child: Text(
                            'No transactions found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : _buildTransactionList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
