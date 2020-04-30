import 'package:flutter/material.dart';
import 'package:wifi_configuration/wifi_configuration.dart';

enum ConfirmAction { CANCEL, ACCEPT }

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
  static Future<ConfirmAction> asyncConfirmEject({
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
                Navigator.of(context).pop(ConfirmAction.CANCEL);
              },
            ),
            FlatButton(
              child: Text(confirmButtonText),
              color: Colors.green,
              onPressed: () {
                Navigator.of(context).pop(ConfirmAction.ACCEPT);
              },
            ),
          ],
        );
      },
    );
  }

  static Future<bool> connect(String ssid, String password) async {
    bool isConnectedBool = await WifiConfiguration.isConnectedToWifi(ssid);
    //to get status if device connected to some wifi
    print('isConnected bool $isConnectedBool');

    isWiFiConnected = isConnectedBool;

    // String isConnectedString = await WifiConfiguration.connectedToWifi();
    // //to get current connected wifi name
    // print('isConnected string $isConnectedString');

    if (!isWiFiConnected && !isWiFiConnecting) {
      WifiConnectionStatus connectionStatus = WifiConnectionStatus.notConnected;
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

    return isWiFiConnected;
  }
}
