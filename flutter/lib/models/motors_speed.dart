import 'dart:math';

class MotorsSpeed {
  static int minSpeed = 250;
  static int maxSpeed = 1023;

  static int left;
  static int right;

  static int leftAdjustment;
  static int rightAdjustment;

  static void setMotorsSpeed(int left, int right) {
    left = left + (MotorsSpeed.leftAdjustment ?? 0);
    right = right + (MotorsSpeed.rightAdjustment ?? 0);
    MotorsSpeed.left = left != null && left > minSpeed ? left : 0;
    MotorsSpeed.right = right != null && right > minSpeed ? right : 0;
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

    setMotorsSpeed(left, right);
  }

  static void setAdjstment(int left, int right) {
    MotorsSpeed.leftAdjustment = left;
    MotorsSpeed.rightAdjustment = right;
  }
}
