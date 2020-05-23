#include <Arduino.h>
#include <WiFi.h>
#include <WiFiServer.h>
#include <esp_wifi.h>
#include <WebServer.h>
#include <WebSocketsClient.h>
#include <math.h>
#include <AnalogController.h>

// PIN declaration

// #define LED_RGB_RED 23
// #define LED_RGB_GREEN 33
// #define LED_RGB_BLUE 19
// #define LED_BACK 27
#define LED_STATUS 27

#define TEMP_SENSORS_BUS 18

#define BTRX1 21 // TX on BT
#define BTTX1 22 // RX on BT

// AnalogController ledRgbRed;
// AnalogController ledRgbBlue;
// AnalogController ledRgbGreen;
// AnalogController ledBack;
AnalogController ledStatus;

const String FLUTTER = "fl";
const String SEA = "se";
const String EARTH = "ea";
const String EARTH_BT = "bt";

bool debug = true; // set false to avoid debug serial print
bool debugSocket = true; // set false to avoid debug serial print

const int MAX_MOTOR_SPEED = 1023;
const int MIN_MOTOR_SPEED = 250; // sotto questa velocità i motori fischiano ma non si muove

int tempSensorResolution = 10;

HardwareSerial SerialBT(1);

class myWebSocketsClient: public WebSocketsClient {
  public:
    bool clientIsConnected(void) {
      return WebSocketsClient::clientIsConnected(&_client);
    }
};

WebServer server;
myWebSocketsClient webSocket = myWebSocketsClient();
// int pingInterval = 750;
// int pongTimeout = 500;
// int wsTimeoutsBeforeDisconnet = 0;
bool isSocketConnected = false;

// Global variables
String me = EARTH;
String commandSeparator = ";";

bool ledBuiltInIsOn = false;

unsigned long previousWiFiCheckMillis = 0;
unsigned long previousLoopMillis = 0;

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
 
int8_t getSignalStrength() {
  wifi_ap_record_t ap;
  esp_wifi_sta_get_ap_info(&ap);
  return ap.rssi;
}

void sendToSerialBt(String message) {
    // per essere sicuro ci sia un '\n' alla fine della stringa
    if (!message.endsWith("\n"))
      message += '\n';
    SerialBT.print(message);
}

void sendToWebSocket(String message) {
  if (isSocketConnected)
    webSocket.sendTXT(message);
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

  if (receiver == SEA) {
    sendToWebSocket(response);     
  } else if (receiver == FLUTTER) {
    sendToSerialBt(response);
  } else {
    return;
  }
}

String appendStatusString(String rawMessage) {
  return rawMessage += "rssi" + commandSeparator + String(getSignalStrength()) + commandSeparator;
}

void spreadMessage(String receiver, String rawMessage) {
  if (receiver == SEA) {
    sendToWebSocket(rawMessage);     
  } else if (receiver == FLUTTER) {
    if (getValue(rawMessage, 2) == "status") {
      // append connection status data before spread
      rawMessage = appendStatusString(rawMessage);
    }
    if (debug) {
      Serial.print("bt to Flutter: ");Serial.println(rawMessage);
    }
    sendToSerialBt(rawMessage);
  } else if (receiver == EARTH_BT) {
    SerialBT.print(rawMessage);
    delay(10);
  }
  else {
    return;
  }
}

void handleMessage(String sender, String receiver, String fullMessage) {
  Serial.print("Message to handle: ");Serial.println(fullMessage);
}

