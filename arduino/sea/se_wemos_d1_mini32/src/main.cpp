#include <Arduino.h>
#include <WiFi.h>
#include <WiFiServer.h>
#include <esp_wifi.h>
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

const String FLUTTER = "fl";
const String SEA = "se";
const String EARTH = "ea";
const String EARTH_BT = "bt";

bool debug = true; // set false to avoid debug serial print
bool debugSocket = true; // set false to avoid debug serial print

const int MAX_MOTOR_SPEED = 1023;
const int MIN_MOTOR_SPEED = 250; // sotto questa velocità i motori fischiano ma non si muove

// temp sensor
OneWire oneWire(TEMP_SENSORS_BUS);
DallasTemperature sensors(&oneWire);
DeviceAddress emptyAddress = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
DeviceAddress tempSensor1 = {0x28, 0xAA, 0x2C, 0xCA, 0x4F, 0x14, 0x01, 0x91};
DeviceAddress tempSensor2 = {0x28, 0xAA, 0xD8, 0xDD, 0x4F, 0x14, 0x01, 0x96};

int tempSensorResolution = 10;

// Global variables
String me = SEA;
String commandSeparator = ";";
Servo ejectServo;
AnalogController ledEspOn; //ledRgbRed
AnalogController ledWifi; //ledRgbBlue
AnalogController ledWebSocket; //ledRgbGreen
AnalogController ledBack;
AnalogController leftMotor;
AnalogController rightMotor;

int pingInterval = 750;
int pongTimeout = 500;
int wsTimeoutsBeforeDisconnet = 0;
bool isSocketConnected = false;

class myWebSocketsServer: public WebSocketsServer {
  private:
    unsigned long _previousMillis = 0;
  public:
    myWebSocketsServer(uint16_t port, String origin = "", String protocol = "arduino") : WebSocketsServer(port, origin, protocol) {}

    void loop(void) {
      if ((millis() - _previousMillis) > 500) {
        _previousMillis = millis();
        Serial.print("WSLoop: connectedClients(): ");Serial.println(WebSocketsServer::connectedClients(true));
      }

      if(!(WebSocketsServer::connectedClients() > 0)) {
        isSocketConnected = false;
        if (ledWebSocket.isOn)
          ledWebSocket.off();
      }
      WebSocketsServer::loop();
    }
};

WebServer webServer;
myWebSocketsServer webSocketServer = myWebSocketsServer(81);

unsigned long previousWiFiCheckMillis = 0;
unsigned long previousMillis = 0;

// WiFiServer wifiServer(80);
unsigned long previousHealtCheck = 0;
unsigned long healtCheckInterval = 1600; // 1 seconds
bool isHealtCheckTimeoutEnabled = true;

const char *myPassword = "ciaociao";
const char *mySsid = "BarkiFi";

long disconnectionCounter = 0;
long lastSocketClientCounter = 0;

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
    if (millis() - previousHealtCheck > healtCheckInterval)
    {
      Serial.println("Websocket is dead! HealtCheck timer triggered.");

      // Do what you have to do when server gets lost
      stopMotors();

      previousHealtCheck = 0;
    }
  }
}

String getStatusString() {
  String result = "status" + commandSeparator;
  result += "lm" + commandSeparator + String(leftMotor.intensity) + commandSeparator;
  result += "rm" + commandSeparator + String(rightMotor.intensity) + commandSeparator;
  result += "ledBack" + commandSeparator + String(ledBack.intensity) + commandSeparator;
  result += "hcInterval" + commandSeparator + String(healtCheckInterval) + commandSeparator;
  result += "isTimeoutEnabled" + commandSeparator + String(isHealtCheckTimeoutEnabled) + commandSeparator;
  result += "disconnCounter" + commandSeparator + String(disconnectionCounter) + commandSeparator;
  result += "pingInterval" + commandSeparator + String(pingInterval) + commandSeparator;
  result += "pongTimeout" + commandSeparator + String(pongTimeout) + commandSeparator;
  result += "wsTimeoutsBeforeDisconnet" + commandSeparator + String(wsTimeoutsBeforeDisconnet) + commandSeparator;
  
  sensors.requestTemperaturesByAddress(tempSensor1);
  float temp = sensors.getTempC(tempSensor1);
  result += "temp" + commandSeparator + String(temp) + commandSeparator;
  return result;
}

void respondToCommand(uint8_t num, String receiver, bool isOk = true, String message = "") {
  String response = "#" + me + receiver + commandSeparator;

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
  webSocketServer.sendTXT(num, response);
}

