import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/tide_data.dart';

class TideChart extends StatelessWidget {
  final List<HourlyLevel> hourlyLevels;
  final List<TideEvent> tideEvents;
  final SunTimes? sunTimes;
  final double height;

  const TideChart({
    super.key,
    required this.hourlyLevels,
    required this.tideEvents,
    this.sunTimes,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _TideChartPainter(
          hourlyLevels: hourlyLevels,
          tideEvents: tideEvents,
          sunTimes: sunTimes,
        ),
      ),
    );
  }
}

class _TideChartPainter extends CustomPainter {
  final List<HourlyLevel> hourlyLevels;
  final List<TideEvent> tideEvents;
  final SunTimes? sunTimes;

  _TideChartPainter({
    required this.hourlyLevels,
    required this.tideEvents,
    this.sunTimes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (hourlyLevels.isEmpty) return;

    final padding = const EdgeInsets.only(left: 40, right: 16, top: 16, bottom: 28);
    final chartRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      size.width - padding.left - padding.right,
      size.height - padding.top - padding.bottom,
    );

    // Calculate data bounds
    final heights = hourlyLevels.map((l) => l.heightMetres).toList();
    final minH = heights.reduce(math.min) - 0.5;
    final maxH = heights.reduce(math.max) + 0.5;

    // Draw sunrise/sunset background
    if (sunTimes != null) {
      _drawSunBackground(canvas, chartRect, sunTimes!);
    }

    // Draw grid
    _drawGrid(canvas, chartRect, minH, maxH);

    // Draw tide curve with gradient fill
    _drawTideCurve(canvas, chartRect, minH, maxH);

    // Draw high/low markers
    _drawExtremeMarkers(canvas, chartRect, minH, maxH);

    // Draw time axis
    _drawTimeAxis(canvas, chartRect);

    // Draw current time indicator
    _drawCurrentTime(canvas, chartRect);
  }

