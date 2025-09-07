class SudokuCell {
  int? digit;
  Set<int> cornerMarks;
  Set<int> centerMarks;
  int colorHighlight; // 0 = no color, 1-9 = different colors
  bool isGiven;
  bool hasConflict;

  SudokuCell({
    this.digit,
    this.cornerMarks = const {},
    this.centerMarks = const {},
    this.colorHighlight = 0,
    this.isGiven = false,
    this.hasConflict = false,
  });

  SudokuCell copyWith({
    int? digit,
    Set<int>? cornerMarks,
    Set<int>? centerMarks,
    int? colorHighlight,
    bool? isGiven,
    bool? hasConflict,
  }) {
    return SudokuCell(
      digit: digit ?? this.digit,
      cornerMarks: cornerMarks ?? this.cornerMarks,
      centerMarks: centerMarks ?? this.centerMarks,
      colorHighlight: colorHighlight ?? this.colorHighlight,
      isGiven: isGiven ?? this.isGiven,
      hasConflict: hasConflict ?? this.hasConflict,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'digit': digit,
      'cornerMarks': cornerMarks.toList(),
      'centerMarks': centerMarks.toList(),
      'colorHighlight': colorHighlight,
      'isGiven': isGiven,
      'hasConflict': hasConflict,
    };
  }

  static SudokuCell fromJson(Map<String, dynamic> json) {
    return SudokuCell(
      digit: json['digit'],
      cornerMarks: Set<int>.from(json['cornerMarks'] ?? []),
      centerMarks: Set<int>.from(json['centerMarks'] ?? []),
      colorHighlight: json['colorHighlight'] ?? 0,
      isGiven: json['isGiven'] ?? false,
      hasConflict: json['hasConflict'] ?? false,
    );
  }
}