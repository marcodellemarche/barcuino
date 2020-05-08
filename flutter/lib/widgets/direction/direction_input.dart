import 'package:flutter/material.dart';
import 'package:control_pad/models/pad_button_item.dart';
import 'package:control_pad/views/joystick_view.dart';
import 'package:control_pad/views/pad_button_view.dart';

import '../../utils.dart';
import '../../models/motors_speed.dart';

class DirectionInput extends StatelessWidget {
  final Function onDirectionChanged;
  // type 0 = Joystick, type 1 = arrows
  final int controllerType;
  final double size;

  const DirectionInput({
    @required this.onDirectionChanged,
    this.controllerType,
    this.size
  });

  void _onPadButtonPressed(int buttonPressed, var gesture) {
    int left;
    int right;
    bool includeAdjstments = false;

    switch (buttonPressed) {
      case ButtonPressed.RIGHT:
        left = MotorsSpeed.maxSpeed;
        right = 0;
        break;
      case ButtonPressed.UPWARD:
        left = MotorsSpeed.maxSpeed;
        right = MotorsSpeed.maxSpeed;
        includeAdjstments = true;
        break;
      case ButtonPressed.LEFT:
        left = 0;
        right = MotorsSpeed.maxSpeed;
        break;
      case ButtonPressed.STOP:
        left = 0;
        right = 0;
        break;
      default:
    }

    MotorsSpeed.setMotorsSpeed(left: left, right: right, includeAdjustments: includeAdjstments);
    print('setMotorsSpeed');

    this.onDirectionChanged();
  }

  void _onJoypadChanged(double degrees, double distance) {
    //double distanceShort = (distance * 10).floor() / 10;

    MotorsSpeed.setMotorsSpeedFromPad(degrees, distance);
    
    this.onDirectionChanged();
  }

  @override
  Widget build(BuildContext context) {
    //print('direction_controller build');
    if (controllerType == null || controllerType == 0) {
      return Container(
        padding: EdgeInsets.all(20),
        color: Colors.transparent,
        child: JoystickView(
          size: size,
          onDirectionChanged: _onJoypadChanged,
          interval: Duration(milliseconds: 300),
        ),
      );
    } else {
      return Container(
        padding: EdgeInsets.all(20),
        child: PadButtonsView(
          size: size,
          padButtonPressedCallback: _onPadButtonPressed,
          buttons: const [
            PadButtonItem(
              index: ButtonPressed.RIGHT,
              buttonIcon: Icon(Icons.arrow_forward, size: 30),
              backgroundColor: Colors.white54,
            ),
            PadButtonItem(
              index: ButtonPressed.STOP,
              buttonIcon: Icon(
                Icons.stop,
                size: 40,
              ),
              backgroundColor: Colors.white54,
              pressedColor: Colors.red,
            ),
            PadButtonItem(
              index: ButtonPressed.LEFT,
              buttonIcon: Icon(
                Icons.arrow_back,
                size: 30,
              ),
              backgroundColor: Colors.white54,
            ),
            PadButtonItem(
              index: 3,
              buttonIcon: Icon(Icons.arrow_upward, size: 30),
              backgroundColor: Colors.white54,
            ),
          ],
        ),
      );
    }
  }
}