class Position {
  final int row;
  final int col;

  const Position(this.row, this.col);

  /// 0-based box index, reading order.
  int get boxIndex => (row ~/ 3) * 3 + (col ~/ 3);

  /// How players say it: r4c7, 1-based. Used throughout hint explanations, so
  /// the wording matches what a solver would read out loud.
  String get label => 'r${row + 1}c${col + 1}';

  /// Whether two cells share a row, column or box — "sees", in sudoku terms.
  /// A cell does not see itself.
  bool sees(Position other) {
    if (this == other) return false;
    return row == other.row || col == other.col || boxIndex == other.boxIndex;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Position && other.row == row && other.col == col;
  }

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  @override
  String toString() => 'Position($row, $col)';

  Map<String, dynamic> toJson() {
    return {
      'row': row,
      'col': col,
    };
  }

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(json['row'], json['col']);
  }
}
