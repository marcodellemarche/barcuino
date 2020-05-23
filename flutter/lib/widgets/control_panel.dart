import 'package:flutter/material.dart';

import './control_panel_element.dart';

class ControlPanel extends StatefulWidget {
  final _ControlPanelState controlPanelState = _ControlPanelState();
  final ControlPanelElementStatus btStatus;
  final ControlPanelElementStatus wifiStatus;
  final ControlPanelElementStatus socketStatus;

  ControlPanel({this.btStatus, this.wifiStatus, this.socketStatus});

  void updateElement (String element, ControlPanelElementStatus elemStatus) {
    controlPanelState.updateElement(element, elemStatus);
  }

  @override
  _ControlPanelState createState() => controlPanelState;
}

class _ControlPanelState extends State<ControlPanel> {
  ControlPanelElement btElement;
  ControlPanelElement wifiElement;
  ControlPanelElement socketElement;

  updateElement(String element, ControlPanelElementStatus elemStatus) {
    switch (element) {
      case 'bluetooth':
        btElement = ControlPanelElement(
          text: 'Bluetooth',
          status: elemStatus,
        );
        break;
      case 'wifi':
        wifiElement = ControlPanelElement(
          text: 'WiFi',
          status: elemStatus,
        );
        break;
      case 'socket':
        socketElement = ControlPanelElement(
          text: 'Socket',
          status: elemStatus,
        );
        break;
      default:
    }
    setState(() { });
  }

  @override
  void initState() {
    updateElement('bluetooth', ControlPanelElementStatus.off);
    updateElement('wifi', ControlPanelElementStatus.off);
    updateElement('socket', ControlPanelElementStatus.off);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Container(
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  btElement,
                ],
              ),
              Row(
                children: <Widget>[
                  wifiElement,
                ],
              ),
              Row(
                children: <Widget>[
                  socketElement,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
