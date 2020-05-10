import 'dart:io';

class WebSocketManager {
  static WebSocket _socket;

  static Future<bool> connect(
    String serverAddress,
    int serverPort,
  ) async {
    _socket = await WebSocket.connect('ws://$serverAddress:$serverPort');
  }
}
