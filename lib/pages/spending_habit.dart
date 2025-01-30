import 'dart:io';
import 'dart:ui';

import 'package:fbla_finance/backend/auth.dart';
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

class SpendingHabitPage extends StatefulWidget {

  SpendingHabitPage({Key? key}) : super(key: key);

  @override
  _SpendingHabitPageState createState() => _SpendingHabitPageState();
}

class _SpendingHabitPageState extends State<SpendingHabitPage> {
  final User? user = Auth().currentUser;
  String docID = "";
  final List<Color> gradientColors = [
    Colors.redAccent,
    Colors.orangeAccent,
  ];
  int touchedIndex = -1;
  final GlobalKey _expenseGraphKey = GlobalKey();
  final GlobalKey _balanceGraphKey = GlobalKey();
  final GlobalKey _pieChartKey = GlobalKey();

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

  final int minDays = 1;
  final int maxDays = 31;

  int _currentMonthIndex = 0;
  late final List<String> monthsNames;


  // Add this map to store category-wise totals
  final Map<String, double> _categoryTotals = {};

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  void _fetchRawData() async {
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
            _categoryTotals[category] =
                (_categoryTotals[category] ?? 0) + amount;
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

  void _fetchRawDataLine() async {
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



  void _fetchRawDataCurrentBalance() async {
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
            'amount': doc['amount'] as double, // Ensuring double type
            'date': (doc['date'] as Timestamp).toDate(),
            'type': doc['type']
          });
        }
        _createCleanDataCurrentBalance();
      });
    } catch (error) {
      print("Error fetching transactions: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch transactions')),
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

Future<void> _initializeData() async {
  await fetchDocID();  // Wait for fetchDocID to complete
  _fetchRawDataLine();
  _fetchRawData();
  _fetchRawDataCurrentBalance();
}

  @override
void initState() {
  super.initState();
  
  monthsNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  // Fetch data
  _initializeData();

  // Wait for the first frame and then delay before capturing images
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Delay to ensure rendering is complete
    await Future.delayed(Duration(milliseconds: 500));

    // Save the graphs as images after rendering
    await saveGraphAsImage(_expenseGraphKey, 'expense_graph.png');
    await saveGraphAsImage(_balanceGraphKey, 'balance_graph.png');
    await saveGraphAsImage(_pieChartKey, 'pie_chart.png');
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Transaction Analysis',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 35,
            ),
            
        Padding(
          padding: const EdgeInsets.only(top: 25),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Expenses Per Month 2025',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: _canGoPrevious ? _previousMonth : null,
                  icon: const Icon(Icons.navigate_before_rounded),
                ),
              ),
            ),
            SizedBox(
              width: 92,
              child: Text(
                monthsNames[_currentMonthIndex],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.contentColorBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _canGoNext ? _nextMonth : null,
                  icon: const Icon(Icons.navigate_next_rounded),
                ),
              ),
            ),
          ],
        ),

        RepaintBoundary(
          key: _expenseGraphKey,
          child: AspectRatio(
            aspectRatio: 1.5,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    right: 18.0,
                    top: 7.0,
                  ),
                  child: LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots:
                              _expense[_currentMonthIndex].asMap().entries.map((e) {
                            final index = e.key;
                            final val = e.value;
                            return FlSpot(
                              (index).toDouble(),
                              val,
                            );
                          }).toList(),
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
                            margin: const EdgeInsets.only(bottom: 20),
                            child: const Text(
                              'Day of month',
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
                            getTitlesWidget: _bottomTitles,
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        handleBuiltInTouches: false,
                        touchCallback: _touchCallback,
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),

            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text('Current Balance Per Day',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            RepaintBoundary(
              key: _balanceGraphKey,
              child: Padding(
                padding: const EdgeInsets.only(right: 18,top: 7),
                child: AspectRatio(
                  aspectRatio: 1.5,
                  child: LineChart(
                    curve: Curves.linear,
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots:
                              _curBal[_currentMonthIndex].asMap().entries.map((e) {
                            final index = e.key;
                            final val = e.value;
                            return FlSpot(
                              (index).toDouble(),
                              val,
                            );
                          }).toList(),
                          isCurved: true,
                          dotData: const FlDotData(show: true),
                          color: Colors.lightBlue,
                          gradient: const LinearGradient(
                            colors: [Colors.green, Colors.blue],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          barWidth: 4,
                          curveSmoothness: 0.5,
                          preventCurveOverShooting: true,
                        )
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
                            getTitlesWidget: _bottomTitles,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text('Expenses By Category',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                                  touchCallback:
                                      (FlTouchEvent event, pieTouchResponse) {
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
              ),
            ),
            SizedBox(height: 75)
          ],
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

  Future<void> saveGraphAsImage(GlobalKey graphKey, String fileName) async {
  try {
    final boundary =
        graphKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
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

  void _nextMonth() {
    if (!_canGoNext) {
      return;
    }
    setState(() {
      _currentMonthIndex++;
    });
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
          color: isDayHovered
              ? Colors.black
              : Colors.black,
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

  List<PieChartSectionData> showingSections() {
    // Calculate total expenses for the selected month
    final totalExpenses =
        _categoryTotals.values.fold(0.0, (sum, val) => sum + val);

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
