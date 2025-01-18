import 'dart:io';
import 'package:flutter/services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class SaveAndOpenDocument {
  static Future<File> savePdf({
    required String name,
    required pw.Document pdf,
  }) async {
    final root = Platform.isAndroid ? await getExternalStorageDirectory() : await getApplicationDocumentsDirectory();
    final file = File('${root!.path}/$name');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> openPdf(File file) async {
    final path = file.path;
    await OpenFile.open(path);
  }

  static Future<String?> uploadPdfAndGetLink(File pdfFile, String fileName) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('pdfs/$fileName');
      final uploadTask = storageRef.putFile(pdfFile);

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading PDF: $e');
      return null;
    }
  }

  static void copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }
}
