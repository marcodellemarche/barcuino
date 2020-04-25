import 'dart:math';

class MotorsSpeed {
  static int minSpeed = 250;
  static int maxSpeed = 1023;

  static int _left = 0;
  static int _right = 0;

  // 0.0 to 1.0
  static double leftAdjustment = 1;
  static double rightAdjustment = 1;

  static int getLeft() {
    int result = (MotorsSpeed.leftAdjustment * _left).floor();
    return result != null && result > minSpeed ? result : 0;
  }

  static int getRight() {
    int result = (MotorsSpeed.rightAdjustment * _right).floor();
    return result != null && result > minSpeed ? result : 0;
  }

  static void setMotorsSpeed({int left, int right}) {
    if (left != null) _left = left;
    if (right != null) _right = right;
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

    setMotorsSpeed(left: left, right: right);
  }

  static void setAdjstment({double left, double right}) {
    if (left != null) MotorsSpeed.leftAdjustment = left;
    if (right != null) MotorsSpeed.rightAdjustment = right;
  }
}
