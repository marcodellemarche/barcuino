#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <WebSocketsServer.h>
#include <Servo.h>
#include <AnalogController.h>
#include <math.h>
#include <DallasTemperature.h>

// PIN declaration
#define LEFT_MOTOR D8
#define RIGHT_MOTOR D7
#define EJECT_SERVO D4

#define LED_RGB_RED D1
#define LED_RGB_GREEN D6
#define LED_RGB_BLUE D5
#define LED_BACK D0

#define TEMP_SENSORS_BUS D3

bool debug = true; // set false to avoid debug serial print
bool debugSocket = false; // set false to avoid debug serial print

const int MAX_MOTOR_SPEED = 1023;
const int MIN_MOTOR_SPEED = 250; // sotto questa velocità i motori fischiano ma non si muove

// temp sensor
OneWire oneWire(TEMP_SENSORS_BUS);
DallasTemperature sensors(&oneWire);
DeviceAddress emptyAddress = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
DeviceAddress tempSensor1 = {0x28, 0xAA, 0x2C, 0xCA, 0x4F, 0x14, 0x01, 0x91};
DeviceAddress tempSensor2 = {0x28, 0xAA, 0xD8, 0xDD, 0x4F, 0x14, 0x01, 0x96};

int tempSensorResolution = 10;

ESP8266WebServer server;
WebSocketsServer webSocket = WebSocketsServer(81);
bool isSocketConnected = false;

// Global variables
String commandSeparator = ";";
Servo ejectServo;
AnalogController ledRgbRed;
AnalogController ledRgbBlue;
AnalogController ledRgbGreen;
AnalogController ledBack;
AnalogController leftMotor;
AnalogController rightMotor;

// WiFiServer wifiServer(80);
unsigned long previousHealtCheck = 0;
int healtCheckTimeout = 1600; // 1 seconds
bool isHealtCheckTimeoutEnabled = true;

String myPassword = "ciaociao";
String mySsid = "BarkiFi";

long disconnectionCounter = 0;
long lastWifiClientCounter = 0;

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

String setMotorsSpeed(int left, int right)
{
  if (left != 0)
  {
    if (left <= MIN_MOTOR_SPEED)
      left = MIN_MOTOR_SPEED;
    else
      left = min(left, MAX_MOTOR_SPEED);
  }

  if (right != 0)
  {
    if (right <= MIN_MOTOR_SPEED)
      right = MIN_MOTOR_SPEED;
    else
      right = min(right, MAX_MOTOR_SPEED);
  }
  if (debug)
  {
    Serial.print("setMotorsSpeed:");
    Serial.print(" left = ");Serial.print(left);
    Serial.print(" right = ");Serial.println(right);
  }

  leftMotor.setIntensity(left);
  rightMotor.setIntensity(right);
  return "OK";
}

void stopMotors()
{
  setMotorsSpeed(0, 0);
}

String ejectPastura()
{
  if (ejectServo.attached())
  {
    ejectServo.write(90);
    delay(500);
    ejectServo.write(0);
    if (debug)
      Serial.println("Pastura ejected");
    return "OK";
  }
  else
  {
    if (debug)
      Serial.println("Servo not attached!");
    return "Error!";
  }
}

String getValue(String data, int index, char separator = commandSeparator.charAt(0))
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
  if (isHealtCheckTimeoutEnabled && previousHealtCheck > 0)
  {
    // don't check if alarm was already triggered or at the startup
    if (millis() - previousHealtCheck > healtCheckTimeout)
    {
      Serial.println("Websocket is dead! HealtCheck timer triggered.");

      // Do what you have to do when server gets lost
      stopMotors();

      previousHealtCheck = 0;
    }
  }
}

void respondToCommand(uint8_t num, bool isOk = true, String message = "") {
  String response = "#";

  if (isOk)
    response += "ok" + commandSeparator;
  else
    response += "error" + commandSeparator;
  
  if (message != "") {
    response += message;
    if (!message.endsWith(commandSeparator))
      response += commandSeparator;
  }
  
  if (debugSocket) {
    Serial.print("-> ");Serial.println(response);
  }
  webSocket.sendTXT(num, response);
}

