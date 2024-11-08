import 'package:flutter/material.dart';

extension PaintExtension on Paint {
  /// Hides the paint's color, if strokeWidth is zero
  void transparentIfWidthIsZero() {
    if (strokeWidth == 0) {
      shader = null;
      color = color.withOpacity(0);
    }
  }

  void setColorOrGradient(Color? color, Gradient? gradient, Rect rect) {
    this.color = Colors.black;
    return;

    if (gradient != null) {
      this.color = Colors.black;
      shader = gradient.createShader(rect);
    } else {
      this.color = color ?? Colors.transparent;
      shader = null;
    }
  }
/*
  void setGradientWithValues(Map<int, Color> colors, Rect rect) {

var gradient = LinearGradient(colors: )

    if (gradient != null) {
      this.color = Colors.black;
      shader = gradient.createShader(rect);
    } 
  }*/
}
