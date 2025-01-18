import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

class GetUserName {
  final String documentId;
  GetUserName({required this.documentId});

  Future<String> getUserName() async {
    CollectionReference users = FirebaseFirestore.instance.collection('users');
    DocumentSnapshot snapshot = await users.doc(documentId).get();
    
    if (snapshot.exists) {
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      return data['first_name'];
    } else {
      throw Exception('User not found'); // or handle accordingly
    }
  }
}