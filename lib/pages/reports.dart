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
import '../util/profile_picture.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/services.dart';
import 'dart:io';

const double kAppBarHeight = 75;
const Color kAppBarColor = Color(0xFF2A4288);
const TextStyle kAppBarTextStyle = TextStyle(
  fontFamily: 'Barlow',
  fontWeight: FontWeight.bold,
  fontSize: 28,
  color: Colors.white,
);

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
    String selectedName = 'General';
    await showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'Select PDF Type',
                    style: GoogleFonts.barlow(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2A4288),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ...['General', 'Weekly', 'Monthly'].map((option) {
                  IconData icon;
                  Color color;
                  if (option == 'General') {
                    icon = Icons.description_outlined;
                    color = Color(0xff39baf9);
                  } else if (option == 'Weekly') {
                    icon = Icons.calendar_view_week;
                    color = Color(0xff55e6c1);
                  } else {
                    icon = Icons.calendar_today;
                    color = Color(0xff133164);
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14.0),
                    child: Material(
                      color: color.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          selectedName = option;
                          Navigator.pop(context, option);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Icon(icon, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                option,
                                style: GoogleFonts.barlow(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
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
  final Color bgColor = Colors.white;
  final user = FirebaseAuth.instance.currentUser;
  final userId = user?.uid ?? '';

  return Scaffold(
    backgroundColor: kAppBarColor,
    appBar: AppBar(
      toolbarHeight: kAppBarHeight,
      backgroundColor: kAppBarColor,
      elevation: 0,
      centerTitle: true,
      title: Padding(
        padding: const EdgeInsets.only(bottom: 15.0),
        child: Text(
          "Reports",
          style: kAppBarTextStyle,
        ),
      ),
      actions: [
        if (userId.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 10.0, top: 8),
            child: ProfilePicture(userId: userId),
          ),
      ],
    ),
    body: Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(50),
          topRight: Radius.circular(50),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        children: [
          // Balance display
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 30),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2)
                    .format(_totalBalance),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          // Report options
          _buildReportCard(
            context,
            icon: Icons.description_outlined,
            title: "General Report",
            subtitle: "Overview of all your transactions.",
            color: Color(0xff39baf9),
            onTap: () async {
              final paragraphPdf = await ParagraphPdfApi.generateParagraphPdf(docID);
              SaveAndOpenDocument.openPdf(paragraphPdf);
            },
          ),
          const SizedBox(height: 18),
          _buildReportCard(
            context,
            icon: Icons.calendar_view_week,
            title: "Weekly Report",
            subtitle: "See your weekly spending and income.",
            color: Color(0xff55e6c1),
            onTap: () async {
              final paragraphPdf = await ParagraphPdfApi.generateWeeklyPdf(docID);
              SaveAndOpenDocument.openPdf(paragraphPdf);
            },
          ),
          const SizedBox(height: 18),
          _buildReportCard(
            context,
            icon: Icons.calendar_today,
            title: "Monthly Report",
            subtitle: "Track your monthly financial trends.",
            color: Color.fromARGB(255, 40, 102, 210),
            onTap: () async {
              final paragraphPdf = await ParagraphPdfApi.generateMonthlyPdf(docID);
              SaveAndOpenDocument.openPdf(paragraphPdf);
            },
          ),
          const SizedBox(height: 18),
          _buildReportCard(
            context,
            icon: Icons.share,
            title: "Share PDF Link",
            subtitle: "Copy a shareable link to your report.",
            color: Color(0xff39baf9),
            onTap: sharePdfLink,
          ),
        ],
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

Widget _buildReportCard(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.13),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.18), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(14),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.barlow(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.barlow(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 22),
          ],
        ),
      ),
    ),
  );
}
}

