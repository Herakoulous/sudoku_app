import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A small line chart for a single series — rating over time.
///
/// Deliberately minimal: no axes cluttering a phone-width card, just the line,
/// a soft fill beneath it, the end point marked, and the low/high labelled. It
/// reads at a glance, which is all a trend needs to do.
class LineChart extends StatelessWidget {
  final List<int> values;
  final Color color;
  final double height;

  const LineChart({
    super.key,
    required this.values,
    required this.color,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Play a few runs to see your trend.',
            style: AppType.label.copyWith(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _LineChartPainter(values: values, color: color),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<int> values;
  final Color color;

  _LineChartPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);

    // A flat series would divide by zero; give it a nominal band so the line
    // sits sensibly in the middle instead of hugging an edge.
    final span = (hi - lo) == 0 ? 1 : (hi - lo);

    const padTop = 14.0;
    const padBottom = 18.0;
    final chartHeight = size.height - padTop - padBottom;

    Offset pointAt(int index) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      final y = padTop + chartHeight * (1 - (values[index] - lo) / span);
      return Offset(x, y);
    }

    final points = [for (var i = 0; i < values.length; i++) pointAt(i)];

    // Baseline grid line at the mid-value, for a sense of scale.
    final mid = padTop + chartHeight / 2;
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()..color = AppColors.strokeSoft.withValues(alpha: 0.5),
    );

    // Soft fill under the line.
    final fill = Path()..moveTo(points.first.dx, size.height - padBottom);
    for (final p in points) {
      fill.lineTo(p.dx, p.dy);
    }
    fill.lineTo(points.last.dx, size.height - padBottom);
    fill.close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );

    // The line itself.
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    // Mark the current value.
    canvas.drawCircle(
      points.last,
      4,
      Paint()..color = color,
    );
    canvas.drawCircle(
      points.last,
      4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.ink,
    );

    _label(canvas, '$hi', Offset(2, 0), AppColors.textMuted);
    _label(
      canvas,
      '$lo',
      Offset(2, size.height - padBottom + 2),
      AppColors.textMuted,
    );
    _label(
      canvas,
      '${values.last}',
      Offset(points.last.dx - 34, points.last.dy - 18),
      color,
    );
  }

  void _label(Canvas canvas, String text, Offset at, Color colour) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colour,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.values != values || old.color != color;
}
