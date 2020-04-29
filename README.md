[![Arduino Logo](https://www.vectorlogo.zone/logos/arduino/arduino-icon.svg)](https://arduino.cc/) 
[![Flutter Logo](https://www.vectorlogo.zone/logos/flutterio/flutterio-icon.svg)](https://flutter.dev/)

![Maintained](https://img.shields.io/badge/mantained-yes-green)
<!-- [![License](http://img.shields.io/badge/Licence-MIT-brightgreen.svg)](LICENSE.md) -->

# Barqino

Small boat driven by an on-board ESP8266, connected to a smartphone app through WiFi.

ESP8266 programmed using Arduino IDE first and PlatformIO for VS Code then. Smartphone app built with Flutter.

## Getting Started

Clone this repository locally :

``` bash
git clone https://github.com/marcodellemarche/barcuino.git
```

## Arduino

If you use PlatformIO, dependencies will be automatically downloaded. Otherwise, please look for these dependencies:

[WebSockets](https://github.com/Links2004/arduinoWebSockets/blob/master/src/WebSocketsServer.h)

## Flutter

Install dependencies for flutter :

``` bash
cd flutter
flutter pub get
```

If you want to generate Flutter components you **MUST** install `flutter` globally.
Please follow [flutter documentation](https://flutter.dev/docs/get-started/install).

## References

Flutter 
* https://github.com/artrmz/flutter_control_pad
* https://github.com/Ali-Azmoud/flutter_xlider
* https://github.com/fluttercommunity/flutter_launcher_icons
* https://github.com/dart-lang/web_socket_channel
* https://github.com/RohitKumarMishra/wifi_configuration
* https://github.com/flutter/plugins/ (connectivity and shared_preferences)

Arduino
* https://github.com/LilyGO/ESP32-MINI-32-V1.3
* https://randomnerdtutorials.com/esp32-pinout-reference-gpios/
* https://github.com/milesburton/Arduino-Temperature-Control-Library
* https://github.com/stickbreaker/OneWire
* https://github.com/Links2004/arduinoWebSockets

## Links

* https://github.com/G6EJD/LiPo_Battery_Capacity_Estimator

## DHCP bug on ESP32

On espressif ESP32 firmware [v.1.0.4](https://github.com/espressif/arduino-esp32/releases/tag/1.0.4) there is a bug on DHCP in AP mode, causes these errors on client connection to ESP.
```
dhcps: send_offer>>udp_sendto result 0
Guru Meditation Error: Core  0 panic'ed (InstrFetchProhibited). Exception was unhandled.
```
```
#0  0x00000000:0x3ffb3db0 in ?? ??:0
#1  0x4011c34a:0x3ffb3df0 in handle_dhcp at /home/runner/work/esp32-arduino-lib-builder/esp32-arduino-lib-builder/esp-idf/components/lwip/apps/dhcpserver/dhcpserver.c:1031
```
There are two workaround:
1. Set WiFi config [persistence to false](https://github.com/espressif/arduino-esp32/issues/2025#issuecomment-562848209), before enabling WiFi.
    ``` 
    WiFi.persistent(false); 
    ```
    Before upload the sketch to ESP32 you need to [Erase Flash](https://github.com/espressif/esptool#erase-flash-erase_flash--erase-region)

2. If DHCP still not working, trying to [use a delay](https://github.com/espressif/arduino-esp32/issues/2025#issuecomment-544131287) before enabling WiFi
    ``` c++
    WiFi.softAP(mySsid, myPassword);
    delay(1000); // workaround to fix DHCP not working on ESP32 when AP Mode!!!
    WiFi.softAPConfig(local_ip, gateway, netmask);
    ```
    
## OneWire bug on ESP32

Due to some timig problems on original OneWire library, we decided to use the one from [stickbreaker repo](https://github.com/stickbreaker/OneWire).
Here his explanation:
```
A modification of the Arduino OneWire library maintained by @PaulStoffregen. 
This modifications supports the ESP32 under the Arduino-esp32 Environment.
```
