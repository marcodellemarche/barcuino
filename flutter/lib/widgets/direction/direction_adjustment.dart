import 'package:flutter/material.dart';

import '../../models/motors_speed.dart';

class DirectionAdjustment extends StatefulWidget {
  final Function onAdjustmentDone;
  final double startValue;

  DirectionAdjustment({this.startValue, this.onAdjustmentDone});

  @override
  _DirectionAdjustmentState createState() => _DirectionAdjustmentState();
}

class _DirectionAdjustmentState extends State<DirectionAdjustment> {
  double value = 1;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 3,
      child: Slider(
        value: value,
        onChanged: (newValue) {
          setState(() {
            value = newValue;
          });
        },
        onChangeEnd: (newValue) {
          widget.onAdjustmentDone(newValue);
        },
        divisions: 100,
        min: 0,
        max: 1,
        label: "${(value * 100).floor()} %",
      ),
    );
  }
}
