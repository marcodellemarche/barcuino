import 'package:barkino/models/motors_speed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
import 'dart:math';

import './direction_adjustment.dart';
import './direction_input.dart';

class DirectionController extends StatelessWidget {
  final Function onDirectionChanged;
  // type 0 = Joystick, type 1 = arrows
  final int controllerType;

  const DirectionController({
    @required this.onDirectionChanged,
    this.controllerType,
  });

  @override
  Widget build(BuildContext context) {
    final double _size = min(MediaQuery.of(context).size.width,
            MediaQuery.of(context).size.height) *
        0.5;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Column(
          children: <Widget>[
            DirectionAdjustment(
              height: _size,
              startValue: MotorsSpeed.leftAdjustment.toDouble(),
              onAdjustmentDone: (double newValue) {
                MotorsSpeed.setAdjstment(left: newValue);
                MotorsSpeed.saveToSettings().then((_) {MotorsSpeed.getFromSettings();});
                onDirectionChanged();
              },
            ),
            Text(
              'L',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        DirectionInput(
          size: _size,
          onDirectionChanged: onDirectionChanged,
          controllerType: controllerType,
        ),
        Column(
          children: <Widget>[
            DirectionAdjustment(
              height: _size,
              startValue: MotorsSpeed.rightAdjustment.toDouble(),
              onAdjustmentDone: (double newValue) {
                MotorsSpeed.setAdjstment(right: newValue);
                MotorsSpeed.saveToSettings().then((_) {MotorsSpeed.getFromSettings();});
                onDirectionChanged();
              },
            ),
            Text(
              'R',
              style: TextStyle(fontWeight: FontWeight.bold),
            )
          ],
        ),
      ],
    );
  }
}
