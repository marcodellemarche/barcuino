import 'package:flutter/material.dart';
import 'package:control_pad/models/pad_button_item.dart';
import 'package:control_pad/views/joystick_view.dart';
import 'package:control_pad/views/pad_button_view.dart';

import '../utils.dart';

class DirectionController extends StatelessWidget {
  final Function onDirectionChanged;
  // type 0 = Joystick, type 1 = arrows
  final int controllerType;

  const DirectionController(
      {@required this.onDirectionChanged,
      this.controllerType,});

  void _onPadButtonPressed(int buttonPressed, var gesture) {
    double distance = 1;
    double degrees;
    switch (buttonPressed) {
      case ButtonPressed.LEFT:
        degrees = 270;
        break;
      case ButtonPressed.UPWARD:
        degrees = 0;
        break;
      case ButtonPressed.RIGHT:
        degrees = 90;
        break;
      case ButtonPressed.STOP:
        degrees = 0;
        distance = 0;
        break;
      default:
    }
    
    this.onDirectionChanged(degrees, distance);
  }

  @override
  Widget build(BuildContext context) {
    //print('direction_controller build');
    if (controllerType == null || controllerType == 0) {
      return Container(
        padding: EdgeInsets.all(20),
        color: Colors.transparent,
        child: JoystickView(
          onDirectionChanged: onDirectionChanged,
          interval: Duration(milliseconds: 300),
        ),
      );
    } else {
      return Container(
        padding: EdgeInsets.all(20),
        child: PadButtonsView(
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
