import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/services.dart';
import 'package:preferences/preference_service.dart';
import 'package:wifi/wifi.dart';
import 'package:wifi_configuration/wifi_configuration.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import './screens/settings_screen.dart';
import './models/websockets_notifications.dart';
import './models/utils.dart';
import './models/settings.dart';
import './models/motors_speed.dart';
import './widgets/direction/direction_controller.dart';
import './widgets/log_messages.dart';
import './widgets/sensor_card.dart';
import './widgets/control_panel.dart';
import './widgets/control_panel_element.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrefService.init(prefix: 'pref_');
  runApp(MyApp());
}

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
  final _mainPageScaffoldKey = GlobalKey<ScaffoldState>();
  static WebSocketsNotifications webSocket = new WebSocketsNotifications();
  static BluetoothConnection connection;
  static String btDeviceAddress = "98:D3:31:20:40:EB";
  //String wsServerAddress = '192.168.4.1';
  //int wsServerPort = 81;
  static bool _isSocketConnected = false;
  static bool _isBtConnected = false;
  static int _earthToSeaRssi;
  bool _isPasturaEjected = false;
  bool _isLedOn = false;
  bool _isAdjstmentDisabled = true;
  // bool _isRgbRedOn = true;
  // bool _isRgbBlueOn = false;
  // bool _isRgbGreenOn = false;
  // bool _isBackLedOn = false;
  ControlPanel ledControlPanel = ControlPanel();

  bool _isLoading = false;

  List<String> logMessages = new List<String>();
  var logMessageTextController = TextEditingController();
  double _temperature;
  int _controllerType = 1;

  Timer _statusTimer;
  Timer _autoReconnectTimer;

  bool _listenForConnectivityChanged = false;
  StreamSubscription _onWifiChanged;
  Future<bool> _dataLoaded;

  // bt data trick
  List<int> _btIncomingBuffer = List<int>();

  void _onBtData(Uint8List data) {
    _btIncomingBuffer += data;
    // If there is a sample, and it is full received
    int indexOfStringEnd = _btIncomingBuffer.indexOf('\n'.codeUnitAt(0));

    if (indexOfStringEnd > 0) {
      List<List<int>> buffersSplitted = List<List<int>>();

      // splitta il buffer in sotto liste
      int lastFound = 0;
      for (var i = 0; i < _btIncomingBuffer.length; i++) {
        if (_btIncomingBuffer[i] == '\n'.codeUnitAt(0)) {
          buffersSplitted.add(_btIncomingBuffer.sublist(lastFound, i + 1));
          lastFound = i + 1;
        }
      }

      // pulisci il buffer
      _btIncomingBuffer.clear();

      // se l'ultima sotto lista non termina con '\n', usala come inizio del prossimo buffer
      if (buffersSplitted.last.last != '\n'.codeUnitAt(0))
        _btIncomingBuffer = buffersSplitted.removeLast();

      buffersSplitted.forEach((buffer) {
        buffer.removeWhere((char) {
          return (char == '\n'.codeUnitAt(0) || char == '\r'.codeUnitAt(0));
        });
        String btDataReceived = ascii.decode(buffer);
        if (btDataReceived.length > 4) _onMessageReceived(btDataReceived);
      });
    }

    if (_btIncomingBuffer.length > 700) {
      // something wrong, clear buffer
      int lastEndCharIndex = _btIncomingBuffer.lastIndexOf('\n'.codeUnitAt(0));
      if (lastEndCharIndex > 0)
        _btIncomingBuffer = _btIncomingBuffer.sublist(lastEndCharIndex + 1);
      else
        _btIncomingBuffer.clear();
    }
  }

  Future<void> _btConnect(
      {BluetoothDevice device,
      String fixedAddress,
      bool forced = false}) async {
    setState(() {
      _isLoading = true;
    });
    if (connection == null) {
      try {
        if (device != null)
          connection = await BluetoothConnection.toAddress(device.address);
        else if (fixedAddress != null) {
          connection = await BluetoothConnection.toAddress(fixedAddress);
        }

        _onBtConnectionSuccess();

        connection.input.listen(_onBtData).onDone(() {
          setState(() {
            logMessages.add('BT Disconnected by remote request');
            _isBtConnected = false;
            connection = null;
            ledControlPanel.updateElement(
                'bluetooth', ControlPanelElementStatus.off);
            ledControlPanel.updateElement(
                'wifi', ControlPanelElementStatus.off);
            ledControlPanel.updateElement(
                'socket', ControlPanelElementStatus.off);
          });
          Utils.snackBarMessage(
              type: SnackBarType.warning,
              snackBarContent: 'BT Disconnected!',
              scaffoldKey: _mainPageScaffoldKey);
        });

        _isLoading = false;
      } catch (exception) {
        setState(() {
          _isBtConnected = false;
          _isLoading = false;
          ledControlPanel.updateElement(
              'bluetooth', ControlPanelElementStatus.off);
        });
        Utils.snackBarMessage(
            type: SnackBarType.error,
            snackBarContent: 'Error! Can\'t connect.',
            scaffoldKey: _mainPageScaffoldKey);
        if (!forced) _forceBtReconnection();
      }
    } else {
      if (connection.isConnected) {
        setState(() {
          //logMessages.add('bt already connected');
          Utils.snackBarMessage(
              type: SnackBarType.warning,
              snackBarContent: 'BT already connected',
              scaffoldKey: _mainPageScaffoldKey);
          _isBtConnected = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isBtConnected = false;
          _isLoading = false;
        });
        Utils.snackBarMessage(
            type: SnackBarType.error,
            snackBarContent: 'Error! Can\'t connect.',
            scaffoldKey: _mainPageScaffoldKey);
        ledControlPanel.updateElement(
            'bluetooth', ControlPanelElementStatus.off);
        if (!forced) _forceBtReconnection();
      }
    }
  }

  Future<void> _forceBtReconnection() async {
    await FlutterBluetoothSerial.instance.requestDisable();
    if (connection != null) {
      connection.dispose();
      connection = null;
    }
    await FlutterBluetoothSerial.instance.requestEnable();
    _btConnect(fixedAddress: btDeviceAddress, forced: true);
  }

  void _onBtConnectionSuccess() {
    if (!_isBtConnected) {
      print('_isBtConnected');
      setState(() => _isBtConnected = true);
      _setStatusTimer();
      Utils.snackBarMessage(
          type: SnackBarType.normal,
          snackBarContent: 'BT connected succesfully',
          scaffoldKey: _mainPageScaffoldKey);
      ledControlPanel.updateElement('bluetooth', ControlPanelElementStatus.on);
      ledControlPanel.updateElement('wifi', ControlPanelElementStatus.off);
      ledControlPanel.updateElement('socket', ControlPanelElementStatus.off);
    }
  }

  Future<void> _wifiConnect2() async {
    WifiConnectionStatus connectionResult =
        await Utils.connect(Settings.wifiSSID, Settings.wifiPassword);

    if (Utils.isWiFiConnected ||
        connectionResult == WifiConnectionStatus.connected) {
      print(
          'isWiFiConnected: ${Utils.isWiFiConnected}. connectionResult: ${connectionResult.toString()} ');

      setState(() {});

      // Now check for mobile network connection
      await _checkConnectivity();

      Future.delayed(Duration(seconds: 1), _startAutoReconnectSocket);
    }
  }

  Future<void> _checkConnectivity() async {
    ConnectivityResult connectionType =
        await Connectivity().checkConnectivity();

    if (connectionType == ConnectivityResult.mobile) {
      String title = "Network warning";
      String message =
          "Attenzione, la connessione dati mobile è attiva.\r\nSu alcuni dispositivi può impedire il funzionamento dell'app. \r\n\r\nSi consiglia di disattivarla.";

      ConfirmAction response = await Utils.asyncConfirmDialog(
        context: context,
        title: title,
        message: message,
        cancelButtonText: 'Fo come cazzo me pare',
        confirmButtonText: 'Disattiva',
      );

      switch (response) {
        case ConfirmAction.accept:
          await Utils.asyncAlert(
            context: context,
            title: 'Waiting...',
            message:
                'Ok, aspetto qua.\r\nDisattiva la connessione dati mobile e premi ok.',
          );

          break;
        case ConfirmAction.cancel:
          Utils.snackBarMessage(
            snackBarContent: 'Fa n\'po\' come cazzo te pare...',
            scaffoldKey: _mainPageScaffoldKey,
            removeCurrentSnackBar: true,
          );
          // Utils.asyncAlert(
          //   context: context,
          //   title: 'Fanculo!',
          //   message: 'Fa n\'po\' come cazzo te pare...',
          // );
          break;
        default:
      }
    }
  }

  Future<void> _wifiConnect() async {
    if (!Utils.isWiFiConnecting) {
      Utils.isWiFiConnecting = true;
      Utils.isWiFiConnected = false;

      try {
        WifiState wifiState =
            await Wifi.connection(Settings.wifiSSID, Settings.wifiPassword);

        switch (wifiState) {
          case WifiState.success:
          case WifiState.already:
            _listenForConnectivityChanged = true;
            print('WiFi state: $wifiState');

            // Now check for mobile network connection
            await _checkConnectivity();

            Utils.isWiFiConnected = true;

            // wait 1 second and try to connect socket
            Future.delayed(Duration(seconds: 1), _startAutoReconnectSocket);
            break;
          case WifiState.error:
            print('Error connection WiFi. State: $wifiState');
            break;
          case WifiState.platformException:
            print('Error connection WiFi. PlatformException: $wifiState');
            break;
          default:
            print('Error connecting');
            break;
        }
      } on PlatformException catch (err) {
        print('WiFi PlatformException ${err.toString()}');
      } on TimeoutException catch (err) {
        print('WiFi timeout ${err.toString()}');
      } on Error catch (err) {
        print('WiFi error ${err.toString()}');
      }

      Utils.isWiFiConnecting = false;
    }

    setState(() {});
  }

  // void _getGw() {
  //   Gateway.info
  //       .then((gw) => setState(() => ipGateway = gw.ip))
  //       .catchError((error) => print('Error on get gw'));
  // }

  Future<bool> _socketConnect() async {
    bool result = false;
    if (Utils.isWiFiConnected) {
      result = await webSocket.initCommunication(
          serverAddress: Settings.webSocketIp,
          serverPort: Settings.webSocketPort,
          pingInterval: Duration(milliseconds: Settings.clientPing),
          listener: _onMessageReceived);

      if (result) {
        webSocket.onClose.stream.listen((manualDisconnection) {
          if (!manualDisconnection) _onSocketConnectionClosed();
        });
        _onSocketConnectionSuccess();
      }
    } else {
      print('wifi not connected');
    }

    return result;
  }

  void _onSocketConnectionSuccess() {
    if (!_isSocketConnected) {
      _isSocketConnected = true;
      print('_onSocketConnectionSuccess');
      setState(() => _isSocketConnected = true);
      _stopAutoReconnectSocket();
      _setStatusTimer();
    }
  }

  void _setStatusTimer() {
    if (_statusTimer != null) _statusTimer.cancel();
    if (Settings.statusTimerEnabled) {
      _statusTimer = new Timer.periodic(
          Duration(milliseconds: Settings.statusTimer), (timer) {
        if (_isSocketConnected || _isBtConnected) {
          _getStatus();
        }
      });
    }
  }

  void _onSocketConnectionClosed() {
    if (_statusTimer != null) _statusTimer.cancel();

    if (_isSocketConnected) {
      setState(() => _isSocketConnected = false);
      if (Settings.autoReconnectSocketEnabled) {
        _startAutoReconnectSocket();
      }
    }
  }

  void _socketDisconnect() {
    webSocket.reset();
    if (_statusTimer != null) _statusTimer.cancel();
  }

  void _startAutoReconnectSocket() {
    if (_autoReconnectTimer == null || !_autoReconnectTimer.isActive) {
      _autoReconnectTimer = new Timer.periodic(Duration(seconds: 1), (_) {
        _socketConnect();
      });
    }
  }

  String parseValueReceived(List<String> receivedCommands, String key) {
    String value;
    int indexOfValue = receivedCommands.indexOf(key);
    if (indexOfValue > 0) value = receivedCommands[indexOfValue + 1];
    return value;
  }

  void _stopAutoReconnectSocket() {
    if (_autoReconnectTimer != null) _autoReconnectTimer.cancel();
  }

  void _onMessageReceived(String message) {
    String snackBarContent;
    SnackBarType snackBarType = SnackBarType.normal;

    print(message);
    if (message.startsWith('#')) {
      // it's a command
      // message layout #ssrr;xxxxxx;xxxxx;xxxxx
      // sender/receiver list:
      // se -> Arduino sea
      // ea -> Arduino earth
      // bt -> Arduino earth bluetooth
      // fl -> Flutter app
      String sender = message.substring(1, 3);
      String receiver = message.substring(3, 5);
      if (receiver == DeviceName.FLUTTER) {
        String rawCommands = message.substring(6);
        List<String> receivedCommands = rawCommands.split(';');
        if (sender == DeviceName.SEA) {
          setState(() {
            ledControlPanel.updateElement(
              'wifi',
              ControlPanelElementStatus.on,
            );
            ledControlPanel.updateElement(
              'socket',
              ControlPanelElementStatus.on,
            );
          });

          // Arduino Sea
          if (receivedCommands[0] == "ok") {
            // is ok command
            if (receivedCommands[1] == "status") {
              // is response tu status command
              String value;

              value = parseValueReceived(receivedCommands, "temp");
              if (value.isNotEmpty) {
                _temperature = double.tryParse(value);
              }

              value = parseValueReceived(receivedCommands, "lm");
              if (value.isNotEmpty) {
                MotorsSpeed.actualLeft = int.tryParse(value);
              }

              value = parseValueReceived(receivedCommands, "rm");
              if (value.isNotEmpty) {
                MotorsSpeed.actualRight = int.tryParse(value);
              }

              value = parseValueReceived(receivedCommands, "rssi");
              if (value.isNotEmpty) {
                _earthToSeaRssi = int.parse(value);
                print('rssiRaw $value');
              }

              setState(() {});
            } else {
              if (receivedCommands.length > 1 &&
                  receivedCommands[1].isNotEmpty) {
                String commandAfterOk = receivedCommands[1];
                setState(() => logMessages.add(commandAfterOk));
                snackBarContent = 'Arduino response: ' + commandAfterOk;
              } else
                snackBarContent = 'Arduino response: ok';
            }
          } else if (receivedCommands[0] == "error") {
            // is an error response to last command
            // TODO
            snackBarContent = 'ERROR! Arduino response: ' + rawCommands;
            snackBarType = SnackBarType.error;
            setState(() => logMessages.add('Error: ' + rawCommands));
          } else {
            // unknown message
            setState(() => logMessages.add('Unknown command: ' + rawCommands));
          }
        } else if (sender == DeviceName.EARTH) {
          // Arduino earth
        } else if (sender == DeviceName.EARTH_BT) {
          // bt -> Arduino earth bluetooth
          setState(() => logMessages.add(rawCommands));
        } else {
          // unknown sender
        }
      }
    } else {
      // unknown message type
      setState(() => logMessages.add('Unknown: ' + message));
    }

    if (snackBarContent != null) {
      Utils.snackBarMessage(
          type: snackBarType,
          snackBarContent: snackBarContent,
          scaffoldKey: _mainPageScaffoldKey,
          removeCurrentSnackBar: true);
    }
  }

  void _switchOnLed() {
    sendMessage(DeviceName.SEA, 'led;on;', hideSnackBar: true);
    setState(() => _isLedOn = true);
  }

  void _switchOffLed() {
    sendMessage(DeviceName.SEA, 'led;off;', hideSnackBar: true);
    setState(() => _isLedOn = false);
  }

  void _onLedButtonPressed() {
    if (_isSocketConnected || _isBtConnected) {
      if (_isLedOn)
        _switchOffLed();
      else
        _switchOnLed();
    } else {
      // alert
      Utils.snackBarMessage(
        snackBarContent: 'Socket non connesso',
        scaffoldKey: _mainPageScaffoldKey,
        type: SnackBarType.warning,
        removeCurrentSnackBar: true,
      );
      // Utils.asyncAlert(
      //   context: context,
      //   title: 'Errore',
      //   message: 'Socket non connesso!',
      // );
      print('Socket not connected');
    }
  }

  void _onAdjstmentButtonPressed() {
    if (_isAdjstmentDisabled)
      setState(() {
        _isAdjstmentDisabled = false;
      });
    else
      setState(() {
        _isAdjstmentDisabled = true;
      });
  }

  void _getStatus() {
    if (_isSocketConnected || _isBtConnected) {
      try {
        setState(() {
          ledControlPanel.updateElement(
              'wifi', ControlPanelElementStatus.changing);
          ledControlPanel.updateElement(
              'socket', ControlPanelElementStatus.changing);
        });
        sendMessage(DeviceName.SEA, 'getStatus;');
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
    if (_isSocketConnected || _isBtConnected) {
      if (!_isPasturaEjected) {
        Utils.asyncConfirmDialog(
          context: context,
          title: 'Lanciamo?',
          message:
              'Guarda che poi non cen\'hai n\'altra!\r\n\r\nLanciamo qua, sei sicuro?',
          cancelButtonText: 'Statte bono!',
          confirmButtonText: 'LANCIA ZIO!',
        ).then((ConfirmAction response) {
          switch (response) {
            case ConfirmAction.accept:
              sendMessage(DeviceName.SEA, 'ejectPastura;', hideSnackBar: true);
              Utils.asyncAlert(
                context: context,
                title: 'Fatto!',
                message: 'Pastura lanciata!\r\nIn bocca al lupo.',
              );
              setState(() => _isPasturaEjected = true);
              break;
            case ConfirmAction.cancel:
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
      Utils.snackBarMessage(
        snackBarContent: 'Socket non connesso',
        scaffoldKey: _mainPageScaffoldKey,
        type: SnackBarType.warning,
        removeCurrentSnackBar: true,
      );
      // Utils.asyncAlert(
      //   context: context,
      //   title: 'Errore',
      //   message: 'Socket non connesso!',
      // );
      print('Socket not connected');
    }
  }

  void _onDirectionChanged() {
    if (_isSocketConnected || _isBtConnected) {
      sendMessage(DeviceName.SEA,
          'setMotorsSpeed;${MotorsSpeed.getLeft()};${MotorsSpeed.getRight()};',
          hideSnackBar: true);
    }
  }

  void _onSettingsChanged() {
    print('Settings changed');
    _setStatusTimer();
    if (_isSocketConnected || _isBtConnected) {
      if (Settings.timeoutChanged) {
        int arduinoTimeout =
            Settings.arduinoTimeoutEnabled ? Settings.arduinoTimeout : 0;
        sendMessage(DeviceName.SEA, 'setTimeout;$arduinoTimeout;',
            hideSnackBar: true);
        Settings.timeoutChanged = false;
      }
      if (Settings.websocketChanged) {
        sendMessage(DeviceName.SEA,
            'setWebSocket;${Settings.webSocketPing};${Settings.webSocketPongTimeout};${Settings.webSocketTimeoutsBeforeDisconnet};',
            hideSnackBar: true);
        Settings.websocketChanged = false;
      }
    }
  }

  void sendMessage(
    String receiver,
    String message, {
    bool hideSnackBar = false,
  }) async {
    if (hideSnackBar) Utils.removeCurrentSnackBar(_mainPageScaffoldKey);

    String sender = DeviceName.FLUTTER;
    String messageToSend = "#" + sender + receiver + ";" + message;

    if (!messageToSend.endsWith('\n')) messageToSend += '\n';

    if (_isSocketConnected) webSocket.send(messageToSend);
    if (_isBtConnected) {
      connection.output.add(ascii.encode(messageToSend));
      await connection.output.allSent;
      //print("Sent to bt: $messageToSend");
    }
  }

  void _clearLogMessages() {
    setState(() {
      logMessages.clear();
    });
  }

  void _onConnectivityChanged(ConnectivityResult result) {
    if (_listenForConnectivityChanged) {
      logMessages.add(result.toString());

      Utils.isWiFiConnected = result == ConnectivityResult.wifi ? true : false;
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _dataLoaded = MotorsSpeed.getFromSettings();
    _dataLoaded = Settings.loadSettings();
    _onWifiChanged = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      _onConnectivityChanged(result);
    });
  }

  @override
  void dispose() {
    super.dispose();
    _onWifiChanged.cancel();
    _socketDisconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _mainPageScaffoldKey,
      appBar: AppBar(
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.menu),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) {
                    return SettingsScreen(
                      onSettingChanged: _onSettingsChanged,
                    );
                  },
                ),
              );
            },
          )
        ],
        title: Text(widget.title),
      ),
      // backgroundColor: Colors.white,
      body: Builder(
          builder: (context) => Stack(
                children: <Widget>[
                  Opacity(
                    opacity: _isLoading
                        ? 0.5
                        : 1, // You can reduce this when loading to give different effect
                    child: AbsorbPointer(
                      absorbing: _isLoading,
                      child: Container(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(
                              height: 8,
                            ),
                            // Row(
                            //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            //   children: <Widget>[
                            //     RaisedButton(
                            //       child: Text(
                            //         !Utils.isWiFiConnected
                            //             ? "Connect WiFi"
                            //             : "Re-connect WiFi",
                            //         style: TextStyle(
                            //             color: Colors.white, fontSize: 20.0),
                            //       ),
                            //       color: Colors.blue,
                            //       onPressed: _wifiConnect,
                            //     ),
                            //     Card(
                            //       elevation: 5,
                            //       //margin: EdgeInsets.all(10),
                            //       child: Padding(
                            //         padding: const EdgeInsets.symmetric(
                            //           horizontal: 18,
                            //           vertical: 7,
                            //         ),
                            //         child: Text(
                            //           _isSocketConnected
                            //               ? "Connected"
                            //               : "Disconnected",
                            //           style: TextStyle(
                            //               color: Colors.white, fontSize: 20.0),
                            //         ),
                            //       ),
                            //       color: _isSocketConnected
                            //           ? Colors.green
                            //           : Colors.red,
                            //     ),
                            //   ],
                            // ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: RaisedButton(
                                      child: Text(
                                        !_isBtConnected
                                            ? 'BT Connect'
                                            : 'BT Connected',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20.0,
                                        ),
                                      ),
                                      color: !_isBtConnected
                                          ? Colors.blue
                                          : Colors.green,
                                      onPressed: () async {
                                        // final BluetoothDevice selectedDevice =
                                        //     await Navigator.of(context).push(
                                        //   MaterialPageRoute(
                                        //     builder: (context) {
                                        //       return SelectBondedDevicePage(
                                        //           checkAvailability: true);
                                        //     },
                                        //   ),
                                        // );

                                        // if (selectedDevice != null) {
                                        //   print('Connect -> selected ' + selectedDevice.address);
                                        //   _btConnect(device: selectedDevice);
                                        // } else {
                                        //   print('Connect -> no device selected');
                                        //   _btConnect(fixedAddress: btDeviceAddress);
                                        // }
                                        _btConnect(
                                            fixedAddress: btDeviceAddress);
                                      },
                                    ),
                                  ),
                                ),
                                ledControlPanel,
                              ],
                            ),
                            Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: <Widget>[
                                RaisedButton(
                                  child: Text(
                                    _controllerType == 1
                                        ? "Show Joystick"
                                        : "Show Frecce",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 18.0),
                                  ),
                                  color: Colors.blue,
                                  onPressed: () {
                                    // TODO add haptic feedback
                                    //Feedback.forTap(context);
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
                                    "${_isAdjstmentDisabled ? "Enable" : "Disable"} Adjstment",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 18.0),
                                  ),
                                  color: Colors.blue,
                                  onPressed: _onAdjstmentButtonPressed,
                                ),
                              ],
                            ),
                            FutureBuilder(
                              future: _dataLoaded,
                              builder: (BuildContext futureContext,
                                  AsyncSnapshot<bool> snapshot) {
                                if (snapshot.hasData) {
                                  return _controllerType == 0
                                      ? DirectionController(
                                          onDirectionChanged:
                                              _onDirectionChanged,
                                          controllerType: 0,
                                          adjustmentsDisabled:
                                              _isAdjstmentDisabled,
                                        )
                                      : DirectionController(
                                          onDirectionChanged:
                                              _onDirectionChanged,
                                          controllerType: 1,
                                          adjustmentsDisabled:
                                              _isAdjstmentDisabled,
                                        );
                                } else {
                                  return Text('Loading...');
                                }
                              },
                            ),
                            Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                RaisedButton(
                                  padding: EdgeInsets.symmetric(horizontal: 40),
                                  child: Text(
                                    !_isPasturaEjected
                                        ? "Eject Pastura!"
                                        : "Reset pastura",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  color: Colors.blue,
                                  onPressed: !_isPasturaEjected
                                      ? _ejectPastura
                                      : _resetPastura,
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                RaisedButton(
                                  child: Text(
                                    "Switch ${_isLedOn ? "off" : "on"} LED",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18.0,
                                    ),
                                  ),
                                  color: _isLedOn ? Colors.red : Colors.green,
                                  onPressed: _onLedButtonPressed,
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                SensorCard(
                                  value: _temperature,
                                  text: "Temperatura",
                                  flex: 6,
                                ),
                                SensorCard(
                                  value: _earthToSeaRssi,
                                  text: "rssi",
                                  flex: 4
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                SensorCard(
                                  value: MotorsSpeed.actualLeft,
                                  text: "Motore SX",
                                  small: true,
                                ),
                                SensorCard(
                                  value: MotorsSpeed.actualRight,
                                  text: "Motore DX",
                                  small: true,
                                ),
                              ],
                            ),
                            LogMessages(
                              messagesList: logMessages,
                              onClearPressed: _clearLogMessages,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: _isLoading ? 1.0 : 0,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              )),
    );
  }
}
