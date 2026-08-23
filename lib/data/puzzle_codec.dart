import '../models/position.dart';
import '../models/variant_constraint.dart';

/// Compact encoding for bundled puzzle data.
///
/// Written out as Dart constructor calls, 250 variant puzzles with their full
/// constraint sets run to tens of thousands of lines — a kropki grid alone
/// carries forty-odd dots. Encoding each puzzle as a few short strings keeps the
/// generated file small enough to read and quick to compile, and decoding costs
/// a few microseconds per puzzle at load.
///
/// Format
/// ------
/// `grid` and `solution` are 81 digits in reading order, 0 for empty.
///
/// `constraints` is a `;`-separated list of tokens. The leading letter gives the
/// kind, and every cell is one character from [alphabet] encoding `row * 9 + col`:
///
///   * `W<a><b>` — kropki white dot (consecutive)
///   * `B<a><b>` — kropki black dot (ratio 2:1)
///   * `X<a><b>` — XV, cells sum to 10
///   * `V<a><b>` — XV, cells sum to 5
///   * `G<a><b>` — German Whisper link (differ by 5 or more)
///   * `T<a><b><c>…` — thermometer path, bulb first, any length
///   * `R<row><sum>` — sandwich clue for a row
///   * `C<col><sum>` — sandwich clue for a column
class PuzzleCodec {
  PuzzleCodec._();

  /// 81 characters, one per cell index. Excludes `'`, `\`, `$` and `;` so tokens
  /// stay safe inside single-quoted Dart strings and separator parsing is
  /// unambiguous.
  static const String alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
      'abcdefghijklmnopqrstuvwxyz'
      '0123456789'
      '!#%&()*+,-./:<=>?@[';

  static int indexOf(String char) => alphabet.indexOf(char);

  static List<List<int>> decodeGrid(String encoded) {
    return List.generate(
      9,
      (row) => List.generate(
        9,
        (col) => encoded.codeUnitAt(row * 9 + col) - 0x30,
      ),
    );
  }

  static Position _cell(String char) {
    final index = indexOf(char);
    return Position(index ~/ 9, index % 9);
  }

  static List<VariantConstraint> decodeConstraints(String encoded) {
    if (encoded.isEmpty) return const [];

    final out = <VariantConstraint>[];

    for (final token in encoded.split(';')) {
      if (token.length < 2) continue;

      final kind = token[0];
      final body = token.substring(1);

      switch (kind) {
        case 'W':
          out.add(_pair(ConstraintType.KROPKI_WHITE, body));
          break;
        case 'B':
          out.add(_pair(ConstraintType.KROPKI_BLACK, body));
          break;
        case 'X':
          out.add(_pair(ConstraintType.XV_X, body));
          break;
        case 'V':
          out.add(_pair(ConstraintType.XV_V, body));
          break;
        case 'G':
          out.add(_pair(ConstraintType.GERMAN_WHISPERS, body));
          break;

        case 'T':
          final cells = [
            for (var i = 0; i < body.length; i++) _cell(body[i]),
          ];
          if (cells.length < 2) break;
          out.add(
            VariantConstraint(
              type: ConstraintType.THERMO,
              row1: cells.first.row,
              col1: cells.first.col,
              row2: cells.last.row,
              col2: cells.last.col,
              thermoCells: cells,
            ),
          );
          break;

        // Sandwich clues sit outside the grid. The renderer reads col1 == -1 as
        // "draw to the left of this row" and row1 == -1 as "draw above this
        // column", which is the conventional placement.
        case 'R':
          out.add(
            VariantConstraint(
              type: ConstraintType.SANDWICH,
              row1: indexOf(body[0]),
              col1: -1,
              row2: indexOf(body[0]),
              col2: -1,
              sandwichRow: indexOf(body[0]),
              sandwichSum: indexOf(body[1]),
            ),
          );
          break;

        case 'C':
          out.add(
            VariantConstraint(
              type: ConstraintType.SANDWICH,
              row1: -1,
              col1: indexOf(body[0]),
              row2: -1,
              col2: indexOf(body[0]),
              sandwichCol: indexOf(body[0]),
              sandwichSum: indexOf(body[1]),
            ),
          );
          break;
      }
    }

    return out;
  }

  static VariantConstraint _pair(ConstraintType type, String body) {
    final a = _cell(body[0]);
    final b = _cell(body[1]);
    return VariantConstraint(
      type: type,
      row1: a.row,
      col1: a.col,
      row2: b.row,
      col2: b.col,
    );
  }
}

/// One bundled puzzle.
///
/// Grid, solution and constraints are decoded lazily and cached: a realm screen
/// only ever touches the handful of puzzles it draws previews for, so decoding
/// all of them up front would be wasted work.
class PuzzleData {
  final String id;
  final int difficulty;

  final String _grid;
  final String? _solution;
  final String _constraints;

  List<List<int>>? _gridCache;
  List<List<int>>? _solutionCache;
  List<VariantConstraint>? _constraintsCache;

  PuzzleData({
    required this.id,
    required this.difficulty,
    required String grid,
    String? solution,
    String constraints = '',
  })  : _grid = grid,
        _solution = solution,
        _constraints = constraints;

  List<List<int>> get grid => _gridCache ??= PuzzleCodec.decodeGrid(_grid);

  List<List<int>>? get solution {
    final encoded = _solution;
    if (encoded == null) return null;
    return _solutionCache ??= PuzzleCodec.decodeGrid(encoded);
  }

  List<VariantConstraint> get constraints =>
      _constraintsCache ??= PuzzleCodec.decodeConstraints(_constraints);
}