  void _drawSunBackground(Canvas canvas, Rect rect, SunTimes sun) {
    final sunriseParts = sun.sunrise.split(':');
    final sunsetParts = sun.sunset.split(':');
    final sunriseHour = int.parse(sunriseParts[0]) + int.parse(sunriseParts[1]) / 60;
    final sunsetHour = int.parse(sunsetParts[0]) + int.parse(sunsetParts[1]) / 60;

    final sunriseX = rect.left + (sunriseHour / 24) * rect.width;
    final sunsetX = rect.left + (sunsetHour / 24) * rect.width;

    // Night background
    final nightPaint = Paint()..color = const Color(0xFF0a1628);
    canvas.drawRect(rect, nightPaint);

    // Daylight gradient
    final dayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF1a2a4a),
          const Color(0xFF0f1d35),
        ],
      ).createShader(Rect.fromLTRB(sunriseX, rect.top, sunsetX, rect.bottom));
    canvas.drawRect(
      Rect.fromLTRB(sunriseX, rect.top, sunsetX, rect.bottom),
      dayPaint,
    );

    // Dawn/dusk gradients
    final dawnPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0x00FF8F00), const Color(0x33FF8F00), const Color(0x00FF8F00)],
      ).createShader(Rect.fromLTRB(sunriseX - 20, rect.top, sunriseX + 20, rect.bottom));
    canvas.drawRect(
      Rect.fromLTRB(sunriseX - 20, rect.top, sunriseX + 20, rect.bottom),
      dawnPaint,
    );

    final duskPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0x00FF6D00), const Color(0x33FF6D00), const Color(0x00FF6D00)],
      ).createShader(Rect.fromLTRB(sunsetX - 20, rect.top, sunsetX + 20, rect.bottom));
    canvas.drawRect(
      Rect.fromLTRB(sunsetX - 20, rect.top, sunsetX + 20, rect.bottom),
      duskPaint,
    );
  }

  void _drawGrid(Canvas canvas, Rect rect, double minH, double maxH) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.4),
      fontSize: 10,
    );

    // Horizontal grid lines (height)
    final step = ((maxH - minH) / 4).ceilToDouble();
    for (var h = (minH / step).ceil() * step; h <= maxH; h += step) {
      final y = rect.bottom - ((h - minH) / (maxH - minH)) * rect.height;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);

      final tp = TextPainter(
        text: TextSpan(text: '${h.toStringAsFixed(0)}m', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.left - tp.width - 6, y - tp.height / 2));
    }

    // Vertical grid lines (time)
    for (var hour = 0; hour <= 24; hour += 6) {
      final x = rect.left + (hour / 24) * rect.width;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), gridPaint);
    }
  }

  void _drawTideCurve(Canvas canvas, Rect rect, double minH, double maxH) {
    if (hourlyLevels.length < 2) return;

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < hourlyLevels.length; i++) {
      final level = hourlyLevels[i];
      final hour = level.dateTimeUtc.hour + level.dateTimeUtc.minute / 60.0;
      final x = rect.left + (hour / 24) * rect.width;
      final y = rect.bottom - ((level.heightMetres - minH) / (maxH - minH)) * rect.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, rect.bottom);
        fillPath.lineTo(x, y);
      } else {
        // Smooth curve using cubic bezier
        final prevLevel = hourlyLevels[i - 1];
        final prevHour = prevLevel.dateTimeUtc.hour + prevLevel.dateTimeUtc.minute / 60.0;
        final prevX = rect.left + (prevHour / 24) * rect.width;
        final prevY = rect.bottom -
            ((prevLevel.heightMetres - minH) / (maxH - minH)) * rect.height;

        final midX = (prevX + x) / 2;
        path.cubicTo(midX, prevY, midX, y, x, y);
        fillPath.cubicTo(midX, prevY, midX, y, x, y);
      }
    }

    // Close fill path
    final lastHour = hourlyLevels.last.dateTimeUtc.hour +
        hourlyLevels.last.dateTimeUtc.minute / 60.0;
    fillPath.lineTo(rect.left + (lastHour / 24) * rect.width, rect.bottom);
    fillPath.close();

    // Gradient fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF42A5F5).withValues(alpha: 0.4),
          const Color(0xFF1565C0).withValues(alpha: 0.05),
        ],
      ).createShader(rect);
    canvas.drawPath(fillPath, fillPaint);

    // Stroke
    final strokePaint = Paint()
      ..color = const Color(0xFF42A5F5)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);
  }

  void _drawExtremeMarkers(Canvas canvas, Rect rect, double minH, double maxH) {
    for (final event in tideEvents) {
      final hour = event.dateTimeUtc.hour + event.dateTimeUtc.minute / 60.0;
      final x = rect.left + (hour / 24) * rect.width;
      final y = rect.bottom -
          ((event.heightMetres - minH) / (maxH - minH)) * rect.height;

      // Dot
      final dotColor = event.isHigh
          ? const Color(0xFF66BB6A)
          : const Color(0xFFEF5350);
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = dotColor);
      canvas.drawCircle(
        Offset(x, y),
        5,
        Paint()
          ..color = dotColor.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // Label
      final timeStr =
          '${event.dateTimeUtc.hour.toString().padLeft(2, '0')}:${event.dateTimeUtc.minute.toString().padLeft(2, '0')}';
      final label = '${event.heightMetres.toStringAsFixed(1)}m';
      final labelOffset = event.isHigh ? -22.0 : 10.0;

      final tp = TextPainter(
        text: TextSpan(
          text: '$label\n$timeStr',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 9,
            height: 1.3,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y + labelOffset));
    }
  }

  void _drawTimeAxis(Canvas canvas, Rect rect) {
    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.4),
      fontSize: 10,
    );

    for (var hour = 0; hour <= 24; hour += 6) {
      final x = rect.left + (hour / 24) * rect.width;
      final label = hour == 24 ? '00:00' : '${hour.toString().padLeft(2, '0')}:00';
      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, rect.bottom + 8));
    }
  }

  void _drawCurrentTime(Canvas canvas, Rect rect) {
    final now = DateTime.now();
    final hour = now.hour + now.minute / 60.0;
    final x = rect.left + (hour / 24) * rect.width;

    if (x >= rect.left && x <= rect.right) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);

      // Small triangle at top
      final trianglePath = Path()
        ..moveTo(x - 4, rect.top)
        ..lineTo(x + 4, rect.top)
        ..lineTo(x, rect.top + 6)
        ..close();
      canvas.drawPath(trianglePath, Paint()..color = Colors.white.withValues(alpha: 0.5));
    }
  }

  @override
  bool shouldRepaint(covariant _TideChartPainter oldDelegate) {
    return oldDelegate.hourlyLevels != hourlyLevels ||
        oldDelegate.tideEvents != tideEvents;
  }
}
