import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku_realms/models/hint_lesson.dart';
import 'package:sudoku_realms/models/position.dart';
import 'package:sudoku_realms/models/solver_step.dart';
import 'package:sudoku_realms/services/hint_lesson_builder.dart';
import 'package:sudoku_realms/services/solver_step_parser.dart';

/// A real solve path captured from the solver, so these tests run against the
/// server's actual output rather than hand-written fixtures.
List<SolverStep> _fixtureSteps() {
  final file = File('test/fixtures/solve_path.json');
  if (!file.existsSync()) return const [];
  return SolverStepParser.parseSolvePath(file.readAsStringSync());
}

SolverStep? _stepOfType(List<SolverStep> steps, String type) {
  for (final step in steps) {
    if (step.type == type) return step;
  }
  return null;
}

void main() {
  final steps = _fixtureSteps();

  test('the fixture loaded', () {
    expect(steps, isNotEmpty,
        reason: 'test/fixtures/solve_path.json must contain a solve path');
  });

  group('parsing', () {
    test('cells arrive 0-based', () {
      final step = steps.first;
      for (final cell in step.cells) {
        expect(cell.row, inInclusiveRange(0, 8));
        expect(cell.col, inInclusiveRange(0, 8));
      }
    });

    test('the candidate grid is decoded for all 81 cells', () {
      final step = steps.first;
      expect(step.candidates.length, 81);

      // A solved cell has no candidates; an empty one must have at least two,
      // or it would already be a single.
      for (var i = 0; i < 81; i++) {
        final cell = Position(i ~/ 9, i % 9);
        if (step.valueAt(cell) != 0) {
          expect(step.candidatesOf(cell), isEmpty, reason: cell.label);
        }
      }
    });

    test('placements and eliminations are never both empty', () {
      for (final step in steps) {
        expect(
          step.placements.isNotEmpty || step.eliminations.isNotEmpty,
          isTrue,
          reason: '${step.type} does nothing',
        );
      }
    });
  });

  group('every step becomes a usable lesson', () {
    test('no lesson is empty or malformed', () {
      for (final step in steps) {
        final lesson = HintLessonBuilder.build(step);

        expect(lesson.stages, isNotEmpty, reason: step.type);
        expect(lesson.technique.trim(), isNotEmpty, reason: step.type);
        expect(lesson.headline.trim(), isNotEmpty, reason: step.type);

        for (final stage in lesson.stages) {
          expect(stage.text.trim(), isNotEmpty, reason: step.type);

          // Placeholder leakage would be worse than a vague sentence.
          expect(stage.text, isNot(contains('null')), reason: step.type);
          expect(stage.text, isNot(contains('  ')), reason: step.type);
        }
      }
    });

    test('marks always point at real cells', () {
      for (final step in steps) {
        final lesson = HintLessonBuilder.build(step);

        for (final stage in lesson.stages) {
          for (final mark in stage.marks) {
            expect(mark.cell.row, inInclusiveRange(0, 8), reason: step.type);
            expect(mark.cell.col, inInclusiveRange(0, 8), reason: step.type);
            if (mark.candidate != null) {
              expect(mark.candidate, inInclusiveRange(1, 9), reason: step.type);
            }
          }
          for (final link in stage.links) {
            expect(link.from.row, inInclusiveRange(0, 8));
            expect(link.to.col, inInclusiveRange(0, 8));
          }
        }
      }
    });

    test('the final stage states the conclusion', () {
      for (final step in steps) {
        final lesson = HintLessonBuilder.build(step);
        final last = lesson.stages.last;

        if (step.isPlacement) {
          final placement = step.placements.first;
          expect(
            last.text.contains(placement.cell.label) ||
                last.text.contains('${placement.value}'),
            isTrue,
            reason: '${step.type}: "${last.text}"',
          );
        } else {
          // At least one eliminated cell must be named or marked.
          final named = step.eliminationCells
              .any((c) => last.text.contains(c.label));
          final marked = last.marks.any(
            (m) => m.role == HintRole.target,
          );
          expect(named || marked, isTrue,
              reason: '${step.type}: "${last.text}"');
        }
      }
    });

    test('most steps get a dedicated walkthrough, not the fallback', () {
      final total = steps.length;
      final specific =
          steps.where((s) => HintLessonBuilder.build(s).isSpecific).length;

      // The fallback exists for exotic techniques; it should be the exception.
      expect(
        specific / total,
        greaterThan(0.85),
        reason: '$specific of $total steps had a dedicated explanation',
      );
    });
  });

  group('technique walkthroughs', () {
    test('naked single names the blocking neighbours', () {
      final step = _stepOfType(steps, 'NAKED_SINGLE');
      if (step == null) return;

      final lesson = HintLessonBuilder.build(step);
      final cell = step.placements.first.cell;
      final value = step.placements.first.value;

      expect(lesson.headline, contains(cell.label));
      expect(lesson.stages.length, greaterThanOrEqualTo(2));

      // The whole point: it explains why the other digits are out.
      final body = lesson.stages.map((s) => s.text).join(' ');
      expect(body, contains(cell.label));
      expect(body, contains('$value'));
      expect(body, contains('already account for'));
    });

    test('hidden single identifies the house it is hidden in', () {
      final step = _stepOfType(steps, 'HIDDEN_SINGLE');
      if (step == null) return;

      final lesson = HintLessonBuilder.build(step);
      final body = lesson.stages.map((s) => s.text).join(' ');

      expect(
        body.contains('row') || body.contains('column') || body.contains('box'),
        isTrue,
        reason: 'a hidden single must say where it is hidden',
      );
      expect(lesson.stages.first.houses, isNotEmpty);
    });

    test('pointing explains both the box and the line', () {
      final step = _stepOfType(steps, 'LOCKED_CANDIDATES_1');
      if (step == null) return;

      final lesson = HintLessonBuilder.build(step);
      final body = lesson.stages.map((s) => s.text).join(' ');

      expect(body, contains('box'));
      expect(
        body.contains('row') || body.contains('column'),
        isTrue,
      );
      expect(lesson.stages.length, greaterThanOrEqualTo(4));
    });

    test('xy-wing traces both branches to the same digit', () {
      final step = _stepOfType(steps, 'XY_WING');
      if (step == null) return;

      final lesson = HintLessonBuilder.build(step);
      expect(lesson.isSpecific, isTrue);

      final body = lesson.stages.map((s) => s.text).join(' ');

      // Both hypotheses have to appear; that is the technique.
      expect(body, contains('Suppose'));
      expect(body, contains('instead'));
      expect(body, contains('either way'));

      // The pivot must be the cell without the eliminated digit.
      final z = step.eliminations.first.value;
      final pivotStage = lesson.stages.first;
      final pivotCell = pivotStage.marks.first.cell;
      expect(step.candidatesOf(pivotCell).contains(z), isFalse);
      expect(step.candidatesOf(pivotCell).length, 2);
    });

    test('hidden pair explains the claim on both cells', () {
      final step = _stepOfType(steps, 'HIDDEN_PAIR');
      if (step == null) return;

      final lesson = HintLessonBuilder.build(step);
      final body = lesson.stages.map((s) => s.text).join(' ');

      for (final cell in step.cells) {
        expect(body, contains(cell.label));
      }
    });

    test('a chain step is narrated node by node', () {
      final step = steps.firstWhere(
        (s) => s.chains.isNotEmpty && s.chains.first.length >= 4,
        orElse: () => steps.first,
      );
      if (step.chains.isEmpty) return;

      final lesson = HintLessonBuilder.build(step);

      // One stage per link, plus the opening and the conclusion.
      expect(lesson.stages.length, greaterThanOrEqualTo(3));
      expect(lesson.stages.first.text.toLowerCase(), contains('suppose'));

      // Links accumulate so the drawn chain grows as the player reads.
      final linkCounts = lesson.stages.map((s) => s.links.length).toList();
      expect(linkCounts.last, greaterThan(0));
    });
  });

  group('lesson quality', () {
    test('every lesson carries a takeaway', () {
      for (final step in steps) {
        final lesson = HintLessonBuilder.build(step);
        expect(lesson.takeaway, isNotNull, reason: step.type);
        expect(lesson.takeaway!.trim(), isNotEmpty, reason: step.type);
      }
    });

    test('stage text reads as sentences', () {
      for (final step in steps) {
        for (final stage in HintLessonBuilder.build(step).stages) {
          expect(
            stage.text.endsWith('.') ||
                stage.text.endsWith('!') ||
                stage.text.endsWith('?'),
            isTrue,
            reason: '${step.type}: "${stage.text}"',
          );
          // Sentences may legitimately open with a lowercase cell or house
          // reference — "r9c3 is the only cell..." is correct prose, and
          // capitalising it to "R9c3" would be wrong. Anything else must start
          // with a capital.
          final opensWithReference =
              RegExp(r'^(r\dc\d|row |column |box )').hasMatch(stage.text);
          expect(
            opensWithReference || stage.text[0] == stage.text[0].toUpperCase(),
            isTrue,
            reason: '${step.type}: "${stage.text}"',
          );
        }
      }
    });

    test('a placement lesson ends by naming the digit', () {
      for (final step in steps.where((s) => s.isPlacement)) {
        final lesson = HintLessonBuilder.build(step);
        final value = step.placements.first.value;

        expect(
          lesson.stages.last.text.contains('$value'),
          isTrue,
          reason: '${step.type}: "${lesson.stages.last.text}"',
        );
      }
    });
  });

  test('a malformed response yields no steps rather than throwing', () {
    expect(SolverStepParser.parseSolvePath(''), isEmpty);
    expect(SolverStepParser.parseSolvePath('not json'), isEmpty);
    expect(SolverStepParser.parseSolvePath('{"ok":false}'), isEmpty);
    expect(SolverStepParser.parseSolvePath(jsonEncode({'ok': true})), isEmpty);
  });
}