void webSocketEvent(uint8_t num, WStype_t type, uint8_t *payload, size_t length)
{
  if (type == WStype_CONNECTED)
  {
    // Save the last time healtcheck was received
    previousHealtCheck = millis();

    ledRgbGreen.on();

    if (!isSocketConnected)
    {
      Serial.println("WebSocket client connected.");
      isSocketConnected = true;
      respondToCommand(num, true, "Hi! My name is Barkino.");
    }
    else
    {
      Serial.println("WebSocket client already connected.");
    }
  }
  else if (type == WStype_DISCONNECTED)
  {
    // Save the last time healtcheck was received
    previousHealtCheck = millis();

    ledRgbGreen.off();

    isSocketConnected = false;

    disconnectionCounter++;

    Serial.print("WebSocket client disconnection: ");Serial.println(disconnectionCounter);

    // due to some connection errors, autoresolved with auto-reconnect, I don't stop motors suddenly
    //stopMotors();
  }
  else if (type == WStype_ERROR)
  {
    // Save the last time healtcheck was received
    previousHealtCheck = millis();
    
    ledRgbGreen.off();

    Serial.println("WebSocket client error, stopping motors");
    stopMotors();
    respondToCommand(num, false, "WebSocket client error, stopping motors");
  }
  else if (type == WStype_PING)
  {
    // Save the last time healtcheck was received
    previousHealtCheck = millis();

    //Serial.print("<- ");Serial.print("WStype_PING ");Serial.println(millis());
  }
  else if (type == WStype_PONG)
  {
    // Save the last time healtcheck was received
    previousHealtCheck = millis();
    //Serial.print("<- ");Serial.print("WStype_PONG ");Serial.println(millis());
  }
  else if (type == WStype_TEXT)
  {
    // Save the last time healtcheck was received
    previousHealtCheck = millis();
    isSocketConnected = true;

    String serialData = String((char *)payload);
    if (serialData.charAt(0) == '#')
    {
      serialData.trim();
      serialData = serialData.substring(1);

      if (debugSocket)
      {
        Serial.println("****************************");
        Serial.print("<- ");Serial.println(serialData);
      }

      // command is at pos 0
      String command = getValue(serialData, 0);

      if (command == "setMotorsSpeed")
      {
        String leftCommand = getValue(serialData, 1);
        String rightCommand = getValue(serialData, 2);

        int left = leftCommand.toInt();
        int right = rightCommand.toInt();

        setMotorsSpeed(left, right);
        respondToCommand(num);
      }
      else if (command == "stopMotors")
      {
        setMotorsSpeed(0, 0);
        respondToCommand(num);
      }
      else if (command == "ejectPastura")
      {
        ejectPastura();
        respondToCommand(num);
      }
      else if (command == "led")
      {
        String type = getValue(serialData, 1);
        String intensityCmd = getValue(serialData, 2);
        int intensity = intensityCmd != "" ? intensityCmd.toInt() : -1;

        if (type == "green")
        {
          intensity != -1 ? ledRgbGreen.setIntensity(intensity) : ledRgbGreen.toggle();
          respondToCommand(num);
        }
        else if (type == "red")
        {
          intensity != -1 ? ledRgbRed.setIntensity(intensity) : ledRgbRed.toggle();
          respondToCommand(num);
        }
        else if (type == "blue")
        {
          intensity != -1 ? ledRgbBlue.setIntensity(intensity) : ledRgbBlue.toggle();
          respondToCommand(num);
        }
        else if (type == "back")
        {
          intensity != -1 ? ledBack.setIntensity(intensity) : ledBack.toggle();
          respondToCommand(num);
        }
        else if (type == "off")
        {
          ledBack.off();
          // ledRgbRed.on(); // used to check start correctly
          // ledRgbGreen.off(); // used to check websocket connectedion
          ledRgbBlue.off();
          respondToCommand(num);
        }
        else if (type == "on")
        {
          ledBack.on();
          // ledRgbRed.on(); // used to check start correctly
          // ledRgbGreen.on(); // used to check websocket connectedion
          ledRgbBlue.on();
          respondToCommand(num);
        }
      }
      else if (command == "sensors")
      {
        bool isOk = true;
        String type = getValue(serialData, 1);
        uint8_t *sensor = emptyAddress; // selected sensor address
        String result = "";

        if (type == "1")
          sensor = tempSensor1;
        else if (type == "2")
          sensor = tempSensor2;
        else
        {
          // command error
          result = "Sensor type not found!";
          isOk = false;
        }

        if (isOk)
        {
          String function = getValue(serialData, 2); //getTemp or setRes
          if (function == "getTemp")
          {
            sensors.requestTemperaturesByAddress(sensor);
            float temp = sensors.getTempC(sensor);
            result = "temp;" + String(temp);
          }
          else if (function == "setRes")
          {
            String value = getValue(serialData, 3); // value for setRes
            int newResolution = value.toInt();

            if (newResolution >= 9 && newResolution <= 11)
            {
              sensors.setResolution(sensor, newResolution);
              Serial.print("Resolution set to: ");
              Serial.println(newResolution);
            }
            else
            {
              // resolution not supported
              result = "Resolution not supported!";
              isOk = false;
            }
          }
          else
          {
            // function error
            result = "Function not valid!";
            isOk = false;
          }
        }
        respondToCommand(num, isOk, result);
      }
      else if (command == "setTimeout") {
        String value = getValue(serialData, 1); // value for setRes
        int newHealtCheckTimeout = value.toInt(); // value in millis
        if (newHealtCheckTimeout == 0) {
          isHealtCheckTimeoutEnabled = false;
        }
        else if (newHealtCheckTimeout > 0 && newHealtCheckTimeout <= 25000)
        {
          healtCheckTimeout = newHealtCheckTimeout;
          isHealtCheckTimeoutEnabled = true;
          respondToCommand(num);
        }
        else
        {
          // resolution not supported
          respondToCommand(num, false, "Resolution not supported!");
        }
      }
      else if (command == "getStatus") {
        // get status send back temperature and motors values
        String result = "status" + commandSeparator;
        result += "leftMotor" + commandSeparator + String(leftMotor.intensity) + commandSeparator;
        result += "rightMotor" + commandSeparator + String(rightMotor.intensity) + commandSeparator;
        result += "ledRgbRed" + commandSeparator + String(ledRgbRed.intensity) + commandSeparator;
        result += "ledRgbGreen" + commandSeparator + String(ledRgbGreen.intensity) + commandSeparator;
        result += "ledRgbBlue" + commandSeparator + String(ledRgbBlue.intensity) + commandSeparator;
        result += "ledBack" + commandSeparator + String(ledBack.intensity) + commandSeparator;
        result += "healtCheckTimeout" + commandSeparator + String(healtCheckTimeout) + commandSeparator;
        result += "isHealtCheckTimeoutEnabled" + commandSeparator + String(isHealtCheckTimeoutEnabled) + commandSeparator;
        result += "disconnectionCounter" + commandSeparator + String(disconnectionCounter) + commandSeparator;
        
        sensors.requestTemperaturesByAddress(tempSensor1);
        float temp = sensors.getTempC(tempSensor1);
        result += "temp" + commandSeparator + String(temp) + commandSeparator;

        respondToCommand(num, true, result);
      }
      else if (command == "healthcheck")
      {
        // Send back an healthcheck
        String result = "healthcheck";
        respondToCommand(num, true, result);
      }
      else
      {
        String result = "No valid command";
        respondToCommand(num, false, result);
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

  // initialize servo
  ejectServo.attach(EJECT_SERVO);
  delay(15);
  ejectServo.write(0);

  // create leds
  ledRgbBlue.attach(LED_RGB_BLUE, BLUE);
  ledRgbRed.attach(LED_RGB_RED, RED);
  ledRgbGreen.attach(LED_RGB_GREEN, GREEN);
  ledBack.attach(LED_BACK, UNDEFINED);

  // create motors
  rightMotor.attach(RIGHT_MOTOR, MOTOR);
  leftMotor.attach(LEFT_MOTOR, MOTOR);

  // **********************************************

  // initialize sensors and set resolution
  pinMode(TEMP_SENSORS_BUS, INPUT_PULLUP);
  sensors.begin();
  sensors.setResolution(tempSensor1, tempSensorResolution);
  //sensors.setResolution(tempSensor2, tempSensorResolution);

  WiFi.setSleepMode(WIFI_NONE_SLEEP);
  WiFi.mode(WIFI_AP);
  WiFi.softAP(mySsid, myPassword);
  delay(500);
  WiFi.softAPConfig(local_ip, gateway, netmask);

  webSocket.begin();
  webSocket.onEvent(webSocketEvent);

  // server.on("/", []() {
  //   server.send_P(200, "text/html", webpage);
  // });
  // server.begin();

  // setup finished, switch on red led
  ledRgbRed.on();
}

void loop()
{
  if (WiFi.softAPgetStationNum() > 0)
  {
    int connectedWifiClients = webSocket.connectedClients();
    if (lastWifiClientCounter != connectedWifiClients) {
      lastWifiClientCounter = connectedWifiClients;
      disconnectionCounter = 0;
      if (webSocket.connectedClients() > 0)
        ledRgbGreen.on();
      else
        ledRgbGreen.off();
    }
    webSocket.loop();
    // server.handleClient();
    checkHealthCheckTime();
  }
  else
  {
    ledRgbBlue.on();
    delay(500);
    ledRgbBlue.off();
    delay(500);

    // websocket check led
    if (ledRgbGreen.isOn)
      ledRgbGreen.off();
  }
}
