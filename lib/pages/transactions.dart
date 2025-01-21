import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class Transactions extends StatefulWidget {
  @override
  State<Transactions> createState() => _TransactionState();
}

class _TransactionState extends State<Transactions> {
  final List<Map<String, dynamic>> _transactionsList = [];
  DateTime date = DateTime.now();
  double amt = 0.0;
  String? type1;
  String? cat;

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

  void _addTransaction(
      double amount, String? type, String? category, DateTime date) {
    if (!amount.isNaN) {
      setState(() => _transactionsList.add({
            'amount': amount,
            'type': type,
            'category': category,
            'date': date
          }));
    }
  }

  void _removeTransaction(int index) {
    setState(() => _transactionsList.removeAt(index));
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
                    TextFormField(
                      autofocus: true,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          InputDecoration(labelText: 'Enter the amount'),
                      validator: (amt) {
                        if (amt == null || amt.isEmpty) {
                          return 'Please enter a number';
                        }
                        try {
                          double.parse(amt);
                          return null;
                        } catch (e) {
                          return 'Please enter a valid number';
                        }
                      },
                    ),
                    Container(
                      width: 200,
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: 'Expense',
                        hint: Text('Select type'),
                        items:
                            <String>['Expense', 'Income'].map((String value) {
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
                    TextField(
                      decoration:
                          InputDecoration(labelText: 'Please enter category'),
                      onSubmitted: (String? cat) {
                        Navigator.of(context).pop();
                        _addTransaction(amt, type1!, cat!, date);
                      },
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      children: <Widget>[
                        const SizedBox(
                          height: 20.0,
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await _selectDate(context);
                            setState(
                                () {}); // This ensures the dialog updates with the new date
                          },
                          child: Text("${date.toLocal()}".split(' ')[0]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
      },
    );
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
      key: Key(transaction['category']),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _removeTransaction(index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Transaction "${transaction['transaction']}" deleted; Add a NEW Transaction!')),
        );
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        elevation: 4,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: ListTile(
          title: Text(
            transaction['category'] + "${transaction['date'].toLocal()}".split(' ')[0] + transaction['type'] + transaction['amount'].toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Transactions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            stops: [0.3, 0.6, 0.9],
            colors: [
              Color(0xff56018D),
              Color(0xff8B139C),
              Colors.pink,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _transactionsList.isEmpty
              ? Center(
                  child: Text(
                    'No transactions yet. Add a transaction!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                    ),
                  ),
                )
              : _buildTransactionList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _promptAddTransaction,
        tooltip: 'Add a transaction',
        backgroundColor: const Color.fromARGB(255, 252, 192, 12),
        child: Icon(Icons.add),
      ),
    );
  }
}
