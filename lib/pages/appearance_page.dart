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
    [Colors.blue, Colors.green],
    [Colors.red, Colors.orange],
    [Colors.yellow, Colors.green],
    [Colors.teal, Colors.cyan],
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
                  color: Colors.black,
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
