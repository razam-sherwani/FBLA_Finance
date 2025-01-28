import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AppearancePage extends StatefulWidget {
  final String userId;
  AppearancePage({Key? key, required this.userId}) : super(key: key);

  @override
  _AppearancePageState createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  List<List<Color>> gradients = [
    [Color(0xff56018D), Colors.pink],
    [Colors.black, Colors.orange, Colors.pink],
    [Colors.teal, Colors.cyan],
    [Color(0xffABF2FF), Color(0xffB8E8FF), Color(0xffBADFFF)],
    [Color(0xffFFEAB0), Color(0xffFFFDB0), Color(0xffFFF3B1)],
    [Color(0xff73F08F), Color(0xff86F0C1), Color(0xff85F0D1)],
    [Color(0xfffaf3dd), Color(0xffc8d5b9), Color(0xff8fc0a9)],
    [Color(0xff6b9080), Color(0xffa4c3b2), Color(0xffcce3de)],
    [Color(0xffC999DE), Color(0xffDF9ADB), Color(0xffDE99B1)],
    [Color(0xffE0B26E), Color(0xffE1C06F), Color(0xffE0CE6E)],
    [Color(0xff90E082), Color(0xff82E096), Color(0xff82E0B7)],
    [Color(0xffD7A7E0), Color(0xffE0A1C0)]
  ];

  List<Color> selectedGradient = [Color(0xff56018D), Colors.pink];

  @override
  void initState() {
    super.initState();
    _loadSelectedGradient();
  }

  Future<void> _loadSelectedGradient() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    if (doc.exists) {
      final data = doc.data();
      if (data != null && data.containsKey('appearance')) {
        final colors = List<Color>.from((data['appearance'] as List<dynamic>)
            .map((color) => Color(color)));
        setState(() {
          selectedGradient = colors;
        });
      }
    }
  }

  Future<void> _saveSelectedGradient() async {
    final colors = selectedGradient.map((color) => color.value).toList();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .set({
      'appearance': colors,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Appearance'),
        backgroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              const Text(
                'THEME',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 236, 233, 233),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 9,
                    crossAxisSpacing: 9,
                  ),
                  itemCount: gradients.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedGradient = gradients[index];
                          _saveSelectedGradient();
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradients[index],
                          ),
                          border: Border.all(
                            color: selectedGradient == gradients[index]
                                ? Colors.black
                                : Color.fromARGB(255, 111, 0, 255),
                            width: selectedGradient == gradients[index] ? 6 : 3,
                          ),
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
