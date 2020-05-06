#include <Arduino.h>
#include <AnalogController.h>

#define MAX_INTENSITY_RED 700
#define MAX_INTENSITY_GREEN 800
#define MAX_INTENSITY_BLUE 900
#define MAX_INTENSITY_BACK 1023

#define MAX_ANALOG_WRITE 1023

AnalogController::AnalogController()
{
  _attached = false;
  isOn = false;
}

uint8_t AnalogController::attach (int pin, AnalogType type) {
  if (!_attached) {
    _pin = pin;
    _type = type;
    intensity = 0;
    pinMode(_pin, OUTPUT);
    analogWrite(_pin, 0);
    _attached = true;
  }

  return pin;
}

void AnalogController::on () {
  if (_attached) {
    setIntensity(MAX_ANALOG_WRITE);
    isOn = true;
  }
}

void AnalogController::off () {
  if (_attached) {
    setIntensity(0);
    isOn = false;
  }
}

void AnalogController::toggle () {
  if (_attached) {
    if (isOn)
      on();
    else
      off();
  }
}

void AnalogController::setIntensity(int newIntensity) {
  if (_attached) {
    switch (_type)
    {
      case RED:
        newIntensity = min(newIntensity, MAX_INTENSITY_RED);
        break;
      case GREEN:
        newIntensity = min(newIntensity, MAX_INTENSITY_GREEN);
        break;
      case BLUE:
        newIntensity = min(newIntensity, MAX_INTENSITY_BLUE);
        break;
      case BACK:
        newIntensity = min(newIntensity, MAX_INTENSITY_BACK);
        break;
      case MOTOR:
        newIntensity = min(newIntensity, MAX_ANALOG_WRITE);
        break;
      case UNDEFINED:
        newIntensity = min(newIntensity, MAX_ANALOG_WRITE);
        break;    
      default:
        return;
        break;
    }
    intensity = newIntensity;
    analogWrite(_pin, intensity);
    isOn = intensity > 0 ? true : false;
  }
}
