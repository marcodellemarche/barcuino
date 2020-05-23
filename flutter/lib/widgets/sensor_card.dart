import 'package:flutter/material.dart';

class SensorCard extends StatelessWidget {
  final value;
  final text;

  SensorCard({this.value, this.text});

  @override
  Widget build(BuildContext context) {
    final Widget _valueText = Text(
      " ${value != null ? value.toString() : "--"}",
      style: TextStyle(
        color: Colors.black,
        fontSize: 20.0,
      ),
      textAlign: TextAlign.center,
    );

    return Expanded(
      child: Card(
        elevation: 5,
        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
