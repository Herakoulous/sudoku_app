import 'package:flutter/material.dart';

import '../models/hint_lesson.dart';
import '../models/position.dart';
import '../models/solver_step.dart';
import '../theme/app_theme.dart';

/// Renders a lesson's narration with every board reference colour-matched to
/// the board itself.
///
/// A sentence like "r7c1 holds only 1 and 6" is much easier to follow when
/// r7c1 is tinted the same gold the pivot cell is wearing on the grid — the eye
/// can jump straight from the word to the square. House names get the same
/// treatment as the wash drawn over that row, column or box.
class HintText extends StatelessWidget {
  final HintStage stage;
  final TextStyle baseStyle;

  const HintText({
    super.key,
    required this.stage,
    required this.baseStyle,
  });

  /// Matches, in priority order, a cell reference (r4c7) or a house reference
  /// (row 4 / column 7 / box 3).
  ///
  /// Houses are matched as a whole phrase so the number inside "row 5" is never
  /// mistaken for a digit worth highlighting on its own.
  static final RegExp _reference = RegExp(
    r'r(\d)c(\d)|(row|column|box)\s+(\d)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(style: baseStyle, children: _spans()),
    );
  }

  List<InlineSpan> _spans() {
    final text = stage.text;
    final spans = <InlineSpan>[];

    var cursor = 0;
    for (final match in _reference.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }

      final colour = match.group(1) != null
          ? _cellColour(
              Position(int.parse(match.group(1)!) - 1,
                  int.parse(match.group(2)!) - 1),
            )
          : _houseColour(match.group(3)!, int.parse(match.group(4)!));

      spans.add(
        TextSpan(
          text: match.group(0),
          style: colour == null
              ? null
              : TextStyle(
                  color: colour,
                  fontWeight: FontWeight.w700,
                ),
        ),
      );

      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return spans;
  }

  /// The colour this cell is wearing on the board in this stage, or null when
  /// it is not highlighted — an unmarked cell mentioned in passing should not
  /// be dressed up as part of the pattern.
  Color? _cellColour(Position cell) {
    HintMark? best;
    for (final mark in stage.marks) {
      if (mark.cell != cell) continue;
      if (best == null || _salience(mark.role) > _salience(best.role)) {
        best = mark;
      }
    }
    return best?.role.color;
  }

  Color? _houseColour(String word, int number) {
    final type = switch (word.toLowerCase()) {
      'row' => HouseType.row,
      'column' => HouseType.col,
      _ => HouseType.box,
    };

    for (final house in stage.houses) {
      if (house.type == type && house.number == number) return AppColors.gold;
    }
    return null;
  }

  /// Mirrors the painter's ranking so text and board agree when a cell carries
  /// more than one mark.
  static int _salience(HintRole role) {
    switch (role) {
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
}
