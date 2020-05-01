import 'package:flutter/material.dart';
import 'package:wifi_configuration/wifi_configuration.dart';

enum ConfirmAction { cancel, accept }

class ButtonPressed {
  static const RIGHT = 0;
  static const STOP = 1;
  static const LEFT = 2;
  static const UPWARD = 3;
}

class Utils {
  static bool isWiFiConnected = false;
  static bool isWiFiConnecting = false;

  // Alert async, with title, message and Ok button.
  // Can be closed by user clicking anywhere
  static Future asyncAlert({
    @required BuildContext context,
    @required String title,
    @required String message,
  }) async =>
      showDialog(
        context: context,
        barrierDismissible: true, // user must tap button for close dialog!
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: <Widget>[
              FlatButton(
                child: const Text('Ok'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );

  // Confirm alert async with title, message and confirm and cancel button.
  // confirmButtonText and cancelButtonText are optional.
  static Future<ConfirmAction> asyncConfirmDialog({
    @required BuildContext context,
    @required String title,
    @required String message,
    String confirmButtonText = 'Confirm',
    String cancelButtonText = 'Cancel',
  }) async {
    return showDialog<ConfirmAction>(
      context: context,
      barrierDismissible: false, // user must tap button for close dialog!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            FlatButton(
              child: Text(cancelButtonText),
              color: Colors.red,
              onPressed: () {
                Navigator.of(context).pop(ConfirmAction.cancel);
              },
            ),
            FlatButton(
              child: Text(confirmButtonText),
              color: Colors.green,
              onPressed: () {
                Navigator.of(context).pop(ConfirmAction.accept);
              },
            ),
          ],
        );
      },
    );
  }

  static Future<WifiConnectionStatus> connect(String ssid, String password) async {
    WifiConnectionStatus connectionStatus = WifiConnectionStatus.notConnected;
    bool isConnectedBool = false;

    try {
      //to get status if device connected to some wifi
      isConnectedBool = await WifiConfiguration.isConnectedToWifi(ssid).catchError((err) {
        print('error checking WiFi connection ${err.toString()}');
      });
    } catch (err) {
      print('error checking WiFi connection ${err.toString()}');
    }

    isWiFiConnected = isConnectedBool;

    if (!isWiFiConnected && !isWiFiConnecting) {
      isWiFiConnecting = true;
      try {
        connectionStatus = await WifiConfiguration.connectToWifi(
          ssid,
          password,
          "com.example.barkino",
        ).catchError((err) {
          print('error connecting to WiFi ${err.toString()}');
        });
      } catch (err) {
        print('error connecting to WiFi ${err.toString()}');
      }

      isWiFiConnecting = false;

      switch (connectionStatus) {
        case WifiConnectionStatus.connected:
          isWiFiConnected = true;
          print("connected");
          break;

        case WifiConnectionStatus.alreadyConnected:
          isWiFiConnected = true;
          print("alreadyConnected");
          break;

        case WifiConnectionStatus.notConnected:
          isWiFiConnected = false;
          print("notConnected");
          break;

        case WifiConnectionStatus.platformNotSupported:
          isWiFiConnected = false;
          print("platformNotSupported");
          break;

        case WifiConnectionStatus.profileAlreadyInstalled:
          isWiFiConnected = true;
          print("profileAlreadyInstalled");
          break;

        case WifiConnectionStatus.locationNotAllowed:
          isWiFiConnected = false;
          print("locationNotAllowed");
          break;

        default:
          isWiFiConnected = false;
          print("error! connectionStatus: $connectionStatus");
          break;
      }
    }

    return connectionStatus;
  }
}
