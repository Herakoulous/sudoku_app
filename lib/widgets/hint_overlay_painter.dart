import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/hint_lesson.dart';
import '../models/position.dart';
import '../models/solver_step.dart';

/// Draws the reasoning of a hint stage over the board.
///
/// Painting at board level rather than per cell is what makes links between
/// cells possible at all — a per-cell painter cannot draw a line from r7c1 to
/// r8c3. It also keeps the whole illustration in one place, so a stage change is
/// a single repaint rather than 81 rebuilds.
///
/// Layer order matters: house washes sit furthest back, then cell tints, then
/// links, and emphasis rings on top.
class HintOverlayPainter extends CustomPainter {
  final HintStage stage;

  /// 0 to 1 as the stage animates in. Drives fades and the length of links, so
  /// the chain appears to be drawn rather than to blink into place.
  final double progress;

  /// A 0-to-1 loop used for the pulse on emphasised cells.
  final double pulse;

  const HintOverlayPainter({
    required this.stage,
    required this.progress,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
    if (cell <= 0) return;

    final eased = Curves.easeOut.transform(progress.clamp(0.0, 1.0));

    _paintHouses(canvas, cell, eased);
    _paintCellTints(canvas, cell, eased);
    _paintLinks(canvas, cell, eased);
    _paintEmphasis(canvas, cell, eased);
  }

  // ---------------------------------------------------------------------------
  // LAYERS
  // ---------------------------------------------------------------------------

  /// A soft wash over a whole row, column or box: "this is the region we are
  /// reasoning about".
  void _paintHouses(Canvas canvas, double cell, double t) {
    if (stage.houses.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFE0A93B).withValues(alpha: 0.10 * t);

    for (final house in stage.houses) {
      canvas.drawRect(_houseRect(house, cell), paint);
    }
  }

  /// Every marked cell gets a wash in its role colour.
  ///
  /// Candidate-level marks are washed a little more lightly than whole-cell
  /// ones. They used to be drawn as a filled circle over the pencil mark, but
  /// that sat on top of the player's own notes and hid them.
  void _paintCellTints(Canvas canvas, double cell, double t) {
    // A cell can carry several marks in one stage; paint the strongest once
    // rather than stacking translucent fills into mud.
    final strongest = <Position, HintMark>{};

    for (final mark in stage.marks) {
      final current = strongest[mark.cell];
      if (current == null || _salience(mark) > _salience(current)) {
        strongest[mark.cell] = mark;
      }
    }

    for (final mark in strongest.values) {
      final base = mark.role == HintRole.context
          ? 0.12
          : (mark.candidate != null ? 0.18 : 0.24);

      canvas.drawRect(
        _cellRect(mark.cell, cell),
        Paint()
          ..style = PaintingStyle.fill
          ..color = mark.role.color.withValues(alpha: base * t),
      );
    }
  }

  /// Ranking used when one cell carries more than one mark. The conclusion of a
  /// step should win over the context that supports it.
  int _salience(HintMark mark) {
    switch (mark.role) {
      case HintRole.target:
        return 5;
      case HintRole.solution:
        return 4;
      case HintRole.pivot:
        return 3;
      case HintRole.fin:
        return 2;
      case HintRole.pattern:
        return 1;
      case HintRole.context:
        return 0;
    }
  }

  /// Links between candidates. Solid for strong links, dashed for weak — the
  /// convention every sudoku reference uses.
  void _paintLinks(Canvas canvas, double cell, double t) {
    if (stage.links.isEmpty) return;

    // Links are drawn in sequence so a long chain traces itself out.
    final perLink = 1.0 / stage.links.length;

    for (var i = 0; i < stage.links.length; i++) {
      final link = stage.links[i];
      final localT = ((t - i * perLink) / perLink).clamp(0.0, 1.0);
      if (localT <= 0) continue;

      final from = link.candidate == null
          ? _cellCentre(link.from, cell)
          : _candidateCentre(link.from, link.candidate!, cell);
      final to = link.candidate == null
          ? _cellCentre(link.to, cell)
          : _candidateCentre(link.to, link.candidate!, cell);

      // Stop short of the endpoints so the line does not cover the digits.
      final inset = cell * 0.16;
      final direction = to - from;
      final length = direction.distance;
      if (length <= inset * 2) continue;

      final unit = direction / length;
      final start = from + unit * inset;
      final end = from + unit * (length - inset);
      final drawnEnd = start + (end - start) * localT;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.045
        ..strokeCap = StrokeCap.round
        ..color = (link.strong
                ? const Color(0xFFE0A93B)
                : const Color(0xFF9AA4B6))
            .withValues(alpha: 0.95);

      if (link.strong) {
        canvas.drawLine(start, drawnEnd, paint);
      } else {
        _drawDashed(canvas, start, drawnEnd, paint, cell * 0.11);
      }
    }
  }

  /// A pulsing ring on the cells the current sentence is about.
  void _paintEmphasis(Canvas canvas, double cell, double t) {
    final breathe = 0.5 + 0.5 * math.sin(pulse * 2 * math.pi);

    for (final mark in stage.marks) {
      if (!mark.emphasise) continue;

      final rect = _cellRect(mark.cell, cell).deflate(cell * 0.06);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * (0.05 + 0.02 * breathe)
        ..color = mark.role.color.withValues(alpha: (0.55 + 0.45 * breathe) * t);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.12)),
        paint,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // GEOMETRY
  // ---------------------------------------------------------------------------

  Rect _cellRect(Position cell, double size) =>
      Rect.fromLTWH(cell.col * size, cell.row * size, size, size);

  Offset _cellCentre(Position cell, double size) =>
      Offset((cell.col + 0.5) * size, (cell.row + 0.5) * size);

  /// Where digit [value] would sit as a pencil mark: a 3x3 arrangement inside
  /// the cell, reading order.
  Offset _candidateCentre(Position cell, int value, double size) {
    final index = (value - 1).clamp(0, 8);
    final col = index % 3;
    final row = index ~/ 3;

    // Inset so the marks sit inside the cell rather than on its borders.
    const inset = 0.22;
    final span = 1 - inset * 2;

    return Offset(
      (cell.col + inset + span * (col + 0.5) / 3) * size,
      (cell.row + inset + span * (row + 0.5) / 3) * size,
    );
  }

  Rect _houseRect(House house, double size) {
    switch (house.type) {
      case HouseType.row:
        return Rect.fromLTWH(0, (house.number - 1) * size, size * 9, size);
      case HouseType.col:
        return Rect.fromLTWH((house.number - 1) * size, 0, size, size * 9);
      case HouseType.box:
        final br = ((house.number - 1) ~/ 3) * 3;
        final bc = ((house.number - 1) % 3) * 3;
        return Rect.fromLTWH(bc * size, br * size, size * 3, size * 3);
    }
  }

  // ---------------------------------------------------------------------------
  // DRAWING HELPERS
  // ---------------------------------------------------------------------------

  void _drawDashed(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint,
    double dash,
  ) {
    final total = (to - from).distance;
    if (total <= 0) return;

    final unit = (to - from) / total;
    var travelled = 0.0;

    while (travelled < total) {
      final end = math.min(travelled + dash, total);
      canvas.drawLine(from + unit * travelled, from + unit * end, paint);
      travelled = end + dash * 0.8;
    }
  }

  @override
  bool shouldRepaint(HintOverlayPainter old) =>
      old.stage != stage || old.progress != progress || old.pulse != pulse;
}
