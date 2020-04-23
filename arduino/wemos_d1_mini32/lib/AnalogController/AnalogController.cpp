#include <Arduino.h>
#include <AnalogController.h>

#define MAX_INTENSITY_RED 850
#define MAX_INTENSITY_GREEN 800
#define MAX_INTENSITY_BLUE 900
#define MAX_INTENSITY_BACK 1023

#define MAX_ANALOG_WRITE 1023

double frequency = 5000;
uint8_t resolution = 13;

AnalogController::AnalogController()
{
  _attached = false;
  isOn = false;
}

uint8_t AnalogController::attach(int pin, AnalogType type, int channel)
{
  if (!_attached)
  {
    if (channel < 0 || channel > 15)
      return -1;

    _pin = pin;
    _type = type;
    _channel = channel;

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

void analogControllerWrite(uint8_t channel, uint32_t value, uint32_t valueMax)
{
  // Make sure the pin was attached to a channel, if not do nothing
  if (channel > 0 && channel < 16)
  {
    uint32_t levels = pow(2, resolution);
    uint32_t duty = ((levels - 1) / valueMax) * min(value, valueMax);

    // write duty to LEDC
    ledcWrite(channel, duty);
  }
}

void AnalogController::setIntensity(int intensity)
{
  if (_attached)
  {
    switch (_type)
    {
    case RED:
      intensity = min(intensity, MAX_INTENSITY_RED);
      break;
    case GREEN:
      intensity = min(intensity, MAX_INTENSITY_GREEN);
      break;
    case BLUE:
      intensity = min(intensity, MAX_INTENSITY_BLUE);
      break;
    case BACK:
      intensity = min(intensity, MAX_INTENSITY_BACK);
      break;
    case UNDEFINED:
      intensity = min(intensity, MAX_ANALOG_WRITE);
      break;
    case MOTOR:
      intensity = min(intensity, MAX_ANALOG_WRITE);
      break;
    default:
      return;
      break;
    }
    analogControllerWrite(_channel, intensity, _valueMax);
    isOn = intensity > 0 ? true : false;
  }
}
