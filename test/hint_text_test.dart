import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku_realms/models/hint_lesson.dart';
import 'package:sudoku_realms/models/position.dart';
import 'package:sudoku_realms/models/solver_step.dart';
import 'package:sudoku_realms/services/hint_lesson_builder.dart';
import 'package:sudoku_realms/services/solver_step_parser.dart';
import 'package:sudoku_realms/theme/app_theme.dart';
import 'package:sudoku_realms/widgets/hint_text.dart';

/// Collects every span's text paired with the colour it is painted in.
List<(String, Color?)> _spans(WidgetTester tester) {
  final rich = tester.widget<RichText>(find.byType(RichText));
  final out = <(String, Color?)>[];

  rich.text.visitChildren((span) {
    if (span is TextSpan && span.text != null) {
      out.add((span.text!, span.style?.color));
    }
    return true;
  });

  return out;
}

Future<void> _pump(WidgetTester tester, HintStage stage) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HintText(
          stage: stage,
          baseStyle: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a cell reference takes the colour of its mark', (tester) async {
    const cell = Position(6, 0); // r7c1

    await _pump(
      tester,
      const HintStage(
        text: 'r7c1 holds only 1 and 6. It is the pivot.',
        marks: [HintMark(cell: cell, role: HintRole.pivot)],
      ),
    );

    final coloured = _spans(tester).where((s) => s.$1 == 'r7c1').toList();
    expect(coloured, hasLength(1));
    expect(coloured.first.$2, HintRole.pivot.color);
  });

  testWidgets('an eliminated cell reads in the target colour', (tester) async {
    const cell = Position(6, 1); // r7c2

    await _pump(
      tester,
      const HintStage(
        text: 'So r7c2 cannot be 3.',
        marks: [HintMark(cell: cell, role: HintRole.target)],
      ),
    );

    final coloured = _spans(tester).where((s) => s.$1 == 'r7c2').toList();
    expect(coloured.first.$2, HintRole.target.color);
  });

  testWidgets('a highlighted house is tinted, an unrelated one is not',
      (tester) async {
    await _pump(
      tester,
      const HintStage(
        text: 'Inside box 6, 3 can only go in row 4 and row 9.',
        houses: [House(HouseType.box, 6), House(HouseType.row, 4)],
      ),
    );

    final spans = _spans(tester);

    expect(spans.firstWhere((s) => s.$1 == 'box 6').$2, AppColors.gold);
    expect(spans.firstWhere((s) => s.$1 == 'row 4').$2, AppColors.gold);

    // row 9 is mentioned but not highlighted on the board, so colouring it
    // would point the player at a region that is not lit up.
    expect(spans.firstWhere((s) => s.$1 == 'row 9').$2, isNull);
  });

  testWidgets('an unmarked cell is left plain', (tester) async {
    await _pump(
      tester,
      const HintStage(text: 'Nothing special about r1c1 here.'),
    );

    expect(_spans(tester).firstWhere((s) => s.$1 == 'r1c1').$2, isNull);
  });

  testWidgets('the digit inside a house name is never coloured separately',
      (tester) async {
    await _pump(
      tester,
      const HintStage(
        text: 'row 5 already holds 5.',
        houses: [House(HouseType.row, 5)],
      ),
    );

    // "row 5" must be one span, not "row " plus a stray highlighted 5.
    final texts = _spans(tester).map((s) => s.$1).toList();
    expect(texts, contains('row 5'));
  });

  testWidgets('the full sentence survives intact', (tester) async {
    final steps = SolverStepParser.parseSolvePath(
      File('test/fixtures/solve_path.json').readAsStringSync(),
    );

    // Splitting text into spans must never drop or duplicate a character.
    for (final step in steps.take(30)) {
      for (final stage in HintLessonBuilder.build(step).stages) {
        await _pump(tester, stage);
        final joined = _spans(tester).map((s) => s.$1).join();
        expect(joined, stage.text);
      }
    }
  });
}
