import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gateway/gateway.dart';
import 'package:wifi/wifi.dart';

import './websockets.dart';
import './utils.dart';
import './widgets/direction_controller.dart';
import './widgets/log_messages.dart';
import './widgets/temperature.dart';
import './models/motors_speed.dart';

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

  List<String> logMessages = new List<String>();
  var logMessageTextController = TextEditingController();
  double _temperature;
  int _controllerType = 1;

  bool _autoReconnectSocket = true;
  bool _isManuallyDisconnected = false;

  Timer _statusTimer;
  Timer _autoReconnectTimer;
  Timer _healthCheckTimer;

  String ipGateway = '';

  String ssid = 'BarkiFi';
  String password = 'ciaociao';

  TextEditingController _controller;

  bool _isWiFiConnected = false;
  bool _isWiFiConnecting = false;
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

  void _wifiConnect() {
    if (!_isWiFiConnecting) {
      _isWiFiConnecting = true;
      try {
        Wifi.connection(ssid, password).timeout(
          Duration(seconds: 5),
          onTimeout: () {
            return WifiState.error;
          },
        ).then((WifiState state) {
          _isWiFiConnecting = false;
          switch (state) {
            case WifiState.success:
            case WifiState.already:
              print('WiFi state: $state');
              setState(() => _isWiFiConnected = true);
              // wait 1 second and try to connect
              Future.delayed(Duration(seconds: 1), _startAutoReconnectTimer);
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
          print('Error connecting: ${error.toString()}');
          setState(() => _isWiFiConnected = false);
        });
      } catch (err) {
        setState(() => _isWiFiConnected = false);
        print('WiFi error ${err.toString()}');
      }
    }
  }

  void _getGw() {
    Gateway.info
        .then((gw) => setState(() => ipGateway = gw.ip))
        .catchError((error) => print('Error on get gw'));
  }

  void _socketConnect() {
    webSocket.initCommunication(
        serverAddress: wsServerAddress,
        serverPort: wsServerPort,
        timeout: Duration(seconds: 3),
        pingInterval: Duration(milliseconds: 250),
        listener: _onMessageReceived);
    webSocket.isOn.stream.listen((isConnected) {
      isConnected ? _onSocketConnectionSuccess() : _onSocketConnectionClosed();
    });
  }

  void _onSocketConnectionSuccess() {
    if (!_isSocketConnected) {
      //webSocket.addListener(_onMessageReceived);
      setState(() => _isSocketConnected = true);
      _stopAutoReconnectTimer();
      if (_statusTimer != null) _statusTimer.cancel();

      _statusTimer = new Timer.periodic(Duration(seconds: 1), (timer) {
        if (_isSocketConnected) {
          //webSocket.send('#healthcheck;\n');
          _getTemperature(sensorIndex: 1);
        }
      });
    }
  }

  void _onSocketConnectionClosed() {
    if (_isSocketConnected) {
      setState(() => _isSocketConnected = false);
      _socketDisconnect();
      if (!_isManuallyDisconnected && _autoReconnectSocket) {
        _startAutoReconnectTimer();
      }
    }
  }

  void _socketDisconnect() {
    webSocket.removeListener(_onMessageReceived);
    webSocket.reset();
    if (_healthCheckTimer != null) _healthCheckTimer.cancel();
    if (_statusTimer != null) _statusTimer.cancel();
  }

  void _startAutoReconnectTimer() {
    if (_autoReconnectTimer == null || !_autoReconnectTimer.isActive) {
      _autoReconnectTimer = new Timer.periodic(Duration(seconds: 1), (_) {
        _socketConnect();
      });
    }
  }

  void _stopAutoReconnectTimer() {
    if (_autoReconnectTimer != null) _autoReconnectTimer.cancel();
  }

  void _onMessageReceived(String serverMessage) {
    //print('Barkino is still alive');
    // if (_healthCheckTimer != null) _healthCheckTimer.cancel();
    // _healthCheckTimer = new Timer(Duration(seconds: 5), () {
    //   print('Barkino is dead. Switching off websocket');
    //   _socketDisconnect();
    // });

    if (serverMessage.startsWith('#getTemp;')) {
      String value = serverMessage.split(';')[1];
      setState(() => _temperature = double.tryParse(value));
    } else {
      setState(() => logMessages.add(serverMessage));
    }
  }

  void _handleNewIp(String value) {
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

  void _getTemperature({int sensorIndex}) {
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

  void _onSocketConnectionButtonPressed() {
    if (_isSocketConnected) {
      _isManuallyDisconnected = true;
      _socketDisconnect();
    } else {
      _isManuallyDisconnected = false;
      _socketConnect();
    }
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

  static void _onDirectionChanged() {
    webSocket.send('#setMotorsSpeed;${MotorsSpeed.left};${MotorsSpeed.right};\n');
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: wsServerAddress);
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
    _socketDisconnect();
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
            SizedBox(
              height: 8,
            ),
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
                // RaisedButton(
                //   child: Text(
                //     _isSocketConnected ? "Disconnect" : "Connect",
                //     style: TextStyle(color: Colors.white, fontSize: 20.0),
                //   ),
                //   color: _isSocketConnected ? Colors.red : Colors.blue,
                //   onPressed: _onSocketConnectionButtonPressed,
                // ),
                RaisedButton(
                  child: Text(
                    _isSocketConnected ? "Connected" : "Disconnected",
                    style: TextStyle(color: Colors.white, fontSize: 20.0),
                  ),
                  color: _isSocketConnected ? Colors.green : Colors.red,
                  onPressed: () {},
                ),
              ],
            ),
            _controllerType == 0 ? joystick : pad,
            RaisedButton(
              child: Text(
                _controllerType == 1 ? "Show Joystick" : "Show Frecce",
                style: TextStyle(color: Colors.white, fontSize: 20.0),
              ),
              color: Colors.blue,
              onPressed: () {
                setState(() {
                  if (_controllerType == 1)
                    _controllerType = 0;
                  else
                    _controllerType = 1;
                });
              },
            ),
            RaisedButton(
              child: Text(
                !_isPasturaEjected ? "Eject Pastura" : "Reset pastura",
                style: TextStyle(color: Colors.white, fontSize: 20.0),
              ),
              color: Colors.blue,
              onPressed: !_isPasturaEjected ? _ejectPastura : _resetPastura,
            ),
            // Container(
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.center,
            //     children: <Widget>[
            //       Row(
            //         children: <Widget>[
            //           Text(
            //             "Red",
            //             style: TextStyle(color: Colors.black, fontSize: 18.0),
            //           ),
            //           Checkbox(
            //             value: _isRgbRedOn,
            //             onChanged: (value) {
            //               setState(() {
            //                 webSocket.send('#led;red;-1;\n');
            //                 _isRgbRedOn = value;
            //               });
            //             },
            //           ),
            //         ],
            //       ),
            //       Row(
            //         children: <Widget>[
            //           Text(
            //             "Green",
            //             style: TextStyle(color: Colors.black, fontSize: 18.0),
            //           ),
            //           Checkbox(
            //             value: _isRgbGreenOn,
            //             onChanged: (value) {
            //               setState(() {
            //                 webSocket.send('#led;green;\n');
            //                 _isRgbGreenOn = value;
            //               });
            //             },
            //           ),
            //         ],
            //       ),
            //       Row(
            //         children: <Widget>[
            //           Text(
            //             "Blue",
            //             style: TextStyle(color: Colors.black, fontSize: 18.0),
            //           ),
            //           Checkbox(
            //             value: _isRgbBlueOn,
            //             onChanged: (value) {
            //               setState(() {
            //                 webSocket.send('#led;blue;\n');
            //                 _isRgbBlueOn = value;
            //               });
            //             },
            //           ),
            //         ],
            //       ),
            //       Row(
            //         children: <Widget>[
            //           Text(
            //             "Back",
            //             style: TextStyle(color: Colors.black, fontSize: 18.0),
            //           ),
            //           Checkbox(
            //             value: _isBackLedOn,
            //             onChanged: (value) {
            //               setState(() {
            //                 webSocket.send('#led;back;\n');
            //                 _isBackLedOn = value;
            //               });
            //             },
            //           ),
            //         ],
            //       ),
            //     ],
            //   ),
            // ),
            RaisedButton(
              child: Text(
                "Switch ${_isLedOn ? "off" : "on"} LED!",
                style: TextStyle(color: Colors.white, fontSize: 20.0),
              ),
              color: _isLedOn ? Colors.red : Colors.green,
              onPressed: _isLedOn ? _switchOffLed : _switchOnLed,
            ),
            TemperatureSensor(
              value: _temperature,
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