void webSocketEvent(WStype_t type, uint8_t *payload, size_t length)
{
  if (type == WStype_CONNECTED)
  {
    // Save the last time healtcheck was received
    previousHealtCheck = millis();

    ledStatus.on();

    if (!isSocketConnected)
    {
      Serial.println("Earth to Sea connected.");
      isSocketConnected = true;
      ledStatus.on();
      respondToCommand(FLUTTER, true, "wsConnected");
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

    ledStatus.off();

    isSocketConnected = false;

    disconnectionCounter++;

    Serial.print("Earth to Sea connected disconnection: ");Serial.println(disconnectionCounter);

    respondToCommand(FLUTTER, false, "wsDisconnected");

    // due to some connection errors, autoresolved with auto-reconnect, I don't stop motors suddenly
  }
  else if (type == WStype_ERROR)
  {
    // Save the last time healtcheck was received
    previousHealtCheck = millis();
    
    //ledStatus.off();

    Serial.println("Earth to Sea WebSocket client error");
    respondToCommand(FLUTTER, false, "wsError");
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
      if(debugSocket) {
        Serial.print("ws: ");Serial.print(sender);Serial.print("->");Serial.print(receiver);
        Serial.print(" ");Serial.println(wsReceived);
      }
      if (receiver != me) {
        spreadMessage(receiver, wsReceived);
      } else {
        handleMessage(sender, receiver, wsReceived);
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

      if (debug) {
        Serial.print("bt: ");Serial.print(sender);Serial.print("->");Serial.print(receiver);
        Serial.print(" ");Serial.println(btReceived);
      }

      if (receiver != me) {
        spreadMessage(receiver, btReceived);
      }
      else {
        // it's for me! handle message
        handleMessage(sender, receiver, btReceived);
      }
    }
  }
}

void setup()
{
  // Start the Serial communication to send messages to the computer
  Serial.begin(115200);
  SerialBT.begin(115200, SERIAL_8N1, BTRX1, BTTX1);
  delay(250);

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
  // ledRgbBlue.attach(LED_RGB_BLUE, BLUE, 2);
  // ledRgbRed.attach(LED_RGB_RED, RED, 3);
  // ledRgbGreen.attach(LED_RGB_GREEN, GREEN, 4);
  // ledBack.attach(LED_BACK, UNDEFINED, 5);
  ledStatus.attach(LED_STATUS, GREEN, 5);

  //WiFi.persistent(false);
  // workaround DHCP crash on ESP32 when AP Mode!!!
  // https://github.com/espressif/arduino-esp32/issues/2025#issuecomment-562848209
  WiFi.mode(WIFI_STA);
  esp_wifi_set_protocol( WIFI_IF_STA, WIFI_PROTOCOL_LR );

  WiFi.begin(mySsid, myPassword);
  delay(250);

  // workaround DHCP crash on ESP32 when AP Mode!!! Non servirebbe se funzionasse WiFi.persistent(false)
  // https://github.com/espressif/arduino-esp32/issues/2025#issuecomment-544131287
  //WiFi.softAPConfig(local_ip, gateway, netmask);

  //webSocket.enableHeartbeat(pingInterval, pongTimeout, wsTimeoutsBeforeDisconnet);
  webSocket.begin(WebSocketServerIp, WebSocketServerPort);
  webSocket.setReconnectInterval(1000);
  webSocket.onEvent(webSocketEvent);

  // server.on("/", []() {
  //   server.send_P(200, "text/html", webpage);
  // });
  // server.begin();

  // setup finished, switch on red led
  ledStatus.on();
}

void loop()
{
  // if ((millis() - previousWiFiCheckMillis) > 500) {
  //   previousWiFiCheckMillis = millis();
  //   Serial.print("getTxPower: ");Serial.println(WiFi.getTxPower());
  //   Serial.print("ap.rssi: ");Serial.println(String(getSignalStrength()));
  // }
  if (WiFi.status() == WL_CONNECTED)
  {
    webSocket.loop();
    handleBluetooth();
    isSocketConnected = webSocket.clientIsConnected();
    
    if (!isSocketConnected) {
      if ((millis() - previousLoopMillis) > 500) {
        if (!ledStatus.isOn) {
          previousLoopMillis = millis();        
          ledStatus.on();
          // webSocket.begin(WebSocketServerIp, WebSocketServerPort);
          // webSocket.onEvent(webSocketEvent);
        }
        else {
          ledStatus.off();
        }
      }
    }
    else {
      if (!ledStatus.isOn)
        ledStatus.on();
    }
  }
  else
  {
    if ((millis() - previousLoopMillis) > 1000) {
      WiFi.begin(mySsid, myPassword);
      if (debug) {
        Serial.print("WiFi.status() = ");Serial.println(WiFi.status());
      }
      previousLoopMillis = millis();
      if (ledBuiltInIsOn) {
        ledBuiltInIsOn = false;
        ledStatus.off();
        digitalWrite(LED_BUILTIN, LOW);
      }
      else {
        ledBuiltInIsOn = true;
        ledStatus.on();
        digitalWrite(LED_BUILTIN, HIGH);
      }
    }
  }
}
