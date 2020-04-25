import 'package:barkino/models/motors_speed.dart';
import 'package:flutter/material.dart';

import '../widgets/direction_adjustment.dart';
import '../widgets/direction_input.dart';

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Column(
          children: <Widget>[
            DirectionAdjustment(
              startValue: MotorsSpeed.leftAdjustment.toDouble(),
              onAdjustmentDone: (double newValue) {
                MotorsSpeed.setAdjstment(left: MotorsSpeed.maxSpeed - newValue.floor());
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
          onDirectionChanged: onDirectionChanged,
          controllerType: controllerType,
        ),
        Column(
          children: <Widget>[
            DirectionAdjustment(
              startValue: MotorsSpeed.rightAdjustment.toDouble(),
              onAdjustmentDone: (double newValue) {
                MotorsSpeed.setAdjstment(right: MotorsSpeed.maxSpeed - newValue.floor());
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
