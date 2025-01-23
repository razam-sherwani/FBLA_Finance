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
    12,  // 12 months
    (_) => List.generate(
      31,  // 31 days in each month
      (_) => 0.0,  // Default value for each day
    ),
  );
  final List<List<double>> _expense = List.generate(
    12,  // 12 months
    (_) => List.generate(
      31,  // 31 days in each month
      (_) => 0.0,  // Default value for each day
    ),
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
  void _fetchRawData() {
    _firestore.collection('users').doc(widget.userId).collection('Transactions').get().then((querySnapshot) {
      setState(() {
        _rawData.clear(); // Clear existing items
        querySnapshot.docs.forEach((doc) {
          _rawData.add({
            'amount': doc['amount'],
            'date': DateFormat('ddMMyyyy').format(doc['date'].toDate()),
            'type': doc['type']
          });
        });
      });
    }).catchError((error) {
      print("Error fetching transactions: $error");
      // Handle error gracefully, e.g., show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch transations')));
    });
  }

  void _createCleanData() {

    for (var transaction in _rawData) {
    // Parse the date from the 'ddMMyyyy' string format
    String dateStr = transaction['date'];
    DateTime date = DateFormat('ddMMyyyy').parse(dateStr);

    // Extract the month (1-based) and day (1-based)
    int month = date.month - 1;  // Month is 1-based, so we subtract 1 for zero-indexed
    int day = date.day - 1;      // Day is 1-based, so we subtract 1 for zero-indexed

    // Get the amount from the transaction
    double amount = transaction['amount'];

// Add the amount to the correct position in the list
    if (transaction['type'] == 'Expense') {
      // Add the amount to the correct day of the month
      _expense[month][day] += amount;
    } else {
      _income[month][day] += amount;
    }
    }

  }

  double minExpense = 0;
  double maxExpense = 0;
  double minIncome = 0;
  double maxIncome = 0;
  double overallMin = 0;
  double overallMax = 0;
  int _interactedSpotIndex = -1;

  double findMinExpense() {

    return _expense.expand((list) => list).reduce((a,b) => a < b ? a : b);

  }

  double findMaxExpense() {

    return _expense.expand((list) => list).reduce((a, b) => a > b ? a : b);

  }
  double findMinIncome() {

    return _income.expand((list) => list).reduce((a,b) => a < b ? a : b);

  }

  double findMaxIncome() {

    return _income.expand((list) => list).reduce((a, b) => a > b ? a : b);

  }

  
  void initState() {

    minExpense = findMinExpense();
    maxExpense = findMaxExpense();
    minIncome = findMinIncome();
    maxIncome = findMaxIncome();
    overallMin = (minExpense < minIncome) ? minExpense : minIncome;
    overallMax = (maxExpense > maxIncome) ? maxExpense : maxIncome; 
  }
  
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(

        child: 
        Column(


        children: [
          const SizedBox(height: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Transactions: 2025',
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
            ],
          ),
          const SizedBox(height: 18),
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
                    color: Colors.blueAccent,
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
          const SizedBox(height: 18),
          AspectRatio(
            aspectRatio: 1.4,
            child: Stack(
              children: [
                if (_expense != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 0.0,
                      right: 18.0,
                    ),
                    child: LineChart(
                      LineChartData(
                        minY: overallMin - 5,
                        maxY: overallMax + 5,
                        minX: 0,
                        maxX: 31,
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
                            isCurved: false,
                            dotData: const FlDotData(show: false),
                            color: Colors.lightBlue,
                            barWidth: 1,
                
                          ),
                        ],
                        gridData: FlGridData(
                          show: true,
                          drawHorizontalLine: true,
                          drawVerticalLine: false,
                          horizontalInterval: 5,
                          getDrawingHorizontalLine: _horizontalGridLines,
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            drawBelowEverything: true,
                            sideTitles: SideTitles(
                              showTitles: true,
                              maxIncluded: false,
                              minIncluded: false,
                              reservedSize: 10,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(
                                    '${meta.formattedValue}°',
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            axisNameWidget: Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              child: const Text(
                                'Day of month',
                                style: TextStyle(
                                  color: Colors.green,
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
                  ),
                if (_expense == null)
                  const Center(
                    child: CircularProgressIndicator(),
                  )
              ],
            ),
          ),
        ],
        )
    ));
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

  FlLine _horizontalGridLines(double value) {
    final isZero = value == 0.0;
    return FlLine(
      color: isZero ? Colors.white38 : Colors.blueGrey,
      strokeWidth: isZero ? 0.8 : 0.4,
      dashArray: isZero ? null : [8, 4],
    );
  }

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
              ? Colors.white
              : Colors.greenAccent,
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
}

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     appBar: AppBar(
  //       title: Text('Spending Habit'),
  //     ),
  //     body: Padding(
  //       padding: const EdgeInsets.all(16.0),
  //       child: LineChart(
  //         LineChartData(
  //           titlesData: Titles.getTitleData(),
  //           gridData: FlGridData(
  //             show: true,
  //             getDrawingHorizontalLine: (value) {
  //               return FlLine(
  //                 color: Colors.grey[800],
  //                 strokeWidth: 1,
  //               );
  //             },
  //           ),
  //           borderData: FlBorderData(
  //             show: true,
  //             border: Border.all(color: Colors.grey[800] ?? Colors.grey, width: 2),
  //           ),
  //           lineBarsData: [
  //             LineChartBarData(
  //               spots: [
  //                 FlSpot(0, 30000),
  //                 FlSpot(2.5, 10000),
  //                 FlSpot(4, 50000),
  //                 FlSpot(6, 43000),
  //                 FlSpot(8, 40000),
  //                 FlSpot(9, 30000),
  //                 FlSpot(11, 38000),
  //               ],
  //               isCurved: true,
  //               gradient: LinearGradient(
  //                 colors: gradientColors,
  //               ),
  //               barWidth: 3,
  //               belowBarData: BarAreaData(
  //                 show: true,
  //                 gradient: LinearGradient(
  //                   colors: gradientColors.map((color) => color.withOpacity(.4)).toList(),
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }
//}


// class Titles {
//   static getTitleData() => FlTitlesData(
//         show: true,
//         bottomTitles: AxisTitles(
//           sideTitles: SideTitles(
//             showTitles: true,
//             reservedSize: 35,
//             getTitlesWidget: (value, meta) {
//               switch (value.toInt()) {
//                 case 2:
//                   return Padding(
//                     padding: EdgeInsets.only(top: 8.0),
//                     child: Text(
//                       '2020',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.grey,
//                       ),
//                     ),
//                   );
//                 case 5:
//                   return Padding(
//                     padding: EdgeInsets.only(top: 8.0),
//                     child: Text(
//                       '2021',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.grey,
//                       ),
//                     ),
//                   );
//                 case 8:
//                   return Padding(
//                     padding: EdgeInsets.only(top: 8.0),
//                     child: Text(
//                       '2022',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.grey,
//                       ),
//                     ),
//                   );
//               }
//               return Text('');
//             },
//           ),
//         ),
//         leftTitles: AxisTitles(
//           sideTitles: SideTitles(
//             showTitles: true,
//             reservedSize: 35,
//             getTitlesWidget: (value, meta) {
//               switch (value.toInt()) {
//                 case 10000:
//                   return Padding(
//                     padding: EdgeInsets.only(right: 8.0),
//                     child: Text(
//                       '10k',
//                       style: TextStyle(
//                         color: Colors.grey,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 13,
//                       ),
//                     ),
//                   );
//                 case 20000:
//                   return Padding(
//                     padding: EdgeInsets.only(right: 8.0),
//                     child: Text(
//                       '20k',
//                       style: TextStyle(
//                         color: Colors.grey,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 13,
//                       ),
//                     ),
//                   );
//                 case 30000:
//                   return Padding(
//                     padding: EdgeInsets.only(right: 8.0),
//                     child: Text(
//                       '30k',
//                       style: TextStyle(
//                         color: Colors.grey,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 13,
//                       ),
//                     ),
//                   );
//                 case 40000:
//                   return Padding(
//                     padding: EdgeInsets.only(right: 8.0),
//                     child: Text(
//                       '40k',
//                       style: TextStyle(
//                         color: Colors.grey,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 13,
//                       ),
//                     ),
//                   );
//                 case 50000:
//                   return Padding(
//                     padding: EdgeInsets.only(right: 8.0),
//                     child: Text(
//                       '50k',
//                       style: TextStyle(
//                         color: Colors.grey,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 13,
//                       ),
//                     ),
//                   );
//                 case 60000:
//                   return Padding(
//                     padding: EdgeInsets.only(right: 8.0),
//                     child: Text(
//                       '60k',
//                       style: TextStyle(
//                         color: Colors.grey,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 13,
//                       ),
//                     ),
//                   );
//                 case 70000:
//                   return Padding(
//                     padding: EdgeInsets.only(right: 8.0),
//                     child: Text(
//                       '70k',
//                       style: TextStyle(
//                         color: Colors.grey,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 13,
//                       ),
//                     ),
//                   );
//               }
//               return Text('');
//             },
//           ),
//         ),
//       );
// }




