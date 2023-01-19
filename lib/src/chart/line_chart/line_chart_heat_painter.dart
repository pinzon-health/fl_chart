import 'package:fl_chart/src/chart/base/base_chart/base_chart_painter.dart';
import 'package:fl_chart/src/chart/line_chart/line_chart_data.dart';
import 'package:fl_chart/src/chart/line_chart/line_chart_painter.dart';
import 'package:fl_chart/src/utils/canvas_wrapper.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart/src/utils/models/heat_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LineChartHeatPainter extends LineChartPainter {
  List<HeatModel> colors;

  LineChartHeatPainter({
    required this.colors,
  }) : super();

  @override
  void drawBarLine(
    CanvasWrapper canvasWrapper,
    LineChartBarData barData,
    PaintHolder<LineChartData> holder,
  ) {
    final viewSize = canvasWrapper.size;
    final barList = splitByNullSpots(barData.spots);

    for (final bar in barList) {
      generateGraph(viewSize, barData, bar, canvasWrapper, barPaint, holder);
    }
  }

  /// Paints [LineChartData] into the provided canvas.
  @override
  void paint(
    BuildContext context,
    CanvasWrapper canvasWrapper,
    PaintHolder<LineChartData> holder,
  ) {
    final data = holder.data;
    if (data.lineBarsData.isEmpty) {
      return;
    }

    if (data.clipData.any) {
      canvasWrapper.saveLayer(
        Rect.fromLTWH(
          0,
          -40,
          canvasWrapper.size.width + 40,
          canvasWrapper.size.height + 40,
        ),
        Paint(),
      );

      clipToBorder(canvasWrapper, holder);
    }

    super.paint(context, canvasWrapper, holder);

    for (final betweenBarsData in data.betweenBarsData) {
      drawBetweenBarsArea(canvasWrapper, data, betweenBarsData, holder);
    }

    if (!data.extraLinesData.extraLinesOnTop) {
      drawExtraLines(context, canvasWrapper, holder);
    }

    final lineIndexDrawingInfo = <LineIndexDrawingInfo>[];

    /// draw each line independently on the chart
    for (var i = 0; i < data.lineBarsData.length; i++) {
      final barData = data.lineBarsData[i];

      if (!barData.show) {
        continue;
      }

      if (barData.painter != null) {
        barData.painter!.drawBarLine(canvasWrapper, barData, holder);
      } else {
        drawBarLine(canvasWrapper, barData, holder);
      }

      drawDots(canvasWrapper, barData, holder);

      if (data.extraLinesData.extraLinesOnTop) {
        drawExtraLines(context, canvasWrapper, holder);
      }

      final indicatorsData = data.lineTouchData
          .getTouchedSpotIndicator(barData, barData.showingIndicators);

      if (indicatorsData.length != barData.showingIndicators.length) {
        throw Exception(
          'indicatorsData and touchedSpotOffsets size should be same',
        );
      }

      for (var j = 0; j < barData.showingIndicators.length; j++) {
        final indicatorData = indicatorsData[j];
        final index = barData.showingIndicators[j];
        if (index < 0 || index >= barData.spots.length) {
          continue;
        }
        final spot = barData.spots[index];

        if (indicatorData == null) {
          continue;
        }
        lineIndexDrawingInfo.add(
          LineIndexDrawingInfo(barData, i, spot, index, indicatorData),
        );
      }
    }

    drawTouchedSpotsIndicator(canvasWrapper, lineIndexDrawingInfo, holder);

    if (data.clipData.any) {
      canvasWrapper.restore();
    }

    // Draw touch tooltip on most top spot
    for (var i = 0; i < data.showingTooltipIndicators.length; i++) {
      var tooltipSpots = data.showingTooltipIndicators[i];

      final showingBarSpots = tooltipSpots.showingSpots;
      if (showingBarSpots.isEmpty) {
        continue;
      }
      final barSpots = List<LineBarSpot>.of(showingBarSpots);
      FlSpot topSpot = barSpots[0];
      for (final barSpot in barSpots) {
        if (barSpot.y > topSpot.y) {
          topSpot = barSpot;
        }
      }
      tooltipSpots = ShowingTooltipIndicators(barSpots);

      drawTouchTooltip(
        context,
        canvasWrapper,
        data.lineTouchData.touchTooltipData,
        topSpot,
        tooltipSpots,
        holder,
      );
    }
  }

  @visibleForTesting
  @override
  void generateGraph(
    Size viewSize,
    LineChartBarData barData,
    List<FlSpot> barSpots,
    CanvasWrapper canvas,
    Paint painter,
    PaintHolder<LineChartData> holder, {
    Path? appendToPath,
  }) {
    final path = appendToPath ?? Path();
    final size = barSpots.length;

    var temp = Offset.zero;

    colors.sort((a, b) => b.max.compareTo(a.max));

    for (var i = 0; i < size; i++) {
      var tempPath = Path();

      /// CurrentSpot
      final current = Offset(
        getPixelX(barSpots[i].x, viewSize, holder),
        getPixelY(barSpots[i].y, viewSize, holder),
      );

      /// next point
      final next = Offset(
        getPixelX(barSpots[i + 1 < size ? i + 1 : i].x, viewSize, holder),
        getPixelY(barSpots[i + 1 < size ? i + 1 : i].y, viewSize, holder),
      );

      painter.strokeWidth = 3;

      List<Color> gradientColors = [];

      bool falls = barSpots[i].y > barSpots[i + 1 < size ? i + 1 : i].y;

      var firstColor = colors
          .where((element) =>
              element.min <= barSpots[i].y && element.max >= barSpots[i].y)
          .first;

      gradientColors.add(firstColor.color);

      if (falls) {
        var otherColors = colors
            .where((element) =>
                element.max < firstColor.min &&
                element.max >= barSpots[i + 1 < size ? i + 1 : i].y)
            .toList()
            .map((e) => e.color);

        gradientColors.addAll(otherColors);
      } else {
        var otherColors = colors
            .where((element) =>
                element.min > firstColor.max &&
                element.min <= barSpots[i + 1 < size ? i + 1 : i].y)
            .toList()
            .reversed
            .map((e) => e.color);

        gradientColors.addAll(otherColors);
      }

      if (gradientColors.length == 0) {
        throw 'Y is out of range, cannot select any color (' +
            barSpots[i].y.toString() +
            ')';
      } else if (gradientColors.length == 1) {
        gradientColors.add(gradientColors[0]);
      }

      var gradient = LinearGradient(
          colors: gradientColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter);

      final rect = Rect.fromLTRB(
        current.dx,
        current.dy,
        next.dx,
        next.dy,
      );

      painter.shader = gradient.createShader(rect);

      canvas.drawLine(current, next, painter);
    }
  }

  List<List<FlSpot>> splitByNullSpots(List<FlSpot> spots) {
    final barList = <List<FlSpot>>[[]];

    // handle nullability by splitting off the list into multiple
    // separate lists when separated by nulls
    for (final spot in spots) {
      if (spot.isNotNull()) {
        barList.last.add(spot);
      } else if (barList.last.isNotEmpty) {
        barList.add([]);
      }
    }
    // remove last item if one or more last spots were null
    if (barList.last.isEmpty) {
      barList.removeLast();
    }
    return barList;
  }
}
