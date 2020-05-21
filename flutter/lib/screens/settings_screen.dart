import 'package:barkino/models/settings.dart';
import 'package:flutter/material.dart';
import 'package:preferences/preferences.dart';

import '../models/utils.dart';

class SettingsScreen extends StatefulWidget {
  final Function onSettingChanged;

  SettingsScreen({this.onSettingChanged});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<bool> _dataLoaded;
  final _settingsScreenScaffoldKey = GlobalKey<ScaffoldState>();

  Future<bool> _saveSettings() async {
    bool result = await Settings.saveSettings();
    setState(() {});
    print('Saved');
    Utils.snackBarMessage(
        snackBarContent: 'Saved',
        scaffoldKey: _settingsScreenScaffoldKey,
        removeCurrentSnackBar: true);
    if (widget.onSettingChanged != null) widget.onSettingChanged();
    return result;
  }

  @override
  void initState() {
    super.initState();
    _dataLoaded = Settings.loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _settingsScreenScaffoldKey,
      appBar: AppBar(
        title: Text("Settings"),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.save),
        onPressed: _saveSettings,
      ),
      body: FutureBuilder(
        future: _dataLoaded,
        builder: (BuildContext futureContext, AsyncSnapshot<bool> snapshot) {
          if (snapshot.hasData) {
            return PreferencePage(
              [
                /*******************************************************************/
                PreferenceTitle('App'),
                SwitchPreference(
                  'Timer getStatus',
                  'statusTimerEnabled',
                  desc:
                      '${Settings.statusTimerEnabled ? 'Disabilita' : 'Abilita'} il timer periodico getStatus verso l\'Arduino.',
                  defaultVal: Settings.statusTimerEnabled,
                  onChange: () {
                    Settings.statusTimerEnabled =
                        PrefService.getBool('statusTimerEnabled');
                    print('statusTimerEnabled ' +
                        Settings.statusTimerEnabled.toString());
                    _saveSettings();
                  },
                ),
                PreferenceDialogLink(
                  'Status timer in millisecondi',
                  desc: Settings.statusTimer.toString(),
                  onPop: () {
                    int inputVal =
                        int.tryParse(PrefService.getString('statusTimer'));
                    if (inputVal != null && Settings.statusTimer != inputVal) {
                      Settings.statusTimer = inputVal;
                      _saveSettings();
                    }
                  },
                  disabled: !Settings.statusTimerEnabled,
                  barrierDismissible: false,
                  dialog: PreferenceDialog(
                    [
                      TextFieldPreference(
                        'Timer in millisecondi',
                        'statusTimer',
                        defaultVal: Settings.arduinoTimeout.toString(),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: false,
                          signed: false,
                        ),
                        validator: (string) {
                          int inputVal = int.tryParse(string);
                          if (inputVal == null ||
                              inputVal < 10 ||
                              inputVal > 25000) {
                            return 'Inserire un valore fra 10 e 25000';
                          }
                          return null;
                        },
                      ),
                    ],
                    title: 'Status timer',
                    onlySaveOnSubmit: true,
                    submitText: 'Ok',
                    cancelText: 'Cancel',
                    onCancel: () {
                      String previousVal = Settings.statusTimer.toString();
                      PrefService.setString('statusTimer', previousVal);
                    },
                  ),
                ),
                /*******************************************************************/
                PreferenceTitle('Arduino'),
                SwitchPreference(
                  'Arduino timeout',
                  'arduinoTimeoutEnabled',
                  desc:
                      '${Settings.arduinoTimeoutEnabled ? 'Disabilita' : 'Abilita'} il timeout entro il quale, in caso di disconnessione, l\'Arduino si ferma.',
                  defaultVal: Settings.arduinoTimeoutEnabled,
                  onChange: () {
                    Settings.arduinoTimeoutEnabled =
                        PrefService.getBool('arduinoTimeoutEnabled');
                    print('arduinoTimeoutEnabled ' +
                        Settings.arduinoTimeoutEnabled.toString());
                    Settings.timeoutChanged = true;
                    _saveSettings();
                  },
                ),
                PreferenceDialogLink(
                  'Timeout in milliseconds',
                  desc: Settings.arduinoTimeout.toString(),
                  onPop: () {
                    int inputVal =
                        int.tryParse(PrefService.getString('arduinoTimeout'));
                    if (inputVal != null &&
                        Settings.arduinoTimeout != inputVal) {
                      Settings.timeoutChanged = true;
                      Settings.arduinoTimeout = inputVal;
                      _saveSettings();
                    }
                  },
                  barrierDismissible: false,
                  disabled: !Settings.arduinoTimeoutEnabled,
                  dialog: PreferenceDialog(
                    [
                      TextFieldPreference(
                        'Timeout in millisecondi',
                        'arduinoTimeout',
                        defaultVal: Settings.arduinoTimeout.toString(),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: false,
                          signed: false,
                        ),
                        validator: (string) {
                          int inputVal = int.tryParse(string);
                          if (inputVal == null ||
                              inputVal < 10 ||
                              inputVal > 25000) {
                            return 'Inserire un valore fra 10 e 25000';
                          }
                          return null;
                        },
                      ),
                    ],
                    title: 'Arduino timeout',
                    onlySaveOnSubmit: true,
                    submitText: 'Ok',
                    cancelText: 'Cancel',
                    onCancel: () {
                      String previousVal = Settings.arduinoTimeout.toString();
                      PrefService.setString('arduinoTimeout', previousVal);
                    },
                  ),
                ),
                /*******************************************************************/
                PreferenceTitle('WebSocket Client (App)'),
                PreferenceDialogLink(
                  'Ping client in millisecondi',
                  desc: Settings.clientPing.toString(),
                  onPop: () {
                    int inputVal =
                        int.tryParse(PrefService.getString('clientPing'));
                    if (inputVal != null && Settings.clientPing != inputVal) {
                      Settings.clientPing = inputVal;
                      _saveSettings();
                    }
                  },
                  barrierDismissible: false,
                  dialog: PreferenceDialog(
                    [
                      TextFieldPreference(
                        'Ping client in millisecondi',
                        'clientPing',
                        defaultVal: Settings.clientPing.toString(),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: false,
                          signed: false,
                        ),
                        validator: (string) {
                          int inputVal = int.tryParse(string);
                          if (inputVal == null ||
                              inputVal < 10 ||
                              inputVal > 5000) {
                            return 'Inserire un valore fra 10 e 5000';
                          }
                          return null;
                        },
                      ),
                    ],
                    title: 'Ping',
                    onlySaveOnSubmit: true,
                    submitText: 'Ok',
                    cancelText: 'Cancel',
                    onCancel: () {
                      String previousVal = Settings.clientPing.toString();
                      PrefService.setString('clientPing', previousVal);
                    },
                  ),
                ),
                PreferenceDialogLink(
                  'Indirizzo Server WebSocket',
                  desc: Settings.webSocketIp,
                  onPop: () {
                    String inputVal = PrefService.getString('webSocketIp');
                    if (inputVal != null && Settings.webSocketIp != inputVal) {
                      Settings.webSocketIp = inputVal;
                      _saveSettings();
                    }
                  },
                  barrierDismissible: false,
                  dialog: PreferenceDialog(
                    [
                      TextFieldPreference('Indirizzo IP', 'webSocketIp',
                          defaultVal: Settings.webSocketIp,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: false,
                            signed: false,
                          ), validator: (string) {
                        RegExp regex = RegExp(
                            r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');
                        return regex.hasMatch(string)
                            ? null
                            : 'Indirizzo IPv4. Es: 192.168.4.1';
                      }),
                    ],
                    title: 'Indirizzo Server WebSocket',
                    onlySaveOnSubmit: true,
                    submitText: 'Ok',
                    cancelText: 'Cancel',
                    onCancel: () {
                      String previousVal = Settings.webSocketIp;
                      PrefService.setString('webSocketServer', previousVal);
                    },
                  ),
                ),
                /*******************************************************************/
                PreferenceTitle('WebSocket Server (Arduino)'),
                PreferenceDialogLink(
                  'Ping server in millisecondi',
                  desc: Settings.webSocketPing.toString(),
                  onPop: () {
                    int inputVal =
                        int.tryParse(PrefService.getString('webSocketPing'));
                    if (inputVal != null &&
                        Settings.webSocketPing != inputVal) {
                      Settings.websocketChanged = true;
                      Settings.webSocketPing = inputVal;
                      _saveSettings();
                    }
                  },
                  barrierDismissible: false,
                  dialog: PreferenceDialog(
                    [
                      TextFieldPreference(
                        'Ping server in millisecondi',
                        'webSocketPing',
                        defaultVal: Settings.webSocketPing.toString(),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: false,
                          signed: false,
                        ),
                        validator: (string) {
                          int inputVal = int.tryParse(string);
                          if (inputVal == null ||
                              inputVal < 10 ||
                              inputVal > 5000) {
                            return 'Inserire un valore fra 10 e 5000';
                          }
                          return null;
                        },
                      ),
                    ],
                    title: 'Ping',
                    onlySaveOnSubmit: true,
                    submitText: 'Ok',
                    cancelText: 'Cancel',
                    onCancel: () {
                      String previousVal = Settings.webSocketPing.toString();
                      PrefService.setString('webSocketPing', previousVal);
                    },
                  ),
                ),
                PreferenceDialogLink(
                  'Pong timeout in millisecondi',
                  desc: Settings.webSocketPongTimeout.toString(),
                  onPop: () {
                    int inputVal = int.tryParse(
                        PrefService.getString('webSocketPongTimeout'));
                    if (inputVal != null &&
                        Settings.webSocketPongTimeout != inputVal) {
                      Settings.websocketChanged = true;
                      Settings.webSocketPongTimeout = inputVal;
                      _saveSettings();
                    }
                  },
                  barrierDismissible: false,
                  dialog: PreferenceDialog(
                    [
                      TextFieldPreference(
                        'Pong timeout in millisecondi',
                        'webSocketPongTimeout',
                        defaultVal: Settings.webSocketPongTimeout.toString(),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: false,
                          signed: false,
                        ),
                        validator: (string) {
                          int inputVal = int.tryParse(string);
                          if (inputVal == null ||
                              inputVal < 10 ||
                              inputVal > 5000) {
                            return 'Inserire un valore fra 10 e 5000';
                          }
                          return null;
                        },
                      ),
                    ],
                    title: 'Pong timeout',
                    onlySaveOnSubmit: true,
                    submitText: 'Ok',
                    cancelText: 'Cancel',
                    onCancel: () {
                      String previousVal =
                          Settings.webSocketPongTimeout.toString();
                      PrefService.setString(
                          'webSocketPongTimeout', previousVal);
                    },
                  ),
                ),
                PreferenceDialogLink(
                  'Numero di Timeout (poi si diconnette)',
                  desc: Settings.webSocketTimeoutsBeforeDisconnet.toString(),
                  onPop: () {
                    int inputVal = int.tryParse(PrefService.getString(
                        'webSocketTimeoutsBeforeDisconnet'));
                    if (inputVal != null &&
                        Settings.webSocketTimeoutsBeforeDisconnet != inputVal) {
                      Settings.websocketChanged = true;
                      Settings.webSocketTimeoutsBeforeDisconnet = inputVal;
                      _saveSettings();
                    }
                  },
                  barrierDismissible: false,
                  dialog: PreferenceDialog(
                    [
                      TextFieldPreference(
                        'Numero di Timeout (poi si diconnette)',
                        'webSocketTimeoutsBeforeDisconnet',
                        defaultVal: Settings.webSocketTimeoutsBeforeDisconnet
                            .toString(),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: false,
                          signed: false,
                        ),
                        validator: (string) {
                          int inputVal = int.tryParse(string);
                          if (inputVal == null ||
                              inputVal <= 0 ||
                              inputVal > 20) {
                            return 'Inserire un valore fra 0 (non si disconnette mai) e 20';
                          }
                          return null;
                        },
                      ),
                    ],
                    title: 'Numero timeout',
                    onlySaveOnSubmit: true,
                    submitText: 'Ok',
                    cancelText: 'Cancel',
                    onCancel: () {
                      String previousVal =
                          Settings.webSocketTimeoutsBeforeDisconnet.toString();
                      PrefService.setString(
                          'webSocketTimeoutsBeforeDisconnet', previousVal);
                    },
                  ),
                ),
                /*******************************************************************/
                PreferenceTitle('Arduino Earth Bluetooth'),
                PreferenceDialogLink(
                  'Bluetooth baud rate',
                  desc: Settings.btBaudRate.toString(),
                  onPop: () {
                    int inputVal =
                        int.tryParse(PrefService.getString('btBaudRate'));
                    if (inputVal != null && Settings.btBaudRate != inputVal) {
                      Settings.btConfigChanged = true;
                      Settings.btBaudRate = inputVal;
                      _saveSettings();
                    }
                  },
                  barrierDismissible: false,
                  dialog: PreferenceDialog(
                    [
                      RadioPreference(
                          '9600', 'AT+BAUD4', 'btBaudRate_selected'),
                      RadioPreference(
                          '57600', 'AT+BAUD7', 'btBaudRate_selected'),
                      RadioPreference(
                          '115200', 'AT+BAUD8', 'btBaudRate_selected'),
                      RadioPreference(
                          '230400', 'AT+BAUD9', 'btBaudRate_selected'),
                    ],
                    // [
                    //   TextFieldPreference(
                    //     'Baud rate',
                    //     'btBaudRate',
                    //     defaultVal: Settings.btBaudRate.toString(),
                    //     keyboardType: TextInputType.numberWithOptions(
                    //       decimal: false,
                    //       signed: false,
                    //     ),
                    //     validator: (string) {
                    //       int inputVal = int.tryParse(string);
                    //       if (inputVal == null ||
                    //           inputVal < 10 ||
                    //           inputVal > 5000) {
                    //         return 'Inserire un valore fra 10 e 5000';
                    //       }
                    //       return null;
                    //     },
                    //   ),
                    // ],
                    title: 'Baud rate',
                    onlySaveOnSubmit: true,
                    submitText: 'Ok',
                    cancelText: 'Cancel',
                    onCancel: () {
                      String previousVal = Settings.btBaudRate.toString();
                      PrefService.setString('btBaudRate', previousVal);
                    },
                  ),
                ),
                /*******************************************************************/
                PreferenceTitle('WiFi'),
                PreferenceDialogLink(
                  'WiFi SSID',
                  desc: Settings.wifiSSID,
                  onPop: () {
                    String inputVal = PrefService.getString('wifiSSID');
                    if (inputVal != null && Settings.wifiSSID != inputVal) {
                      Settings.wifiSSID = inputVal;
                      _saveSettings();
                    }
                  },
                  barrierDismissible: false,
                  dialog: PreferenceDialog(
                    [
                      TextFieldPreference(
                        'SSID',
                        'wifiSSID',
                        defaultVal: Settings.wifiSSID,
                        validator: (String string) {
                          if (string.isEmpty) {
                            return 'Qualcosa ce devi scrive...';
                          }
                          return null;
                        },
                      ),
                    ],
                    title: 'Ping',
                    onlySaveOnSubmit: true,
                    submitText: 'Ok',
                    cancelText: 'Cancel',
                    onCancel: () {
                      String previousVal = Settings.wifiSSID;
                      PrefService.setString('wifiSSID', previousVal);
                    },
                  ),
                ),
                PreferenceDialogLink(
                  'WiFi Password',
                  desc: Settings.wifiPassword.isEmpty
                      ? 'Non utilizzata'
                      : '********',
                  onPop: () {
                    String inputVal = PrefService.getString('wifiPassword');
                    if (inputVal != null && Settings.wifiPassword != inputVal) {
                      Settings.wifiPassword = inputVal;
                      _saveSettings();
                    }
                  },
                  barrierDismissible: false,
                  dialog: PreferenceDialog(
                    [
                      TextFieldPreference(
                        'Password',
                        'wifiPassword',
                        defaultVal: Settings.wifiPassword,
                      ),
                    ],
                    title: 'Password (se necessaria)',
                    onlySaveOnSubmit: true,
                    submitText: 'Ok',
                    cancelText: 'Cancel',
                    onCancel: () {
                      String previousVal = Settings.wifiPassword;
                      PrefService.setString('wifiPassword', previousVal);
                    },
                  ),
                ),
              ],
            );
          } else {
            return Text('Loading...');
          }
        },
      ),
    );
  }
}
