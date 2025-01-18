import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';



class ScholarshipFinder extends StatefulWidget {
  @override
  _ScholarshipScreenState createState() => _ScholarshipScreenState();
}

class _ScholarshipScreenState extends State<ScholarshipFinder> {
  final TextEditingController _scoreController = TextEditingController();
  String? _selectedTest;
  String _result = '';

  final Map<int, String> actPercentiles = {
    36: '99+', 35: '99', 34: '99', 33: '98', 32: '96', 31: '95', 30: '93',
    29: '90', 28: '88', 27: '85', 26: '82', 25: '78', 24: '74', 23: '70',
    22: '64', 21: '59', 20: '53', 19: '47', 18: '41', 17: '35', 16: '28',
    15: '22', 14: '16', 13: '10', 12: '5', 11: '2', 10: '1', 9: '1', 8: '1',
    7: '1', 6: '1', 5: '1', 4: '1', 3: '1', 2: '1', 1: '1'
  };

  final Map<int, String> satPercentiles = {
    1600: '99+', 1570: '99+', 1560: '99', 1530: '99', 1520: '98', 1500: '98',
    1490: '97', 1480: '97', 1470: '96', 1450: '96', 1440: '95', 1430: '95',
    1420: '94', 1410: '94', 1400: '93', 1390: '92', 1380: '92', 1370: '91',
    1360: '90', 1350: '90', 1340: '89', 1330: '88', 1320: '87', 1310: '87',
    1300: '86', 1290: '85', 1280: '84', 1270: '83', 1260: '82', 1250: '81',
    1240: '80', 1230: '79', 1220: '78', 1210: '76', 1200: '75', 1190: '74',
    1180: '73', 1170: '71', 1160: '70', 1150: '69', 1140: '67', 1130: '66',
    1120: '64', 1110: '63', 1100: '61', 1090: '60', 1080: '58', 1070: '56',
    1060: '55', 1050: '53', 1040: '52', 1030: '50', 1020: '48', 1010: '47',
    1000: '45', 990: '43', 980: '42', 970: '40', 960: '39', 950: '37', 940: '36',
    930: '34', 920: '32', 910: '31', 900: '29', 890: '28', 880: '26', 870: '25',
    860: '23', 850: '22', 840: '20', 830: '19', 820: '17', 810: '16', 800: '14',
    790: '13', 780: '12', 770: '10', 760: '9', 750: '8', 740: '7', 730: '6',
    720: '5', 710: '4', 700: '3', 690: '3', 680: '2', 670: '2', 660: '1',
    620: '1', 610: '1', 600: '1', 590: '1', 580: '1', 570: '1', 560: '1',
    550: '1', 540: '1', 530: '1', 520: '1', 510: '1', 500: '1', 490: '1',
    480: '1', 470: '1', 460: '1', 450: '1', 440: '1', 430: '1', 420: '1',
    410: '1', 400: '1'
  };

  void _findScholarship() {
    int score = int.tryParse(_scoreController.text) ?? 0;
    String percentile = '';

    if (_selectedTest == 'ACT') {
      percentile = actPercentiles[score] ?? 'Invalid score';
    } else if (_selectedTest == 'SAT') {
      percentile = satPercentiles[score] ?? 'Invalid score';
    }

    setState(() {
      _result = 'Your percentile: $percentile\n\n'
                'For merit-based scholarships, visit the following link:\n'
                'https://www.princetonreview.com/college-advice/sat-act-scores-merit-scholarships';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scholar Sphere Scholarship Finder',style: TextStyle(fontWeight: FontWeight.bold),),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your test score to find scholarships:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedTest,
              hint: Text('Select Test'),
              items: <String>['ACT', 'SAT'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedTest = newValue;
                });
              },
            ),
            SizedBox(height: 17),
            TextField(
              controller: _scoreController,
              decoration: InputDecoration(
                labelText: 'Enter your score',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.deepPurple[50],
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _findScholarship,
              child: Text('Find A Scholarship'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, // Button background color
                foregroundColor: Colors.white, // Button text color
              ),
            ),
            SizedBox(height: 16),
            InkWell(
              onTap: ()async => await launchUrlString('https://www.princetonreview.com/college-advice/sat-act-scores-merit-scholarships'),
              child: Text(
                _result,
                style: TextStyle(fontSize: 16),
              ),
            ),
            
            
          ],
        ),
      ),
    );
  }
}
