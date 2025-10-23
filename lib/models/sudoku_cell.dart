// File path: lib/models/sudoku_cell.dart
import 'package:flutter/material.dart';

class SudokuCell {
  // Position (immutable)
  final int row;
  final int col;

  // Core data
  int? number; // Main number (1-9 or null)
  Set<int> sideNotes; // Side note numbers
  Set<int> centerNotes; // Center note numbers

  // Visual state
  Color? cellColor; // Background color (for coloring mode)
  bool isSelected; // Dark blue selection
  bool isHighlighted; // Light blue highlight
  bool isError; // Red border for wrong numbers
  bool isGiven; // Original puzzle number (unchangeable)

  // Default constructor
  SudokuCell({
    required this.row,
    required this.col,
    this.number,
    Set<int>? sideNotes,
    Set<int>? centerNotes,
    this.cellColor,
    this.isSelected = false,
    this.isHighlighted = true,
    this.isError = false,
    this.isGiven = false,
  })  : sideNotes = sideNotes ?? <int>{},
        centerNotes = centerNotes ?? <int>{};

  // Named constructor for given cells (original puzzle numbers)
  SudokuCell.given({
    required this.row,
    required this.col,
    required int this.number,
  })  : sideNotes = <int>{},
        centerNotes = <int>{},
        cellColor = null,
        isSelected = false,
        isHighlighted = false,
        isError = false,
        isGiven = true;

  // Named constructor for empty cells
  SudokuCell.empty({
    required this.row,
    required this.col,
  })  : number = null,
        sideNotes = <int>{},
        centerNotes = <int>{},
        cellColor = null,
        isSelected = false,
        isHighlighted = false,
        isError = false,
        isGiven = false;

  // Copy constructor for state management
  SudokuCell copyWith({
    int? number,
    Set<int>? sideNotes,
    Set<int>? centerNotes,
    Color? cellColor,
    bool? isSelected,
    bool? isHighlighted,
    bool? isError,
    bool? isGiven,
    bool clearNumber = false, // Add this flag
    bool clearColor = false, // Add this flag
  }) {
    return SudokuCell(
      row: row,
      col: col,
      number: clearNumber ? null : (number ?? this.number),
      sideNotes: sideNotes ?? Set.from(this.sideNotes),
      centerNotes: centerNotes ?? Set.from(this.centerNotes),
      cellColor: clearColor ? null : (cellColor ?? this.cellColor),
      isSelected: isSelected ?? this.isSelected,
      isHighlighted: isHighlighted ?? this.isHighlighted,
      isError: isError ?? this.isError,
      isGiven: isGiven ?? this.isGiven,
    );
  }

  // ADD THESE TWO METHODS:
  Map<String, dynamic> toJson() {
    return {
      'row': row,
      'col': col,
      'number': number,
      'sideNotes': sideNotes.toList(),
      'centerNotes': centerNotes.toList(),
      'cellColor': cellColor?.value, // Store color as integer
      'isGiven': isGiven,
    };
  }

  factory SudokuCell.fromJson(Map<String, dynamic> json) {
    return SudokuCell(
      row: json['row'],
      col: json['col'],
      number: json['number'],
      sideNotes: Set<int>.from(json['sideNotes'] ?? []),
      centerNotes: Set<int>.from(json['centerNotes'] ?? []),
      cellColor: json['cellColor'] != null ? Color(json['cellColor']) : null,
      isGiven: json['isGiven'] ?? false,
    );
  }

  // Clear all user input (keep given numbers)
  void clear() {
    if (!isGiven) {
      number = null;
      sideNotes.clear();
      centerNotes.clear();
      cellColor = null;
    }
    isError = false;
  }

  // Add/remove side note
  void toggleSideNote(int noteNumber) {
    if (isGiven) return;

    if (sideNotes.contains(noteNumber)) {
      sideNotes.remove(noteNumber);
    } else {
      sideNotes.add(noteNumber);
    }
  }

  // Add/remove center note
  void toggleCenterNote(int noteNumber) {
    if (isGiven) return;

    if (centerNotes.contains(noteNumber)) {
      centerNotes.remove(noteNumber);
    } else {
      centerNotes.add(noteNumber);
    }
  }

  // Set main number (clears notes)
  void setNumber(int? newNumber) {
    if (isGiven) return;

    number = newNumber;
    if (newNumber != null) {
      // Clear notes when setting a main number
      sideNotes.clear();
      centerNotes.clear();
    }
  }

  // Set cell color
  void setColor(Color? color) {
    cellColor = color;
  }

  // Check if cell is empty (no number, no notes, no color)
  bool get isEmpty {
    return number == null &&
        sideNotes.isEmpty &&
        centerNotes.isEmpty &&
        cellColor == null;
  }

  // Check if cell has any user input
  bool get hasUserInput {
    return !isGiven && !isEmpty;
  }

  // Get sorted side notes as list
  List<int> get sortedSideNotes {
    return sideNotes.toList()..sort();
  }

  // Get sorted center notes as list
  List<int> get sortedCenterNotes {
    return centerNotes.toList()..sort();
  }

  // Debug string representation
  @override
  String toString() {
    return 'SudokuCell($row,$col): number=$number, sides=$sideNotes, centers=$centerNotes, given=$isGiven';
  }

  // Equality comparison
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SudokuCell && other.row == row && other.col == col;
  }

  @override
  int get hashCode {
    return row.hashCode ^ col.hashCode;
  }
}
