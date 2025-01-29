import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
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
    final String generatedTime =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    // Load graph and pie chart images
    final Uint8List graph1 = await loadGraphImage('expense_graph.png');
    final Uint8List graph2 = await loadGraphImage('balance_graph.png');
    final Uint8List pieChart = await loadGraphImage('pie_chart.png');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          customHeader(),
          customHeadline("Income:"),
          buildTable(_incomeList),
          pw.SizedBox(height: 20),
          pw.Text("Income Graph:",
              style:
                  pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Image(pw.MemoryImage(graph1)),
          pw.SizedBox(height: 15),
          customHeadline("Expenses:"),
          buildTable(_expenseList),
          pw.SizedBox(height: 20),
          pw.Text("Expense Graph:",
              style:
                  pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Image(pw.MemoryImage(graph2)),
          pw.SizedBox(height: 20),
          pw.Text("Expense Distribution (Pie Chart):",
              style:
                  pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Image(pw.MemoryImage(pieChart)), // Include the pie chart
        ],
        header: (context) => customDocumentHeader(context, generatedTime),
        footer: (context) => buildPageNumber(context),
      ),
    );
    return SaveAndOpenDocument.savePdf(name: 'GeneralReport.pdf', pdf: pdf);
  }

  static pw.Widget customDocumentHeader(
      pw.Context context, String generatedTime) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        buildPageNumber(context),
        pw.Container(
          padding: pw.EdgeInsets.only(top: 10),
          child: pw.Text("Generated: $generatedTime",
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    );
  }

  static Future<File> generateWeeklyPdf(String docId) async {
    _firestore = FirebaseFirestore.instance;
    await _fetchTransactions(docId);

    final pdf = pw.Document();

    Map<int, List<Map<String, dynamic>>> weeklyIncome = {};
    Map<int, List<Map<String, dynamic>>> weeklyExpense = {};

// Populate weeklyIncome and weeklyExpense
    for (var transaction in _incomeList) {
      int week = _getWeekOfYear(DateTime.parse(transaction['date']));
      weeklyIncome.putIfAbsent(week, () => []).add(transaction);
    }

    for (var transaction in _expenseList) {
      int week = _getWeekOfYear(DateTime.parse(transaction['date']));
      weeklyExpense.putIfAbsent(week, () => []).add(transaction);
    }

// Determine the range of weeks to include
    int firstWeek = weeklyIncome.keys.isEmpty
        ? (weeklyExpense.keys.isEmpty
            ? 1
            : weeklyExpense.keys.reduce((a, b) => a < b ? a : b))
        : weeklyIncome.keys.reduce((a, b) => a < b ? a : b);
    int lastWeek = weeklyIncome.keys.isEmpty
        ? (weeklyExpense.keys.isEmpty
            ? 1
            : weeklyExpense.keys.reduce((a, b) => a > b ? a : b))
        : weeklyIncome.keys.reduce((a, b) => a > b ? a : b);

// Include all weeks in the range
    for (int week = firstWeek; week <= lastWeek; week++) {
      weeklyIncome.putIfAbsent(week, () => []);
      weeklyExpense.putIfAbsent(week, () => []);
    }
    var maxWeek = [...weeklyIncome.keys, ...weeklyExpense.keys]
        .reduce((a, b) => a > b ? a : b);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          customHeader(),
          for (var week = 1; week <= maxWeek; week++) ...[
            customHeadline("Week $week Income:"),
            buildTable(weeklyIncome[week] ?? []),
            pw.SizedBox(height: 20),
            customHeadline("Week $week Expense:"),
            buildTable(weeklyExpense[week] ?? []),
            pw.SizedBox(height: 20),
          ],
        ],
      ),
    );

    return SaveAndOpenDocument.savePdf(name: 'WeeklyReport.pdf', pdf: pdf);
  }

  static Future<File> generateMonthlyPdf(String docId) async {
    _firestore = FirebaseFirestore.instance;
    await _fetchTransactions(docId);

    final pdf = pw.Document();

    Map<int, List<Map<String, dynamic>>> monthlyIncome = {};
    Map<int, List<Map<String, dynamic>>> monthlyExpense = {};

    for (var transaction in _incomeList) {
      int month = DateTime.parse(transaction['date']).month;
      monthlyIncome.putIfAbsent(month, () => []).add(transaction);
    }

    for (var transaction in _expenseList) {
      int month = DateTime.parse(transaction['date']).month;
      monthlyExpense.putIfAbsent(month, () => []).add(transaction);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          customHeader(),
          for (var month in monthlyIncome.keys) ...[
            customHeadline("Month $month Income:"),
            buildTable(monthlyIncome[month] ?? []),
            pw.SizedBox(height: 20),
            customHeadline("Month $month Expense:"),
            buildTable(monthlyExpense[month] ?? []),
            pw.SizedBox(height: 20),
          ],
        ],
      ),
    );

    return SaveAndOpenDocument.savePdf(name: 'MonthlyReport.pdf', pdf: pdf);
  }

//   static Future<File> generateYearlyPdf(String docId) async {
//     _firestore = FirebaseFirestore.instance;
//     await _fetchTransactions(docId);

//     final pdf = pw.Document();

//     Map<int, List<Map<String, dynamic>>> yearlyIncome = {};
//     Map<int, List<Map<String, dynamic>>> yearlyExpense = {};

//     for (var transaction in _incomeList) {
//       int year = DateTime.parse(transaction['date']).year;
//       yearlyIncome.putIfAbsent(year, () => []).add(transaction);
//     }

//     for (var transaction in _expenseList) {
//       int year = DateTime.parse(transaction['date']).year;
//       yearlyExpense.putIfAbsent(year, () => []).add(transaction);
//     }

//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         build: (context) => [
//           customHeader(),
//           for (var year in yearlyIncome.keys) ...[
//             customHeadline("Year $year Income:"),
//             buildTable(yearlyIncome[year] ?? []),
//             pw.SizedBox(height: 20),
//             customHeadline("Year $year Expense:"),
//             buildTable(yearlyExpense[year] ?? []),
//             pw.SizedBox(height: 20),
//           ],
//         ],
//       ),
//     );

//     return SaveAndOpenDocument.savePdf(
//         name: 'YearlyReport.pdf', pdf: pdf);
//   }

  static int _getWeekOfYear(DateTime date) {
    // Adjust to the start of the week (Monday)
    DateTime adjustedDate = date.subtract(Duration(days: date.weekday - 1));

    // First week starts on January 4th
    DateTime firstWeekStart = DateTime(date.year, 1, 4)
        .subtract(Duration(days: DateTime(date.year, 1, 4).weekday - 1));

    int weekNumber = 1 + adjustedDate.difference(firstWeekStart).inDays ~/ 7;

    return weekNumber > 0 ? weekNumber : 1;
  }

// Helper function to load images
  static Future<Uint8List> loadGraphImage(String imagePath) async {
    final directory =
        await getApplicationDocumentsDirectory(); // Get the directory path
    final file =
        File('${directory.path}/$imagePath'); // Construct the file path

    try {
      return await file.readAsBytes(); // Read the file and return the bytes
    } catch (e) {
      throw Exception('Failed to load image: $e');
    }
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
          'date': (doc['date'] as Timestamp)
              .toDate()
              .toLocal()
              .toString()
              .split(' ')[0],
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

      // Sort the lists by date (oldest to newest)
      _transactionsList.sort((a, b) =>
          DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
      _incomeList.sort((a, b) =>
          DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
      _expenseList.sort((a, b) =>
          DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
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
        alignment: pw.Alignment.topLeft,
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
