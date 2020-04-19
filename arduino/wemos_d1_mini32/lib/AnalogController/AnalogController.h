#include <Arduino.h>

enum AnalogType { UNDEFINED, RED, GREEN, BLUE, BACK, MOTOR };

class AnalogController
{
public:
    AnalogController();
    uint8_t attach(int pin, AnalogType type, int channel); // attach the given pin and initialize pin
    void detach();
    void on();  // switch on LED with max value supported by led type
    void toggle(); // switch on/off
    void off();
    void setIntensity(int intensity); // set intensity to the one desired
    bool isOn;
private:
    bool    _attached;
    uint8_t _pin;
    uint8_t _channel;
    AnalogType _type;
    uint32_t _valueMax = 255U;
};