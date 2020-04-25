import 'package:flutter/material.dart';

import '../models/motors_speed.dart';

class DirectionAdjustment extends StatefulWidget {
  final Function onAdjustmentDone;
  final double startValue;
  final double min = MotorsSpeed.minSpeed?.toDouble() ?? 0;
  final double max = MotorsSpeed.maxSpeed?.toDouble() ?? 0;

  DirectionAdjustment({this.startValue, this.onAdjustmentDone});

  @override
  _DirectionAdjustmentState createState() => _DirectionAdjustmentState();
}

class _DirectionAdjustmentState extends State<DirectionAdjustment> {
  double value = MotorsSpeed.maxSpeed?.toDouble() ?? 0;

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
        min: 0,
        max: widget.max,
        label: "$value",
      ),
    );
  }
}
