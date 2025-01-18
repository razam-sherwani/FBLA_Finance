import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


class VRTourScreen extends StatefulWidget {
  @override
  _VRTourScreenState createState() => _VRTourScreenState();
}

class _VRTourScreenState extends State<VRTourScreen> {
  final List<Map<String, String>> _vrTours = [
    {'name': 'Frankfurt School', 'link': 'https://www.youtube.com/watch?v=N74KtkmObLg'},
    {'name': 'York University', 'link': 'https://www.youtube.com/watch?v=bFqGtZBZkNU'},
    {'name': 'Western Kentucky University', 'link': 'https://www.youtube.com/watch?v=oeF2SmkzxrQ'},
    {'name': 'University College Cork', 'link': 'https://www.youtube.com/watch?v=47reFDbCAY8'},
    {'name': 'Lakeland University', 'link': 'https://www.youtube.com/watch?v=Ap9L9ZE-2Fs'},
    {'name': 'The University of Tampa', 'link': 'https://www.youtube.com/watch?v=koeWmA4_iAs'},
    {'name': 'Pomona College', 'link': 'https://www.youtube.com/watch?v=BX5xXSRCM04'},
    {'name': 'Augustana College', 'link': 'https://www.youtube.com/watch?v=gI88SgxKN4s'},
    {'name': 'IU Indianapolis', 'link': 'https://www.youtube.com/watch?v=o9wkyt8PrEs'},
    {'name': 'Princeton University', 'link': 'https://www.youtube.com/watch?v=VwRd_yjMPYE'},
    {'name': 'Alexander College', 'link': 'https://www.youtube.com/watch?v=A6VVGNRNW8U'},
    {'name': 'Ithaca College', 'link': 'https://www.youtube.com/watch?v=ZpjuMBKeoaw'},
    {'name': 'Trinity University', 'link': 'https://www.youtube.com/watch?v=Gg7RBz_2Zqk'},
    {'name': 'North Park University', 'link': 'https://www.youtube.com/watch?v=sCRVn4nFvq4'},
    {'name': 'North Idaho College', 'link': 'https://www.youtube.com/watch?v=cuW9aFP98BQ'},
    {'name': 'University of St. Thomas', 'link': 'https://www.youtube.com/watch?v=nvYV2EeB5Jc'},
    {'name': 'Texas A&M', 'link': 'https://www.youtube.com/watch?v=ojjDIduvN4c'},
    {'name': 'Santa Clara University', 'link': 'https://www.youtube.com/watch?v=uQSMSLolz2A'},
    {'name': 'UGA', 'link': 'https://www.youtube.com/watch?v=h1g5mTi4pPA'},
    {'name': 'Oxford', 'link': 'https://www.youtube.com/watch?v=qUwmb5lyvYQ'},
  ];

  void _showLinkDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Open Link'),
          content: GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied to clipboard: $url'),
                ),
              );
            },
            child: Text(
              url,
              style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('College VR Tours'),
        backgroundColor: Colors.deepPurple[900],
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            // Add your back button functionality here, if needed
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Explore 3D Virtual Tours of Colleges',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'We have VR tours available for some colleges. Click on the links below to explore:',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _vrTours.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(
                        _vrTours[index]['name']!,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Tap to view tour',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: Icon(Icons.open_in_new, color: Colors.orange),
                      onTap: () {
                        _showLinkDialog(context, _vrTours[index]['link']!);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
