import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
//import '../../packages/flutter_xlider.dart';

class DirectionAdjustment extends StatefulWidget {
  final Function onAdjustmentDone;
  final FlutterSliderTooltipDirection toolTipDirection;
  final double startValue;
  final double height;
  final bool disabled;

  DirectionAdjustment({this.startValue, this.onAdjustmentDone, this.height, this.toolTipDirection, this.disabled});

  @override
  _DirectionAdjustmentState createState() => _DirectionAdjustmentState();
}

class _DirectionAdjustmentState extends State<DirectionAdjustment> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      alignment: AlignmentDirectional.center,
      child: FlutterSlider(
        disabled: widget.disabled,
        rangeSlider: false,
        min: 0,
        max: 100,
        axis: Axis.vertical,
        rtl: true,
        values: [widget.startValue * 100],
        handlerWidth: 20,
        tooltip: FlutterSliderTooltip(
          direction: widget.toolTipDirection,
          disableAnimation: true,
          custom: (value) {
            return FractionallySizedBox(
              alignment: AlignmentDirectional.center,
              widthFactor: 1.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).accentColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    '${value.toStringAsFixed(0)} %',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
          // boxStyle: FlutterSliderTooltipBox(
          //   decoration: BoxDecoration(
          //     color: Theme.of(context).accentColor,
          //     borderRadius: BorderRadius.circular(15),
          //   ),
          // ),
          // textStyle: TextStyle(
          //   color: Colors.white,
          // ),
          // format: (String val) {
          //   double valueNormalized = num.parse(val);
          //   return valueNormalized.toStringAsFixed(0);
          // },
          // rightSuffix: Text(
          //   ' %',
          //   style: TextStyle(
          //     color: Colors.white,
          //   ),
          // ),
        ),
        trackBar: FlutterSliderTrackBar(
          inactiveTrackBarHeight: 2,
          activeTrackBarHeight: 2,
        ),
        handler: FlutterSliderHandler(
          disabled: true,
          child: Container(),
          decoration: BoxDecoration(
              color: Theme.of(context).accentColor, shape: BoxShape.circle),
        ),
        onDragCompleted: (handlerIndex, newValue, _) {
          double valueNormalized =
              num.parse((newValue / 100).toStringAsFixed(2));
          widget.onAdjustmentDone(valueNormalized);
        },
      ),
    );
  }
}
