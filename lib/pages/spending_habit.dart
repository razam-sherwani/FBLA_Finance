import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fbla_finance/backend/indicator.dart';
import 'package:fbla_finance/backend/app_colors.dart';


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
  int touchedIndex = -1;

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

  // Add this map to store category-wise totals
final Map<String, double> _categoryTotals = {};

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
        _categoryTotals.clear(); // Reset category totals
        for (var doc in querySnapshot.docs) {
          final amount = doc['amount'] as double;
          final date = (doc['date'] as Timestamp).toDate();
          final type = doc['type'];
          final category = doc['category'] ?? 'Other'; // Default to 'Other'

          _rawData.add({
            'amount': amount,
            'date': date,
            'type': type,
            'category': category,
          });

          // Filter data for the selected month and only for expenses
          if (type == 'Expense' && date.month - 1 == _currentMonthIndex) {
            _categoryTotals[category] = (_categoryTotals[category] ?? 0) + amount;
          }
        }
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

      // Update the category totals
      String category = transaction['category'] ?? 'Other'; // Default to "Other" if category is missing
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

void _fetchRawDataLine() async {
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
        _createCleanDataLine();
      });
    } catch (error) {
      print("Error fetching transactions: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch transactions')),
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
    _fetchRawDataLine();
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
      appBar: AppBar(
        title: Text('Transaction Analysis', style: TextStyle(fontWeight: FontWeight.bold),),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text('Expenses Per Month', style: TextStyle(fontSize: 22,fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: AspectRatio(
                aspectRatio: 2.0,
                child: LineChart(
                  curve: Curves.linear,
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
                        curveSmoothness: 0.5,
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
          AspectRatio(
      aspectRatio: 1.3,
      child: Row(
        children: <Widget>[
          const SizedBox(
            height: 18,
          ),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse
                            .touchedSection!.touchedSectionIndex;
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
          const Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Indicator(
                color: AppColors.contentColorBlue,
                text: 'Food',
                isSquare: true,
              ),
              SizedBox(
                height: 4,
              ),
              Indicator(
                color: AppColors.contentColorYellow,
                text: 'Entertainment',
                isSquare: true,
              ),
              SizedBox(
                height: 4,
              ),
              Indicator(
                color: AppColors.contentColorPurple,
                text: 'Utilties',
                isSquare: true,
              ),
              SizedBox(
                height: 4,
              ),
              Indicator(
                color: AppColors.contentColorGreen,
                text: 'Other',
                isSquare: true,
              ),
              SizedBox(
                height: 18,
              ),
            ],
          ),
          const SizedBox(
            width: 28,
          ),
        ],
      ),
          ),
      ],
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
List<PieChartSectionData> showingSections() {
    // Calculate total expenses for the selected month
    final totalExpenses = _categoryTotals.values.fold(0.0, (sum, val) => sum + val);

    // Generate pie chart sections
    return _categoryTotals.entries.map((entry) {
      final category = entry.key;
      final amount = entry.value;
      final percentage = (amount / totalExpenses) * 100;

      final isTouched = category == touchedIndex;
      final fontSize = isTouched ? 25.0 : 16.0;
      final radius = isTouched ? 60.0 : 50.0;

      // Assign colors to categories
      final categoryColors = {
        'Food': AppColors.contentColorBlue,
        'Entertainment': AppColors.contentColorYellow,
        'Utilities': AppColors.contentColorPurple,
        'Other': AppColors.contentColorGreen,
      };

      return PieChartSectionData(
        color: categoryColors[category] ?? AppColors.contentColorGreen,
        value: percentage,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: AppColors.mainTextColor1,
          shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      );
    }).toList();
  }
}


