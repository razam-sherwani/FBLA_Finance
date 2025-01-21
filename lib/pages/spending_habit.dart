import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Spending Habit'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LineChart(
          LineChartData(
            titlesData: Titles.getTitleData(),
            gridData: FlGridData(
              show: true,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey[800],
                  strokeWidth: 1,
                );
              },
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey[800] ?? Colors.grey, width: 2),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  FlSpot(0, 30000),
                  FlSpot(2.5, 10000),
                  FlSpot(4, 50000),
                  FlSpot(6, 43000),
                  FlSpot(8, 40000),
                  FlSpot(9, 30000),
                  FlSpot(11, 38000),
                ],
                isCurved: true,
                gradient: LinearGradient(
                  colors: gradientColors,
                ),
                barWidth: 3,
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: gradientColors.map((color) => color.withOpacity(.4)).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class Titles {
  static getTitleData() => FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 35,
            getTitlesWidget: (value, meta) {
              switch (value.toInt()) {
                case 2:
                  return Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      '2020',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  );
                case 5:
                  return Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      '2021',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  );
                case 8:
                  return Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      '2022',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  );
              }
              return Text('');
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 35,
            getTitlesWidget: (value, meta) {
              switch (value.toInt()) {
                case 10000:
                  return Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Text(
                      '10k',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  );
                case 20000:
                  return Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Text(
                      '20k',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  );
                case 30000:
                  return Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Text(
                      '30k',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  );
                case 40000:
                  return Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Text(
                      '40k',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  );
                case 50000:
                  return Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Text(
                      '50k',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  );
                case 60000:
                  return Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Text(
                      '60k',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  );
                case 70000:
                  return Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Text(
                      '70k',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  );
              }
              return Text('');
            },
          ),
        ),
      );
}




// class Titles {
//   static getTitleData() => FlTitlesData(
//     show: true,
//     bottomTitles: SideTitles(
//       showTitles: true,
//       reservedSize: 35,
//       getTextStyles: (value) => const TextStyle(
//         color: Colors.grey,
//         fontWeight: FontWeight.bold,
//         fontSize: 16,
//       ),
//       getTitles: (value) {
//         switch (value.toInt()) {
//           case 2:
//             return '2020';
//           case 5:
//             return '2021';
//           case 8:
//             return '2022';
//         }
//         return '';
//       },
//       margin: 5,
//     ),
//     leftTitles: SideTitles(
//       showTitles: true,
//       getTextStyles: (value) => const TextStyle(
//         color: Colors.grey,
//         fontWeight: FontWeight.bold,
//         fontSize: 13,
//       ),
//       getTitles: (value) {
//         switch (value.toInt()) {
//           case 10000:
//             return '10k';
//           case 20000:
//             return '20k';
//           case 30000:
//             return '30k';
//           case 40000:
//             return '40k';
//           case 50000:
//             return '50k';
//           case 60000:
//             return '60k';
//           case 70000:
//             return '70k';
//         }
//         return '';
//       },
//       reservedSize: 35,
//       margin: 5,
//     ),
//   );
// }
