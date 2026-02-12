import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/tide_data.dart';

class TideChart extends StatefulWidget {
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
  State<TideChart> createState() => _TideChartState();
}

class _TideChartState extends State<TideChart>
    with SingleTickerProviderStateMixin {
  double? _touchX;
  late AnimationController _animController;
  late Animation<double> _drawAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _drawAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(TideChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hourlyLevels != widget.hourlyLevels) {
      _animController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: GestureDetector(
        onPanStart: (d) => setState(() => _touchX = d.localPosition.dx),
        onPanUpdate: (d) => setState(() => _touchX = d.localPosition.dx),
        onPanEnd: (_) => setState(() => _touchX = null),
        onTapDown: (d) => setState(() => _touchX = d.localPosition.dx),
        onTapUp: (_) =>
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => _touchX = null);
            }),
        child: AnimatedBuilder(
          animation: _drawAnimation,
          builder: (context, _) {
            return CustomPaint(
              size: Size.infinite,
              painter: _TideChartPainter(
                hourlyLevels: widget.hourlyLevels,
                tideEvents: widget.tideEvents,
                sunTimes: widget.sunTimes,
                touchX: _touchX,
                drawProgress: _drawAnimation.value,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TideChartPainter extends CustomPainter {
  final List<HourlyLevel> hourlyLevels;
  final List<TideEvent> tideEvents;
  final SunTimes? sunTimes;
  final double? touchX;
  final double drawProgress;

  _TideChartPainter({
    required this.hourlyLevels,
    required this.tideEvents,
    this.sunTimes,
    this.touchX,
    this.drawProgress = 1.0,
  });

  /// Get the UTC hour offset from midnight UTC of the first data point's date.
  /// This ensures monotonic x-positions even across DST boundaries.
  double _utcHour(DateTime utcTime) {
    return utcTime.hour + utcTime.minute / 60.0;
  }

  /// For tide events, calculate UTC hour relative to the hourly data's
  /// start date to handle events that span midnight correctly.
  double _eventUtcHour(TideEvent event) {
    if (hourlyLevels.isEmpty) return _utcHour(event.dateTimeUtc);
    final baseDate = DateTime.utc(
      hourlyLevels.first.dateTimeUtc.year,
      hourlyLevels.first.dateTimeUtc.month,
      hourlyLevels.first.dateTimeUtc.day,
    );
    return event.dateTimeUtc.difference(baseDate).inMinutes / 60.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (hourlyLevels.isEmpty) return;

    final padding =
        const EdgeInsets.only(left: 40, right: 16, top: 16, bottom: 28);
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
    if (drawProgress > 0.5) {
      final markerAlpha = ((drawProgress - 0.5) * 2).clamp(0.0, 1.0);
      _drawExtremeMarkers(canvas, chartRect, minH, maxH, markerAlpha);
    }

    // Draw time axis
    _drawTimeAxis(canvas, chartRect);

    // Draw current time indicator
    _drawCurrentTime(canvas, chartRect);

    // Draw touch tooltip
    if (touchX != null) {
      _drawTooltip(canvas, size, chartRect, minH, maxH);
    }
  }

  void _drawSunBackground(Canvas canvas, Rect rect, SunTimes sun) {
    final sunriseParts = sun.sunrise.split(':');
    final sunsetParts = sun.sunset.split(':');
    final sunriseHour =
        int.parse(sunriseParts[0]) + int.parse(sunriseParts[1]) / 60;
    final sunsetHour =
        int.parse(sunsetParts[0]) + int.parse(sunsetParts[1]) / 60;

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
      ).createShader(
          Rect.fromLTRB(sunriseX, rect.top, sunsetX, rect.bottom));
    canvas.drawRect(
      Rect.fromLTRB(sunriseX, rect.top, sunsetX, rect.bottom),
      dayPaint,
    );

    // Dawn/dusk gradients
    final dawnPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0x00FF8F00),
          const Color(0x33FF8F00),
          const Color(0x00FF8F00)
        ],
      ).createShader(Rect.fromLTRB(
          sunriseX - 20, rect.top, sunriseX + 20, rect.bottom));
    canvas.drawRect(
      Rect.fromLTRB(sunriseX - 20, rect.top, sunriseX + 20, rect.bottom),
      dawnPaint,
    );

    final duskPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0x00FF6D00),
          const Color(0x33FF6D00),
          const Color(0x00FF6D00)
        ],
      ).createShader(Rect.fromLTRB(
          sunsetX - 20, rect.top, sunsetX + 20, rect.bottom));
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
      final y =
          rect.bottom - ((h - minH) / (maxH - minH)) * rect.height;
      canvas.drawLine(
          Offset(rect.left, y), Offset(rect.right, y), gridPaint);

      final tp = TextPainter(
        text: TextSpan(
            text: '${h.toStringAsFixed(0)}m', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.left - tp.width - 6, y - tp.height / 2));
    }

    // Vertical grid lines (time)
    for (var hour = 0; hour <= 24; hour += 6) {
      final x = rect.left + (hour / 24) * rect.width;
      canvas.drawLine(
          Offset(x, rect.top), Offset(x, rect.bottom), gridPaint);
    }
  }

  void _drawTideCurve(
      Canvas canvas, Rect rect, double minH, double maxH) {
    if (hourlyLevels.length < 2) return;

    final path = Path();
    final fillPath = Path();

    // How far along the curve to draw (for animation)
    final maxIndex =
        ((hourlyLevels.length - 1) * drawProgress).round();

    for (var i = 0; i <= maxIndex && i < hourlyLevels.length; i++) {
      // Use index-based positioning: 25 points map to hours 0-24
      final hour = i * 24.0 / (hourlyLevels.length - 1);
      final x = rect.left + (hour / 24) * rect.width;
      final y = rect.bottom -
          ((hourlyLevels[i].heightMetres - minH) / (maxH - minH)) *
              rect.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, rect.bottom);
        fillPath.lineTo(x, y);
      } else {
        final prevHour = (i - 1) * 24.0 / (hourlyLevels.length - 1);
        final prevX = rect.left + (prevHour / 24) * rect.width;
        final prevY = rect.bottom -
            ((hourlyLevels[i - 1].heightMetres - minH) / (maxH - minH)) *
                rect.height;

        final midX = (prevX + x) / 2;
        path.cubicTo(midX, prevY, midX, y, x, y);
        fillPath.cubicTo(midX, prevY, midX, y, x, y);
      }
    }

    // Close fill path at current draw position
    if (maxIndex < hourlyLevels.length) {
      final lastHour = maxIndex * 24.0 / (hourlyLevels.length - 1);
      fillPath.lineTo(
          rect.left + (lastHour / 24) * rect.width, rect.bottom);
    }
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

  void _drawExtremeMarkers(Canvas canvas, Rect rect, double minH,
      double maxH, double alpha) {
    for (final event in tideEvents) {
      // Use UTC hour for positioning to avoid DST wrapping
      final hour = _eventUtcHour(event);
      if (hour < 0 || hour > 24) continue; // skip out-of-range events
      final x = rect.left + (hour / 24) * rect.width;
      final y = rect.bottom -
          ((event.heightMetres - minH) / (maxH - minH)) * rect.height;

      // Dot
      final dotColor = event.isHigh
          ? const Color(0xFF66BB6A)
          : const Color(0xFFEF5350);

      // Glow effect
      canvas.drawCircle(
        Offset(x, y),
        10,
        Paint()
          ..color = dotColor.withValues(alpha: 0.15 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      canvas.drawCircle(
          Offset(x, y), 5, Paint()..color = dotColor.withValues(alpha: alpha));
      canvas.drawCircle(
        Offset(x, y),
        5,
        Paint()
          ..color = dotColor.withValues(alpha: 0.3 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // Label - show LOCAL time for display
      final timeStr =
          '${event.dateTimeLocal.hour.toString().padLeft(2, '0')}:${event.dateTimeLocal.minute.toString().padLeft(2, '0')}';
      final label = '${event.heightMetres.toStringAsFixed(1)}m';
      final labelOffset = event.isHigh ? -22.0 : 10.0;

      final tp = TextPainter(
        text: TextSpan(
          text: '$label\n$timeStr',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9 * alpha),
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
      final label = hour == 24
          ? '00:00'
          : '${hour.toString().padLeft(2, '0')}:00';
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
      canvas.drawLine(
          Offset(x, rect.top), Offset(x, rect.bottom), paint);

      // Small triangle at top
      final trianglePath = Path()
        ..moveTo(x - 4, rect.top)
        ..lineTo(x + 4, rect.top)
        ..lineTo(x, rect.top + 6)
        ..close();
      canvas.drawPath(trianglePath,
          Paint()..color = Colors.white.withValues(alpha: 0.5));
    }
  }

  void _drawTooltip(
      Canvas canvas, Size size, Rect rect, double minH, double maxH) {
    if (touchX == null || hourlyLevels.length < 2) return;

    // Clamp touch to chart area
    final clampedX = touchX!.clamp(rect.left, rect.right);
    final fraction = (clampedX - rect.left) / rect.width;

    // Map fraction to data index (0 to length-1)
    final exactIndex = fraction * (hourlyLevels.length - 1);
    final i0 = exactIndex.floor().clamp(0, hourlyLevels.length - 2);
    final i1 = i0 + 1;
    final t = exactIndex - i0;

    // Interpolate height between the two bracketing data points
    final interpHeight = hourlyLevels[i0].heightMetres +
        t * (hourlyLevels[i1].heightMetres - hourlyLevels[i0].heightMetres);

    final y = rect.bottom -
        ((interpHeight - minH) / (maxH - minH)) * rect.height;

    // Interpolate local time for display
    final localMs0 =
        hourlyLevels[i0].dateTimeLocal.millisecondsSinceEpoch.toDouble();
    final localMs1 =
        hourlyLevels[i1].dateTimeLocal.millisecondsSinceEpoch.toDouble();
    final interpMs = localMs0 + t * (localMs1 - localMs0);
    final interpLocal =
        DateTime.fromMillisecondsSinceEpoch(interpMs.round());

    // Vertical tracking line
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(clampedX, rect.top), Offset(clampedX, rect.bottom), linePaint);

    // Tracking dot on curve
    canvas.drawCircle(
      Offset(clampedX, y),
      7,
      Paint()
        ..color = const Color(0xFF42A5F5).withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
        Offset(clampedX, y), 5, Paint()..color = const Color(0xFF42A5F5));
    canvas.drawCircle(
      Offset(clampedX, y),
      5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Tooltip bubble - show local time
    final timeStr =
        '${interpLocal.hour.toString().padLeft(2, '0')}:${interpLocal.minute.toString().padLeft(2, '0')}';
    final heightStr = '${interpHeight.toStringAsFixed(1)}m';

    final tp = TextPainter(
      text: TextSpan(
        text: '$timeStr  $heightStr',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bubbleWidth = tp.width + 16;
    final bubbleHeight = tp.height + 10;
    // Position tooltip above the point, keep within bounds
    var bubbleX = clampedX - bubbleWidth / 2;
    bubbleX = bubbleX.clamp(rect.left, rect.right - bubbleWidth);
    var bubbleY = y - bubbleHeight - 12;
    if (bubbleY < rect.top) bubbleY = y + 12;

    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bubbleX, bubbleY, bubbleWidth, bubbleHeight),
      const Radius.circular(8),
    );

    // Shadow
    canvas.drawRRect(
      bubbleRect.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Background
    canvas.drawRRect(bubbleRect, Paint()..color = const Color(0xFF1E3A5F));
    // Border
    canvas.drawRRect(
      bubbleRect,
      Paint()
        ..color = const Color(0xFF42A5F5).withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // Text
    tp.paint(canvas, Offset(bubbleX + 8, bubbleY + 5));
  }

  @override
  bool shouldRepaint(covariant _TideChartPainter oldDelegate) {
    return oldDelegate.hourlyLevels != hourlyLevels ||
        oldDelegate.tideEvents != tideEvents ||
        oldDelegate.touchX != touchX ||
        oldDelegate.drawProgress != drawProgress;
  }
}
