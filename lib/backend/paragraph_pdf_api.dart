import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:fbla_finance/backend/save_and_open_pdf.dart';

class ParagraphPdfApi {
  static Future<File> generateParagraphPdf(String docId) async {
    final pdf = pw.Document();
    final userId = docId;

    final transcripts = await fetchTranscripts(userId);
    final awards = await fetchAwards(userId);
    final extracurriculars = await fetchEcs(userId);
    final clubs = await fetchClubs(userId);
    final others = await fetchOthers(userId);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          customHeader(),
          customHeadline("Semester Report Cards:"),
          buildTranscriptSection(transcripts),
          customHeadline("Awards:"),
          buildBulletPoints(awards),
          customHeadline("Extracurriculars:"),
          buildBulletPoints(extracurriculars),
          customHeadline("Clubs:"),
          buildBulletPoints(clubs),
          customHeadline("Other:"),
          buildBulletPoints(others),
        ],
        header: (context) => buildPageNumber(context),
        footer: (context) => buildPageNumber(context),
      ),
    );
    return SaveAndOpenDocument.savePdf(name: 'ScholarSpherePortfolio.pdf', pdf: pdf);
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
              'Scholar Sphere Portfolio',
              style: pw.TextStyle(fontSize: 40, color: PdfColors.blue, fontWeight: pw.FontWeight.bold),

            ),
            
          ],
        ),
      );

  static pw.Widget customHeadline(String str) => pw.Header(
        child: pw.Text(
          str,
          style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
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

  static pw.Widget buildBulletPoints(List<String> points) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: points
          .map((point) => pw.Bullet(
                text: point,
                style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
              ))
          .toList(),
    );
  }

  static pw.Widget buildTranscriptSection(List<Map<String, List<String>>> transcripts) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: transcripts.map((transcript) {
        final fileName = transcript['fileName']![0];
        final grades = transcript['grades']!;
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(fileName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ...grades.map((grade) => pw.Bullet(
                  text: grade,
                  style: pw.TextStyle(fontSize: 15),
                )),
          ],
        );
      }).toList(),
    );
  }

  static Future<List<Map<String, List<String>>>> fetchTranscripts(String userId) async {
    List<Map<String, List<String>>> transcripts = [];
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('transcripts')
        .get()
        .then((querySnapshot) {
      for (var doc in querySnapshot.docs) {
        List<String> grades = List<String>.from(doc['grades']);
        transcripts.add({'fileName': [doc['fileName']], 'grades': grades});
      }
    });
    return transcripts;
  }

  static Future<List<String>> fetchAwards(String userId) async {
    List<String> awards = [];
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('awards')
        .get()
        .then((querySnapshot) {
      for (var doc in querySnapshot.docs) {
        awards.add(doc['task']);
      }
    });
    return awards;
  }

  static Future<List<String>> fetchEcs(String userId) async {
    List<String> extracurriculars = [];
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('Ecs')
        .get()
        .then((querySnapshot) {
      for (var doc in querySnapshot.docs) {
        extracurriculars.add(doc['task']);
      }
    });
    return extracurriculars;
  }

  static Future<List<String>> fetchClubs(String userId) async {
    List<String> clubs = [];
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('Clubs')
        .get()
        .then((querySnapshot) {
      for (var doc in querySnapshot.docs) {
        clubs.add(doc['task']);
      }
    });
    return clubs;
  }

  static Future<List<String>> fetchOthers(String userId) async {
    List<String> others = [];
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('Others')
        .get()
        .then((querySnapshot) {
      for (var doc in querySnapshot.docs) {
        others.add(doc['task']);
      }
    });
    return others;
  }
}
