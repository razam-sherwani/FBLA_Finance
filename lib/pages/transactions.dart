import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Transactions extends StatefulWidget {
  final String userId;

  Transactions({Key? key, required this.userId}) : super(key: key);

  @override
  _TransactionState createState() => _TransactionState();
}

class _TransactionState extends State<Transactions> {
  final List<Map<String, dynamic>> _transactionsList = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  double _totalBalance = 0.0;
  DateTime date = DateTime.now();
  double amt = 0;
  String? type1;
  String? categ;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  void _fetchTransactions() {
    _firestore.collection('users').doc(widget.userId).collection('Transactions').get().then((querySnapshot) {
      setState(() {
        _transactionsList.clear();
        _totalBalance = 0.0;
        querySnapshot.docs.forEach((doc) {
          var transaction = {
            'transactionId': doc.id,
            'amount': doc['amount'],
            'type': doc['type'],
            'category': doc['category'],
            'date': (doc['date'] as Timestamp).toDate(),
          };
          _transactionsList.add(transaction);
          if (transaction['type'] == 'Income') {
            _totalBalance += transaction['amount'];
          } else {
            _totalBalance -= transaction['amount'];
          }
        });
      });
    }).catchError((error) {
      print("Error fetching transactions: $error");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch transactions')));
    });
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

  void _addTransaction(double amount, String? type, String? category, DateTime date) {
    if (!amount.isNaN) {
      _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('Transactions')
          .add({
        'amount': amount,
        'type': type,
        'category': category,
        'date': date
      }).then((value) {
        setState(() {
          _transactionsList.add({
            'transactionId': value.id,
            'amount': amount,
            'type': type,
            'category': category,
            'date': date
          });
          if (type == 'Income') {
            _totalBalance += amount;
          } else {
            _totalBalance -= amount;
          }
        });
      });
    }
  }

  void _removeTransaction(String transactionId, int index) {
    var transaction = _transactionsList[index];
    _firestore.collection('users').doc(widget.userId).collection('Transactions').doc(transactionId).delete().then((value) {
      setState(() {
        _transactionsList.removeAt(index);
        if (transaction['type'] == 'Income') {
          _totalBalance -= transaction['amount'];
        } else {
          _totalBalance += transaction['amount'];
        }
      });
    }).catchError((error) => print("Failed to delete transaction: $error"));
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
                    TextField(
                      autofocus: true,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Enter the amount'),
                      onChanged: (String? val) {
                        amt = double.parse(val!);
                      },
                    ),
                    Container(
                      width: 200,
                      child: DropdownButton<String>(
                        isExpanded: true,
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
                            type1 = newValue!;
                          });
                        },
                      ),
                    ),
                    TextField(
                      decoration: InputDecoration(labelText: 'Please enter category'),
                      onChanged: (String? cat) {
                        categ = cat;
                      },
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      children: <Widget>[
                        const SizedBox(height: 20.0),
                        ElevatedButton(
                          onPressed: () async {
                            await _selectDate(context);
                            setState(() {});
                          },
                          child: Text("${date.toLocal()}".split(' ')[0]),
                        ),
                      ],
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
                      child: Text('Enter'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _addTransaction(amt, type1, categ, date);
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
                height: 230,
                width: 250,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Enter the amount'),
                      controller: TextEditingController(text: updatedAmount.toString()),
                      onChanged: (String? val) {
                        updatedAmount = double.parse(val!);
                      },
                    ),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: updatedType,
                      hint: Text('Select type'),
                      items: <String>['Expense', 'Income'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          updatedType = newValue!;
                        });
                      },
                    ),
                    TextField(
                      decoration: InputDecoration(labelText: 'Please enter category'),
                      controller: TextEditingController(text: updatedCategory),
                      onChanged: (String? cat) {
                        updatedCategory = cat!;
                      },
                    ),
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
                      child: Text("${updatedDate.toLocal()}".split(' ')[0]),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text('Update'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _updateTransaction(transaction['transactionId'], updatedAmount, updatedType, updatedCategory, updatedDate, index);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _updateTransaction(String transactionId, double amount, String type, String category, DateTime date, int index) {
    _firestore.collection('users').doc(widget.userId).collection('Transactions').doc(transactionId).update({
      'amount': amount,
      'type': type,
      'category': category,
      'date': date
    }).then((value) {
      setState(() {
        _transactionsList[index] = {
          'transactionId': transactionId,
          'amount': amount,
          'type': type,
          'category': category,
          'date': date
        };
        _totalBalance = 0.0;
        _transactionsList.forEach((transaction) {
          if (transaction['type'] == 'Income') {
            _totalBalance += transaction['amount'];
          } else {
            _totalBalance -= transaction['amount'];
          }
        });
      });
    }).catchError((error) {
      print("Failed to update transaction: $error");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update transaction')));
    });
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
      key: Key(transaction['transactionId']),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _removeTransaction(transaction['transactionId'], index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaction "${transaction['category']}" deleted; Add a NEW Transaction!')),
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    transaction['category'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    "${(transaction['date'] as DateTime).toLocal()}".split(' ')[0],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    transaction['type'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2).format(transaction['amount']),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: (transaction['type'] == 'Expense' ? Colors.red : Colors.green),
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => _promptEditTransaction(transaction, index),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold),),
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
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(15),
              child: Text(
                'Total Balance: ${NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2).format(_totalBalance)}',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              
            ),
            Expanded(child: _buildTransactionList()),
          ],
          
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _promptAddTransaction,
        child: Icon(Icons.add),
      ),
    );
  }
}
