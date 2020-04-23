#include <Arduino.h>
#include <WiFi.h>
#include <WiFiServer.h>
#include <WebServer.h>
#include <WebSocketsServer.h>
#include <Servo.h>
#include <AnalogController.h>
#include <math.h>
#include <OneWire.h>
#include <DallasTemperature.h>

// PIN declaration
#define LEFT_MOTOR 17
#define RIGHT_MOTOR 21
#define EJECT_SERVO 26

#define LED_RGB_RED 23
#define LED_RGB_GREEN 33
#define LED_RGB_BLUE 19
#define LED_BACK 22

#define TEMP_SENSORS_BUS 18

// temp sensor
OneWire oneWire(TEMP_SENSORS_BUS);
DallasTemperature sensors(&oneWire);
DeviceAddress emptyAddress = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
DeviceAddress tempSensor1 = {0x28, 0xAA, 0x2C, 0xCA, 0x4F, 0x14, 0x01, 0x91};
DeviceAddress tempSensor2 = {0x28, 0xAA, 0xD8, 0xDD, 0x4F, 0x14, 0x01, 0x96};

int tempSensorResolution = 10;

#define MAX_ANALOG_WRITE 1023

WebServer server;
WebSocketsServer webSocket = WebSocketsServer(81);
bool isSocketConnected = false;

// Global variables
char commandSeparator = ';';
Servo ejectServo;
AnalogController ledRgbRed;
AnalogController ledRgbBlue;
AnalogController ledRgbGreen;
AnalogController ledBack;
AnalogController leftMotor;
AnalogController rightMotor;

double maxSpeed = 1023;
double minMotorSpeed = 200; // sotto questa velocità i motori fischiano ma non si muove
double maxTurningSpeed = 1023;
// WiFiServer wifiServer(80);
unsigned long previousHealtCheck = 0;
unsigned long maxTimeInterval = 1000; // 1 seconds

const char *myPassword = "ciaociao";
const char *mySsid = "BarkiFi";

long disconnectionCounter = 0;

// IPAddress local_ip(192,168,1,4);
// IPAddress gateway(192,168,1,1);
IPAddress local_ip(192, 168, 4, 1);
IPAddress gateway(192, 168, 4, 1);
IPAddress netmask(255, 255, 255, 0);

char webpage[] PROGMEM = R"=====(
<html>
<head>
  <script>
    var Socket;
    function init() {
      Socket = new WebSocket('ws://' + window.location.hostname + ':81/');
      Socket.onmessage = function(event){
        document.getElementById("rxConsole").value += event.data;
      }
    }
    function sendText(){
      Socket.send(document.getElementById("txBar").value);
      document.getElementById("txBar").value = "";
    }
    function sendBrightness(){
      Socket.send("#"+document.getElementById("brightness").value);
    }    
  </script>
</head>
<body onload="javascript:init()">
  <div>
    <textarea id="rxConsole"></textarea>
  </div>
  <hr/>
  <div>
    <input type="text" id="txBar" onkeydown="if(event.keyCode == 13) sendText();" />
  </div>
  <hr/>
  <div>
    <input type="range" min="0" max="1023" value="512" id="brightness" oninput="sendBrightness()" />
  </div>  
</body>
</html>
)=====";

double absPro(double x)
{
  return x > 0 ? x : -x;
}

int getLeftMotorValueNew(double degrees, double distance)
{
  double speedResult = 0;
  if (degrees >= 0 && degrees <= 180)
  {
    speedResult = maxSpeed;
  }
  else
  {
    speedResult = maxSpeed * absPro(cos(radians(degrees)));
  }
  int result = speedResult * distance;
  return result > minMotorSpeed ? result : 0;
}

int getRightMotorValueNew(double degrees, double distance)
{
  double speedResult = 0;
  if (degrees >= 0 && degrees <= 180)
  {
    speedResult = maxSpeed * absPro(cos(radians(degrees)));
  }
  else
  {
    speedResult = maxSpeed;
  }
  int result = speedResult * distance;
  return result > minMotorSpeed ? result : 0;
}

String setMotorsSpeed(int left, int right)
{
  if ((0 <= left && left <= MAX_ANALOG_WRITE) && (0 <= right && right <= MAX_ANALOG_WRITE))
  {
    leftMotor.setIntensity(left);
    rightMotor.setIntensity(right);
    return "OK";
  }
  else
  {
    Serial.println("Not valid values");
    return "Error";
  }
}

void stopMotors()
{
  setMotorsSpeed(0, 0);
}

String setMotorsSpeedFromPad(double degrees, double distance)
{
  if (distance > 0)
  {
    int left = getLeftMotorValueNew(degrees, distance);
    int right = getRightMotorValueNew(degrees, distance);
    Serial.print("degrees: ");
    Serial.println(degrees);
    Serial.print("SX: ");
    Serial.println(left);
    Serial.print("DX: ");
    Serial.println(right);
    Serial.print("Distance: ");
    Serial.println(distance);

    setMotorsSpeed(left, right);
    return "OK";
  }
  else
  {
    stopMotors();
    Serial.println("Distance 0. Motors stopped");
    return "Distance 0. Motors stopped";
  }
}

