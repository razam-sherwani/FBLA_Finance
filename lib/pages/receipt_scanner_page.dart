import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class ReceiptScanner extends StatefulWidget {
  const ReceiptScanner({super.key});

  @override
  _ReceiptScanner createState() => _ReceiptScanner();
}

class _ReceiptScanner extends State<ReceiptScanner> {
  File? _imageFile;

  Future<void> _pickImage() async {
    final PickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (PickedFile != null) {
      setState(() {
        _imageFile = File(PickedFile.path);
      });
    } else {
      print('No image selected.');
      _processImage();
    }
  }

  Future<void> _processImage() async {
    final inputImage = InputImage.fromFilePath(_imageFile!.path);
    final textRecognizer = TextRecognizer();
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    String extractedText = recognizedText.text;
    print(extractedText);
    }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Receipt Scanner'),
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _imageFile == null ? Text('Select an image to analyze.') : Image.file(_imageFile!),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _pickImage,
                  child: Text('Select Image'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}