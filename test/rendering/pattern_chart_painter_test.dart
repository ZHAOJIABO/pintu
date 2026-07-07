import 'package:bobobeads/models/pattern_chart.dart';
import 'package:bobobeads/rendering/pattern_chart_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('border coordinates keep at least a 30 by 30 chart area', () {
    final chart = PatternChartData(
      width: 3,
      height: 2,
      cells: List<PatternChartCell?>.filled(6, null),
    );

    final size = PatternChartPainter.chartSize(
      chart: chart,
      cellSize: 10,
      showCoordinates: false,
      showBorderCoordinates: true,
    );

    expect(size, const Size(320, 320));
  });
}
