import 'package:shared_preferences/shared_preferences.dart';

class Setting {
  String key;
  String dataType;
  dynamic value;

  Setting({this.key, this.dataType, this.value});
}

class Settings {
  static Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  static bool arduinoTimeoutEnabled;
  static int arduinoTimeout;
  static bool statusTimerEnabled;
  static int statusTimer;
  static String wifiSSID;
  static String wifiPassword;
  static int clientPing;
  static String webSocketIp;
  static int webSocketPort;
  static int webSocketPing;
  static int webSocketPongTimeout;
  static int webSocketTimeoutsBeforeDisconnet;
  static bool autoReconnectSocketEnabled;

  static int defaultControllerType;
  static double leftAdjustment;
  static double rightAdjustment;

  static bool timeoutChanged = false;
  static bool websocketChanged = false;

  static List<Setting> _list = [
    Setting(
      key: 'arduinoTimeoutEnabled',
      dataType: 'bool',
    ),
    Setting(
      key: 'arduinoTimeout',
      dataType: 'int',
    ),
    Setting(
      key: 'statusTimerEnabled',
      dataType: 'bool',
    ),
    Setting(
      key: 'statusTimer',
      dataType: 'int',
    ),
    Setting(
      key: 'autoReconnectSocketEnabled',
      dataType: 'bool',
    ),
    Setting(
      key: 'wifiSsid',
      dataType: 'string',
    ),
    Setting(
      key: 'wifiPassword',
      dataType: 'string',
    ),
    Setting(
      key: 'clientPing',
      dataType: 'int',
    ),
    Setting(
      key: 'webSocketIp',
      dataType: 'string',
    ),
    Setting(
      key: 'webSocketPort',
      dataType: 'int',
    ),
    Setting(
      key: 'webSocketPing',
      dataType: 'int',
    ),
    Setting(
      key: 'webSocketPongTimeout',
      dataType: 'int',
    ),
    Setting(
      key: 'webSocketTimeoutsBeforeDisconnet',
      dataType: 'int',
    ),
    Setting(
      key: 'defaultControllerType',
      dataType: 'string',
    ),
    Setting(
      key: 'leftAdjustment',
      dataType: 'double',
    ),
    Setting(
      key: 'rightAdjustment',
      dataType: 'double',
    ),
  ];

  static Future<dynamic> getByKey(String key) {
    dynamic result;
    Setting setting = _searchSetting(key);
    if (setting != null) {
      switch (setting.dataType) {
        case 'bool':
          result = _prefs.then((SharedPreferences prefs) {
            return prefs.getBool(key);
          });
          break;
        case 'string':
          result = _prefs.then((SharedPreferences prefs) {
            return prefs.getString(key);
          });
          break;
        case 'double':
          result = _prefs.then((SharedPreferences prefs) {
            return prefs.getDouble(key);
          });
          break;
        case 'int':
          result = _prefs.then((SharedPreferences prefs) {
            return prefs.getInt(key);
          });
          break;
        default:
      }
    }

    return result;
  }

  static Future<bool> setByKey(String key, dynamic value) async {
    Setting setting = _searchSetting(key);
    if (setting != null) {
      SharedPreferences prefs = await _prefs;
      switch (setting.dataType) {
        case 'bool':
          if (value is bool) {
            return prefs.setBool(key, value).then((bool success) {
              return success;
            });
          }
          break;
        case 'double':
          if (value is double) {
            return prefs.setDouble(key, value).then((bool success) {
              return success;
            });
          }
          break;
        case 'string':
          if (value is String) {
            return prefs.setString(key, value).then((bool success) {
              return success;
            });
          }
          break;
        case 'int':
          if (value is int) {
            return prefs.setInt(key, value).then((bool success) {
              return success;
            });
          }
          break;
        default:
          return false;
      }

      return false;
    } else
      return false;
  }

  static Setting _searchSetting(String key) {
    return _list.firstWhere((setting) => setting.key == key,
        orElse: () => null);
  }

  static Future<bool> loadSettings() async {
    try {
      arduinoTimeoutEnabled = await getByKey('arduinoTimeoutEnabled') ?? true;
      arduinoTimeout = await getByKey('arduinoTimeout') ?? 2300;
      statusTimerEnabled = await getByKey('statusTimerEnabled') ?? true;
      statusTimer = await getByKey('statusTimer') ?? 1000;
      wifiSSID = await getByKey('wifiSSID') ?? 'BarkiFi';
      wifiPassword = await getByKey('wifiPassword') ?? 'ciaociao';
      webSocketIp = await getByKey('webSocketIp') ?? '192.168.4.1';
      webSocketPort = await getByKey('webSocketPort') ?? 81;
      webSocketPing = await getByKey('webSocketPing') ?? 750;
      webSocketPongTimeout = await getByKey('webSocketPongTimeout') ?? 500;
      webSocketTimeoutsBeforeDisconnet = await getByKey('webSocketTimeoutsBeforeDisconnet') ?? 0;
      clientPing = await getByKey('clientPing') ?? 750;
      autoReconnectSocketEnabled = await getByKey('autoReconnectSocketEnabled') ?? true;
      defaultControllerType = await getByKey('defaultControllerType') ?? 1;
    } catch (err) {
      print(err.toString());
    }
    return true;
  }

  static Future<bool> saveSettings() async {
    try {
      await setByKey('arduinoTimeoutEnabled', arduinoTimeoutEnabled);
      await setByKey('arduinoTimeout', arduinoTimeout);
      await setByKey('statusTimerEnabled', statusTimerEnabled);
      await setByKey('statusTimer', statusTimer);
      await setByKey('wifiSSID', wifiSSID);
      await setByKey('wifiPassword', wifiPassword);
      await setByKey('webSocketIp', webSocketIp);
      await setByKey('webSocketPort', webSocketPort);
      await setByKey('webSocketPing', webSocketPing);
      await setByKey('webSocketPongTimeout', webSocketPongTimeout);
      await setByKey('webSocketTimeoutsBeforeDisconnet', webSocketTimeoutsBeforeDisconnet);
      await setByKey('clientPing', clientPing);
      await setByKey('autoReconnectSocketEnabled', autoReconnectSocketEnabled);
      await setByKey('defaultControllerType', defaultControllerType);
    } catch (err) {
      print(err.toString());
    }
    return true;
  }
}
