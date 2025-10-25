// File path: lib/models/variant_constraint.dart

/// Types of variant constraints that can be applied to Sudoku puzzles
enum ConstraintType {
  KROPKI_WHITE, // Two cells differ by 1 (consecutive)
  KROPKI_BLACK, // Two cells are in 2:1 ratio
  // Future variants can be added here:
  // KILLER_CAGE,
  // THERMO,
  // ARROW,
  // etc.
}

/// Represents a constraint between two cells in the grid
class VariantConstraint {
  final ConstraintType type;
  final int row1;
  final int col1;
  final int row2;
  final int col2;

  const VariantConstraint({
    required this.type,
    required this.row1,
    required this.col1,
    required this.row2,
    required this.col2,
  });

  /// Checks if this constraint is between two specific cells (order independent)
  bool isBetween(int r1, int c1, int r2, int c2) {
    return (row1 == r1 && col1 == c1 && row2 == r2 && col2 == c2) ||
        (row1 == r2 && col1 == c2 && row2 == r1 && col2 == c1);
  }

  /// Checks if this constraint involves a specific cell
  bool involvesCell(int row, int col) {
    return (row1 == row && col1 == col) || (row2 == row && col2 == col);
  }

  /// Returns the other cell in the constraint given one cell
  (int, int)? getOtherCell(int row, int col) {
    if (row1 == row && col1 == col) {
      return (row2, col2);
    } else if (row2 == row && col2 == col) {
      return (row1, col1);
    }
    return null;
  }

  /// Determines orientation: 'horizontal' or 'vertical'
  String get orientation {
    if (row1 == row2) return 'horizontal';
    if (col1 == col2) return 'vertical';
    throw Exception('Invalid constraint: cells are not adjacent');
  }

  /// JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'row1': row1,
      'col1': col1,
      'row2': row2,
      'col2': col2,
    };
  }

  factory VariantConstraint.fromJson(Map<String, dynamic> json) {
    return VariantConstraint(
      type: ConstraintType.values[json['type']],
      row1: json['row1'],
      col1: json['col1'],
      row2: json['row2'],
      col2: json['col2'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VariantConstraint &&
        other.type == type &&
        ((other.row1 == row1 &&
                other.col1 == col1 &&
                other.row2 == row2 &&
                other.col2 == col2) ||
            (other.row1 == row2 &&
                other.col1 == col2 &&
                other.row2 == row1 &&
                other.col2 == col1));
  }

  @override
  int get hashCode {
    // Order-independent hash
    final hash1 = row1.hashCode ^ col1.hashCode;
    final hash2 = row2.hashCode ^ col2.hashCode;
    return type.hashCode ^ (hash1 + hash2);
  }

  @override
  String toString() {
    return 'VariantConstraint($type, ($row1,$col1)-($row2,$col2))';
  }
}