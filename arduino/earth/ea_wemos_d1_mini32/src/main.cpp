#include <Arduino.h>
#include <WiFi.h>
#include <WiFiServer.h>
#include <esp_wifi.h>
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

#define BTRX1 21 // TX on BT
#define BTTX1 22 // RX on BT

bool debug = true; // set false to avoid debug serial print
bool debugSocket = true; // set false to avoid debug serial print

const int MAX_MOTOR_SPEED = 1023;
const int MIN_MOTOR_SPEED = 250; // sotto questa velocità i motori fischiano ma non si muove

int tempSensorResolution = 10;

HardwareSerial SerialBT(1);

WebServer server;
WebSocketsClient webSocket = WebSocketsClient();
int pingInterval = 750;
int pongTimeout = 500;
int wsTimeoutsBeforeDisconnet = 0;
bool isSocketConnected = false;

// Global variables
String me = "ea";
String commandSeparator = ";";
AnalogController ledRgbRed;
AnalogController ledRgbBlue;
AnalogController ledRgbGreen;
AnalogController ledBack;

bool ledBuiltInIsOn = false;
unsigned long previousDisconnectedMillis = 0;

unsigned long previousHealtCheck = 0;
unsigned long healtCheckTimeout = 1600; // 1 seconds
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

void respondToCommand(String receiver, bool isOk = true, String message = "") {
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
    Serial.println(response);
  }

  if (receiver == "se") {
    webSocket.sendTXT(response);     
  } else if (receiver == "fl") {
    SerialBT.println(response);
  } else {
    return;
  }
}

void spreadMessage(String receiver, String message) {
  if (receiver == "se") {
    webSocket.sendTXT(message);     
  } else if (receiver == "fl") {
    Serial.println("Message for flutter!");
    SerialBT.println(message);
  } else if (receiver == "bt") {
    SerialBT.println(message);
  }
  else {
    return;
  }
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
      Serial.println("Earth to Sea connected.");
      isSocketConnected = true;
      respondToCommand("fl", true, "Earth to Sea connected.");
    }
    else
    {
      Serial.println("Earth to Sea already connected!!!");
    }
  }
  else if (type == WStype_DISCONNECTED)
  {
    // Save the last time healtcheck was received
    previousHealtCheck = millis();

    ledRgbGreen.off();

    isSocketConnected = false;

    disconnectionCounter++;

    Serial.print("Earth to Sea connected disconnection: ");Serial.println(disconnectionCounter);

    // due to some connection errors, autoresolved with auto-reconnect, I don't stop motors suddenly
    //stopMotors();
  }
  else if (type == WStype_ERROR)
  {
    // Save the last time healtcheck was received
    previousHealtCheck = millis();
    
    ledRgbGreen.off();

    Serial.println("Earth to Sea WebSocket client error");
    respondToCommand("fl", false, "Earth to Sea WebSocket client error");
  }
  else if (type == WStype_PING)
  {
    // Save the last time healtcheck was received
    previousHealtCheck = millis();
  }
  else if (type == WStype_PONG)
  {
    // Save the last time healtcheck was received
    previousHealtCheck = millis();
  }
  else if (type == WStype_TEXT)
  {
    // Save the last time healtcheck was received
    previousHealtCheck = millis();
    isSocketConnected = true;

    String wsReceived = String((char *)payload);

    if (wsReceived.charAt(0) == '#') {
      // it's a command
      // message layout #ssrr;xxxxxx;xxxxx;xxxxx
      // sender/receiver list:
      // se -> Arduino sea
      // ea -> Arduino earth
      // bt -> Arduino earth bluetooth
      // fl -> Flutter app
      String sender = wsReceived.substring(1, 3);
      String receiver = wsReceived.substring(3, 5);
      Serial.print(sender);Serial.print("->");Serial.print(receiver);
      Serial.print(" ");Serial.println(wsReceived);
      if (receiver != me) {
        spreadMessage(receiver, wsReceived);
      } else {
        Serial.print("Message for me!");
      }
    }
  }
}

void handleBluetooth() {
  if (SerialBT.available())
  {
    String btReceived = SerialBT.readStringUntil('\n');

    if (btReceived.charAt(0) == '#') {
      // it's a command
      // message layout #ssrr;xxxxxx;xxxxx;xxxxx
      // sender/receiver list:
      // se -> Arduino sea
      // ea -> Arduino earth
      // bt -> Arduino earth bluetooth
      // fl -> Flutter app
      String sender = btReceived.substring(1, 3);
      String receiver = btReceived.substring(3, 5);

      Serial.print(sender);Serial.print("->");Serial.print(receiver);
      Serial.print(" ");Serial.println(btReceived);

      if (receiver != me) {
        spreadMessage(receiver, btReceived);
      }
    }
  }
}

void setup()
{
  // Start the Serial communication to send messages to the computer
  Serial.begin(115200);
  SerialBT.begin(9600, SERIAL_8N1, BTRX1, BTTX1);
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

  //WiFi.persistent(false);
  // workaround DHCP crash on ESP32 when AP Mode!!!
  // https://github.com/espressif/arduino-esp32/issues/2025#issuecomment-562848209
  WiFi.mode(WIFI_STA);
  //esp_wifi_set_protocol( WIFI_IF_STA, WIFI_PROTOCOL_LR );

  WiFi.begin(mySsid, myPassword);

  // while (WiFi.status() != WL_CONNECTED) {
  //     delay(250);
  //     Serial.print(".");
  // }

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
  if (WiFi.status() == WL_CONNECTED)
  {
    webSocket.loop();
    handleBluetooth();
  }
  else
  {
    if ((millis() - previousDisconnectedMillis) > 500) {
      Serial.print("WiFi.status() = ");Serial.println(WiFi.status());
      previousDisconnectedMillis = millis();
      if (ledBuiltInIsOn) {
        Serial.println("OFF");
        ledBuiltInIsOn = false;
        digitalWrite(LED_BUILTIN, LOW);
      }
      else {
        Serial.println("ON");
        ledBuiltInIsOn = true;
        digitalWrite(LED_BUILTIN, HIGH);
      }
    }
  }
}
