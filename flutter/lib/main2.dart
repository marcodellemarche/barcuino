import 'dart:math';
import 'package:flutter/material.dart';
import './widgets/led.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<Decoration> decoration;
  Animation<Decoration> greenDecoration;
  Animation<Decoration> yellowDecoration;
  Animation<Decoration> whiteDecoration;
  Animation<Decoration> blueDecoration;

  void _doNothing() {}

  @override
  initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);

    decoration = DecorationTween(
      begin: BoxDecoration(
        gradient: new RadialGradient(colors: [
          new Color.fromRGBO(170, 0, 0, 1),
          new Color.fromRGBO(114, 12, 17, 1)
        ], //new Color.fromRGBO(168, 0, 0, 1)],
            stops: [
              0.3,
              1
            ], center: const Alignment(0.0, -0.05)),
        boxShadow: [
          new BoxShadow(
              color: new Color.fromRGBO(0, 0, 0, 0.2),
              offset: new Offset(0.0, -1.0),
              blurRadius: 7.0,
              spreadRadius: 1.0),
          new BoxShadow(
              color: new Color.fromRGBO(255, 0, 0, 0.5),
              offset: new Offset(0.0, 0.0),
              blurRadius: 0.0,
              spreadRadius: 0.0),
        ],
        shape: BoxShape.circle,
      ),
      end: BoxDecoration(
        gradient: new RadialGradient(colors: [
          new Color.fromRGBO(255, 0, 0, 1),
          new Color.fromRGBO(168, 0, 0, 1)
        ], stops: [
          0.3,
          1
        ], center: const Alignment(0.05, -0.05)),
        boxShadow: [
          new BoxShadow(
              color: new Color.fromRGBO(0, 0, 0, 0.2),
              offset: new Offset(0.0, -1.0),
              blurRadius: 7.0,
              spreadRadius: 1.0),
          new BoxShadow(
              color: new Color.fromRGBO(255, 0, 0, 0.5),
              offset: new Offset(0.0, 2.0),
              blurRadius: 12.0,
              spreadRadius: 0.0),
        ],
        shape: BoxShape.circle,
      ),
    ).animate(_controller);

    greenDecoration = DecorationTween(
      begin: BoxDecoration(
        gradient: new RadialGradient(colors: [
          new Color.fromRGBO(121, 205, 0, 1),
          new Color.fromRGBO(48, 121, 1, 1)
        ], stops: [
          0.3,
          1
        ], center: const Alignment(0.0, -0.05)),
        boxShadow: [
          new BoxShadow(
              color: new Color.fromRGBO(0, 0, 0, 0.2),
              offset: new Offset(0.0, -1.0),
              blurRadius: 7.0,
              spreadRadius: 1.0),
          new BoxShadow(
              color: new Color.fromRGBO(137, 255, 0, 0.5),
              offset: new Offset(0.0, 2.0),
              blurRadius: 12.0,
              spreadRadius: 0.0)
        ],
        shape: BoxShape.circle,
      ),
      end: BoxDecoration(
        gradient: new RadialGradient(colors: [
          new Color.fromRGBO(171, 255, 0, 1),
          new Color.fromRGBO(98, 171, 51, 1)
        ], stops: [
          0.3,
          1
        ], center: const Alignment(0.05, -0.05)),
        boxShadow: [
          new BoxShadow(
              color: new Color.fromRGBO(0, 0, 0, 0.2),
              offset: new Offset(0.0, -1.0),
              blurRadius: 7.0,
              spreadRadius: 1.0),
          new BoxShadow(
              color: new Color.fromRGBO(137, 255, 0, 0.5),
              offset: new Offset(0.0, 2.0),
              blurRadius: 12.0,
              spreadRadius: 0.0)
        ],
        shape: BoxShape.circle,
      ),
    ).animate(_controller);

    yellowDecoration = buildDecorationTween(255, 255, 0).animate(_controller);
    whiteDecoration = buildDecorationTween(255, 255, 255).animate(_controller);

    blueDecoration = DecorationTween(
      begin: new BoxDecoration(
        gradient: new RadialGradient(colors: [
          new Color.fromRGBO(36, 174, 205, 1),
          new Color.fromRGBO(27, 116, 177, 1)
        ], stops: [
          0.3,
          1
        ], center: const Alignment(0.05, -0.05)),
        boxShadow: [
          new BoxShadow(
              color: new Color.fromRGBO(0, 0, 0, 0.2),
              offset: new Offset(0.0, -1.0),
              blurRadius: 7.0,
              spreadRadius: 1.0),
          new BoxShadow(
              color: new Color.fromRGBO(63, 140, 255, 0.5),
              offset: new Offset(0.0, 2.0),
              blurRadius: 12.0,
              spreadRadius: 0.0)
        ],
        shape: BoxShape.circle,
      ),
      end: new BoxDecoration(
        gradient: new RadialGradient(colors: [
          new Color.fromRGBO(36, 224, 255, 1),
          new Color.fromRGBO(37, 136, 197, 1)
        ], stops: [
          0.3,
          1
        ], center: const Alignment(0.05, -0.05)),
        boxShadow: [
          new BoxShadow(
              color: new Color.fromRGBO(0, 0, 0, 0.2),
              offset: new Offset(0.0, -1.0),
              blurRadius: 7.0,
              spreadRadius: 1.0),
          new BoxShadow(
              color: new Color.fromRGBO(63, 140, 255, 0.5),
              offset: new Offset(0.0, 2.0),
              blurRadius: 12.0,
              spreadRadius: 0.0)
        ],
        shape: BoxShape.circle,
      ),
    ).animate(_controller);

    _controller.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Column(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        children: <Widget>[
          ListTile(
            leading: new Led(color: new Color.fromRGBO(255, 20, 20, 1)),
            title: Text('static red'),
          ),
          ListTile(
            leading: new Led(color: new Color.fromRGBO(20, 20, 255, 1)),
            title: Text('static blue'),
          ),
          ListTile(
            leading: new Led(color: new Color.fromRGBO(20, 255, 20, 1)),
            title: Text('static green'),
          ),
          ListTile(
            leading: new Led(color: new Color.fromRGBO(255, 255, 20, 1)),
            title: Text('static yellow'),
          ),
          ListTile(
            leading: new AnimatedLed(animation: decoration),
            title: Text('animated red'),
          ),
          ListTile(
            leading: new AnimatedLed(animation: greenDecoration),
            title: Text('animated green'),
          ),
          ListTile(
            leading: new AnimatedLed(animation: yellowDecoration),
            title: Text('animated yellow'),
          ),
          ListTile(
            leading: new AnimatedLed(animation: whiteDecoration),
            title: Text('animated white'),
          ),
          ListTile(
            leading: new AnimatedLed(animation: blueDecoration),
            title: Text('animated blue'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _doNothing,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

DecorationTween buildDecorationTween(red, green, blue) {
  int lightRed = max(red - 50, 0);
  int lightGreen = max(green - 50, 0);
  int lightBlue = max(blue - 50, 0);
  int darkRed = max(red - 70, 0);
  int darkGreen = max(green - 70, 0);
  int darkBlue = max(blue - 70, 0);
  int darkerRed = max(red - 90, 0);
  int darkerGreen = max(green - 90, 0);
  int darkerBlue = max(blue - 90, 0);

  return DecorationTween(
    begin: BoxDecoration(
      gradient: new RadialGradient(colors: [
        new Color.fromRGBO(lightRed, lightGreen, lightBlue, 1),
        new Color.fromRGBO(darkRed, darkGreen, darkBlue, 1)
      ], stops: [
        0.3,
        1
      ], center: const Alignment(0.0, -0.05)),
      boxShadow: [
        new BoxShadow(
            color: new Color.fromRGBO(0, 0, 0, 0.2),
            offset: new Offset(0.0, -1.0),
            blurRadius: 7.0,
            spreadRadius: 1.0),
        new BoxShadow(
            color: new Color.fromRGBO(red, green, blue, 0.5),
            offset: new Offset(0.0, 0.0),
            blurRadius: 0.0,
            spreadRadius: 0.0),
      ],
      shape: BoxShape.circle,
    ),
    end: BoxDecoration(
      gradient: new RadialGradient(colors: [
        new Color.fromRGBO(red, green, blue, 1),
        new Color.fromRGBO(darkerRed, darkerGreen, darkerBlue, 1)
      ], stops: [
        0.3,
        1
      ], center: const Alignment(0.05, -0.05)),
      boxShadow: [
        new BoxShadow(
            color: new Color.fromRGBO(0, 0, 0, 0.2),
            offset: new Offset(0.0, -1.0),
            blurRadius: 7.0,
            spreadRadius: 1.0),
        new BoxShadow(
            color: new Color.fromRGBO(red, green, blue, 0.5),
            offset: new Offset(0.0, 2.0),
            blurRadius: 12.0,
            spreadRadius: 0.0),
      ],
      shape: BoxShape.circle,
    ),
  );
}