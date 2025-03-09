import 'package:fbla_finance/util/gradient_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class FilterByTypePage extends StatefulWidget {
  final String userId;

  FilterByTypePage({Key? key, required this.userId}) : super(key: key);

  @override
  _FilterByTypePageState createState() => _FilterByTypePageState();
}

class _FilterByTypePageState extends State<FilterByTypePage> {
  String? _selectedType;
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
      if (_selectedType == null || _selectedType!.isEmpty) {
        _filteredTransactions = [..._transactions];
      } else {
        _filteredTransactions = _transactions
            .where((transaction) => transaction['type'] == _selectedType)
            .toList();
      }
    });
  }

  void _fetchColors() {
    setState(() {
      ;
    });
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      itemCount: _filteredTransactions.length,
      itemBuilder: (context, index) {
        final transaction = _filteredTransactions[index];
        return Card(
    color: Colors.white,
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
          'Filter by Type',
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0)),
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
                      value: _selectedType,
                      hint: Text('Select Type'),
                      items: <String>['Income', 'Expense']
                          .map((type) =>
                              DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedType = newValue;
                          _filterTransactions();
                        });
                      },
                    ),
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
        },
      ),
    );
  }
}
