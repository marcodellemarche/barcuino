import 'package:barkino/models/settings.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final Function onSettingChanged;

  SettingsScreen({this.onSettingChanged});

  void _toggleArduinoTimeout(bool newValue) {
    Settings settings = Settings();
    settings.setByKey('arduinoTimeoutEnabled', newValue).then((result) {
      if (result) onSettingChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('Abilita timeout Arduino'),
            Checkbox(
              value: true,
              onChanged: _toggleArduinoTimeout,
            ),
          ],
        ),
        Row(
          children: <Widget>[
            Text('Arduino timeout'),
            TextField(),
          ],
        ),
      ],
    );
  }
}
