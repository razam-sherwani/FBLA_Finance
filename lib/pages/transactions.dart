import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class Transactions extends StatefulWidget {

  @override
  State<Transactions> createState() => _TransactionState();
}

class _TransactionState extends State<Transactions> {
  final List<Map<String, dynamic>> _transactionsList = [];
  double amt = 0.0;
  String? type1;
  String cat = '';
  String date1 = '';

  void _addTransaction(double amount, String type, String category, String date) {
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
        return AlertDialog(
          title: Text('New Transaction'),
          content: Container(
            height: 250,
            child: Column(
              children: [
                TextFormField(
                  autofocus: true,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Enter the amount'),
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
                DropdownButton<String>(
                value: type1,
                hint: Text('Select type'),
                items: <String>['Expense', 'Income'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    type1 = newValue;
                  });
                },
              ),
                TextField(
                  decoration: InputDecoration(labelText: 'Please enter category'),
                  onSubmitted: (cat) {
                    Navigator.of(context).pop();
                  },
                ),
                TextField(
                  decoration: InputDecoration(labelText: 'date of transaction'),
                  onSubmitted: (date1) {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
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

  Widget _buildTransactionItem(Map<String, dynamic> todoItem, int index) {
    return Dismissible(
      key: Key(todoItem['task']),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _removeTransaction(index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Task "${todoItem['task']}" deleted; Add a NEW Task!')),
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
            todoItem['task'],
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              decoration: todoItem['completed']
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
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
                    'No tasks just yet. Add a task!',
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
        tooltip: 'Add a task',
        backgroundColor: const Color.fromARGB(255, 252, 192, 12),
        child: Icon(Icons.add),
      ),
    );
  }
}
