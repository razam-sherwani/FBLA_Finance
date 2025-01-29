import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GradientService {
  final String userId;
  GradientService({required this.userId});

  Stream<LinearGradient> getGradientStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      if (data != null && data.containsKey('appearance')) {
        final colors = List<Color>.from((data['appearance'] as List<dynamic>)
            .map((color) => Color(color)));
        return LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: colors,
        );
      } else {
        return LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Colors.cyan,
            Colors.teal,
          ],
        );
      }
    });
  }
}