String ejectPastura()
{
  if (ejectServo.attached())
  {
    ejectServo.write(90);
    delay(500);
    ejectServo.write(0);
    Serial.println("Pastura ejected");
    return "OK";
  }
  else
  {
    Serial.println("Servo not attached!");
    return "Error!";
  }
}

String getValue(String data, char separator, int index)
{
  int found = 0;
  int strIndex[] = {0, -1};
  int maxIndex = data.length() - 1;

  for (int i = 0; i <= maxIndex && found <= index; i++)
  {
    if (data.charAt(i) == separator)
    {
      found++;
      strIndex[0] = strIndex[1] + 1;
      strIndex[1] = i;
    }
  }
  return found > index ? data.substring(strIndex[0], strIndex[1]) : "";
}

// Check if Health Check time has been triggered. If so, the server is no more active
void checkHealthCheckTime()
{
  if (previousHealtCheck > 0)
  {
    // don't check if alarm was already triggered or at the startup
    if (millis() - previousHealtCheck > maxTimeInterval)
    {
      Serial.println("Server is dead! HealtCheck timer triggered.");

      // Do what you have to do when server gets lost
      stopMotors();

      previousHealtCheck = 0;
    }
  }
}

void webSocketEvent(uint8_t num, WStype_t type, uint8_t *payload, size_t length)
{
  if (type == WStype_CONNECTED)
  {
    ledRgbGreen.on();

    if (!isSocketConnected) {
      // Save the last time healtcheck was received
      previousHealtCheck = millis();

      String payload = "Hi! My name is Barkino.";
      Serial.println("WebSocket client connected.");
      webSocket.broadcastTXT(payload);
      isSocketConnected = true;
    }
    else
    {
      // Save the last time healtcheck was received
      previousHealtCheck = millis();

      Serial.println("WebSocket client already connected.");
    }
  }
  else if (type == WStype_DISCONNECTED)
  {
    ledRgbGreen.off();

    isSocketConnected = false;
    previousHealtCheck = 0;

    disconnectionCounter++;

    Serial.print("WebSocket client disconnection: ");Serial.println(disconnectionCounter);
    // due to some connection errors, autoresolved with auto-reconnect, I don't stop motors suddenly
    //stopMotors();
  }
  else if (type == WStype_ERROR)
  {
    ledRgbGreen.off();

    isSocketConnected = false;
    previousHealtCheck = 0;

    Serial.println("WebSocket client error, stopping motors");
    stopMotors();
  }
  else if (type == WStype_PING) {
    // Save the last time healtcheck was received
    previousHealtCheck = millis();

    //Serial.print("<- ");Serial.print("WStype_PING ");Serial.println(millis());
  }
  else if (type == WStype_PONG) {
    // Save the last time healtcheck was received
    previousHealtCheck = millis();

    //Serial.print("<- ");Serial.print("WStype_PONG ");Serial.println(millis());
  }
  else if (type == WStype_TEXT)
  {
    // Save the last time healtcheck was received
    previousHealtCheck = millis();

    String serialData = String((char *)payload);
    if (serialData.charAt(0) == '#')
    {
      serialData.trim();
      serialData = serialData.substring(1);

      Serial.println("****************************");
      Serial.print("<- ");Serial.println(serialData);

      // command is at pos 0
      String command = getValue(serialData, commandSeparator, 0);

      if (command == "setMotorsSpeed")
      {
        String leftCommand = getValue(serialData, commandSeparator, 1);
        String rightCommand = getValue(serialData, commandSeparator, 2);

        int left = leftCommand.toInt();
        int right = rightCommand.toInt();

        setMotorsSpeed(left, right);
      }
      else if (command == "setMotorsSpeedFromPad")
      {
        String degreesCmd = getValue(serialData, commandSeparator, 1);
        String distanceCmd = getValue(serialData, commandSeparator, 2);

        double degrees = degreesCmd.toDouble();
        double distance = distanceCmd.toDouble();

        setMotorsSpeedFromPad(degrees, distance);
      }
      else if (command == "stopMotors")
      {
        setMotorsSpeed(0, 0);
      }
      else if (command == "ejectPastura")
      {
        ejectPastura();
      }
      else if (command == "led")
      {
        String type = getValue(serialData, commandSeparator, 1);
        String intensityCmd = getValue(serialData, commandSeparator, 2);
        int intensity = intensityCmd != "" ? intensityCmd.toInt() : -1;

        if (type == "green")
        {
          intensity != -1 ? ledRgbGreen.setIntensity(intensity) : ledRgbGreen.toggle();
        }
        else if (type == "red")
        {
          intensity != -1 ? ledRgbRed.setIntensity(intensity) : ledRgbRed.toggle();
        }
        else if (type == "blue")
        {
          intensity != -1 ? ledRgbBlue.setIntensity(intensity) : ledRgbBlue.toggle();
        }
        else if (type == "back")
        {
          intensity != -1 ? ledBack.setIntensity(intensity) : ledBack.toggle();
        }
        else if (type == "off")
        {
          ledBack.off();
          // ledRgbRed.on(); // used to check start correctly
          // ledRgbGreen.off(); // used to check websocket connectedion
          ledRgbBlue.off();
        }
        else if (type == "on")
        {
          ledBack.on();
          ledRgbRed.on();
          ledRgbGreen.on();
          ledRgbBlue.on();
        }
      }
      else if (command == "sensors")
      {
        bool goOn = true;
        String type = getValue(serialData, commandSeparator, 1);
        uint8_t *sensor = emptyAddress; // selected sensor address
        String result;

        if (type == "1")
          sensor = tempSensor1;
        else if (type == "2")
          sensor = tempSensor2;
        else
        {
          // command error
          result = "Sensor type not found!";
          goOn = false;
        }

        if (goOn)
        {
          String function = getValue(serialData, commandSeparator, 2); //getTemp or setRes
          if (function == "getTemp")
          {
            sensors.requestTemperaturesByAddress(sensor);
            float temp = sensors.getTempC(sensor);
            result = "#getTemp;" + String(temp);
          }
          else if (function == "setRes")
          {
            String value = getValue(serialData, commandSeparator, 3); // value for setRes
            int newResolution = value.toInt();

            if (newResolution >= 9 && newResolution <= 11)
            {
              sensors.setResolution(sensor, newResolution);
              Serial.print("Resolution set to: ");
              Serial.println(newResolution);
              result = "Ok!";
            }
            else
            {
              // resolution not supported
              result = "Resolution not supported!";
              goOn = false;
            }
          }
          else
          {
            // function error
            result = "Function not valid!";
            goOn = false;
          }
        }
        Serial.print("-> ");Serial.println(result);
        webSocket.broadcastTXT(result);
      }
      else if (command == "healthcheck")
      {
        // Send back an healthcheck
        String payload = "healthcheck";
        Serial.print("-> ");Serial.println(payload);
        webSocket.broadcastTXT(payload);
      }
      else
      {
        Serial.println("No valid command");
      }
    }
  }
}

