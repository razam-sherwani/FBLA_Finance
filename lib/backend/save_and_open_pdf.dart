import 'dart:io'; // Provides file system access
import 'package:flutter/services.dart'; // Used for clipboard operations
import 'package:firebase_storage/firebase_storage.dart'; // For uploading files to Firebase Storage
import 'package:pdf/widgets.dart' as pw; // Library for generating PDFs
import 'package:path_provider/path_provider.dart'; // Provides paths to directories on the device
import 'package:open_file/open_file.dart'; // Allows opening files using the device's default apps

// A utility class for saving, opening, uploading, and copying PDF documents.
class SaveAndOpenDocument {
  static Future<File> savePdf({
    required String name,
    required pw.Document pdf,
  }) async {
    // Determine the root directory to save the file
    final root = Platform.isAndroid ? await getExternalStorageDirectory() : await getApplicationDocumentsDirectory();

    // Define the file path using the determined directory
    final file = File('${root!.path}/$name');

    // Write the generated PDF data to the file
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> openPdf(File file) async {
    final path = file.path;
    await OpenFile.open(path);
  }

  // Uploads a PDF file to Firebase Storage and returns the download link.
  static Future<String?> uploadPdfAndGetLink(File pdfFile, String fileName) async {
    try {

      // Create a reference to the Firebase Storage location
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
