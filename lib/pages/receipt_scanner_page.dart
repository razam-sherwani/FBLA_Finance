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
  String? date;
  bool loading = false;

  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

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

    if (recognizedText.blocks.isNotEmpty) {
      List<TextLine> allLines = recognizedText.blocks.expand((b) => b.lines).toList();

      // Sort lines top-to-bottom
      allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

      String? foundMerchant;
      String? foundTotal;
      String? foundDate;

      // === Patterns ===
      final keywordTotalRegex = RegExp(
        r'(total|amount due|subtotal)[^\d]*([\$€₺]?\s*\d+[.,]?\d*)',
        caseSensitive: false,
      );
      final looseMoneyRegex = RegExp(r'[\$€₺]?\s*\d{1,5}[.,]\d{2}'); // e.g., $12.50 or 12.50
      final dateRegex = RegExp(
        r'\b\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}\b' // e.g. 04/05/2024
        r'|\b\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}\b'   // e.g. 2024-04-05
        r'|\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},\s+\d{4}\b',
        caseSensitive: false,
      );
      final merchantRegex = RegExp(r'[A-Za-z]{2,}');

      for (int i = 0; i < allLines.length; i++) {
        final line = allLines[i].text.trim();

        // Merchant - first valid alphabetic line
        if (foundMerchant == null &&
            i < 6 &&
            merchantRegex.hasMatch(line) &&
            !RegExp(r'^\d+$').hasMatch(line)) {
          foundMerchant = line;
        }

        // Total - keyword-based match
        if (foundTotal == null && keywordTotalRegex.hasMatch(line)) {
          foundTotal = keywordTotalRegex.firstMatch(line)?.group(2)?.trim();
        }

        // Date - standard or word-based formats
        if (foundDate == null && dateRegex.hasMatch(line)) {
          foundDate = dateRegex.firstMatch(line)?.group(0)?.trim();
        }
      }

      // Fallback total detection – pick the largest dollar value
      if (foundTotal == null) {
        double maxValue = 0.0;
        for (var line in allLines) {
          final matches = looseMoneyRegex.allMatches(line.text);
          for (final match in matches) {
            final raw = match.group(0)?.replaceAll(RegExp(r'[^\d.,]'), '') ?? '';
            final cleaned = raw.replaceAll(',', '.');
            final value = double.tryParse(cleaned);
            if (value != null && value > maxValue) {
              maxValue = value;
              foundTotal = match.group(0)?.trim();
            }
          }
        }
      }

      setState(() {
        total = foundTotal;
        merchant = foundMerchant;
        date = foundDate;
      });

      await FirebaseFirestore.instance.collection('receipts').add({
        'total': total,
        'merchant': merchant,
        'date': date,
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
                  if (date != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Date: $date'),
                    ),
                ],
              ),
      ),
    );
  }
}
