import 'package:flutter/material.dart';

class SensorCard extends StatelessWidget {
  final value;
  final text;
  final bool small;
  final int flex;

  SensorCard({this.value, this.text, this.small = false, this.flex = 1});

  @override
  Widget build(BuildContext context) {
    final Widget _valueText = Text(
      " ${value != null ? value.toString() : "--"}",
      style: TextStyle(
        color: Colors.black,
        fontSize: !small ? 20.0 : 15,
      ),
      textAlign: TextAlign.center,
    );

    final card = Card(
      elevation: !small ? 5 : 3,
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: !small ? 5 : 1),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: !small ? 10 : 5,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Container(
              child: Text(
                "$text:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: _valueText,
            )
          ],
        ),
      ),
    );

    return Expanded(
      child: card,
      flex: flex,
    );
  }
}
