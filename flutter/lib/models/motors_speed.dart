import 'dart:math';

class MotorsSpeed {
  static int minSpeed = 250;
  static int maxSpeed = 1023;

  static int _left = 0;
  static int _right = 0;

  static int leftAdjustment = 0;
  static int rightAdjustment = 0;

  static int getLeft() {
    int result = _left - (MotorsSpeed.leftAdjustment ?? 0);
    return result != null && result > minSpeed ? result : 0;
  }

  static int getRight() {
    int result = _right - (MotorsSpeed.rightAdjustment ?? 0);
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

  static void setAdjstment({int left, int right}) {
    if (left != null) MotorsSpeed.leftAdjustment = left;
    if (right != null) MotorsSpeed.rightAdjustment = right;
  }
}
