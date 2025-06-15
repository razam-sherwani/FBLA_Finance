import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OthersPage extends StatefulWidget {
  final String userId; // Add userId as a parameter

  OthersPage({Key? key, required this.userId}) : super(key: key);

  @override
  _OthersPageState createState() => _OthersPageState();
}

class _OthersPageState extends State<OthersPage> {
  final List<Map<String, dynamic>> _Items = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Call a method to fetch Others from Firestore when the page loads
    _fetchOthers();
  }

  void _fetchOthers() {
    _firestore.collection('users').doc(widget.userId).collection('Others').get().then((querySnapshot) {
      setState(() {
        _Items.clear(); // Clear existing items
        querySnapshot.docs.forEach((doc) {
          _Items.add({
            'taskId': doc.id,
            'task': doc['task'],
            'completed': doc['completed'],
          });
        });
      });
    }).catchError((error) {
      print("Error fetching Others: $error");
      // Handle error gracefully, e.g., show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch Others')));
    });
  }

  void _addItem(String task) {
    if (task.isNotEmpty) {
      _firestore.collection('users').doc(widget.userId).collection('Others').add({
        'task': task,
        'completed': false,
      }).then((value) {
        setState(() {
          _Items.add({
            'taskId': value.id,
            'task': task,
            'completed': false,
          });
        });
      }).catchError((error) => print("Failed to add Other: $error"));
    }
  }

  void _removeItem(String taskId, int index) {
    _firestore.collection('users').doc(widget.userId).collection('Others').doc(taskId).delete().then((value) {
      setState(() {
        _Items.removeAt(index);
      });
    }).catchError((error) => print("Failed to delete Other: $error"));
  }

  Widget _buildList() {
    return _Items.isEmpty
        ? Center(
            child: Text(
              'No Others yet. Add an Other!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          )
        : ListView.builder(
            itemCount: _Items.length,
            itemBuilder: (context, index) {
              return _buildItem(_Items[index], index);
            },
          );
  }

  Widget _buildItem(Map<String, dynamic> item, int index) {
    return Dismissible(
      key: Key(item['taskId']),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _removeItem(item['taskId'], index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Other "${item['task']}" deleted')),
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
            item['task'],
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _promptAddItem() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('New Other'),
          content: TextField(
            autofocus: true,
            onSubmitted: (val) {
              Navigator.of(context).pop();
              _addItem(val);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A4288),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, bottom: 30, left: 24, right: 24),
            decoration: const BoxDecoration(
              color: Color(0xFF2A4288),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
            child: Center(
              child: Text(
                'Others',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(36),
                  topRight: Radius.circular(36),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildList(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _promptAddItem,
        tooltip: 'Add task',
        backgroundColor: const Color(0xFF2A4288),
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
