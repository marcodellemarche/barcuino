#include <Arduino.h>
#include <WiFi.h>
#include <WiFiServer.h>
#include <WebServer.h>
#include <WebSocketsClient.h>
#include <math.h>
#include <AnalogController.h>

// PIN declaration
#define LEFT_MOTOR 17
#define RIGHT_MOTOR 21
#define EJECT_SERVO 26

#define LED_RGB_RED 23
#define LED_RGB_GREEN 33
#define LED_RGB_BLUE 19
#define LED_BACK 22

#define TEMP_SENSORS_BUS 18

bool debug = true; // set false to avoid debug serial print
bool debugSocket = false; // set false to avoid debug serial print

const int MAX_MOTOR_SPEED = 1023;
const int MIN_MOTOR_SPEED = 250; // sotto questa velocità i motori fischiano ma non si muove

int tempSensorResolution = 10;

WebServer server;
WebSocketsClient webSocket = WebSocketsClient();
int pingInterval = 750;
int pongTimeout = 500;
int wsTimeoutsBeforeDisconnet = 0;
bool isSocketConnected = false;

// Global variables
String commandSeparator = ";";
AnalogController ledRgbRed;
AnalogController ledRgbBlue;
AnalogController ledRgbGreen;
AnalogController ledBack;

bool ledBuiltInIsOn = false;
unsigned long previousDisconnectedMillis = 0;

unsigned long previousHealtCheck = 0;
int healtCheckTimeout = 1600; // 1 seconds
bool isHealtCheckTimeoutEnabled = true;

const char *myPassword = "ciaociao";
const char *mySsid = "BarkiFi";

long disconnectionCounter = 0;
long lastSocketClientCounter = 0;

int WebSocketServerPort = 81;
IPAddress WebSocketServerIp(192, 168, 4, 1);

IPAddress WiFiLocalIp(192, 168, 4, 2);
IPAddress WiFiGateway(192, 168, 4, 1);
IPAddress WiFiNetmask(255, 255, 255, 0);

#define BTRX1 21
#define BTTX1 22
HardwareSerial SerialBT(1);

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

      previousHealtCheck = 0;
    }
  }
}

void respondToCommand(bool isOk = true, String message = "") {
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
  webSocket.sendTXT(response);
}

void webSocketEvent(WStype_t type, uint8_t *payload, size_t length)
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
      respondToCommand(true, "Hi! My name is Barkino.");
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
    respondToCommand(false, "WebSocket client error, stopping motors");
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
    }
  }
}

void setup()
{
  // Start the Serial communication to send messages to the computer
  Serial.begin(115200);
  SerialBT.begin(115200, SERIAL_8N1, BTRX1, BTTX1);
  delay(500);

  // set pinMode
  pinMode(LED_BUILTIN, OUTPUT);

  // initialize pins values
  digitalWrite(LED_BUILTIN, HIGH);
  ledBuiltInIsOn = true;
  // **********************************************
  // AnalogWrite section
  // Due to incompatibility between analogWrite library and Servo library, I had to rewrite the analog flow
  // So, you have to setup different channels (1-15) for each analog pin

  // create leds
  ledRgbBlue.attach(LED_RGB_BLUE, BLUE, 2);
  ledRgbRed.attach(LED_RGB_RED, RED, 3);
  ledRgbGreen.attach(LED_RGB_GREEN, GREEN, 4);
  ledBack.attach(LED_BACK, UNDEFINED, 5);

  WiFi.persistent(false);
  // workaround DHCP crash on ESP32 when AP Mode!!!
  // https://github.com/espressif/arduino-esp32/issues/2025#issuecomment-562848209
  WiFi.mode(WIFI_STA);
  //WiFi.softAP(mySsid, myPassword);
  delay(1000);
  // workaround DHCP crash on ESP32 when AP Mode!!! Non servirebbe se funzionasse WiFi.persistent(false)
  // https://github.com/espressif/arduino-esp32/issues/2025#issuecomment-544131287
  //WiFi.softAPConfig(local_ip, gateway, netmask);

  webSocket.enableHeartbeat(pingInterval, pongTimeout, wsTimeoutsBeforeDisconnet);
  webSocket.begin(WebSocketServerIp, WebSocketServerPort);
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
    webSocket.loop();
    
  }
  else
  {
    if ((millis() - previousDisconnectedMillis) > 500) {
      previousDisconnectedMillis = millis();
      if (ledBuiltInIsOn) {
        ledBuiltInIsOn = false;
        digitalWrite(LED_BUILTIN, LOW);
      }
      else {
        ledBuiltInIsOn = true;
        digitalWrite(LED_BUILTIN, HIGH);
      }
    }
  }
}
