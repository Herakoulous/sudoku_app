import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/difficulty_tier.dart';
import '../../theme/app_theme.dart';

/// Five segments, lit up to the puzzle's tier, with the tier name beside them.
/// Reads at a glance and scales down to a bare meter for dense grids.
class DifficultyMeter extends StatelessWidget {
  final int rating;
  final bool showLabel;
  final double segmentWidth;
  final double segmentHeight;

  const DifficultyMeter({
    super.key,
    required this.rating,
    this.showLabel = true,
    this.segmentWidth = 12,
    this.segmentHeight = 4,
  });

  @override
  Widget build(BuildContext context) {
    final tier = DifficultyTier.fromRating(rating);

    final meter = Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(DifficultyTier.values.length, (i) {
        final lit = i < tier.filledSegments;
        return Container(
          width: segmentWidth,
          height: segmentHeight,
          margin: EdgeInsets.only(
            right: i == DifficultyTier.values.length - 1 ? 0 : 3,
          ),
          decoration: BoxDecoration(
            color: lit ? tier.color : AppColors.stroke,
            borderRadius: BorderRadius.circular(segmentHeight),
          ),
        );
      }),
    );

    if (!showLabel) return meter;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        meter,
        const SizedBox(width: AppSpace.xs),
        Text(
          tier.label,
          style: AppType.overline.copyWith(color: tier.color),
        ),
      ],
    );
  }
}

/// A thin circular progress track. Used for per-puzzle completion and realm
/// progress, so "how far along am I" always looks the same.
class ProgressRing extends StatelessWidget {
  final double progress; // 0..1
  final double size;
  final double strokeWidth;
  final Color color;
  final Widget? center;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 44,
    this.strokeWidth = 3,
    this.color = AppColors.gold,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              progress: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              color: color,
            ),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - strokeWidth) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppColors.stroke;

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(center, radius, track);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

/// A horizontal progress bar with an optional caption above it.
class ProgressBar extends StatelessWidget {
  final double progress; // 0..1
  final Color color;
  final double height;

  const ProgressBar({
    super.key,
    required this.progress,
    this.color = AppColors.gold,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: AppColors.stroke),
          AnimatedFractionallySizedBox(
            duration: AppMotion.slow,
            curve: AppMotion.enter,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(color, Colors.white, 0.35)!,
                    color,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill showing an icon and a value — best time, hints used, streak.
class StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color? color;

  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xs,
        vertical: AppSpace.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tint),
          const SizedBox(width: AppSpace.xxs + 1),
          Text(value, style: AppType.numeric.copyWith(fontSize: 12, color: tint)),
        ],
      ),
    );
  }
}
