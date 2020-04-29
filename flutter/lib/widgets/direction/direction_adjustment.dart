import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
// import 'package:flutter_xlider/flutter_xlider.dart';
import '../../packages/flutter_xlider.dart';

class DirectionAdjustment extends StatefulWidget {
  final Function onAdjustmentDone;
  final double startValue;
  final double height;

  DirectionAdjustment({this.startValue, this.onAdjustmentDone, this.height});

  @override
  _DirectionAdjustmentState createState() => _DirectionAdjustmentState();
}

class _DirectionAdjustmentState extends State<DirectionAdjustment> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      child: FlutterSlider(
        rangeSlider: false,
        min: 0,
        max: 100,
        axis: Axis.vertical,
        rtl: true,
        values: [widget.startValue * 100],
        selectByTap: false,
        handlerWidth: 20,
        handlerAnimation: FlutterSliderHandlerAnimation(
          scale: 1,
        ),
        tooltip: FlutterSliderTooltip(
          disableToolTipAnimation: true,
          boxStyle: FlutterSliderTooltipBox(
            decoration: BoxDecoration(
              color: Theme.of(context).accentColor,
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          textStyle: TextStyle(
            color: Colors.white,
          ),
          format: (String val) {
            double valueNormalized = num.parse(val);
            return valueNormalized.toStringAsFixed(0);
          },
          rightSuffix: Text(
            ' %',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
        trackBar: FlutterSliderTrackBar(
          inactiveTrackBarHeight: 2,
          activeTrackBarHeight: 2,
        ),
        handler: FlutterSliderHandler(
          child: Container(),
          decoration: BoxDecoration(
              color: Theme.of(context).accentColor, shape: BoxShape.circle),
        ),
        // onDragStarted: (_, __, ___) {
        //   // TODO add haptic feedback
        //   Feedback.forTap(context);
        // },
        onDragCompleted: (handlerIndex, newValue, _) {
          double valueNormalized =
              num.parse((newValue / 100).toStringAsFixed(2));
          widget.onAdjustmentDone(valueNormalized);
        },
      ),
    );
  }
}
