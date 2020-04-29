import 'package:flutter/material.dart';

class LogMessages extends StatelessWidget {
  final List<String> messagesList;

  LogMessages({@required this.messagesList});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Stack(
        children: <Widget>[
          SizedBox(
            height: 200.0,
            child: ListView.builder(
              scrollDirection: Axis.vertical,
              itemCount: messagesList.length,
              itemBuilder: (BuildContext ctxt, int index) {
                // use "messagesList.length - index + 1" instead of index
                // to reverse list and show last one on top of the list
                int reverserdIndex = messagesList.length - index - 1;
                return Text(
                  "$reverserdIndex: ${messagesList[reverserdIndex]}",
                  textAlign: TextAlign.center,
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Transform.scale(
              scale: 0.6,
              child: FloatingActionButton(
                child: Icon(
                  Icons.delete,
                  size: 28,
                ),
                backgroundColor: Colors.red,
                onPressed: () {
                  messagesList.clear();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
