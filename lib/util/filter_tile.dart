import 'package:flutter/material.dart';

class FilterTile extends StatelessWidget {
  final icon;
  final String FilterName;
  final Color color;
  const FilterTile({super.key,required this.icon,required this.FilterName, required this.color});

  @override
  Widget build(BuildContext context) {
    
    return Expanded(
      child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                        padding: EdgeInsets.all(14),
                        color: color,
                        child: Icon(
                          icon,
                          color: Colors.white,
                        )),
                  ),
                  SizedBox(width: 12),
                  Text(
                        FilterName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          
                        ),
                        textAlign: TextAlign.center,
                      ),
                ],
              ),
            ],
          ),
    );
  }
}