void setup()
{
  // Start the Serial communication to send messages to the computer
  Serial.begin(115200);
  delay(500);

  // set pinMode
  pinMode(LED_BUILTIN, OUTPUT);
  pinMode(RIGHT_MOTOR, OUTPUT);
  pinMode(LEFT_MOTOR, OUTPUT);

  // initialize pins values
  digitalWrite(LED_BUILTIN, HIGH);
  digitalWrite(RIGHT_MOTOR, LOW);
  digitalWrite(LEFT_MOTOR, LOW);

  // **********************************************
  // AnalogWrite section
  // Due to incompatibility between analogWrite library and Servo library, I had to rewrite the analog flow
  // So, you have to setup different channels (1-15) for each analog pin

  // initialize servo, with explicit channel declaration
  ejectServo.attach(EJECT_SERVO, 1);
  delay(15);
  ejectServo.write(0);

  // create leds
  ledRgbBlue.attach(LED_RGB_BLUE, BLUE, 2);
  ledRgbRed.attach(LED_RGB_RED, RED, 3);
  ledRgbGreen.attach(LED_RGB_GREEN, GREEN, 4);
  ledBack.attach(LED_BACK, UNDEFINED, 5);

  // create motors
  rightMotor.attach(RIGHT_MOTOR, MOTOR, 6);
  leftMotor.attach(LEFT_MOTOR, MOTOR, 7);

  // **********************************************

  // initialize sensors and set resolution
  pinMode(TEMP_SENSORS_BUS, INPUT_PULLUP);
  sensors.begin();
  sensors.setResolution(tempSensor1, tempSensorResolution);
  sensors.setResolution(tempSensor2, tempSensorResolution);

  WiFi.persistent(false); 
  // workaround DHCP crash on ESP32 when AP Mode!!!
  // https://github.com/espressif/arduino-esp32/issues/2025#issuecomment-562848209
  WiFi.mode(WIFI_AP);
  WiFi.softAP(mySsid, myPassword);
  delay(1000); 
  // workaround DHCP crash on ESP32 when AP Mode!!! Non servirebbe se funzionasse WiFi.persistent(false)
  // https://github.com/espressif/arduino-esp32/issues/2025#issuecomment-544131287
  WiFi.softAPConfig(local_ip, gateway, netmask);

  webSocket.begin();
  webSocket.onEvent(webSocketEvent);

  server.on("/", []() {
    server.send_P(200, "text/html", webpage);
  });
  server.begin();

  // setup finished, switch on red led
  ledRgbRed.on();
}

void loop()
{
  if(WiFi.softAPgetStationNum() > 0) {
    if (webSocket.connectedClients() > 0) {
      ledRgbGreen.on();
    }
    else {
      ledRgbGreen.off();
    }
    webSocket.loop();
    delay(1);
    server.handleClient();
    delay(1);
    checkHealthCheckTime();
  }
  else {
    ledRgbBlue.on();
    delay(500);
    ledRgbBlue.off();
    delay(500);
  }
}
