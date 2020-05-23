import 'package:barkino/widgets/led.dart';
import 'package:flutter/material.dart';

enum ControlPanelElementStatus { on, off, changing }

class ControlPanelElement extends StatelessWidget {
  final ControlPanelElementStatus status;
  final text;

  ControlPanelElement({this.status, this.text});

  @override
  Widget build(BuildContext context) {
    Color _ledColor = Colors.red;
    switch (status) {
      case ControlPanelElementStatus.off:
        _ledColor = Colors.red;
        break;
      case ControlPanelElementStatus.on:
        _ledColor = Colors.green;
        break;
      case ControlPanelElementStatus.changing:
        _ledColor = Colors.yellow;
        break;
      default:
    }

    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Container(
                alignment: Alignment.centerLeft,
                child: Text(
                  "$text",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Led(
                color: _ledColor,
                width: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
