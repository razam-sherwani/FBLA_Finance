import 'package:flutter/material.dart';

class Transactions extends StatefulWidget{
  @override
  State<Transactions> createState() => _TransactionState();
}

class _TransactionState extends State<Transactions> {
  final List<Map<String, dynamic>> _transactionsList = [];

  void _addTransaction(double amount, String type, String category, String date) {
    if(!amount.isNaN) {
      setState(() => _transactionsList.add({'amount' : amount, 'type' : type, 'category' : category, 'date' : date}));
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
          content: TextField(
            autofocus: true,
          )
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
          SnackBar(content: Text('Task "${todoItem['task']}" deleted; Add a NEW Task!')),
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
        title: Text('Income/Expenses', style: TextStyle(fontWeight: FontWeight.bold),),
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