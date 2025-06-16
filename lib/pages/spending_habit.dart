import 'dart:io';
import 'dart:ui';

import 'package:fbla_finance/backend/auth.dart';
import 'package:fbla_finance/pages/chat_screen.dart';
import 'package:fbla_finance/util/gradient_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:fbla_finance/backend/indicator.dart';
import 'package:fbla_finance/backend/app_colors.dart';
import 'package:fbla_finance/backend/app_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'package:fbla_finance/util/profile_picture.dart';

enum PeriodType { monthly, quarterly, yearly, custom }

class SpendingHabitPage extends StatefulWidget {
  SpendingHabitPage({Key? key}) : super(key: key);

  @override
  _SpendingHabitPageState createState() => _SpendingHabitPageState();
}

class _SpendingHabitPageState extends State<SpendingHabitPage> {
  final User? user = Auth().currentUser;
  String docID = "";
  bool _loading = true;
  final List<Color> gradientColors = [
    Colors.redAccent,
    Colors.orangeAccent,
  ];
  int touchedIndex = -1;
  final GlobalKey _expenseGraphKey = GlobalKey();
  final GlobalKey _balanceGraphKey = GlobalKey();
  final GlobalKey _pieChartKey = GlobalKey();
  late AnimationController _controller;
  double targetProgress = 0;

  final List<Map<String, dynamic>> _rawData = [];
  final List<List<double>> _income = List.generate(
    12,
    (_) => List.generate(31, (_) => 0.0),
  );
  final List<List<double>> _expense = List.generate(
    12,
    (_) => List.generate(31, (_) => 0.0),
  );
  final List<List<double>> _curBal = List.generate(
    12,
    (_) => List.generate(31, (_) => 0.0),
  );

  List<Color> colors = [Color(0xffB8E8FF), Colors.blue.shade900];
  final int minDays = 1;
  final int maxDays = 31;
  double budget = 0;

  int _currentMonthIndex = 5;
  int _currentWeekIndex = 0;
  int _currentYearIndex = DateTime.now().year - 2020; // adjust as needed
  final List<String> monthsNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final List<String> quarterNames = [
    'Q1', 'Q2', 'Q3', 'Q4'
  ];
  final List<int> years = List.generate(6, (i) => 2020 + i); // 2020-2025

  // Add this map to store category-wise totals
  final Map<String, double> _categoryTotals = {};

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // For selected period
  PeriodType _selectedPeriod = PeriodType.monthly;
  DateTime? _customStart;
  DateTime? _customEnd;

  double _periodInflow = 0;
  double _periodOutflow = 0;

