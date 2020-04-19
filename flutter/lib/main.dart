import 'package:barkino/widgets/direction_controller.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:gateway/gateway.dart';
import 'package:wifi/wifi.dart';

import './widgets/log_messages.dart';
import './widgets/temperature.dart';
import './websockets.dart';
import './utils.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  final String _title = 'Barkino';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _title,
      home: MyHomePage(_title),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  MyHomePage(this.title);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static WebSocketsNotifications webSocket = new WebSocketsNotifications();
  String wsServerAddress = '192.168.4.1';
  int wsServerPort = 81;
  bool _isSocketConnected = false;
  bool _isPasturaEjected = false;
  bool _isLedOn = false;
  bool _isRgbRedOn = true;
  bool _isRgbBlueOn = false;
  bool _isRgbGreenOn = false;
  bool _isBackLedOn = false;
  bool _autoReconnectSocket = true;
  List<String> logMessages = new List<String>();
  var logMessageTextController = TextEditingController();
  Timer _timer;
  Timer _autoReconnectTimer;
  Timer _healthCheckTimer;
  var _temperature;
  int controllerType = 0;

  String ipGateway = '';

  String ssid = 'BarkiFi';
  String password = 'ciaociao';

  TextEditingController _controller;

  bool _isWiFiConnected = false;
  String showMessage = '';

  // set as static objects to avoid re-building on each timer trigger
  final DirectionController joystick = DirectionController(
    onDirectionChanged: _onDirectionChanged,
    controllerType: 0,
  );
  final DirectionController pad = DirectionController(
    onDirectionChanged: _onDirectionChanged,
    controllerType: 1,
  );

  void initState() {
    super.initState();
    _controller = TextEditingController(text: wsServerAddress);
    _timer = new Timer.periodic(Duration(seconds: 1), (timer) {
      if (_isSocketConnected) {
        webSocket.send('#healthcheck;\n');
        _getTemperature(1);
      }
    });
  }

  void _wifiConnect() {
    Wifi.connection(ssid, password).then((WifiState state) {
      switch (state) {
        case WifiState.success:
        case WifiState.already:
          print('WiFi state: $state');
          setState(() => _isWiFiConnected = true);
          break;
        case WifiState.error:
          print('Error connection WiFi. State: $state');
          setState(() => _isWiFiConnected = false);
          break;
        default:
          print('Error connecting');
          setState(() => _isWiFiConnected = false);
          break;
      }
    }).catchError((error) {
      print('Error connecting');
      setState(() => _isWiFiConnected = false);
    });
  }

  void _getGw() {
    Gateway.info
        .then((gw) => setState(() => ipGateway = gw.ip))
        .catchError((error) => print('Error on get gw'));
  }

  void _socketConnect() {
    webSocket.initCommunication(wsServerAddress, wsServerPort);
    webSocket.addListener(_onMessageReceived);
    webSocket.isOn.stream.listen((state) {
      setState(() {
        _isSocketConnected = state;
        if (_isSocketConnected) {
          if (_autoReconnectTimer != null && _autoReconnectTimer.isActive)
            _autoReconnectTimer.cancel();
        }
      });
    });
  }

  void _onMessageReceived(String serverMessage) {
    print('Barkino is still alive');
    if (_healthCheckTimer != null) _healthCheckTimer.cancel();
    _healthCheckTimer = new Timer(Duration(seconds: 5), () {
      print('Barkino is dead. Switching off websocket');
      _socketDisconnect();
    });

    if (serverMessage.startsWith('#getTemp;')) {
      String value = serverMessage.split(';')[1];
      setState(() => _temperature = double.tryParse(value));
    } else {
      setState(() => logMessages.add(serverMessage));
    }
  }

  void _socketDisconnect() {
    webSocket.removeListener(_onMessageReceived);
    webSocket.reset();
    if (_healthCheckTimer != null) _healthCheckTimer.cancel();
    // Utils.asyncAlert(
    //   context: context,
    //   title: 'Disconnesso',
    //   message:
    //       'Socket disconnesso!\r\nRiconnetterlo per comunicare con il barchino.',
    // );
    if (_autoReconnectSocket) {
      _autoReconnectTimer = new Timer(Duration(seconds: 1),  _socketConnect);
    }
  }

  _handleNewIp(String value) {
    setState(() => wsServerAddress = value);
  }

  void _switchOnLed() {
    setState(() => _isLedOn = true);
    webSocket.send('#led;on;\n');
  }

  void _switchOffLed() {
    setState(() => _isLedOn = false);
    webSocket.send('#led;off;\n');
  }

  void _getTemperature(int sensorIndex) {
    if (_isSocketConnected) {
      try {
        webSocket.send('#sensors;${sensorIndex.toString()};getTemp;\n');
      } catch (err) {
        setState(() {
          logMessages.add(err.toString());
        });
      }
    } else {
      setState(() {
        logMessages.add('Socket not connected.');
        _temperature = null;
      });
    }
  }

  void _resetPastura() {
    setState(() => _isPasturaEjected = false);
  }

  void _ejectPastura() {
    if (_isSocketConnected) {
      if (!_isPasturaEjected) {
        Utils.asyncConfirmEject(
          context: context,
          title: 'Lanciamo?',
          message:
              'Guarda che poi non cen\'hai n\'altra!\r\n\r\nLanciamo qua, sei sicuro?',
          cancelButtonText: 'Statte bono!',
          confirmButtonText: 'LANCIA ZIO!',
        ).then((ConfirmAction response) {
          switch (response) {
            case ConfirmAction.ACCEPT:
              webSocket.send('#ejectPastura;\n');
              Utils.asyncAlert(
                context: context,
                title: 'Fatto!',
                message: 'Pastura lanciata!\r\nIn bocca al lupo.',
              );
              setState(() => _isPasturaEjected = true);
              break;
            case ConfirmAction.CANCEL:
              print('User aborted');
              break;
            default:
          }
        });
      } else {
        Utils.asyncAlert(
          context: context,
          title: 'Errore',
          message: 'Pastura già lanciata!\r\nNon cen\'è più...',
        );
        print('No more pastura to eject');
      }
    } else {
      // alert
      Utils.asyncAlert(
        context: context,
        title: 'Errore',
        message: 'Socket non connesso!',
      );
      print('Socket not connected');
    }
  }

  static void _onDirectionChanged(double degrees, double normalizedDistance) {
    int degreesInt = degrees.floor();
    double distanceShort = (normalizedDistance * 10).floor() / 10;
    webSocket.send('#setMotorsSpeedFromPad;$degreesInt;$distanceShort;\n');
  }

  @override
  void dispose() {
    _controller.dispose();
    _socketDisconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      // backgroundColor: Colors.white,
      body: Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            RaisedButton(
              child: Text(
                !_isWiFiConnected ? "Connect WiFi" : "Re-connect WiFi",
                style: TextStyle(color: Colors.white, fontSize: 20.0),
              ),
              color: Colors.blue,
              onPressed: _wifiConnect,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  margin: EdgeInsets.all(10),
                  width: 150,
                  height: 45,
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Server IP',
                    ),
                    onChanged: _handleNewIp,
                  ),
                ),
                RaisedButton(
                  child: Text(
                    _isSocketConnected ? "Disconnect" : "Connect",
                    style: TextStyle(color: Colors.white, fontSize: 20.0),
                  ),
                  color: _isSocketConnected ? Colors.red : Colors.blue,
                  onPressed:
                      _isSocketConnected ? _socketDisconnect : _socketConnect,
                ),
              ],
            ),
            controllerType == 0 ? joystick : pad, // DirectionController
            RaisedButton(
              child: Text(
                controllerType == 1 ? "Show Joystick" : "Show Frecce",
                style: TextStyle(color: Colors.white, fontSize: 20.0),
              ),
              color: Colors.blue,
              onPressed: () {
                setState(() {
                  if (controllerType == 1)
                    controllerType = 0;
                  else
                    controllerType = 1;
                });
              },
            ),
            RaisedButton(
              child: Text(
                !_isPasturaEjected ? "Eject Pastura" : "Reset pastura",
                style: TextStyle(color: Colors.white, fontSize: 20.0),
              ),
              color: Colors.green,
              onPressed: !_isPasturaEjected ? _ejectPastura : _resetPastura,
            ),
            Container(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        "Red",
                        style: TextStyle(color: Colors.black, fontSize: 18.0),
                      ),
                      Checkbox(
                        value: _isRgbRedOn,
                        onChanged: (value) {
                          setState(() {
                            webSocket.send('#led;red;-1;\n');
                            _isRgbRedOn = value;
                          });
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      Text(
                        "Green",
                        style: TextStyle(color: Colors.black, fontSize: 18.0),
                      ),
                      Checkbox(
                        value: _isRgbGreenOn,
                        onChanged: (value) {
                          setState(() {
                            webSocket.send('#led;green;\n');
                            _isRgbGreenOn = value;
                          });
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      Text(
                        "Blue",
                        style: TextStyle(color: Colors.black, fontSize: 18.0),
                      ),
                      Checkbox(
                        value: _isRgbBlueOn,
                        onChanged: (value) {
                          setState(() {
                            webSocket.send('#led;blue;\n');
                            _isRgbBlueOn = value;
                          });
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      Text(
                        "Back",
                        style: TextStyle(color: Colors.black, fontSize: 18.0),
                      ),
                      Checkbox(
                        value: _isBackLedOn,
                        onChanged: (value) {
                          setState(() {
                            webSocket.send('#led;back;\n');
                            _isBackLedOn = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // RaisedButton(
            //   child: Text(
            //     "Switch ${_isLedOn ? "off" : "on"} LED!",
            //     style: TextStyle(color: Colors.white, fontSize: 20.0),
            //   ),
            //   color: Colors.green,
            //   onPressed: _isLedOn ? _switchOffLed : _switchOnLed,
            // ),
            TemperatureSensor(
              value: _isSocketConnected ? _temperature.toString() : null,
            ),
            LogMessages(
              messagesList: logMessages,
            ),
          ],
        ),
      ),
    );
  }
}