void webSocketEvent(uint8_t num, WStype_t type, uint8_t *payload, size_t length)
{
  if (type == WStype_CONNECTED)
  {
    // Save the last time healtcheck was received
    previousHealtCheck = millis();

    ledWebSocket.on();

    if (!isSocketConnected)
    {
      Serial.println("WebSocket client connected.");
      isSocketConnected = true;
      respondToCommand(num, FLUTTER, true, "Hi! My name is Barkino.");
      delay(20);
      respondToCommand(num, FLUTTER, true, getStatusString());
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

    ledWebSocket.off();

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

    Serial.println("WebSocket client error");
    respondToCommand(num, FLUTTER, false, "WebSocket client error");
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
    if (serialData.charAt(0) == '#') {
      // it's a command
      // sender/receiver list:
      // message layout #ssrr;xxxxxx;xxxxx;xxxxx
      // se -> Arduino sea
      // ea -> Arduino earth
      // bt -> Arduino earth bluetooth
      // fl -> Flutter app
      String sender = serialData.substring(1, 3);
      String receiver = serialData.substring(3, 5);

      if (receiver == SEA)
      {
        String rawCommands = serialData.substring(6);

        if (debugSocket)
        {
          // Serial.println("****************************");
          // Serial.print("<- ");Serial.println(serialData);
        }

        // command is at pos 0
        String command = getValue(rawCommands, 0);

        if (command == "setMotorsSpeed")
        {
          String leftCommand = getValue(rawCommands, 1);
          String rightCommand = getValue(rawCommands, 2);

          int left = leftCommand.toInt();
          int right = rightCommand.toInt();

          setMotorsSpeed(left, right);
          respondToCommand(num, sender);
        }
        else if (command == "stopMotors")
        {
          setMotorsSpeed(0, 0);
          respondToCommand(num, sender);
        }
        else if (command == "ejectPastura")
        {
          ejectPastura();
          respondToCommand(num, sender);
        }
        else if (command == "led")
        {
          String type = getValue(rawCommands, 1);
          String intensityCmd = getValue(rawCommands, 2);
          int intensity = intensityCmd != "" ? intensityCmd.toInt() : -1;

          if (type == "green")
          {
            // intensity != -1 ? ledRgbGreen.setIntensity(intensity) : ledRgbGreen.toggle();
            // respondToCommand(num, sender);
          }
          else if (type == "red")
          {
            // intensity != -1 ? ledRgbRed.setIntensity(intensity) : ledRgbRed.toggle();
            // respondToCommand(num, sender);
          }
          else if (type == "blue")
          {
            // intensity != -1 ? ledRgbBlue.setIntensity(intensity) : ledRgbBlue.toggle();
            // respondToCommand(num, sender);
          }
          else if (type == "back")
          {
            intensity != -1 ? ledBack.setIntensity(intensity) : ledBack.toggle();
            respondToCommand(num, sender);
          }
          else if (type == "off")
          {
            ledBack.off();
            // ledRgbRed.on(); // used to check start correctly
            // ledRgbGreen.off(); // used to check websocket connectedion
            //ledRgbBlue.off(); // used to check wifi connection
            respondToCommand(num, sender);
          }
          else if (type == "on")
          {
            ledBack.on();
            // ledRgbRed.on(); // used to check start correctly
            // ledRgbGreen.on(); // used to check websocket connectedion
            //ledRgbBlue.on(); // used to check wifi connection
            respondToCommand(num, sender);
          }
        }
        else if (command == "sensors")
        {
          bool isOk = true;
          String type = getValue(rawCommands, 1);
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
            String function = getValue(rawCommands, 2); //getTemp or setRes
            if (function == "getTemp")
            {
              sensors.requestTemperaturesByAddress(sensor);
              float temp = sensors.getTempC(sensor);
              result = "temp;" + String(temp);
            }
            else if (function == "setRes")
            {
              String value = getValue(rawCommands, 3); // value for setRes
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
          respondToCommand(num, sender, isOk, result);
        }
        else if (command == "setTimeout") {
          String value = getValue(rawCommands, 1);
          int newHealtCheckTimeout = value.toInt(); // value in millis
          if (newHealtCheckTimeout == 0) {
            isHealtCheckTimeoutEnabled = false;
            respondToCommand(num, sender);
          }
          else if (newHealtCheckTimeout > 0 && newHealtCheckTimeout <= 25000)
          {
            healtCheckInterval = newHealtCheckTimeout;
            isHealtCheckTimeoutEnabled = true;
            respondToCommand(num, sender);
          }
          else
          {
            // resolution not supported
            respondToCommand(num, sender, false, "setTimeout millis between 0 a 25000!");
          }
        }
        else if (command == "setWebSocket") {
          String strPingInterval = getValue(rawCommands, 1);
          String strPongTimeout = getValue(rawCommands, 2);
          String strWsTimeoutsBeforeDisconnet = getValue(rawCommands, 3);

          int newPingInterval = strPingInterval.toInt(); // value in millis
          int newPongTimeout = strPongTimeout.toInt(); // value in millis
          int newWsTimeoutsBeforeDisconnet = strWsTimeoutsBeforeDisconnet.toInt(); // value in millis

          if (newPingInterval == 0) {
            webSocketServer.disableHeartbeat();
          }
          else if (newPingInterval > 0 && newPingInterval <= 25000 
            && newPongTimeout > 0 && newPongTimeout <= 25000)
          {
            pingInterval = newPingInterval;
            pongTimeout = newPongTimeout;
            wsTimeoutsBeforeDisconnet = newWsTimeoutsBeforeDisconnet;
            webSocketServer.enableHeartbeat(pingInterval, pongTimeout, wsTimeoutsBeforeDisconnet);
            respondToCommand(num, sender);
          }
          else
          {
            // resolution not supported
            respondToCommand(num, sender, false, "setWebSocket command error!");
          }
        }
        else if (command == "getStatus") {
          // get status send back temperature and motors values
          String result = getStatusString();

          respondToCommand(num, sender, true, result);
        }
        else if (command == "healthcheck")
        {
          // Send back an healthcheck
          String result = "healthcheck";
          respondToCommand(num, sender, true, result);
        }
        else
        {
          String result = "No valid command";
          respondToCommand(num, sender, false, result);
        }
      } else {
        Serial.print("receiver is not me: ");
        Serial.print(sender);Serial.print("->");Serial.println(receiver);
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
  ledWifi.attach(LED_RGB_BLUE, BLUE, 2);
  ledEspOn.attach(LED_RGB_RED, RED, 3);
  ledWebSocket.attach(LED_RGB_GREEN, GREEN, 4);
  ledBack.attach(LED_BACK, UNDEFINED, 5);

  // create motors
  rightMotor.attach(RIGHT_MOTOR, MOTOR, 6);
  leftMotor.attach(LEFT_MOTOR, MOTOR, 7);

  // **********************************************

  // initialize sensors and set resolution
  pinMode(TEMP_SENSORS_BUS, INPUT_PULLUP);
  sensors.begin();
  sensors.setResolution(tempSensor1, tempSensorResolution);
  //sensors.setResolution(tempSensor2, tempSensorResolution);

  WiFi.persistent(false);
  // workaround DHCP crash on ESP32 when AP Mode!!!
  // https://github.com/espressif/arduino-esp32/issues/2025#issuecomment-562848209
  WiFi.mode(WIFI_AP);
  esp_wifi_set_protocol( WIFI_IF_AP, WIFI_PROTOCOL_LR );
  //esp_wifi_set_max_tx_power(82);
  WiFi.softAP(mySsid, myPassword);
  delay(1000);

  // workaround DHCP crash on ESP32 when AP Mode!!! Non servirebbe se funzionasse WiFi.persistent(false)
  // https://github.com/espressif/arduino-esp32/issues/2025#issuecomment-544131287
  WiFi.softAPConfig(local_ip, gateway, netmask);

  webSocketServer.enableHeartbeat(pingInterval, pongTimeout, wsTimeoutsBeforeDisconnet);
  webSocketServer.begin();
  webSocketServer.onEvent(webSocketEvent);

  // server.on("/", []() {
  //   server.send_P(200, "text/html", webpage);
  // });
  // server.begin();

  // setup finished, switch on red led
  ledEspOn.on();
}

void loop()
{
  if ((millis() - previousWiFiCheckMillis) > 500) {
    previousWiFiCheckMillis = millis();
    Serial.print("softAPgetStationNum: ");Serial.println(WiFi.softAPgetStationNum());
    Serial.print("status: ");Serial.println(WiFi.status());
    wifi_sta_list_t clients;
    esp_wifi_ap_get_sta_list(&clients);
    Serial.print("clients.num: ");Serial.println(clients.num);
    Serial.print("clients.sta[0].rssi: ");Serial.println(clients.sta[0].rssi);
  }

  if (WiFi.softAPgetStationNum() > 0)
  {
    previousMillis = 0;

    webSocketServer.loop();
    // server.handleClient();

    int connectedSocketClients = webSocketServer.connectedClients();

    if(!ledWifi.isOn)
      ledWifi.on();

    if (lastSocketClientCounter != connectedSocketClients) {
      lastSocketClientCounter = connectedSocketClients;
      disconnectionCounter = 0;
      previousHealtCheck = 0;
      if (connectedSocketClients > 0) {
        digitalWrite(LED_BUILTIN, LOW);
        ledWebSocket.on();
      }
      else {
        digitalWrite(LED_BUILTIN, HIGH);
        ledWebSocket.off();
      }
    }

    if (connectedSocketClients > 0)
      checkHealthCheckTime();
  }
  else
  {
    if ((millis() - previousMillis) > 500) {
      Serial.println("No wifi clients connected");
      previousMillis = millis();
      if (ledWifi.isOn) {
        digitalWrite(LED_BUILTIN, HIGH);
        ledWifi.off();
      }
      else {
        digitalWrite(LED_BUILTIN, LOW);
        ledWifi.on();
      }
    }

    // websocket check led
    if (ledWebSocket.isOn)
      ledWebSocket.off();
  }
}
