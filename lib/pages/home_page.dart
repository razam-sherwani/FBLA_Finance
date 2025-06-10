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
    _fetchTransactions(); // Call _fetchTransactions after fetchDocID
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
        public_bal = _totalBalance;
      });
    }).catchError((error) {
      print("Error fetching transactions: $error");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch transactions')));
    });
  }

  void _fetchTransactions() {
    _firestore
        .collection('users')
        .doc(docID)
        .collection('Transactions')
        .get()
        .then((querySnapshot) {
      setState(() {
        _transactionsList.clear();
        _totalBalance = 0.0;
        querySnapshot.docs.forEach((doc) {
          var transaction = {
            'transactionId': doc.id,
            'amount': doc['amount'] ?? 0.0,
            'type': doc['type'] ?? 'Unknown',
            'category': doc['category'] ?? 'Uncategorized',
            'date': (doc['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
          };
          _transactionsList.add(transaction);
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

  Widget _buildTransactionList() {
    return ListView.builder(
      itemCount: _transactionsList.length > 6 ? 6 : _transactionsList.length,
      itemBuilder: (context, index) {
        return _buildTransactionItem(_transactionsList[index], index);
      },
    );
  }

 Widget _buildTransactionItem(Map<String, dynamic> transaction, int index) {
  return Card(
    color: colors[0],
    elevation: 4,
    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    child: ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Added padding
      leading: Container(
        width: 40, // Fixed width
        height: 40, // Fixed height
        decoration: BoxDecoration(
          color: Colors.white, // White background
          borderRadius: BorderRadius.circular(8), // Rounded corners
        ),
        child: Center(
          child: Icon(
            transaction['type'] != 'Income' 
              ? Icons.arrow_downward 
              : Icons.arrow_upward,
            color: colors[1],
            size: 20, // Consistent icon size
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
            overflow: TextOverflow.ellipsis, // Prevent overflow
            maxLines: 1, // Single line
          ),
          SizedBox(height: 4), // Spacing between texts
          Text(
            "${DateFormat('yyyy-MM-dd').format(transaction['date'] ?? DateTime.now())}",
            style: GoogleFonts.ibmPlexSans(
              fontSize: 10,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis, // Prevent overflow
            maxLines: 1, // Single line
          ),
        ],
      ),
      trailing: Container(
        constraints: BoxConstraints(minWidth: 70), // Ensure minimum width
        child: Text(
          NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2)
              .format(transaction['amount'] ?? 0.0),
          style: GoogleFonts.ibmPlexSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: (transaction['type'] ?? 'Unknown') == 'Expense'
                ? Colors.red
                : Colors.green,
          ),
          overflow: TextOverflow.ellipsis, // Prevent overflow
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
      body: StreamBuilder<List<Color>>(
        stream: docID.isNotEmpty
            ? GradientService(userId: docID).getGradientStream()
            : Stream.value([Color(0xffB8E8FF), Colors.blue.shade900]),
        builder: (context, snapshot) {
          colors = snapshot.data ?? [Color(0xffB8E8FF), Colors.blue.shade900];
          return Container(
            color: colors[0],
            child: SafeArea(
              child: Column(
                children: [
                  // Greetings row
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
                                  future: GetUserName(documentId: docID)
                                      .getUserName(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Text('Loading...',
                                          style:
                                              TextStyle(color: Colors.white));
                                    } else if (snapshot.hasError) {
                                      print(snapshot.error.toString());
                                      return const Text('Error',
                                          style:
                                              TextStyle(color: Colors.white));
                                    } else if (snapshot.hasData &&
                                        snapshot.data != null) {
                                      String userName = snapshot.data ?? 'User';
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(top: 10.0),
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
                                    } else {
                                      return const Text(
                                          'Username not available',
                                          style:
                                              TextStyle(color: Colors.white));
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Current balance display

                        SizedBox(
                          height: 25,
                        ),
                        Container(
                          height: 160 * 1.25,
                          width: 260 * 1.25,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFe7b8ff),
                                Color(0xFFb7e9ff),
                                Color(0xFFcaffbf),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.all(
                                  16.0), // Add some padding from the edges
                              child: Text(
                                NumberFormat.simpleCurrency(
                                        locale: 'en_US', decimalDigits: 2)
                                    .format(_totalBalance),
                                style: GoogleFonts.ibmPlexSans(
                                  color: Colors.grey.shade700,
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                  // Other Widgets...
                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(25)),
                      child: Container(
                        padding: const EdgeInsets.all(25),
                        color: Colors.white,
                        child: Center(
                          child: Column(
                            children: [
                              // Heading
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                      final homePageState =
                                          context.findAncestorStateOfType<
                                              HomePageWithNavState>();
                                      homePageState?.onItemTapped(
                                          1); // 1 is the index for Transactions page
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
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) {
                return ChatScreen();
              },
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
