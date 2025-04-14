import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptScanner extends StatefulWidget {
  const ReceiptScanner({super.key});

  @override
  State<ReceiptScanner> createState() => _ReceiptScannerPage();
}

class _ReceiptScannerPage extends State<ReceiptScanner> {
  String? total;
  String? merchant;
  bool loading = false;
  final textRecognizer = TextRecognizer();

  @override
  void dispose() {
    textRecognizer.close();
    super.dispose();
  }

  Future<void> scanReceipt({required ImageSource source}) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;

    setState(() => loading = true);

    final file = File(picked.path);
    final inputImage = InputImage.fromFile(file);
    final recognizedText = await textRecognizer.processImage(inputImage);

    if (recognizedText.text.isNotEmpty) {
      // Simple parsing logic - you might need to adjust this based on your receipt format
      final lines = recognizedText.text.split('\n');
      String? foundTotal;
      String? foundMerchant;

      for (var line in lines) {
        // Look for total amount (usually contains currency symbol)
        if (line.contains('\$') || line.contains('€') || line.contains('₺')) {
          foundTotal = line;
        }
        // Look for merchant name (usually at the top)
        if (foundMerchant == null && line.isNotEmpty) {
          foundMerchant = line;
        }
      }

      setState(() {
        total = foundTotal;
        merchant = foundMerchant;
      });

      await FirebaseFirestore.instance.collection('receipts').add({
        'total': total,
        'merchant': merchant,
        'timestamp': FieldValue.serverTimestamp(),
        'rawText': recognizedText.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt saved to Firestore')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read receipt')),
      );
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan Receipt')),
      body: Center(
        child: loading
            ? CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => scanReceipt(source: ImageSource.camera),
                        child: Text('Take Photo'),
                      ),
                      SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () => scanReceipt(source: ImageSource.gallery),
                        child: Text('Choose from Gallery'),
                      ),
                    ],
                  ),
                  if (merchant != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text('Merchant: $merchant'),
                    ),
                  if (total != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Total: $total'),
                    ),
                ],
              ),
      ),
    );
  }
}
