class Position {
  final int row;
  final int col;

  Position(this.row, this.col);

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