  // Shared scroll index for month/quarter/year
  int _sharedScrollIndex = 5;
  int _selectedYear = 2025;

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
  }

  Future<void> _fetchRawData() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(docID)
          .collection('Transactions')
          .get();

      setState(() {
        _rawData.clear();
        _categoryTotals.clear(); // Reset category totals
        for (var doc in querySnapshot.docs) {
          final amount = (doc['amount'] as num).toDouble();
          final date = (doc['date'] as Timestamp).toDate();
          final type = doc['type'];
          final category = doc['category'] ?? 'Other'; // Default to 'Other'

          //herehere

          _rawData.add({
            'amount': amount,
            'date': date,
            'type': type,
            'category': category,
          });

          // Filter data for the selected month and only for expenses
          if (type == 'Expense' && date.month - 1 == _currentMonthIndex) {
            _categoryTotals[category] =
                (_categoryTotals[category] ?? 0) + amount;
          }
        }
      });
    } catch (error) {
      print("Error fetching transactions: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch transactions RAW DATA')),
      );
    }
  }

  // void _findSum() {
  //   //hereagain
  //   // ignore: unused_local_variable
  //   for(var entry in _marchTotals.entries) {
  //     marchSum += entry.value;
  //   }
  // }
  void _createCleanData() {
    for (var transaction in _rawData) {
      DateTime date = transaction['date'];
      int month = date.month - 1;
      int day = date.day - 1;
      double amount = transaction['amount'];

      if (transaction['type'] == 'Expense') {
        _expense[month][day] += amount;

        // Update the category totals
        String category = transaction['category'] ??
            'Other'; // Default to "Other" if category is missing
        if (_categoryTotals.containsKey(category)) {
          _categoryTotals[category] = _categoryTotals[category]! + amount;
        } else {
          _categoryTotals['Other'] = _categoryTotals['Other']! + amount;
        }
      } else {
        _income[month][day] += amount;
      }
    }
  }

  Future<void> _fetchRawDataLine() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(docID)
          .collection('Transactions')
          .get();

      setState(() {
        _rawData.clear();
        for (var doc in querySnapshot.docs) {
          _rawData.add({
            'amount': (doc['amount'] as num).toDouble(), // Ensuring double type
            'date': (doc['date'] as Timestamp).toDate(),
            'type': doc['type']
          });
        }
        _createCleanDataLine();
      });
    } catch (error) {
      print("Error fetching transactions: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch transactions DATALINE')),
      );
    }
  }

  void _createCleanDataLine() {
    for (var transaction in _rawData) {
      DateTime date = transaction['date'];
      int month = date.month - 1;
      int day = date.day - 1;
      double amount = transaction['amount'];

      if (transaction['type'] == 'Expense') {
        _expense[month][day] += amount;
      } else {
        _income[month][day] += amount;
      }
    }
  }

  Future<void> _fetchRawDataCurrentBalance() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(docID)
          .collection('Transactions')
          .get();

      setState(() {
        _rawData.clear();
        for (var doc in querySnapshot.docs) {
          _rawData.add({
            'amount': (doc['amount'] as num).toDouble(), // Ensuring double type
            'date': (doc['date'] as Timestamp).toDate(),
            'type': doc['type']
          });
        }
        _createCleanDataCurrentBalance();
      });
    } catch (error) {
      print("Error fetching transactions: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to fetch transactions CURRENT BAL')),
      );
    }
  }

  void _createCleanDataCurrentBalance() {
    for (int month = 0; month < 12; month++) {
      for (int day = 0; day < 31; day++) {
        // Set the starting balance for the first day of the first month
        if (month == 0 && day == 0) {
          _curBal[month][day] = 0.0; // Assume initial balance is 0
        } else if (day == 0) {
          // Carry over balance from the last day of the previous month
          _curBal[month][day] = _curBal[month - 1][30];
        } else {
          // Carry over from the previous day in the same month
          _curBal[month][day] = _curBal[month][day - 1];
        }

        // Add or subtract the current transaction amount
        for (var transaction in _rawData) {
          DateTime date = transaction['date'];
          if (date.month - 1 == month && date.day - 1 == day) {
            double amount = transaction['amount'];
            if (transaction['type'] == 'Expense') {
              _curBal[month][day] -= amount;
            } else {
              _curBal[month][day] += amount;
            }
          }
        }
      }
    }
  }

  double findMinExpense() {
    return _expense[_currentMonthIndex].reduce((a, b) => a < b ? a : b);
  }

  double findMaxExpense() {
    return _expense[_currentMonthIndex].reduce((a, b) => a > b ? a : b);
  }

  double findMinIncome() {
    return _income[_currentMonthIndex].reduce((a, b) => a < b ? a : b);
  }

  double findMaxIncome() {
    return _income[_currentMonthIndex].reduce((a, b) => a > b ? a : b);
  }

  double minExpense = 0;
  double maxExpense = 0;
  double minIncome = 0;
  double maxIncome = 0;
  double overallMin = 0;
  double overallMax = 0;
  int _interactedSpotIndex = -1;
  int _interactedSpotIndexExpense = -1; // For expense graph
  int _interactedSpotIndexBalance = -1; // For balance graph

  Future<void> _initializeData() async {
    await fetchDocID(); // Wait for fetchDocID to complete
    _fetchRawDataLine();
    _fetchRawData();
    _fetchRawDataCurrentBalance();
  }

  void _fetchBudget() async {
    try {
      final querySnapshot =
          await _firestore.collection('users').doc(docID).get();

      setState(() {
        if (querySnapshot.exists) {
          Map<String, dynamic>? data = querySnapshot.data();
          targetProgress = data?["budget"];
        }
      });
    } catch (error) {
      print("Error fetching budget: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch budget')),
      );
    }
  }

  Future<double> getCurrentMonthExpenseTotal() async {
  try {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    // Fetch all transactions
    final querySnapshot = await _firestore
        .collection('users')
        .doc(docID)
        .collection('Transactions')
        .get();

    double totalExpenses = 0;

    for (var doc in querySnapshot.docs) {
      final data = doc.data();

      if (data['type'] == 'Expense') {
        final date = (data['date'] as Timestamp).toDate();
        final amount = (data['amount'] as num).toDouble();

        if (date.month == currentMonth && date.year == currentYear) {
          totalExpenses += amount;
        }
      }
    }

    return totalExpenses;
  } catch (e) {
    print("Error calculating current month expenses: $e");
    return 0.0;
  }
}




 void _updateBudget(double num) {
    budget = num;
  }

