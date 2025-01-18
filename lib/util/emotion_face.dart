import 'package:flutter/material.dart';

class EmotionFace extends StatelessWidget {
  final String emoticanFace;
  const EmotionFace(
    {
      Key? key,
      required this.emoticanFace
    }
    );
   

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.grey[350], borderRadius: BorderRadius.circular(12),
          border: Border.all(width: 2,color: Colors.black)
          ),
      padding: const EdgeInsets.all(16),
      child: Text(
        emoticanFace,
        style: TextStyle(fontSize: 28),
        ),
    );
  }
}
