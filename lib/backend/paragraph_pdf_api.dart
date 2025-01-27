import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:fbla_finance/backend/save_and_open_pdf.dart';

class ParagraphPdfApi {
  static List<Map<String, dynamic>> _transactionsList = [];
  static List<Map<String, dynamic>> _incomeList = [];
  static List<Map<String, dynamic>> _expenseList = [];
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static double _totalBalance = 0.0;

  static Future<File> generateParagraphPdf(String docId) async {
    _firestore = FirebaseFirestore.instance;
    await _fetchTransactions(docId);
    final pdf = pw.Document();
    final userId = docId;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          customHeader(),
          customHeadline("Income:"),
          buildTable(_incomeList),
          customHeadline("Expenses:"),
          buildTable(_expenseList),
        ],
        header: (context) => buildPageNumber(context),
        footer: (context) => buildPageNumber(context),
      ),
    );
    return SaveAndOpenDocument.savePdf(
        name: 'ScholarSpherePortfolio.pdf', pdf: pdf);
  }

  static Future<void> _fetchTransactions(String docID) async {
  try {
    // Await the Firestore query to ensure completion before moving forward
    final querySnapshot = await _firestore
        .collection('users')
        .doc(docID)
        .collection('Transactions')
        .get();

    // Clear lists and reset total balance
    _transactionsList.clear();
    _incomeList.clear();
    _expenseList.clear();
    _totalBalance = 0.0;

    // Process documents and populate lists
    for (var doc in querySnapshot.docs) {
      // Extract type separately
      String type = doc['type'];

      // Create a transaction map excluding the 'type'
      var transaction = {
        'category': doc['category'],
        'amount': doc['amount'],
        'date': (doc['date'] as Timestamp).toDate().toLocal().toString().split(' ')[0],
      };

      // Add to the main list
      _transactionsList.add(transaction);

      // Add to income or expense lists based on type
      if (type == 'Income') {
        _totalBalance += transaction['amount'];
        _incomeList.add(transaction);
      } else {
        _totalBalance -= transaction['amount'];
        _expenseList.add(transaction);
      }
    }
  } catch (error) {
    print("Error fetching transactions: $error");
    // Handle the error appropriately (e.g., show a snackbar)
  }
}



  static pw.Widget customHeader() => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 3 * PdfPageFormat.mm),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(width: 2, color: PdfColors.blue),
          ),
        ),
        child: pw.Row(
          children: [
            pw.PdfLogo(),
            pw.SizedBox(width: 0.5 * PdfPageFormat.cm),
            pw.Text(
              'FinSafe Report',
              style: pw.TextStyle(
                  fontSize: 40,
                  color: PdfColors.blue,
                  fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );

  static pw.Widget customHeadline(String str) => pw.Header(
        child: pw.Text(
          str,
          style: pw.TextStyle(
              fontSize: 30,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white),
        ),
        padding: const pw.EdgeInsets.all(8.0),
        decoration: const pw.BoxDecoration(color: PdfColors.red),
      );

  static pw.Widget buildPageNumber(pw.Context context) => pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
      );

  static pw.Widget buildBulletPoints(List<Map<String, dynamic>> points) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: points.map((point) {
        final transactionId = point['transactionId'];
        final amount = point['amount'];
        final type = point['type'];
        final category = point['category'];
        final date = point['date'];

        return pw.Bullet(
          text:
              'ID: $transactionId, Amount: $amount, Type: $type, Category: $category, Date: $date',
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        );
      }).toList(),
    );
  }

  static Future<List<String>> fetch(String userId, String item) async {
    List<String> awards = [];
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection(item)
        .get()
        .then((querySnapshot) {
      for (var doc in querySnapshot.docs) {
        awards.add(doc['task']);
      }
    });
    return awards;
  }

  static pw.Widget buildTable(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return pw.Text('No data available', style: pw.TextStyle(fontSize: 15));
    }

    // Extract headers from the first map
    final headers = data.first.keys.toList();

    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: const PdfColor(0.9, 0.9, 0.9)),
          children: headers
              .map((header) => pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      header.toString(),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ))
              .toList(),
        ),
        // Data rows
        ...data.map((row) {
          return pw.TableRow(
            children: headers.map((header) {
              final value = row[header] ?? '';
              return pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  value.toString(),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }
}