void _promptUpdateBudget() {
    double tempBudget = 0;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Update Budget'),
              content: Container(
                height: 230,
                width: 250,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          InputDecoration(labelText: 'Enter the amount'),
                      onChanged: (String? val) {
                        tempBudget = double.parse(val!);
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          child: Text('Cancel'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        TextButton(
                          child: Text('Enter'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _updateBudget(tempBudget);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onPeriodChanged(PeriodType type) async {
    setState(() {
      _selectedPeriod = type;
      if (type == PeriodType.monthly) {
        _sharedScrollIndex = DateTime.now().month - 1;
        _selectedYear = DateTime.now().year;
      } else if (type == PeriodType.quarterly) {
        // 0 = Q1, 1 = Q2, ...
        _sharedScrollIndex = ((DateTime.now().month - 1) ~/ 3);
        _selectedYear = DateTime.now().year;
      } else if (type == PeriodType.yearly) {
        _sharedScrollIndex = 0;
        _selectedYear = DateTime.now().year;
      }
    });
    if (type != PeriodType.custom) {
      _fetchPeriodData();
    }
  }

  void _previousPeriod() {
    setState(() {
      if (_selectedPeriod == PeriodType.monthly && _sharedScrollIndex > 0) {
        _sharedScrollIndex--;
      } else if (_selectedPeriod == PeriodType.monthly && _sharedScrollIndex == 0) {
        _selectedYear--;
        _sharedScrollIndex = 11;
      } else if (_selectedPeriod == PeriodType.quarterly && _sharedScrollIndex > 0) {
        _sharedScrollIndex--;
      } else if (_selectedPeriod == PeriodType.quarterly && _sharedScrollIndex == 0) {
        _selectedYear--;
        _sharedScrollIndex = 3;
      } else if (_selectedPeriod == PeriodType.yearly) {
        _selectedYear--;
      }
    });
    _fetchPeriodData();
  }

  void _nextPeriod() {
    setState(() {
      if (_selectedPeriod == PeriodType.monthly && _sharedScrollIndex < 11) {
        _sharedScrollIndex++;
      } else if (_selectedPeriod == PeriodType.monthly && _sharedScrollIndex == 11) {
        _selectedYear++;
        _sharedScrollIndex = 0;
      } else if (_selectedPeriod == PeriodType.quarterly && _sharedScrollIndex < 3) {
        _sharedScrollIndex++;
      } else if (_selectedPeriod == PeriodType.quarterly && _sharedScrollIndex == 3) {
        _selectedYear++;
        _sharedScrollIndex = 0;
      } else if (_selectedPeriod == PeriodType.yearly) {
        _selectedYear++;
      }
    });
    _fetchPeriodData();
  }

  Future<void> _fetchPeriodData() async {
    // Fetch and aggregate data for the selected period
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(docID)
          .collection('Transactions')
          .get();

      List<Map<String, dynamic>> periodData = [];
      double inflow = 0, outflow = 0;
      DateTime start, end;

      if (_selectedPeriod == PeriodType.monthly) {
        start = DateTime(_selectedYear, _sharedScrollIndex + 1, 1);
        end = DateTime(_selectedYear, _sharedScrollIndex + 2, 0);
      } else if (_selectedPeriod == PeriodType.quarterly) {
        int startMonth = _sharedScrollIndex * 3 + 1;
        int endMonth = startMonth + 2;
        start = DateTime(_selectedYear, startMonth, 1);
        end = DateTime(_selectedYear, endMonth + 1, 0);
      } else if (_selectedPeriod == PeriodType.yearly) {
        start = DateTime(_selectedYear, 1, 1);
        end = DateTime(_selectedYear, 12, 31);
      } else {
        // Custom
        if (_customStart == null || _customEnd == null) return;
        start = DateTime(_customStart!.year, _customStart!.month, _customStart!.day);
        end = DateTime(_customEnd!.year, _customEnd!.month, _customEnd!.day, 23, 59, 59);
      }

      _categoryTotals.clear();
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        if (date.isBefore(start) || date.isAfter(end)) continue;
        final amount = (data['amount'] as num).toDouble();
        final type = data['type'];
        final category = data['category'] ?? 'Other';

        periodData.add({
          'amount': amount,
          'date': date,
          'type': type,
          'category': category,
        });

        if (type == 'Expense') {
          outflow += amount;
          _categoryTotals[category] = (_categoryTotals[category] ?? 0) + amount;
        } else {
          inflow += amount;
        }
      }

      setState(() {
        _rawData
          ..clear()
          ..addAll(periodData);
        _periodInflow = inflow;
        _periodOutflow = outflow;
      });
    } catch (e) {
      print("Error fetching period data: $e");
    }
  }

  // Helper to aggregate data for the selected period for the line chart
  List<FlSpot> _getExpenseSpots() {
    if (_rawData.isEmpty) return [];
    Map<int, double> map = {};
    if (_selectedPeriod == PeriodType.monthly) {
      for (var tx in _rawData) {
        final date = tx['date'] as DateTime;
        final day = date.day - 1;
        if (tx['type'] == 'Expense') {
          map[day] = (map[day] ?? 0) + (tx['amount'] as double);
        }
      }
      int daysInMonth = DateTime(_selectedYear, _sharedScrollIndex + 2, 0).day;
      return List.generate(daysInMonth, (i) => FlSpot(i.toDouble(), map[i] ?? 0));
    } else if (_selectedPeriod == PeriodType.quarterly) {
      // Group by month in quarter
      int startMonth = _sharedScrollIndex * 3 + 1;
      for (var tx in _rawData) {
        final date = tx['date'] as DateTime;
        final month = date.month - startMonth;
        if (tx['type'] == 'Expense' && month >= 0 && month < 3) {
          map[month] = (map[month] ?? 0) + (tx['amount'] as double);
        }
      }
      return List.generate(3, (i) => FlSpot(i.toDouble(), map[i] ?? 0));
    } else if (_selectedPeriod == PeriodType.yearly) {
      for (var tx in _rawData) {
        final date = tx['date'] as DateTime;
        final month = date.month - 1;
        if (tx['type'] == 'Expense') {
          map[month] = (map[month] ?? 0) + (tx['amount'] as double);
        }
      }
      return List.generate(12, (i) => FlSpot(i.toDouble(), map[i] ?? 0));
    } else if (_selectedPeriod == PeriodType.custom) {
      for (var tx in _rawData) {
        final date = tx['date'] as DateTime;
        final day = date.difference(_customStart!).inDays;
        if (tx['type'] == 'Expense') {
          map[day] = (map[day] ?? 0) + (tx['amount'] as double);
        }
      }
      int totalDays = _customEnd!.difference(_customStart!).inDays + 1;
      return List.generate(totalDays, (i) => FlSpot(i.toDouble(), map[i] ?? 0));
    }
    return [];
  }

  // Helper for balance graph (simple running total)
  List<FlSpot> _getBalanceSpots() {
    if (_rawData.isEmpty) return [];
    List<Map<String, dynamic>> sorted = List.from(_rawData)
      ..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    double balance = 0;
    List<FlSpot> spots = [];
    if (_selectedPeriod == PeriodType.monthly) {
      int daysInMonth = DateTime(_selectedYear, _sharedScrollIndex + 2, 0).day;
      for (int i = 0; i < daysInMonth; i++) {
        for (var tx in sorted) {
          final txDate = tx['date'] as DateTime;
          if (txDate.day - 1 == i) {
            balance += tx['type'] == 'Expense' ? -tx['amount'] : tx['amount'];
          }
        }
        spots.add(FlSpot(i.toDouble(), balance));
      }
    } else if (_selectedPeriod == PeriodType.quarterly) {
      int startMonth = _sharedScrollIndex * 3 + 1;
      for (int i = 0; i < 3; i++) {
        for (var tx in sorted) {
          final txDate = tx['date'] as DateTime;
          if (txDate.month == startMonth + i) {
            balance += tx['type'] == 'Expense' ? -tx['amount'] : tx['amount'];
          }
        }
        spots.add(FlSpot(i.toDouble(), balance));
      }
    } else if (_selectedPeriod == PeriodType.yearly) {
      for (int i = 0; i < 12; i++) {
        for (var tx in sorted) {
          final txDate = tx['date'] as DateTime;
          if (txDate.month - 1 == i) {
            balance += tx['type'] == 'Expense' ? -tx['amount'] : tx['amount'];
          }
        }
        spots.add(FlSpot(i.toDouble(), balance));
      }
    } else if (_selectedPeriod == PeriodType.custom) {
      int totalDays = _customEnd!.difference(_customStart!).inDays + 1;
      for (int i = 0; i < totalDays; i++) {
        for (var tx in sorted) {
          final txDate = tx['date'] as DateTime;
          if (txDate.difference(_customStart!).inDays == i) {
            balance += tx['type'] == 'Expense' ? -tx['amount'] : tx['amount'];
          }
        }
        spots.add(FlSpot(i.toDouble(), balance));
      }
    }
    return spots;
  }

  /// Helper to split spots into segments above and below cutoff (y=0)
  List<List<List<FlSpot>>> splitSpotsByCutoff(List<FlSpot> spots, double cutoff) {
    List<List<FlSpot>> aboveSegments = [];
    List<List<FlSpot>> belowSegments = [];
    List<FlSpot> currentAbove = [];
    List<FlSpot> currentBelow = [];

    for (int i = 0; i < spots.length; i++) {
      final spot = spots[i];
      final isAbove = spot.y > cutoff;
      final isBelow = spot.y < cutoff;
      final isAt = spot.y == cutoff;

      // Handle above 0
      if (isAbove) {
        if (currentBelow.isNotEmpty) {
          // Crossing from below to above
          if (i > 0 && spots[i - 1].y <= cutoff) {
            final prev = spots[i - 1];
            final t = (cutoff - prev.y) / (spot.y - prev.y);
            final crossX = prev.x + (spot.x - prev.x) * t;
            final crossSpot = FlSpot(crossX, cutoff);
            currentBelow.add(crossSpot);
            belowSegments.add(List.from(currentBelow));
            currentBelow.clear();
            currentAbove.add(crossSpot);
          }
        }
        currentAbove.add(spot);
      } else if (isBelow) {
        if (currentAbove.isNotEmpty) {
          // Crossing from above to below
          if (i > 0 && spots[i - 1].y >= cutoff) {
            final prev = spots[i - 1];
            final t = (cutoff - prev.y) / (spot.y - prev.y);
            final crossX = prev.x + (spot.x - prev.x) * t;
            final crossSpot = FlSpot(crossX, cutoff);
            currentAbove.add(crossSpot);
            aboveSegments.add(List.from(currentAbove));
            currentAbove.clear();
            currentBelow.add(crossSpot);
          }
        }
        currentBelow.add(spot);
      } else if (isAt) {
        // At cutoff, add to both if transitioning
        if (currentAbove.isNotEmpty) {
          currentAbove.add(spot);
          aboveSegments.add(List.from(currentAbove));
          currentAbove.clear();
        }
        if (currentBelow.isNotEmpty) {
          currentBelow.add(spot);
          belowSegments.add(List.from(currentBelow));
          currentBelow.clear();
        }
        // If not transitioning, do nothing (isolated cutoff point)
      }
    }
    if (currentAbove.isNotEmpty) aboveSegments.add(currentAbove);
    if (currentBelow.isNotEmpty) belowSegments.add(currentBelow);
    return [aboveSegments, belowSegments];
  }

  // Add this method for saving graph as image
  Future<void> saveGraphAsImage(GlobalKey graphKey, String fileName) async {
    try {
      final boundary =
          graphKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);

      if (byteData != null) {
        final buffer = byteData.buffer.asUint8List();

        // Get the application's documents directory
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';

        // Save the file
        final file = File(filePath);
        await file.writeAsBytes(buffer);

        print('Graph saved to $filePath');
      }
    } catch (e) {
      print('Error saving graph: $e');
    }
  }

  // Add this method for picking custom dates
  void _pickCustomDates() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
      });
      _fetchPeriodData();
    }
  }

  @override
  void initState() {
    super.initState();

    // Fetch docID, then all transaction data, then compute period data, then set loading to false
    fetchDocID().then((_) async {
      // Wait for all fetches to complete in order
      await _fetchRawDataLine();
      await _fetchRawData();
      await _fetchRawDataCurrentBalance();
      await _fetchPeriodData();
      setState(() {
        _loading = false;
      });
    });

    // Wait for the first frame and then delay before capturing images
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration(milliseconds: 500));

      // Save the graphs as images after rendering
      await saveGraphAsImage(_expenseGraphKey, 'expense_graph.png');
      await saveGraphAsImage(_balanceGraphKey, 'balance_graph.png');
      //await saveGraphAsImage(_pieChartKey, 'pie_chart.png');
    });

    // Initialize min/max values
    minExpense = findMinExpense();
    maxExpense = findMaxExpense();
    minIncome = findMinIncome();
    maxIncome = findMaxIncome();
    overallMin = minExpense < minIncome ? minExpense : minIncome;
    overallMax = maxExpense > maxIncome ? maxExpense : maxIncome;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF2A4288),
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
        child: const Icon(Icons.chat),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      appBar: AppBar(
        toolbarHeight: 75,
        title: Padding(
          padding: const EdgeInsets.only(bottom: 15.0), // Move title up
          child: Text(
            'Transaction Analysis',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2A4288),
        actions: [
          if (userId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10.0, top: 8),
              child: ProfilePicture(userId: userId),
            ),
        ],
      ),
      body: StreamBuilder<List<Color>>(
        stream: docID.isNotEmpty
            ? GradientService(userId: docID).getGradientStream()
            : Stream.value([Color(0xffB8E8FF), Colors.blue.shade900]),
        builder: (context, snapshot) {
          colors = snapshot.data ?? [Color(0xffB8E8FF), Colors.blue.shade900];
          // If custom is selected and dates are not picked, show a prompt
          if (_selectedPeriod == PeriodType.custom && (_customStart == null || _customEnd == null)) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Please select a start and end date to view custom data.',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    MaterialButton(
                      minWidth: 150,
                      height: 50,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      onPressed: _pickCustomDates,
                      color: colors[1],
                      textColor: Colors.white,
                      child: Text('Select Dates', style: TextStyle(fontSize: 20)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(50),
                      topRight: Radius.circular(50),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: 32),
                        // PERIOD SELECTION BAR
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              _periodButton('Month', PeriodType.monthly),
                              _periodButton('Quarter', PeriodType.quarterly),
                              _periodButton('Year', PeriodType.yearly),
                              _periodButton('Custom', PeriodType.custom),
                            ],
                          ),
                        ),
                        // PERIOD NAVIGATION & LABEL
                        if (_selectedPeriod != PeriodType.custom)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(Icons.chevron_left),
                                onPressed: (_selectedPeriod == PeriodType.monthly && (_sharedScrollIndex > 0 || _selectedYear > 2020)) ||
                                          (_selectedPeriod == PeriodType.quarterly && (_sharedScrollIndex > 0 || _selectedYear > 2020)) ||
                                          (_selectedPeriod == PeriodType.yearly && _selectedYear > 2020)
                                    ? _previousPeriod
                                    : null,
                              ),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _selectedPeriod == PeriodType.monthly
                                        ? '${_selectedYear} ${monthsNames[_sharedScrollIndex]}'
                                        : _selectedPeriod == PeriodType.quarterly
                                            ? '${_selectedYear} ${quarterNames[_sharedScrollIndex]}'
                                            : _selectedPeriod == PeriodType.yearly
                                                ? '${_selectedYear}'
                                                : '',
                                    style: TextStyle(
                                      color: AppColors.contentColorBlue,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.chevron_right),
                                onPressed: (_selectedPeriod == PeriodType.monthly) ||
                                          (_selectedPeriod == PeriodType.quarterly) ||
                                          (_selectedPeriod == PeriodType.yearly)
                                    ? _nextPeriod
                                    : null,
                              ),
                            ],
                          ),
                        if (_selectedPeriod == PeriodType.custom)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: AnimatedContainer(
                                    duration: Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [colors[1], colors[0]],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colors[1].withOpacity(0.18),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: colors[1],
                                        width: 2,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(22),
                                        onTap: _pickCustomDates,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                          child: Text(
                                            _customStart == null || _customEnd == null
                                                ? 'Select Date Range'
                                                : '${DateFormat.yMMMd().format(_customStart!)} - ${DateFormat.yMMMd().format(_customEnd!)}',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // INFLOW/OUTFLOW BOXES
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(child: _summaryBox('Inflow', _periodInflow, Colors.green)),
                              SizedBox(width: 8),
                              Expanded(child: _summaryBox('Outflow', _periodOutflow, Colors.red)),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('Expenses By Category',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: RepaintBoundary(
                            key: _pieChartKey,
                            child: AspectRatio(
                              aspectRatio: 2,
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: PieChart(
                                        PieChartData(
                                          pieTouchData: PieTouchData(
                                            touchCallback: (FlTouchEvent event,
                                                pieTouchResponse) {
                                              setState(() {
                                                if (!event
                                                        .isInterestedForInteractions ||
                                                    pieTouchResponse == null ||
                                                    pieTouchResponse.touchedSection ==
                                                        null) {
                                                  touchedIndex = -1;
                                                  return;
                                                }
                                                touchedIndex = pieTouchResponse
                                                    .touchedSection!
                                                    .touchedSectionIndex;
                                              });
                                            },
                                          ),
                                          borderData: FlBorderData(
                                            show: false,
                                          ),
                                          sectionsSpace: 0,
                                          centerSpaceRadius: 40,
                                          sections: showingSections(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: List.generate(
                                            _categoryTotals.keys.length, (index) {
                                          final category =
                                              _categoryTotals.keys.elementAt(index);
                                          final color =
                                              pieColors[index % pieColors.length];
              
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 2.0),
                                            child: Indicator(
                                              color: color,
                                              text: category,
                                              isSquare: true,
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 28,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _selectedPeriod == PeriodType.monthly
                                        ? 'Expenses Per Month'
                                        : _selectedPeriod == PeriodType.yearly
                                            ? 'Expenses Per Year'
                                            : 'Expenses (Custom)',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // EXPENSE LINE GRAPH
                        RepaintBoundary(
                          key: _expenseGraphKey,
                          child: AspectRatio(
                            aspectRatio: 1.5,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 18.0, top: 7.0),
                              child: LineChart(
                                LineChartData(
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: _getExpenseSpots(),
                                      isCurved: true,
                                      dotData: const FlDotData(show: true),
                                      color: Colors.lightBlue,
                                      gradient: const LinearGradient(
                                        colors: [Colors.red, Colors.purple],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                      barWidth: 4,
                                      curveSmoothness: 0.5,
                                      preventCurveOverShooting: true,
                                      belowBarData: BarAreaData(
                                        show: true,
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.red.withOpacity(0.25),
                                            Colors.purple.withOpacity(0.10),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                  ],
                                  titlesData: FlTitlesData(
                                    show: true,
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    bottomTitles: AxisTitles(
                                      axisNameWidget: Container(
                                        margin: const EdgeInsets.only(left: 25, bottom: 20),
                                        child: Text(
                                          _selectedPeriod == PeriodType.monthly
                                              ? 'Day of Month'
                                              : _selectedPeriod == PeriodType.yearly
                                                  ? 'Month'
                                                  : 'Day',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      axisNameSize: 40,
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 38,
                                        maxIncluded: false,
                                        interval: 1,
                                        getTitlesWidget: (value, meta) {
                                          if (_selectedPeriod == PeriodType.monthly) {
                                            int day = value.toInt() + 1;
                                            int daysInMonth = DateTime(DateTime.now().year, _sharedScrollIndex + 2, 0).day;
                                            // Only show first, last, every 5th day
                                            if (day == 1 || day == daysInMonth || day % 5 == 0) {
                                              return SideTitleWidget(
                                                meta: meta,
                                                child: Transform.rotate(
                                                  angle: -0.7,
                                                  child: Text(
                                                    '$day',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            } else {
                                              return const SizedBox.shrink();
                                            }
                                          } else if (_selectedPeriod == PeriodType.quarterly) {
                                            return SideTitleWidget(
                                              meta: meta,
                                              child: Text(
                                                quarterNames[value.toInt().clamp(0, 3)],
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            );
                                          } else if (_selectedPeriod == PeriodType.yearly) {
                                            return SideTitleWidget(
                                              meta: meta,
                                              child: Text(
                                                monthsNames[value.toInt().clamp(0, 11)].substring(0, 3),
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            );
                                          } else {
                                            return SideTitleWidget(
                                              meta: meta,
                                              child: Text(
                                                '${value.toInt() + 1}',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  lineTouchData: LineTouchData(
                                    enabled: true,
                                    handleBuiltInTouches: true,
                                    touchTooltipData: LineTouchTooltipData(
                                      getTooltipColor: (LineBarSpot touchedSpot) => colors[0], // <-- Blue background for tooltip
                                      getTooltipItems: (touchedSpots) {
                                        // Only show one tooltip per x value (day), and skip if at intersection (start/end of segment)
                                        final seen = <double>{};
                                        return touchedSpots
                                            .where((spot) {
                                              // Prevent hover at intersection points (where x is not an integer)
                                              // Only allow hover if x is a whole number (i.e., a real day)
                                              return seen.add(spot.x) && spot.x == spot.x.roundToDouble();
                                            })
                                            .map((spot) {
                                              final value = spot.y;
                                              final day = spot.x.toInt() + 1;
                                              return LineTooltipItem(
                                                'Day $day\n${value.toStringAsFixed(2)}',
                                                const TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              );
                                            }).toList();
                                      },
                                    ),
                                    touchCallback: (event, touchResponse) {
                                      // Prevent interaction at intersection points (non-integer x)
                                      if (!event.isInterestedForInteractions ||
                                          touchResponse?.lineBarSpots == null ||
                                          touchResponse!.lineBarSpots!.isEmpty ||
                                          touchResponse.lineBarSpots!.first.x != touchResponse.lineBarSpots!.first.x.roundToDouble()) {
                                        setState(() {
                                          _interactedSpotIndexBalance = -1;
                                        });
                                        return;
                                      }
                                      setState(() {
                                        _interactedSpotIndexBalance = touchResponse.lineBarSpots!.first.spotIndex;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // BALANCE GRAPH
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _selectedPeriod == PeriodType.monthly
                                ? 'Balance Per Day (Month)'
                                : _selectedPeriod == PeriodType.yearly
                                    ? 'Balance Per Month (Year)'
                                    : 'Balance (Custom)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        RepaintBoundary(
                          key: _balanceGraphKey,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 18, top: 7),
                            child: AspectRatio(
                              aspectRatio: 1.5,
                              child: LineChart(
                                curve: Curves.linear,
                                LineChartData(
                                  lineBarsData: [
                                    // Robust split: above 0 segments
                                    ...splitSpotsByCutoff(_getBalanceSpots(), 0)[0].map((segment) =>
                                      LineChartBarData(
                                        spots: segment,
                                        isCurved: true,
                                        dotData: const FlDotData(show: false),
                                        barWidth: 4,
                                        curveSmoothness: 0.5,
                                        preventCurveOverShooting: true,
                                        gradient: const LinearGradient(
                                          colors: [Colors.green, Colors.blue],
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                        ),
                                        aboveBarData: BarAreaData(
                                          show: true,
                                          color: Colors.red.withOpacity(0.18),
                                          cutOffY: 0,
                                          applyCutOffY: true,
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: Colors.green.withOpacity(0.18),
                                          cutOffY: 0,
                                          applyCutOffY: true,
                                        ),
                                      )
                                    ),
                                    // Robust split: below 0 segments
                                    ...splitSpotsByCutoff(_getBalanceSpots(), 0)[1].map((segment) =>
                                      LineChartBarData(
                                        spots: segment,
                                        isCurved: true,
                                        dotData: const FlDotData(show: false),
                                        barWidth: 4,
                                        curveSmoothness: 0.5,
                                        preventCurveOverShooting: true,
                                        gradient: const LinearGradient(
                                          colors: [Colors.red, Colors.orange],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                        aboveBarData: BarAreaData(
                                          show: true,
                                          color: Colors.red.withOpacity(0.18),
                                          cutOffY: 0,
                                          applyCutOffY: true,
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: Colors.green.withOpacity(0.18),
                                          cutOffY: 0,
                                          applyCutOffY: true,
                                        ),
                                      )
                                    ),
                                  ],
                                  titlesData: FlTitlesData(
                                    show: true,
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    bottomTitles: AxisTitles(
                                      axisNameSize: 40,
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 38,
                                        maxIncluded: false,
                                        interval: 1,
                                        getTitlesWidget: (value, meta) {
                                          if (_selectedPeriod == PeriodType.monthly) {
                                            int day = value.toInt() + 1;
                                            int daysInMonth = DateTime(DateTime.now().year, _sharedScrollIndex + 2, 0).day;
                                            // Only show first, last, every 5th day
                                            if (day == 1 || day == daysInMonth || day % 5 == 0) {
                                              return SideTitleWidget(
                                                meta: meta,
                                                child: Transform.rotate(
                                                  angle: -0.7,
                                                  child: Text(
                                                    '$day',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            } else {
                                              return const SizedBox.shrink();
                                            }
                                          } else if (_selectedPeriod == PeriodType.quarterly) {
                                            return SideTitleWidget(
                                              meta: meta,
                                              child: Text(
                                                quarterNames[value.toInt().clamp(0, 3)],
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            );
                                          } else if (_selectedPeriod == PeriodType.yearly) {
                                            return SideTitleWidget(
                                              meta: meta,
                                              child: Text(
                                                monthsNames[value.toInt().clamp(0, 11)].substring(0, 3),
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            );
                                          } else {
                                            return SideTitleWidget(
                                              meta: meta,
                                              child: Text(
                                                '${value.toInt() + 1}',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  lineTouchData: LineTouchData(
                                    enabled: true,
                                    handleBuiltInTouches: true,
                                    touchTooltipData: LineTouchTooltipData(
                                      getTooltipColor: (LineBarSpot touchedSpot) => colors[0],
                                      getTooltipItems: (touchedSpots) {
                                        // Only show one tooltip per x value (day), and skip if at intersection (start/end of segment)
                                        final seen = <double>{};
                                        return touchedSpots
                                            .where((spot) {
                                              // Prevent hover at intersection points (where x is not an integer)
                                              // Only allow hover if x is a whole number (i.e., a real day)
                                              return seen.add(spot.x) && spot.x == spot.x.roundToDouble();
                                            })
                                            .map((spot) {
                                              final value = spot.y;
                                              final day = spot.x.toInt() + 1;
                                              return LineTooltipItem(
                                                'Day $day\n${value.toStringAsFixed(2)}',
                                                const TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              );
                                            }).toList();
                                      },
                                    ),
                                    touchCallback: (event, touchResponse) {
                                      // Prevent interaction at intersection points (non-integer x)
                                      if (!event.isInterestedForInteractions ||
                                          touchResponse?.lineBarSpots == null ||
                                          touchResponse!.lineBarSpots!.isEmpty ||
                                          touchResponse.lineBarSpots!.first.x != touchResponse.lineBarSpots!.first.x.roundToDouble()) {
                                        setState(() {
                                          _interactedSpotIndexBalance = -1;
                                        });
                                        return;
                                      }
                                      setState(() {
                                        _interactedSpotIndexBalance = touchResponse.lineBarSpots!.first.spotIndex;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // PIE CHART
                        SizedBox(height: 24),
                        
                        SizedBox(height: 75)
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  FlSpotErrorRangePainter _errorPainter(
    LineChartSpotErrorRangeCallbackInput input,
  ) =>
      FlSimpleErrorPainter(
        lineWidth: 1.0,
        lineColor: _interactedSpotIndex == input.spotIndex
            ? Colors.white
            : Colors.white38,
        showErrorTexts: _interactedSpotIndex == input.spotIndex,
      );

  Widget _bottomTitles(double value, TitleMeta meta) {
    final day = value.toInt() + 1;

    final isDayHovered = _interactedSpotIndex == day - 1;

    final isImportantToShow = day % 5 == 0 || day == 1;

    if (!isImportantToShow && !isDayHovered) {
      return const SizedBox();
    }

    return SideTitleWidget(
      meta: meta,
      child: Text(
        day.toString(),
        style: TextStyle(
          color: isDayHovered ? Colors.black : Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  _touchCallback(FlTouchEvent event, LineTouchResponse? touchResponse) {
    if (!event.isInterestedForInteractions ||
        touchResponse?.lineBarSpots == null ||
        touchResponse!.lineBarSpots!.isEmpty) {
      setState(() {
        _interactedSpotIndex = -1;
      });
      return;
    }

    setState(() {
      _interactedSpotIndex = touchResponse.lineBarSpots!.first.spotIndex;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<Color> pieColors = [
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.green,
    Colors.red,
    Colors.yellow,
    Colors.cyan,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.brown,
    Colors.amber,
    Colors.grey,
  ];

  List<PieChartSectionData> showingSections() {
    final totalExpenses =
        _categoryTotals.values.fold(0.0, (sum, val) => sum + val);

    int index = 0;

    return _categoryTotals.entries.map((entry) {
      final category = entry.key;
      final amount = entry.value;
      final percentage = (amount / totalExpenses) * 100;

      final isTouched = index == touchedIndex;
      final fontSize = isTouched ? 20.0 : 14.0;
      final radius = isTouched ? 60.0 : 50.0;

      final color = pieColors[index % pieColors.length];
      index++;

      return PieChartSectionData(
        color: color,
        value: percentage,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      );
    }).toList();
  }

  Widget _periodButton(String label, PeriodType type) {
    final selected = _selectedPeriod == type;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [colors[1], colors[0]],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(22),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors[1].withOpacity(0.18),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : [],
          border: Border.all(
            color: selected ? colors[1] : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () async {
              if (type == PeriodType.custom) {
                setState(() {
                  _selectedPeriod = type;
                });
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: _customStart != null && _customEnd != null
                      ? DateTimeRange(start: _customStart!, end: _customEnd!)
                      : null,
                );
                if (picked != null) {
                  setState(() {
                    _customStart = picked.start;
                    _customEnd = picked.end;
                  });
                  _fetchPeriodData();
                }
              } else {
                _onPeriodChanged(type);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? Colors.white : colors[1],
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryBox(String label, double value, Color color) {
    return Container(
      width: 120,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          SizedBox(height: 4),
          Text('\$${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _balanceSignRow(List<FlSpot> spots) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(spots.length, (i) {
          final y = spots[i].y;
          Color color;
          if (y > 0) {
            color = Colors.green;
          } else if (y < 0) {
            color = Colors.red;
          } else {
            color = Colors.grey;
          }
          return Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}
