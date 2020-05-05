#include <Arduino.h>
#include <AnalogController.h>

#define MAX_INTENSITY_RED 850
#define MAX_INTENSITY_GREEN 800
#define MAX_INTENSITY_BLUE 900
#define MAX_INTENSITY_BACK 1023

double frequency = 5000;
uint8_t resolution = 10;

AnalogController::AnalogController()
{
  _attached = false;
  isOn = false;
}

uint8_t AnalogController::attach(int pin, AnalogType type, int channel, uint32_t maxValue)
{
  if (!_attached)
  {
    if (channel < 0 || channel > 15)
      return -1;

    _pin = pin;
    _type = type;
    _channel = channel;
    _maxValue = maxValue;
    intensity = 0;

    ledcSetup(channel, frequency, resolution);
    ledcAttachPin(_pin, channel);
    ledcWrite(channel, 0);
    _attached = true;
  }

  return pin;
}

void AnalogController::on()
{
  if (_attached)
  {
    setIntensity(MAX_ANALOG_WRITE);
    isOn = true;
  }
}

void AnalogController::off()
{
  if (_attached)
  {
    setIntensity(0);
    isOn = false;
  }
}

void AnalogController::toggle()
{
  if (_attached)
  {
    if (isOn)
      off();
    else
      on();
  }
}

void AnalogController::analogControllerWrite(uint32_t value)
{
  // Make sure the pin was attached to a channel, if not do nothing
  if (_channel > 0 && _channel < 16)
  {
    uint32_t levels = pow(2, resolution);
    uint32_t duty = ((levels - 1) / _maxValue) * min(value, _maxValue);
    
    intensity = value;    
    isOn = intensity > 0 ? true : false;

    // Serial.println("****************");
    // Serial.print("value ");Serial.println(value);
    // Serial.print("valueMax ");Serial.println(valueMax);
    // Serial.print("resolution ");Serial.println(resolution);
    // Serial.print("levels ");Serial.println(levels);
    // Serial.print("duty ");Serial.println(duty);
    // Serial.println("****************");

    // write duty to LEDC
    ledcWrite(_channel, duty);
  }
}

void AnalogController::setIntensity(int newIntensity)
{
  if (_attached)
  {
    switch (_type)
    {
    case RED:
      newIntensity = min(intensity, MAX_INTENSITY_RED);
      break;
    case GREEN:
      newIntensity = min(intensity, MAX_INTENSITY_GREEN);
      break;
    case BLUE:
      newIntensity = min(intensity, MAX_INTENSITY_BLUE);
      break;
    case BACK:
      newIntensity = min(intensity, MAX_INTENSITY_BACK);
      break;

    case MOTOR:
      newIntensity = min(intensity, MAX_ANALOG_WRITE);
      break;
    case UNDEFINED:
      newIntensity = min(intensity, MAX_ANALOG_WRITE);
      break;
    default:
      return;
      break;
    }
    analogControllerWrite(newIntensity);
  }
}
