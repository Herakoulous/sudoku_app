import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku_realms/data/puzzle_codec.dart';
import 'package:sudoku_realms/data/puzzles.dart';
import 'package:sudoku_realms/data/realm_config.dart';
import 'package:sudoku_realms/models/variant_constraint.dart';

/// Validates the bundled puzzle data through the same codec the app uses.
///
/// The Python generator verifies uniqueness, but it encodes the data; this
/// checks the *decoding* side, so an encoder/codec mismatch cannot silently ship
/// a board whose printed constraints contradict its own solution.
void main() {
  group('PuzzleCodec', () {
    test('alphabet is 81 distinct characters', () {
      expect(PuzzleCodec.alphabet.length, 81);
      expect(PuzzleCodec.alphabet.split('').toSet().length, 81);
    });

    test('alphabet avoids characters that break Dart string literals', () {
      for (final forbidden in ["'", r'\', r'$', ';']) {
        expect(
          PuzzleCodec.alphabet.contains(forbidden),
          isFalse,
          reason: 'alphabet must not contain $forbidden',
        );
      }
    });

    test('cell indices round-trip through the alphabet', () {
      for (var index = 0; index < 81; index++) {
        expect(PuzzleCodec.indexOf(PuzzleCodec.alphabet[index]), index);
      }
    });
  });

  group('bundled puzzles', () {
    final all = Puzzles.allPuzzles.values.toList();

    test('every realm has puzzles and no id collides', () {
      expect(all, isNotEmpty);
      expect(Puzzles.allPuzzles.length, all.length);

      for (final realm in RealmConfig.realms) {
        expect(
          RealmConfig.getPuzzlesForRealm(realm.name),
          isNotEmpty,
          reason: '${realm.name} has no puzzles',
        );
      }
    });

    test('grids are 9x9 with digits 0-9', () {
      for (final puzzle in all) {
        expect(puzzle.grid.length, 9, reason: puzzle.id);
        for (final row in puzzle.grid) {
          expect(row.length, 9, reason: puzzle.id);
          for (final value in row) {
            expect(value, inInclusiveRange(0, 9), reason: puzzle.id);
          }
        }
      }
    });

    test('difficulty is on the 1-10 scale', () {
      for (final puzzle in all) {
        expect(puzzle.difficulty, inInclusiveRange(1, 10), reason: puzzle.id);
      }
    });

    test('every puzzle ships a solution', () {
      for (final puzzle in all) {
        expect(puzzle.solution, isNotNull, reason: '${puzzle.id} has no solution');
      }
    });

    test('solutions are valid sudoku grids', () {
      for (final puzzle in all) {
        final solution = puzzle.solution!;

        for (var i = 0; i < 9; i++) {
          expect(
            solution[i].toSet(),
            hasLength(9),
            reason: '${puzzle.id}: row $i repeats a digit',
          );
          expect(
            {for (var r = 0; r < 9; r++) solution[r][i]},
            hasLength(9),
            reason: '${puzzle.id}: column $i repeats a digit',
          );
        }

        for (var br = 0; br < 9; br += 3) {
          for (var bc = 0; bc < 9; bc += 3) {
            final box = <int>{};
            for (var r = br; r < br + 3; r++) {
              for (var c = bc; c < bc + 3; c++) {
                box.add(solution[r][c]);
              }
            }
            expect(box, hasLength(9), reason: '${puzzle.id}: box repeats a digit');
          }
        }
      }
    });

    test('givens agree with the solution', () {
      for (final puzzle in all) {
        final solution = puzzle.solution!;
        for (var r = 0; r < 9; r++) {
          for (var c = 0; c < 9; c++) {
            final given = puzzle.grid[r][c];
            if (given != 0) {
              expect(
                given,
                solution[r][c],
                reason: '${puzzle.id}: given at r${r + 1}c${c + 1} '
                    'contradicts the solution',
              );
            }
          }
        }
      }
    });

    test('constraint cells are inside the grid', () {
      for (final puzzle in all) {
        for (final c in puzzle.constraints) {
          if (c.type == ConstraintType.SANDWICH) continue;

          expect(c.row1, inInclusiveRange(0, 8), reason: puzzle.id);
          expect(c.col1, inInclusiveRange(0, 8), reason: puzzle.id);
          expect(c.row2, inInclusiveRange(0, 8), reason: puzzle.id);
          expect(c.col2, inInclusiveRange(0, 8), reason: puzzle.id);
        }
      }
    });

    test('every constraint is satisfied by the stored solution', () {
      for (final puzzle in all) {
        final solution = puzzle.solution!;

        for (final c in puzzle.constraints) {
          switch (c.type) {
            case ConstraintType.KROPKI_WHITE:
              final a = solution[c.row1][c.col1];
              final b = solution[c.row2][c.col2];
              expect(
                (a - b).abs(),
                1,
                reason: '${puzzle.id}: white dot on $a/$b',
              );
              break;

            case ConstraintType.KROPKI_BLACK:
              final a = solution[c.row1][c.col1];
              final b = solution[c.row2][c.col2];
              expect(
                a == 2 * b || b == 2 * a,
                isTrue,
                reason: '${puzzle.id}: black dot on $a/$b',
              );
              break;

            case ConstraintType.XV_V:
              expect(
                solution[c.row1][c.col1] + solution[c.row2][c.col2],
                5,
                reason: '${puzzle.id}: V does not sum to 5',
              );
              break;

            case ConstraintType.XV_X:
              expect(
                solution[c.row1][c.col1] + solution[c.row2][c.col2],
                10,
                reason: '${puzzle.id}: X does not sum to 10',
              );
              break;

            case ConstraintType.GERMAN_WHISPERS:
              final a = solution[c.row1][c.col1];
              final b = solution[c.row2][c.col2];
              expect(
                (a - b).abs() >= 5,
                isTrue,
                reason: '${puzzle.id}: whisper link on $a/$b',
              );
              break;

            case ConstraintType.THERMO:
              final cells = c.thermoCells!;
              expect(cells.length, greaterThanOrEqualTo(2), reason: puzzle.id);

              final values = [
                for (final p in cells) solution[p.row][p.col],
              ];
              for (var i = 0; i < values.length - 1; i++) {
                expect(
                  values[i] < values[i + 1],
                  isTrue,
                  reason: '${puzzle.id}: thermo $values does not increase',
                );
              }
              break;

            case ConstraintType.SANDWICH:
              final line = c.sandwichRow != null
                  ? [for (var i = 0; i < 9; i++) solution[c.sandwichRow!][i]]
                  : [for (var i = 0; i < 9; i++) solution[i][c.sandwichCol!]];

              final lo = line.indexOf(1);
              final hi = line.indexOf(9);
              final between = line
                  .sublist(lo < hi ? lo + 1 : hi + 1, lo < hi ? hi : lo)
                  .fold<int>(0, (sum, v) => sum + v);

              expect(
                between,
                c.sandwichSum,
                reason: '${puzzle.id}: sandwich total is $between, '
                    'clue says ${c.sandwichSum}',
              );
              break;
          }
        }
      }
    });
  });
}
