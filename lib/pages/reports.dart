import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_finance/pages/chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:fbla_finance/backend/auth.dart';
import 'package:fbla_finance/backend/paragraph_pdf_api.dart';
import 'package:fbla_finance/backend/read_data/get_user_name.dart';
import 'package:fbla_finance/backend/save_and_open_pdf.dart';
import 'package:fbla_finance/util/gradient_service.dart';
import 'package:fbla_finance/util/profile_picture.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class Reports extends StatefulWidget {
  const Reports({super.key});

  @override
  State<Reports> createState() => _ReportsState();
}

class _ReportsState extends State<Reports> {
  double _totalBalance = 0.0;
  final User? user = Auth().currentUser;
  String docID = "";
  var now = DateTime.now();
  List<Color> colors = [Color(0xffB8E8FF), Colors.blue.shade900];
  var formatter = DateFormat.yMMMMd('en_US');
  String? formattedDate;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    formattedDate = formatter.format(now);
    fetchDocID();
  }

  Future<void> fetchDocID() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          setState(() {
            docID = snapshot.docs[0].id;
          });
        } else {
          setState(() {
            docID = '';
          });
        }
      }).catchError((error) {
        print('Error fetching docID: $error');
        setState(() {
          docID = '';
        });
      });
    }
    calculateTotalBalance();
  }

  Future<void> calculateTotalBalance() async {
    _firestore
        .collection('users')
        .doc(docID)
        .collection('Transactions')
        .get()
        .then((querySnapshot) {
      setState(() {
        _totalBalance = 0.0;
        querySnapshot.docs.forEach((doc) {
          var transaction = {
            'transactionId': doc.id,
            'amount': doc['amount'],
            'type': doc['type'],
            'category': doc['category'],
            'date': (doc['date'] as Timestamp).toDate(),
          };
          //_transactionsList.add(transaction);
          if (transaction['type'] == 'Income') {
            _totalBalance += transaction['amount'];
          } else {
            _totalBalance -= transaction['amount'];
          }
        });
      });
    }).catchError((error) {
      print("Error fetching transactions: $error");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch transactions')));
    });
  }

  Future<void> sharePdfLink() async {
    // Show dialog to select the name type
    String selectedName = 'General'; // Default value
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select PDF Type'),
          content: DropdownButton<String>(
            value: selectedName,
            items: ['General', 'Weekly', 'Monthly'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                selectedName = newValue;
                Navigator.pop(context); // Close dialog when a selection is made
              }
            },
          ),
        );
      },
    );

    // Generate the PDF with the selected name
    var paragraphPdf;
    if (selectedName == 'General') {
      paragraphPdf = await ParagraphPdfApi.generateParagraphPdf(docID);
    } else if (selectedName == 'Weekly') {
      paragraphPdf = await ParagraphPdfApi.generateWeeklyPdf(docID);
    } else if (selectedName == 'Monthly') {
      paragraphPdf = await ParagraphPdfApi.generateMonthlyPdf(docID);
    }
    final pdfFileName = selectedName + 'Report.pdf';
    final downloadUrl = await SaveAndOpenDocument.uploadPdfAndGetLink(
        paragraphPdf, pdfFileName);

    if (downloadUrl != null) {
      SaveAndOpenDocument.copyToClipboard(downloadUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF link copied to clipboard!')),
      );
      print('Download URL: $downloadUrl');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload PDF')),
      );
    }
  }

  // Future<void> shareToInstagramStory() async {
  //   final paragraphPdf = await ParagraphPdfApi.generateParagraphPdf(docID);
  //   final pdfFileName = 'ScholarSpherePortfolio.pdf';
  //   final downloadUrl = await SaveAndOpenDocument.uploadPdfAndGetLink(
  //       paragraphPdf, pdfFileName);

  //   if (downloadUrl != null) {
  //     SaveAndOpenDocument.copyToClipboard(downloadUrl);
  //     final imagePath = 'assets/Scholar_Sphere_Insta.png';

  //     try {
  //       final directory = await getApplicationDocumentsDirectory();
  //       final imageFile = File('${directory.path}/Scholar_Sphere_Insta.png');
  //       await imageFile.writeAsBytes(
  //           (await rootBundle.load(imagePath)).buffer.asUint8List());

  //       final xFile = XFile(imageFile.path);

  //       await Share.shareXFiles([xFile], text: downloadUrl);
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Image shared to Instagram story!')),
  //       );
  //     } catch (e) {
  //       print('Error sharing to Instagram: $e');
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Failed to share to Instagram story')),
  //       );
  //     }
  //   } else {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to upload PDF')),
  //     );
  //   }
  // }

  Future<String> fetchPortfolioData() async {
    String userId = docID;
    StringBuffer portfolioData = StringBuffer();
    portfolioData.write("Check Out My Scholar Sphere Portfolio!\n");
    // Fetch transcripts
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('transcripts')
        .get()
        .then((querySnapshot) {
      portfolioData.writeln('Semester Report Cards:');
      for (var doc in querySnapshot.docs) {
        List<String> grades = List<String>.from(doc['grades']);
        portfolioData.writeln('\n ${doc['fileName']}: ${grades.join('\n')}');
      }
    });
    portfolioData.writeln('\n');
    // Fetch awards
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('awards')
        .get()
        .then((querySnapshot) {
      portfolioData.writeln('Awards:');
      for (var doc in querySnapshot.docs) {
        portfolioData.writeln(' - ${doc['task']}');
      }
    });
    portfolioData.writeln('\n');
    // Fetch extracurriculars (Ecs)
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('Ecs')
        .get()
        .then((querySnapshot) {
      portfolioData.writeln('Extracurriculars:');
      for (var doc in querySnapshot.docs) {
        portfolioData.writeln(' - ${doc['task']}');
      }
    });
    portfolioData.writeln('\n');
    // Fetch clubs
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('Clubs')
        .get()
        .then((querySnapshot) {
      portfolioData.writeln('Clubs:');
      for (var doc in querySnapshot.docs) {
        portfolioData.writeln(' - ${doc['task']}');
      }
    });
    portfolioData.writeln('\n');
    // Fetch others
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('Others')
        .get()
        .then((querySnapshot) {
      portfolioData.writeln('Other:');
      for (var doc in querySnapshot.docs) {
        portfolioData.writeln(' - ${doc['task']}');
      }
    });
    portfolioData.writeln('\n');

    return portfolioData.toString();
  }

  void sharePortfolio() async {
    String portfolioData = await fetchPortfolioData();
    await Share.share(portfolioData);
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    body: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xffB8E8FF), // Light blue
            Colors.white,             // White
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with time and title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    "Reports",
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.black,
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Balance display
            Center(
              child: Container(
                padding: const EdgeInsets.only(left: 4),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20), // Adjust for desired roundness
                        gradient: const LinearGradient(
                                  colors: [
                                    Color.fromRGBO(132, 255, 201, 1), // hsla(154, 100%, 76%)
                                    Color.fromRGBO(170, 178, 255, 1), // hsla(234, 100%, 83%)
                                    Color.fromRGBO(255, 97, 246, 1),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),

                        boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 3),
                      )],
                      ),
                      child: Text(
                        NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2)
                .format(_totalBalance),
                        style: GoogleFonts.ibmPlexSans(
              fontSize: 50,
              fontWeight: FontWeight.bold,
              color: Colors.white, // Ensure text is visible on white
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Spacer to push options down slightly
            const SizedBox(height: 80),
            
            // Floating report options
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildFloatingOption(
                    icon: Icons.description,
                    title: "Generate General Report",
                    onTap: () async {
                      final paragraphPdf = await ParagraphPdfApi.generateParagraphPdf(docID);
                      SaveAndOpenDocument.openPdf(paragraphPdf);
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  _buildFloatingOption(
                    icon: Icons.calendar_view_week,
                    title: "Generate Weekly Report",
                    onTap: () async {
                      final paragraphPdf = await ParagraphPdfApi.generateWeeklyPdf(docID);
                      SaveAndOpenDocument.openPdf(paragraphPdf);
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  _buildFloatingOption(
                    icon: Icons.calendar_today,
                    title: "Generate Monthly Report",
                    onTap: () async {
                      final paragraphPdf = await ParagraphPdfApi.generateMonthlyPdf(docID);
                      SaveAndOpenDocument.openPdf(paragraphPdf);
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  _buildFloatingOption(
                    icon: Icons.share,
                    title: "Share PDF Link",
                    onTap: sharePdfLink,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatScreen()),
        );
      },
      child: const Icon(Icons.chat),
      backgroundColor: Colors.blue.shade900,
      foregroundColor: Colors.white,
    ),
  );
}

Widget _buildFloatingOption({
  required IconData icon,
  required String title,
  required VoidCallback onTap,
}) {
  return Material(
    elevation: 2,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Colors.blue.shade900),
            const SizedBox(width: 20),
            Text(
              title,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 21,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    ),
  );
}
}
