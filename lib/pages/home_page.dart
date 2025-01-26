import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_finance/pages/filter_by_amount.dart';
import 'package:fbla_finance/pages/filter_by_category.dart';
import 'package:fbla_finance/pages/filter_by_date.dart';
import 'package:fbla_finance/pages/filter_by_type.dart';
import 'package:fbla_finance/pages/transactions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fbla_finance/backend/read_data/get_user_name.dart';
import 'package:fbla_finance/pages/academics_page.dart';
import 'package:fbla_finance/pages/awards_page.dart';
import 'package:fbla_finance/pages/clubs_page.dart';
import 'package:fbla_finance/pages/ec_page.dart';
import 'package:fbla_finance/pages/other_page.dart';
import 'package:fbla_finance/util/ec_tile.dart';
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
  int myIndex = 0;
  final User? user = Auth().currentUser;
  var now = DateTime.now();
  var formatter = DateFormat.yMMMMd('en_US');
  String? formattedDate;
  String docID = "6cHwPquSMMkpue7r6RRN";
  double _totalBalance = 0.0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    formattedDate = formatter.format(now);
    fetchDocID();
    
    // Fetch the total balance
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
    _firestore.collection('users').doc(docID).collection('Transactions').get().then((querySnapshot) {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch transactions')));
    });
  }

  Future<void> signOut() async {
    await Auth().signOut();
  }

  Widget _userUID() {
    return Text(user?.email ?? 'User email');
  }

  Widget _signOutButton() {
    return ElevatedButton(onPressed: signOut, child: const Text("Sign Out"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<LinearGradient>(
        stream: GradientService(userId: docID ?? '').getGradientStream(),
        builder: (context, snapshot) {
          final gradient = snapshot.data ??
              LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  const Color(0xff56018D),
                  Colors.pink,
                ],
              );
          return Container(
            decoration: BoxDecoration(gradient: gradient),
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
                            Column(
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
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Text('Loading...',
                                          style: TextStyle(color: Colors.white));
                                    } else if (snapshot.hasError) {
                                      print(snapshot.error.toString());
                                      return const Text('Error',
                                          style: TextStyle(color: Colors.white));
                                    } else if (snapshot.hasData &&
                                        snapshot.data != null) {
                                      String userName = snapshot.data!;
                                      return Text(
                                        "Hi $userName!",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    } else {
                                      return const Text('Username not available',
                                          style: TextStyle(color: Colors.white));
                                    }
                                  },
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.all(12),
                                  child: const Icon(
                                    Icons.notifications,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 45),
                                Text(
                                  formattedDate!,
                                  style: TextStyle(
                                      color: Colors.blue[200], fontSize: 20),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),

                        // Current balance display
                        Container(
                          padding: const EdgeInsets.only(left: 4),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Current Balance: ${NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 2).format(_totalBalance)}',
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
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
                        color: Colors.grey[300],
                        child: Center(
                          child: Column(
                            children: [
                              // Heading
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Your Portfolio',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                  Icon(Icons.more_horiz),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // ListView
                              Expanded(
                                child: ListView(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => Transactions(userId: docID),
  ),
).then((_) {
  // Recalculate the balance when returning to the home page
  calculateTotalBalance();
});
                                      },
                                      child: EcTile(
                                        icon: Icons.lightbulb,
                                        EcName: 'Transactions',
                                        color: Colors.orange,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    SpendingHabitPage(userId: docID)));
                                      },
                                      child: EcTile(
                                        icon: Icons.lightbulb,
                                        EcName: 'Spending Habit',
                                        color: Colors.orange,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    FilterByAmountPage(userId: docID)));
                                      },
                                      child: EcTile(
                                        icon: Icons.emoji_events,
                                        EcName: 'Filter by Amount',
                                        color: Colors.blue,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    TransactionsByCategory(
                                                        userId: docID)));
                                      },
                                      child: EcTile(
                                        icon: Icons.groups,
                                        EcName: 'Filter by Category',
                                        color: Colors.pink,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    FilterByTypePage(userId: docID)));
                                      },
                                      child: EcTile(
                                        icon: Icons.assignment,
                                        EcName: 'Filter by Type',
                                        color: Colors.green,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    FilterByDatePage(userId: docID)));
                                      },
                                      child: EcTile(
                                        icon: Icons.assignment,
                                        EcName: 'Filter by Date',
                                        color: Colors.green,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    OthersPage(userId: docID)));
                                      },
                                      child: EcTile(
                                        icon: Icons.more_horiz,
                                        EcName: 'Other',
                                        color: Colors.purple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
