#include <Arduino.h>

enum AnalogType { UNDEFINED, RED, GREEN, BLUE, BACK, MOTOR };

class AnalogController
{
public:
    AnalogController();
    uint8_t attach(int pin, AnalogType type); // attach the given pin and initialize pin
    void detach();
    void on();  // switch on LED with max value supported by led type
    void toggle(); // switch on/off
    void off();
    void setIntensity(int intensity); // set intensity to the one desired
    bool isOn;
    int intensity; // get intensity
private:
    bool    _attached;
    uint8_t _pin;
    AnalogType _type;
};