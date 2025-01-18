import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class EcTile extends StatelessWidget {
  final icon;
  final String EcName;
  final Color color;
  const EcTile({Key? key,required this.icon,required this.EcName, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 12.0),
    child:  Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                      padding: EdgeInsets.all(16),
                      color: color,
                      child: Icon(
                        icon,
                        color: Colors.white,
                      )),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      EcName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    
                  ],
                ),
              ],
            ),
            Icon(Icons.more_horiz),
          ],
        )),
    );
  }
}
