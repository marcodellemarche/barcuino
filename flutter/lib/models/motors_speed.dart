import 'dart:math';

import 'package:barkino/models/settings.dart';

class MotorsSpeed {
  static int minSpeed = 250;
  static int maxSpeed = 1023;

  static int _leftOut = 0;
  static int _rightOut = 0;

  static int _leftIn = 0;
  static int _rightIn = 0;

  // 0.0 to 1.0
  static double leftAdjustment = 1;
  static double rightAdjustment = 1;

  static int getLeft() {
    //int result = (MotorsSpeed.leftAdjustment * _left).floor();
    int result = _leftOut;
    return result != null && result > minSpeed ? result : 0;
  }

  static int getRight() {
    //int result = (MotorsSpeed.rightAdjustment * _right).floor();
    int result = _rightOut;
    return result != null && result > minSpeed ? result : 0;
  }

  static void setMotorsSpeed({int left, int right, bool includeAdjustments = false,}) 
  {
    if (left != null) _leftIn = left;

    if (right != null) _rightIn = right;

    if (includeAdjustments) {
      _rightOut = (MotorsSpeed.rightAdjustment * _rightIn).floor();
      _leftOut = (MotorsSpeed.leftAdjustment * _leftIn).floor();
    } else
    {
      _rightOut = _rightIn;
      _leftOut = _leftIn;
    }
  }

  static void setMotorsSpeedFromPad(double degrees, double distance) {
    const degrees2Radians = pi / 180.0;

    double rightSpeed = 0;
    double leftSpeed = 0;

    if (degrees >= 0 && degrees <= 180) {
      leftSpeed = maxSpeed.toDouble();
      rightSpeed = maxSpeed * (cos(degrees * degrees2Radians)).abs();
    } else {
      rightSpeed = maxSpeed.toDouble();
      leftSpeed = maxSpeed * (cos(degrees * degrees2Radians)).abs();
    }

    int left = (leftSpeed * distance).round();
    int right = (rightSpeed * distance).round();

    setMotorsSpeed(left: left, right: right, includeAdjustments: true);
  }

  static void setAdjstment({double left, double right}) {
    if (left != null) MotorsSpeed.leftAdjustment = left;
    if (right != null) MotorsSpeed.rightAdjustment = right;
  }

  static Future<bool> saveToSettings() async {
    try {
      Settings settings = Settings();
      await settings
          .setByKey('leftAdjustment', leftAdjustment)
          .then((bool result) {
        print('leftAdjustment saved $leftAdjustment. result $result');
        return result;
      });
      await settings
          .setByKey('rightAdjustment', rightAdjustment)
          .then((bool result) {
        print('rightAdjustment saved $rightAdjustment. result $result');
        return result;
      });
      return true;
    } catch (err) {
      return err;
    }
  }

  static Future<bool> getFromSettings() async {
    Settings settings = Settings();
    leftAdjustment = await settings.getByKey('leftAdjustment') ?? 1;
    print('leftAdjustment $leftAdjustment');

    rightAdjustment = await settings.getByKey('rightAdjustment') ?? 1;
    print('rightAdjustment $rightAdjustment');

    return true;
  }
}
