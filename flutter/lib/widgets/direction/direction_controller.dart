import 'package:barkino/models/motors_speed.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import './direction_adjustment.dart';
import './direction_input.dart';

class DirectionController extends StatelessWidget {
  final Function onDirectionChanged;
  // type 0 = Joystick, type 1 = arrows
  final int controllerType;
  final bool adjustmentsDisabled;

  const DirectionController({
    @required this.onDirectionChanged,
    this.controllerType,
    this.adjustmentsDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final double _size = min(
          MediaQuery.of(context).size.width,
          MediaQuery.of(context).size.height,
        ) *
        0.5;

    final DirectionInput directionInput = DirectionInput(
      size: _size,
      onDirectionChanged: onDirectionChanged,
      controllerType: controllerType,
    );

    void _onAdjustmentDone(double newValue, String type) {
      switch (type) {
        case "left":
          MotorsSpeed.setAdjstment(left: newValue);
          break;
        case "right":
          MotorsSpeed.setAdjstment(right: newValue);
          break;
        default:
          return;
      }
      MotorsSpeed.saveToSettings().then((_) {
        MotorsSpeed.getFromSettings();
      });
      onDirectionChanged();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Column(
          children: <Widget>[
            DirectionAdjustment(
              height: _size,
              startValue: MotorsSpeed.leftAdjustment.toDouble(),
              disabled: adjustmentsDisabled,
              onAdjustmentDone: (double newValue) {
                _onAdjustmentDone(newValue, "left");
              },
            ),
            Text(
              'L',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        directionInput,
        Column(
          children: <Widget>[
            DirectionAdjustment(
              height: _size,
              startValue: MotorsSpeed.rightAdjustment.toDouble(),
              disabled: adjustmentsDisabled,
              onAdjustmentDone: (double newValue) {
                _onAdjustmentDone(newValue, "right");
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
