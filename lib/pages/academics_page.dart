import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class AcademicsPage extends StatefulWidget {
  final String userId;

  AcademicsPage({Key? key, required this.userId}) : super(key: key);

  @override
  _AcademicsPageState createState() => _AcademicsPageState();
}

class _AcademicsPageState extends State<AcademicsPage> {
  final List<Map<String, dynamic>> _transcripts = [];
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchTranscripts();
  }

  void _fetchTranscripts() {
    // Fetch transcripts from Firestore
    _firestore.collection('users').doc(widget.userId).collection('transcripts').get().then((querySnapshot) {
      setState(() {
        _transcripts.clear(); // Clear existing items
        querySnapshot.docs.forEach((doc) {
          _transcripts.add({
            'fileName': doc['fileName'],
            'grades': List<String>.from(doc['grades']),
          });
        });
      });
    }).catchError((error) {
      print("Error fetching transcripts: $error");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch transcripts')));
    });
  }

  Future<void> _pickTranscript() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);

      setState(() {
        _transcripts.add({
          'file': file,
          'text': '',
          'grades': <String>[],
        });
      });

      await _uploadTranscript(file);
      await _extractTextAndGrades(file);
    }
  }

  Future<void> _uploadTranscript(File file) async {
    try {
      String fileName = 'transcripts/${DateTime.now().millisecondsSinceEpoch}.pdf';
      Reference storageRef = _storage.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(file);

      await uploadTask.whenComplete(() => null);
      String fileURL = await storageRef.getDownloadURL();

      print('File uploaded to Firebase Storage: $fileURL');
    } catch (e) {
      print('Error uploading transcript: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload transcript')));
    }
  }

  Future<void> _extractTextAndGrades(File file) async {
    try {
      // Load the PDF document
      final PdfDocument document = PdfDocument(inputBytes: file.readAsBytesSync());

      // Extract text from all the pages
      String text = PdfTextExtractor(document).extractText();
      document.dispose();

      List<String> grades = _extractGrades(text);

      setState(() {
        _transcripts.last['text'] = text;
        _transcripts.last['grades'] = grades;
      });

      print('Extracted text: $text');
      print('Extracted grades: $grades');

      await _saveGradesToFirestore(file.path.split('/').last, grades);
    } catch (e) {
      print('Error extracting text: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to extract text from transcript')));
    }
  }

  Future<void> _saveGradesToFirestore(String fileName, List<String> grades) async {
    try {
      await _firestore.collection('users').doc(widget.userId).collection('transcripts').add({
        'fileName': fileName,
        'grades': grades,
      });
    } catch (e) {
      print('Error saving grades to Firestore: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save grades')));
    }
  }

  List<String> _extractGrades(String text) {
    List<String> grades = [];
    // Updated regular expression to capture complex course titles
    RegExp gradePattern = RegExp(r'(.+?)\s+\d+\s+\d+\s+\d+\s+(\d+)\s+Self-Direction');

    Iterable<RegExpMatch> matches = gradePattern.allMatches(text);

    for (var match in matches) {
      String course = match.group(1)!.trim();
      int newlineIndex = course.lastIndexOf('\n');

      if (newlineIndex != -1) {
        course = course.substring(newlineIndex + 1);
      }

      String grade = match.group(2)!.trim();
      grades.add('$course: $grade');
    }

    return grades;
  }

  void _removeTranscript(int index) {
    setState(() {
      _transcripts.removeAt(index);
    });
    // Remove from Firebase Storage or Firestore if needed
  }

  Widget _buildList() {
    return _transcripts.isEmpty
        ? Center(
            child: Text(
              'No transcripts yet. Upload a transcript!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          )
        : ListView.builder(
            itemCount: _transcripts.length,
            itemBuilder: (context, index) {
              return _buildItem(_transcripts[index], index);
            },
          );
  }

  Widget _buildItem(Map<String, dynamic> item, int index) {
    return Dismissible(
      key: Key(item['fileName'] ?? item['file'].path),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _removeTranscript(index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transcript deleted')),
        );
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        elevation: 4,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: ListTile(
          title: Text(
            item['fileName'] ?? item['file'].path.split('/').last,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Extracted Grades:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...item['grades'].map((grade) => Text(grade)).toList(),
            ],
          ),
        ),
      ),
    );
  }

  void _promptAddItem() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('New Transcript'),
          content: Text('Upload a new transcript to add it to your academic records.'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Upload'),
              onPressed: () {
                Navigator.of(context).pop();
                _pickTranscript();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Academics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            stops: [0.3, 0.6, 0.9],
            colors: [
              Color(0xff56018D),
              Color(0xff8B139C),
              Colors.pink,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _promptAddItem,
        tooltip: 'Upload transcript',
        backgroundColor: Colors.amber,
        child: Icon(Icons.add),
      ),
    );
  }
}
