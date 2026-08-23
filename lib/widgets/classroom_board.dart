import 'package:flutter/material.dart';

import '../models/hint_lesson.dart';
import '../models/position.dart';
import '../models/solver_step.dart';
import '../theme/app_theme.dart';
import 'hint_overlay_painter.dart';

/// A read-only board for the classroom.
///
/// Separate from the playable grid because it answers a different question:
/// there is no game state, no notes to edit and no rules to enforce — only a
/// position to look at, with its candidates already pencilled in. Painting it
/// in one pass keeps it cheap enough to sit under an animating overlay.
class ClassroomBoard extends StatelessWidget {
  final SolverStep step;

  /// The tutorial beat currently being illustrated, if any.
  final HintStage? stage;
  final double stageProgress;
  final double pulse;

  /// Cells the student has picked while hunting for the pattern.
  final Set<Position> selected;

  /// Set once an answer has been graded: which picks were right, and which
  /// pattern cells were missed.
  final Set<Position>? correct;
  final Set<Position>? missed;

  final ValueChanged<Position>? onTapCell;

  const ClassroomBoard({
    super.key,
    required this.step,
    this.stage,
    this.stageProgress = 1,
    this.pulse = 0,
    this.selected = const {},
    this.correct,
    this.missed,
    this.onTapCell,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest.shortestSide;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: onTapCell == null
                ? null
                : (details) {
                    final cell = size / 9;
                    final col = (details.localPosition.dx / cell)
                        .floor()
                        .clamp(0, 8);
                    final row = (details.localPosition.dy / cell)
                        .floor()
                        .clamp(0, 8);
                    onTapCell!(Position(row, col));
                  },
            // Framed as a card: rounded, softly shadowed, and clipped so the
            // painted grid does not fight the dark page with hard white
            // corners. A thin gold hairline ties it to the rest of the app.
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.25),
                ),
                boxShadow: AppShadow.lifted,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _BoardPainter(
                        step: step,
                        selected: selected,
                        correct: correct,
                        missed: missed,
                      ),
                    ),
                    if (stage != null)
                      CustomPaint(
                        painter: HintOverlayPainter(
                          stage: stage!,
                          progress: stageProgress,
                          pulse: pulse,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final SolverStep step;
  final Set<Position> selected;
  final Set<Position>? correct;
  final Set<Position>? missed;

  _BoardPainter({
    required this.step,
    required this.selected,
    this.correct,
    this.missed,
  });

  // Paper-white, so the board reads as a puzzle rather than as more UI.
  static const Color _paper = Color(0xFFF7F5F0);
  static const Color _given = Color(0xFF1A1A1A);
  static const Color _candidate = Color(0xFF7A8494);
  static const Color _line = Color(0xFF3A3A3A);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
    if (cell <= 0) return;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _paper,
    );

    _paintFeedback(canvas, cell);
    _paintDigits(canvas, cell);
    _paintLines(canvas, cell, size);
  }

  /// Selection while hunting, then the verdict once graded.
  void _paintFeedback(Canvas canvas, double cell) {
    void fill(Position at, Color colour) {
      canvas.drawRect(
        Rect.fromLTWH(at.col * cell, at.row * cell, cell, cell),
        Paint()..color = colour,
      );
    }

    if (correct == null && missed == null) {
      for (final at in selected) {
        fill(at, AppColors.gold.withValues(alpha: 0.30));
      }
      return;
    }

    // Graded. A wrong pick is a selection that was not part of the pattern.
    for (final at in selected) {
      final right = correct?.contains(at) ?? false;
      fill(
        at,
        right
            ? AppColors.success.withValues(alpha: 0.32)
            : AppColors.danger.withValues(alpha: 0.28),
      );
    }
    for (final at in missed ?? const <Position>{}) {
      fill(at, AppColors.warning.withValues(alpha: 0.34));
    }
  }

  void _paintDigits(Canvas canvas, double cell) {
    for (var index = 0; index < 81; index++) {
      final row = index ~/ 9;
      final col = index % 9;
      final value = step.grid[index];

      if (value != 0) {
        _text(
          canvas,
          '$value',
          Offset((col + 0.5) * cell, (row + 0.5) * cell),
          cell * 0.58,
          _given,
          FontWeight.w700,
        );
        continue;
      }

      // Candidates in the usual 3x3 arrangement, so their positions are
      // predictable and the overlay can point at them.
      for (final candidate in step.candidates[index]) {
        final slot = candidate - 1;
        final cx = (col + 0.22 + 0.56 * ((slot % 3) + 0.5) / 3) * cell;
        final cy = (row + 0.22 + 0.56 * ((slot ~/ 3) + 0.5) / 3) * cell;

        _text(
          canvas,
          '$candidate',
          Offset(cx, cy),
          cell * 0.22,
          _candidate,
          FontWeight.w600,
        );
      }
    }
  }

  void _paintLines(Canvas canvas, double cell, Size size) {
    for (var i = 0; i <= 9; i++) {
      final heavy = i % 3 == 0;
      final paint = Paint()
        ..color = heavy ? _line : _line.withValues(alpha: 0.32)
        ..strokeWidth = heavy ? 1.8 : 0.7;

      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), paint);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), paint);
    }
  }

  void _text(
    Canvas canvas,
    String value,
    Offset centre,
    double fontSize,
    Color colour,
    FontWeight weight,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: weight,
          color: colour,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.step != step ||
      !setEquals(old.selected, selected) ||
      !setEquals(old.correct, correct) ||
      !setEquals(old.missed, missed);

  static bool setEquals(Set<Position>? a, Set<Position>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}
