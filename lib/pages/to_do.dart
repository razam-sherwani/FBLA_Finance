import 'package:flutter/material.dart';

class ToDoList1 extends StatefulWidget {
  @override
  _TodoListState createState() => _TodoListState();
}

class _TodoListState extends State<ToDoList1> {
  final List<Map<String, dynamic>> _todoItems = [];

  void _addTodoItem(String task) {
    if (task.isNotEmpty) {
      setState(() => _todoItems.add({'task': task, 'completed': false}));
    }
  }

  void _removeTodoItem(int index) {
    setState(() => _todoItems.removeAt(index));
  }

  void _toggleTodoItem(int index) {
    setState(() {
      _todoItems[index]['completed'] = !_todoItems[index]['completed'];
    });
  }

  void _promptAddTodoItem() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('New Task'),
          content: TextField(
            autofocus: true,
            onSubmitted: (val) {
              Navigator.of(context).pop();
              _addTodoItem(val);
            },
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
  }

  Widget _buildTodoItem(Map<String, dynamic> todoItem, int index) {
    return Dismissible(
      key: Key(todoItem['task']),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _removeTodoItem(index);
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
          leading: Checkbox(
            value: todoItem['completed'],
            onChanged: (bool? value) {
              _toggleTodoItem(index);
            },
          ),
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

  Widget _buildTodoList() {
    return ListView.builder(
      itemCount: _todoItems.length,
      itemBuilder: (context, index) {
        return _buildTodoItem(_todoItems[index], index);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('To-Do List', style: TextStyle(fontWeight: FontWeight.bold),),
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
          child: _todoItems.isEmpty
              ? Center(
                  child: Text(
                    'No tasks just yet. Add a task!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                    ),
                  ),
                )
              : _buildTodoList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _promptAddTodoItem,
        tooltip: 'Add a task',
        backgroundColor: const Color.fromARGB(255, 252, 192, 12),
        child: Icon(Icons.add),
      ),
    );
  }
}
