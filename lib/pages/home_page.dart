import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_finance/pages/chat_screen.dart';
import 'package:fbla_finance/pages/filter_by_amount.dart';
import 'package:fbla_finance/pages/filter_by_category.dart';
import 'package:fbla_finance/pages/filter_by_date.dart';
import 'package:fbla_finance/pages/filter_by_type.dart';
import 'package:fbla_finance/pages/transactions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fbla_finance/backend/read_data/get_user_name.dart';
import 'package:fbla_finance/pages/academics_page.dart';
import 'package:fbla_finance/pages/awards_page.dart';
import 'package:fbla_finance/pages/clubs_page.dart';
import 'package:fbla_finance/pages/ec_page.dart';
import 'package:fbla_finance/pages/other_page.dart';
import 'package:fbla_finance/util/filter_tile.dart';
import 'package:fbla_finance/home_page_with_nav.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fbla_finance/backend/auth.dart';
import 'package:fbla_finance/util/gradient_service.dart';
import 'package:fbla_finance/util/profile_picture.dart';
import 'package:fbla_finance/pages/spending_habit.dart';

double public_bal = 0;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Map<String, dynamic>> _transactionsList = [];
  int myIndex = 0;
  bool _isLoading = true;
  final User? user = Auth().currentUser;
  List<Color> colors = [Color(0xffB8E8FF), Colors.blue.shade900];
  var now = DateTime.now();
  var formatter = DateFormat.yMMMMd('en_US');
  String? formattedDate;
  String docID = "6cHwPquSMMkpue7r6RRN";
  double _totalBalance = 0.0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime date = DateTime.now();
  double amt = 0;
  String? type1;
  String? categ;

  @override
  void initState() {
    super.initState();
    _initializeData();
    formattedDate = formatter.format(now);
  }

  Future<void> _initializeData() async {
    await fetchDocID(); // Wait for fetchDocID to complete
    await _fetchTransactions(); // Call _fetchTransactions after fetchDocID
  }

  Future<void> fetchDocID() async {
    setState(() => _isLoading = true);

    try {
      var user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        var snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: user.email)
            .get();

        if (snapshot.docs.isNotEmpty) {
          setState(() {
            docID = snapshot.docs[0].id;
          });

          // Only fetch data once docID is valid
          await _fetchTransactions();
          await calculateTotalBalance();
        } else {
          setState(() {
            docID = '';
          });
        }
      }
    } catch (e) {
      print('Error in fetchDocID: $e');
      setState(() {
        docID = '';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> calculateTotalBalance() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(docID)
          .collection('Transactions')
          .get();

      double total = 0.0;
      for (var doc in querySnapshot.docs) {
        var transaction = {
          'transactionId': doc.id,
          'amount': doc['amount'],
          'type': doc['type'],
          'category': doc['category'],
          'date': (doc['date'] as Timestamp).toDate(),
        };
        if (transaction['type'] == 'Income') {
          total += transaction['amount'];
        } else {
          total -= transaction['amount'];
        }
      }
      setState(() {
        _totalBalance = total;
        public_bal = _totalBalance;
      });
    } catch (error) {
      print("Error fetching transactions: $error");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch transactions')));
    }
  }

  Future<void> _fetchTransactions() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(docID)
          .collection('Transactions')
          .get();

      setState(() {
        _transactionsList.clear();
        for (var doc in querySnapshot.docs) {
          var transaction = {
            'transactionId': doc.id,
            'amount': doc['amount'] ?? 0.0,
            'type': doc['type'] ?? 'Unknown',
            'category': doc['category'] ?? 'Uncategorized',
            'date': (doc['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
          };
          _transactionsList.add(transaction);
        }
      });
      // Always update total balance after fetching transactions
      await calculateTotalBalance();
    } catch (e) {
      print("Error fetching transactions: $e");
    }
  }

  // Call this after adding a transaction
  Future<void> addTransaction(Map<String, dynamic> transaction) async {
    // ...add transaction logic...
    await _fetchTransactions();
  }

  // Call this after deleting a transaction
  Future<void> deleteTransaction(String transactionId) async {
    // ...delete transaction logic...
    await _fetchTransactions();
  }

  Widget _buildTransactionList() {
    if (_isLoading) {
  return const Center(child: CircularProgressIndicator());
} else if (_transactionsList.isEmpty) {
    return Center(
      child: Text(
        'No transactions yet!',
        style: GoogleFonts.ibmPlexSans(fontSize: 16),
      ),
    );
  }

  return ListView.builder(
  itemCount: _transactionsList.length > 6 ? 6 : _transactionsList.length,
  itemBuilder: (context, index) {
    if (index < 0 || index >= _transactionsList.length) {
      return const SizedBox(); // Prevent RangeError
    }
    return _buildTransactionItem(_transactionsList[index], index);
  },
);
}


  Widget _buildTransactionItem(Map<String, dynamic> transaction, int index) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.7),
            colors[0].withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors[1].withOpacity(0.25),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        color: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: colors[1].withOpacity(0.5),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                transaction['type'] != 'Income'
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                color: colors[1],
                size: 20,
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction['category'] ?? 'Uncategorized',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              SizedBox(height: 4),
              Text(
                "${DateFormat('yyyy-MM-dd').format(transaction['date'] ?? DateTime.now())}",
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 10,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
          trailing: Container(
            constraints: BoxConstraints(minWidth: 70),
            child: Text(
              NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2)
                  .format(transaction['amount'] ?? 0.0),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: transaction['type'] != 'Income'
                      ? Colors.red
                      : Colors.green,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> signOut() async {
    await Auth().signOut();
  }

  Widget _userUID() {
    return Text(
      user?.email ?? 'User email',
      style: GoogleFonts.ibmPlexSans(),
    );
  }

  Widget _signOutButton() {
    return ElevatedButton(onPressed: signOut, child: const Text("Sign Out"));
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
              const Color(0xffB8E8FF),
              Colors.white,
            ],
          ),
        ),
        child: StreamBuilder<List<Color>>(
          stream: docID.isNotEmpty
              ? GradientService(userId: docID).getGradientStream()
              : Stream.value([Color(0xffB8E8FF)]),
          builder: (context, snapshot) {
            //colors = snapshot.data ?? [Color(0xffB8E8FF)];
            return Stack(
              children: [
                // Remove glassmorphic BackdropFilter/background
                SafeArea(
                  child: Column(
                    children: [
                      // Keep all existing widgets inside this column unchanged
                      // They will now appear above the blurred background
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      children: [
                                        ProfilePicture(userId: docID),
                                      ],
                                    ),
                                    FutureBuilder<String>(
                                      future: GetUserName(documentId: docID).getUserName(),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return const Text('Loading...', style: TextStyle(color: Colors.white));
                                        } else if (snapshot.hasError) {
                                          return const Text('Error', style: TextStyle(color: Colors.white));
                                        } else {
                                          String userName = snapshot.data ?? 'User';
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 10.0),
                                            child: Row(
                                              children: [
                                                Text(
                                                  "Welcome ",
                                                  style: GoogleFonts.ibmPlexSans(
                                                    color: Colors.black,
                                                    fontSize: 30,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  "$userName!",
                                                  style: GoogleFonts.ibmPlexSans(
                                                    color: Colors.black,
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 25),
                            Container(
                              height: 160 * 1.25,
                              width: 260 * 1.25,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color.fromRGBO(132, 255, 201, 1), // hsla(154, 100%, 76%)
                                    Color.fromRGBO(170, 178, 255, 1), // hsla(234, 100%, 83%)
                                    Color.fromRGBO(255, 97, 246, 1),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.center,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2).format(_totalBalance),
                                    style: GoogleFonts.ibmPlexSans(
                                      color: Colors.white,
                                      fontSize: 42,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 30),
                          ],
                        ),
                      ),
                      // Remaining widgets...
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.7),
                                colors[0].withOpacity(0.4),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Recent Activity',
                                      style: GoogleFonts.ibmPlexSans(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        final homePageState = context.findAncestorStateOfType<HomePageWithNavState>();
                                        homePageState?.onItemTapped(1);
                                      },
                                      child: Text(
                                        "See More",
                                        style: GoogleFonts.ibmPlexSans(
                                          color: colors[1],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Expanded(
                                  child: _buildTransactionList(),
                                ),
                                SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(),
            ),
          );
        },
        foregroundColor: colors[1],
        backgroundColor: colors[0],
        child: const Icon(Icons.chat),
      ),
    );
  }
}