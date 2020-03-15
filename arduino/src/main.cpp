#include <Arduino.h>
#include <ArduinoJson.h>
// #include <ESP8266WiFi.h>
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <WebSocketsServer.h>
#include <Servo.h>
// #include "motors.cpp"

// PIN declaration
#define LEFT_MOTOR D4
#define RIGHT_MOTOR D3
#define EJECT_SERVO D7

#define MAX_ANALOG_WRITE 1023

ESP8266WebServer server;
WebSocketsServer webSocket = WebSocketsServer(81);

// Global variables
bool motorsEnabled = false; // flag to avoid motor activation
int step = 1;
String serializedJSON;
Servo ejectServo;

// functions declaration
void stopMotors();
String setMotorsSpeed(int left, int right);
void handleDataReceived(char *dataStr);
void serialFlush();
String getValue(String data, char separator, int index);
String ejectPastura();
int getLeftMotorValue(double degrees);
int getRightMotorValue(double degrees);
void webSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length);

// const
double maxSpeed = 1023;
double maxTurningSpeed = 511;
// WiFiServer wifiServer(80);

String myPassword = "ciaociao";
String mySsid = "BarkiFi";

IPAddress local_ip(192,168,1,4);
IPAddress gateway(192,168,1,1);
IPAddress netmask(255,255,255,0);

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

void setup()
{
  // put your setup code here, to run once:

  // set pinMode
  pinMode(LED_BUILTIN, OUTPUT);
  pinMode(RIGHT_MOTOR, OUTPUT);
  pinMode(LEFT_MOTOR, OUTPUT);

  // initialize pins values
  digitalWrite(LED_BUILTIN, LOW);
  digitalWrite(RIGHT_MOTOR, LOW);
  digitalWrite(LEFT_MOTOR, LOW);
  // initialize servo
  ejectServo.attach(EJECT_SERVO);
  delay(15);
  ejectServo.write(0);

  // Start the Serial communication to send messages to the computer
  Serial.begin(115200); 
  delay(5000);

  server.on("/", [] () {
    server.send_P(200, "text/html", webpage);  
  });
  server.begin();
  webSocket.begin();
  webSocket.onEvent(webSocketEvent);

  WiFi.setSleepMode(WIFI_NONE_SLEEP);
  WiFi.mode(WIFI_AP);
  // WiFi.softAPConfig(local_ip, gateway, netmask);
  WiFi.softAP(mySsid, myPassword);
}

void loop()
{
  webSocket.loop();
  server.handleClient();
  if(Serial.available() > 0){
    char c[] = {(char)Serial.read()};
    webSocket.broadcastTXT(c, sizeof(c));
  }
}


int getLeftMotorValue(double degrees, double distance)
{
  // degrees: from 0 to 360
  // distance: from 0 to 1
  double result = 0;
  if (degrees >= 0 && degrees <= 90)
  {
    result = maxSpeed * (1 - (degrees / (90 * (maxSpeed / maxTurningSpeed))));
  }
  else if (degrees >= 270 && degrees <= 360)
  {
    result = maxSpeed * (1 - ((360 - degrees) / 90));
  }
  return (int) result * distance;
}

int getRightMotorValue(double degrees, double distance)
{
  // degrees: from 0 to 360
  // distance: from 0 to 1
  double result = 0;
  if (degrees >= 0 && degrees <= 90)
  {
    result = maxSpeed * (1 - (degrees / 90));
  }
  else if (degrees >= 270 && degrees <= 360)
  {
    result = maxSpeed * (1 - ((360 - degrees) / (90 * (maxSpeed / maxTurningSpeed))));
  }
  return (int) result * distance;
}

String setMotorsSpeedFromPad(double degrees, double distance)
{
  int left = getLeftMotorValue(degrees, distance);
  int right = getRightMotorValue(degrees, distance);
  Serial.print("SX: ");
  Serial.println(left);
  Serial.print("DX: ");
  Serial.println(right);
  Serial.print("Distance: ");
  Serial.println(distance);

  if (distance > 0) {
    setMotorsSpeed(left, right);
    return "OK";
  }
  else {
    stopMotors();
    Serial.println("Distance 0. Motors stopped");
    return "Distance 0. Motors stopped";
  }
}

String setMotorsSpeed(int left, int right)
{
  if ((0 <= left && left <= MAX_ANALOG_WRITE) && (0 <= right && right <= MAX_ANALOG_WRITE)) {
    analogWrite(LEFT_MOTOR, left);
    analogWrite(RIGHT_MOTOR, right);
    return "OK";
  }
  else {
    Serial.println("Not valid values");
    return "Error";
  }
}

void stopMotors() {
  setMotorsSpeed(0,0);
}

String ejectPastura() {
  if(ejectServo.attached()) {
    ejectServo.write(90);
    delay(500);
    ejectServo.write(0);
    Serial.println("Pastura ejected");
    return "OK";
  }
  else {
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

void serialFlush()
{
  while (Serial.available() > 0)
  {
    Serial.read();
  }
}

void webSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length) {
  if (type == WStype_CONNECTED) {
    // char c[] = {(char)Serial.read()};
    char payload[] = {"Hi! My name is Barkino."};
    webSocket.broadcastTXT(payload, sizeof(payload));
  }

  if (type == WStype_TEXT) {
    String serialData = String((char *)payload);
    if (serialData.charAt(0) == '#') {
      serialData = serialData.substring(1);
      // uint16_t command = (uint16_t) strtol((const char *) &payload[1], NULL, 10);
      // String command = (String) strtol((const char *) &payload[0], NULL, 10);
      
      // String serialData = Serial.readStringUntil('!');
      serialData.trim();
      Serial.println(serialData);

      // command is at pos 0
      String command = getValue(serialData, ';', 0);
      Serial.println(command);

      if (command == "setMotorsSpeed")
      {
        String leftCommand = getValue(serialData, ';', 1);
        String rightCommand = getValue(serialData, ';', 2);

        int left = leftCommand.toInt();
        int right = rightCommand.toInt();

        setMotorsSpeed(left, right);
      }
      else if (command == "setMotorsSpeedFromPad")
      {
        String leftCommand = getValue(serialData, ';', 1);
        String rightCommand = getValue(serialData, ';', 2);

        double degrees = leftCommand.toDouble();
        double distance = rightCommand.toDouble();

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
      else
      {
        Serial.println("No valid command");
      }
    }
  }
  
}


