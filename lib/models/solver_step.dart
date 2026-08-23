import 'position.dart';

/// A candidate: a digit in a particular cell.
class CandidateRef {
  final Position cell;
  final int value;

  const CandidateRef(this.cell, this.value);

  @override
  bool operator ==(Object other) =>
      other is CandidateRef && other.cell == cell && other.value == value;

  @override
  int get hashCode => Object.hash(cell, value);

  @override
  String toString() => '${cell.label}=$value';
}

enum HouseType { row, col, box }

/// A row, column or box. Numbers are 1-based, matching how players read them.
class House {
  final HouseType type;
  final int number;

  const House(this.type, this.number);

  static House? parse(Map<String, dynamic>? json) {
    if (json == null) return null;
    final number = json['number'] as int? ?? 0;
    if (number <= 0) return null;

    switch (json['type'] as String? ?? '') {
      case 'ROW':
        return House(HouseType.row, number);
      case 'COL':
        return House(HouseType.col, number);
      case 'BLOCK':
        return House(HouseType.box, number);
      default:
        return null;
    }
  }

  String get label {
    switch (type) {
      case HouseType.row:
        return 'row $number';
      case HouseType.col:
        return 'column $number';
      case HouseType.box:
        return 'box $number';
    }
  }

  /// The nine cells of this house.
  List<Position> get cells {
    switch (type) {
      case HouseType.row:
        return [for (var c = 0; c < 9; c++) Position(number - 1, c)];
      case HouseType.col:
        return [for (var r = 0; r < 9; r++) Position(r, number - 1)];
      case HouseType.box:
        final br = ((number - 1) ~/ 3) * 3;
        final bc = ((number - 1) % 3) * 3;
        return [
          for (var r = br; r < br + 3; r++)
            for (var c = bc; c < bc + 3; c++) Position(r, c),
        ];
    }
  }

  bool contains(Position cell) {
    switch (type) {
      case HouseType.row:
        return cell.row == number - 1;
      case HouseType.col:
        return cell.col == number - 1;
      case HouseType.box:
        return cell.boxIndex == number - 1;
    }
  }

  /// The three houses a cell belongs to.
  static List<House> of(Position cell) => [
        House(HouseType.row, cell.row + 1),
        House(HouseType.col, cell.col + 1),
        House(HouseType.box, cell.boxIndex + 1),
      ];

  @override
  bool operator ==(Object other) =>
      other is House && other.type == type && other.number == number;

  @override
  int get hashCode => Object.hash(type, number);
}

/// One node of a solver chain, with the link that carries on from it.
class ChainNode {
  final Position cell;
  final int value;

  /// True when the link leaving this node is strong ("if not this, then that").
  final bool strong;

  const ChainNode({
    required this.cell,
    required this.value,
    required this.strong,
  });
}

/// An Almost Locked Set: n cells holding n+1 digits between them.
class AlsRef {
  final List<Position> cells;
  final Set<int> candidates;

  const AlsRef({required this.cells, required this.candidates});
}

/// A single solving step, exactly as the solver described it.
///
/// This is a faithful decoding of the server's JSON, with no interpretation.
/// Turning it into an explanation is the lesson builder's job.
class SolverStep {
  /// HoDoKu's enum name, e.g. `XY_WING`. Stable, so it is what code switches on.
  final String type;

  /// Display name, e.g. "XY-Wing".
  final String name;

  /// The solver's own compact notation. Kept as a fallback and for debugging.
  final String notation;

  /// Cells forming the pattern.
  final List<Position> cells;

  /// Digits the pattern is about.
  final List<int> values;

  final List<CandidateRef> placements;
  final List<CandidateRef> eliminations;

  final House? house;
  final House? house2;
  final List<House> base;
  final List<House> cover;

  final List<CandidateRef> fins;
  final List<CandidateRef> endoFins;
  final List<CandidateRef> cannibalistic;

  final List<List<ChainNode>> chains;
  final List<AlsRef> alses;

  /// The 81 placed digits this step reasoned over, 0 for empty.
  final List<int> grid;

  /// Candidates per cell, indexed `row * 9 + col`.
  ///
  /// This is what makes real explanation possible: without it the app can say a
  /// cell is a pivot but not what the pivot holds.
  final List<Set<int>> candidates;

  const SolverStep({
    required this.type,
    required this.name,
    required this.notation,
    required this.cells,
    required this.values,
    required this.placements,
    required this.eliminations,
    this.house,
    this.house2,
    this.base = const [],
    this.cover = const [],
    this.fins = const [],
    this.endoFins = const [],
    this.cannibalistic = const [],
    this.chains = const [],
    this.alses = const [],
    required this.grid,
    required this.candidates,
  });

  bool get isPlacement => placements.isNotEmpty;

  Set<int> candidatesOf(Position cell) =>
      candidates[cell.row * 9 + cell.col];

  int valueAt(Position cell) => grid[cell.row * 9 + cell.col];

  /// Digits removed by this step, deduplicated.
  Set<int> get eliminatedValues => {for (final e in eliminations) e.value};

  /// Cells touched by eliminations, deduplicated.
  List<Position> get eliminationCells {
    final seen = <Position>{};
    return [
      for (final e in eliminations)
        if (seen.add(e.cell)) e.cell,
    ];
  }
}
