import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SpendingHabitPage extends StatefulWidget {
  final String userId;

  SpendingHabitPage({Key? key, required this.userId}) : super(key: key);

  @override
  _SpendingHabitPageState createState() => _SpendingHabitPageState();
}

class _SpendingHabitPageState extends State<SpendingHabitPage> {
  final List<Color> gradientColors = [
    Colors.redAccent,
    Colors.orangeAccent,
  ];

  final List<Map<String, dynamic>> _rawData = [];
  final List<List<double>> _income = List.generate(
    12,
    (_) => List.generate(31, (_) => 0.0),
  );
  final List<List<double>> _expense = List.generate(
    12,
    (_) => List.generate(31, (_) => 0.0),
  );

  int _currentMonthIndex = 0;
  late final List<String> monthsNames = [
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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _fetchRawData() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('Transactions')
          .get();

      setState(() {
        _rawData.clear();
        for (var doc in querySnapshot.docs) {
          _rawData.add({
            'amount': doc['amount'] as double, // Ensuring double type
            'date': (doc['date'] as Timestamp).toDate(),
            'type': doc['type']
          });
        }
        _createCleanData();
      });
    } catch (error) {
      print("Error fetching transactions: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch transactions')),
      );
    }
  }

  void _createCleanData() {
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

  @override
  void initState() {
    super.initState();
    _fetchRawData();
    minExpense = findMinExpense();
    maxExpense = findMaxExpense();
    minIncome = findMinIncome();
    maxIncome = findMaxIncome();
    overallMin = minExpense < minIncome ? minExpense : minIncome;
    overallMax = maxExpense > maxIncome ? maxExpense : maxIncome;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AspectRatio(
          aspectRatio: 2.0,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: _expense[_currentMonthIndex]
                      .asMap()
                      .entries
                      .map((e) {
                    final index = e.key;
                    final val = e.value;
                    return FlSpot(
                      index.toDouble(),
                      val,
                    );
                  }).toList(),
                  isCurved: true,
                  dotData: const FlDotData(show: false),
                  color: Colors.lightBlue,
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.purple],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  barWidth: 4,
                  curveSmoothness: 0.2,
                  preventCurveOverShooting: true,
                )
              ],
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _canGoNext => _currentMonthIndex < 11;

  bool get _canGoPrevious => _currentMonthIndex > 0;

  void _previousMonth() {
    if (!_canGoPrevious) {
      return;
    }
    setState(() {
      _currentMonthIndex--;
    });
  }

  void _nextMonth() {
    if (!_canGoNext) {
      return;
    }
    setState(() {
      _currentMonthIndex++;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }
}
