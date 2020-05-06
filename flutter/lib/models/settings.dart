import 'package:shared_preferences/shared_preferences.dart';

class Setting {
  String key;
  String dataType;
  dynamic value;

  Setting({this.key, this.dataType, this.value});
}

class Settings {
  static Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  double leftMotorAdjustment;
  double rightMotorAdjustment;

  List<Setting> _list = [
    Setting(
      key: 'leftAdjustment',
      dataType: 'double',
    ),
    Setting(
      key: 'rightAdjustment',
      dataType: 'double',
    ),
    Setting(
      key: 'autoReconnect',
      dataType: 'bool',
    ),
    Setting(
      key: 'defaultControllerType',
      dataType: 'string',
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
      key: 'socketServerIp',
      dataType: 'string',
    ),
    Setting(
      key: 'arduinoTimeoutEnabled',
      dataType: 'bool',
    ),
    Setting(
      key: 'arduinoTimeout',
      dataType: 'int',
    ),
    Setting(
      key: 'websocketTimeout',
      dataType: 'bool',
    ),
  ];

  Future<dynamic> getByKey(String key) {
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

  Future<bool> setByKey(String key, dynamic value) async {
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
    }
    else
      return false;
  }

  Setting _searchSetting(String key) {
    return _list.firstWhere((setting) => setting.key == key,
        orElse: () => null);
  }
}
