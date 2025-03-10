import 'package:cloud_firestore/cloud_firestore.dart';
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
  await fetchDocID();  // Wait for fetchDocID to complete
  _fetchTransactions();  // Call _fetchTransactions after fetchDocID
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

  void _fetchTransactions() {
    _firestore.collection('users').doc(docID).collection('Transactions').get().then((querySnapshot) {
      setState(() {
        _transactionsList.clear();
        _totalBalance = 0.0;
        querySnapshot.docs.forEach((doc) {
          var transaction = {
            'transactionId': doc.id,
            'amount': doc['amount'],
            'type': doc['type'],
            'category': doc['category'],
            'date': (doc['date'] as Timestamp).toDate(),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch transactions')));
    });
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      itemCount: _transactionsList.length > 5 ? 5 : _transactionsList.length,
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            transaction['category'],
            style: GoogleFonts.ibmPlexSans(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            "Type: ${transaction['type']} - Date: ${DateFormat('yyyy-MM-dd').format(transaction['date'])}",
            style: GoogleFonts.ibmPlexSans(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2)
                .format(transaction['amount']),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: transaction['type'] == 'Expense' ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    ),
  );
}
  

  Future<void> signOut() async {
    await Auth().signOut();
  }

  Widget _userUID() {
    return Text(user?.email ?? 'User email', style: GoogleFonts.ibmPlexSans(),);
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
              colors = snapshot.data ??
                  [Color(0xffB8E8FF), Colors.blue.shade900];
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
                                      String userName = snapshot.data!;
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 20.0),
                                        child: Row(
                                          children: [
                                            Text(
                                              "Hi ",
                                              style: GoogleFonts.ibmPlexSans(
                                                color: Colors.black,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              "$userName!",
                                              style: GoogleFonts.ibmPlexSans(
                                                color: Colors.black,
                                                fontSize: 18,
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formattedDate!,
                                  style: GoogleFonts.ibmPlexSans(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w500),
                                )
                              ],
                            ),
                          ],
                        ),
                        // Current balance display
                        Container(
                          padding: const EdgeInsets.only(left: 4),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Text(
                                'Balance',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2).format(_totalBalance),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 50,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 25,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 20.0, left: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) {
                                        return FilterByAmountPage(userId: docID);
                                      },
                                    ),
                                  );
                                },
                                child: FilterTile(
                                            icon: Icons.price_check,
                                            FilterName: 'Amount',
                                            color: colors[1],
                                          ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) {
                                        return TransactionsByCategory(userId: docID);
                                      },
                                    ),
                                  );
                                },
                                child: FilterTile(
                                            icon: Icons.category,
                                            FilterName: 'Category',
                                            color: colors[1],
                                          ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) {
                                        return FilterByTypePage(userId: docID);
                                      },
                                    ),
                                  );
                                },
                                child: FilterTile(
                                            icon: Icons.filter_alt,
                                            FilterName: 'Type',
                                            color: colors[1],
                                          ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) {
                                        return FilterByDatePage(userId: docID);
                                      },
                                    ),
                                  );
                                },
                                child: FilterTile(
                                            icon: Icons.calendar_month,
                                            FilterName: 'Date',
                                            color: colors[1],
                                          ),
                              ),
                            ],
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
                                    'Recent Transactions',
                                    style: GoogleFonts.ibmPlexSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      final homePageState = context.findAncestorStateOfType<HomePageWithNavState>();
                                      homePageState?.onItemTapped(1); // 1 is the index for Transactions page
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
                              Expanded(child: _buildTransactionList(),),
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
    );
  }
}
