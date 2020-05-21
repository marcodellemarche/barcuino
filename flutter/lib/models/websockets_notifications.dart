import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:web_socket_channel/io.dart';

///
/// Application-level global variable to access the WebSockets
///
// WebSocketsNotifications sockets = new WebSocketsNotifications();

///
/// Put your WebSockets server IP address
///
// const String _SERVER_IP = "192.168.4.1";

///
/// Put your WebSockets server port number
///
// const int _SERVER_PORT = 81;

// const String _SERVER_ADDRESS = "ws://$_SERVER_IP:$_SERVER_PORT";

class WebSocketsNotifications {

  ///
  /// The WebSocket "open" channel
  ///
  IOWebSocketChannel _channel;

  ///
  /// Is the connection established?
  ///
  bool _isConnected = false;
  final BehaviorSubject onClose = BehaviorSubject<bool>();
  bool manualDisconnection = false;

  ///
  /// Listeners
  /// List of methods to be called when a new message
  /// comes in.
  ///
  ObserverList<Function> _listeners;

  /// ----------------------------------------------------------
  /// Initialization the WebSockets connection with the server
  /// ----------------------------------------------------------
  Future<bool> initCommunication({
    String serverAddress,
    int serverPort,
    Duration pingInterval,
    Function listener,
  }) async {
    // Just in case, close any previous communication
    try {
      await reset();

      WebSocket webSocket = await WebSocket.connect('ws://$serverAddress:$serverPort');
      
      // useless code to fix intellisense error on WebSocket.connect
      if (false) webSocket.close();

      if (pingInterval != null) {
        webSocket.pingInterval = pingInterval;
      }

      _channel = new IOWebSocketChannel(webSocket);
      _listeners = new ObserverList<Function>();
      addListener(listener);

      _isConnected = true;

      _channel.stream.listen(
        (message) => _onReceptionOfMessageFromServer(message),
        onError: (error) {
          print('onError');
          manualDisconnection = false;
          onClose.add(manualDisconnection);
        },
        onDone: () {
          print('onDone');
          manualDisconnection = false;
          onClose.add(manualDisconnection);
        },
      );

      return true;
    }
    catch (err) {
      print(err.toString());
      return false;
    }
    

    // WebSocket.connect('ws://$serverAddress:$serverPort').then((webSocket) {
    //   try {
    //     if (webSocket != null) {
    //       if (pingInterval != null) {
    //         webSocket.pingInterval = pingInterval;
    //       }
    //       _channel = new IOWebSocketChannel(webSocket);
    //       _listeners = new ObserverList<Function>();

    //       addListener(listener);

    //       _isOn = true;
    //       isOn.add(_isOn);

    //       _channel.stream.listen(
    //         (message) => _onReceptionOfMessageFromServer(message),
    //         onError: (error) {
    //           print('onError');
    //           _isOn = false;
    //           isOn.add(_isOn);
    //         },
    //         onDone: () {
    //           print('onDone');
    //           _isOn = false;
    //           isOn.add(_isOn);
    //         },
    //       );
    //     } else {
    //       print('timpeout on WebSocket.connect');
    //     }
    //   } catch (e) {
    //     print(
    //         'Error happened when opening a new websocket connection. ${e.toString()}');
    //     _isOn = false;
    //     isOn.add(_isOn);
    //   }
    // }).catchError((error) {
    //   _isOn = false;
    //   isOn.add(_isOn);
    //   print(error);
    //   return;
    // });
  }

  /// ----------------------------------------------------------
  /// Closes the WebSocket communication
  /// ----------------------------------------------------------
  Future<void> reset() async {
    if (_channel != null) {
      if (_channel.sink != null) {
        await _channel.sink.close();
        manualDisconnection = true;
        onClose.add(manualDisconnection);
      }
    }
    _listeners = null;
  }

  /// ---------------------------------------------------------
  /// Sends a message to the server
  /// ---------------------------------------------------------
  send(String message) {
    if (_channel != null) {
      if (_channel.sink != null && _isConnected) {
        //print('Sending message: $message');
        _channel.sink.add(message);
      } else {
        print(
            'Channel is down or sink is null, not possible to send: $message');
      }
    } else {
      print('Channel is null, not possible to send: $message');
    }
  }

  /// ---------------------------------------------------------
  /// Adds a callback to be invoked in case of incoming
  /// notification
  /// ---------------------------------------------------------
  addListener(Function callback) {
    _listeners.add(callback);
  }

  removeListener(Function callback) {
    _listeners.remove(callback);
  }

  /// ----------------------------------------------------------
  /// Callback which is invoked each time that we are receiving
  /// a message from the server
  /// ----------------------------------------------------------
  _onReceptionOfMessageFromServer(message) {
    _listeners.forEach((Function callback) {
      callback(message);
    });
  }
}
