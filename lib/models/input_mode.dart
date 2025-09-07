enum InputMode {
  normal,
  corner,
  center,
  color,
  sideNotes,
  centerNotes,
  coloring,
}

extension InputModeExtension on InputMode {
  String get displayName {
    switch (this) {
      case InputMode.normal:
        return 'Normal';
      case InputMode.corner:
        return 'Corner';
      case InputMode.center:
        return 'Center';
      case InputMode.color:
        return 'Color';
      case InputMode.sideNotes:
        return 'Side Notes';
      case InputMode.centerNotes:
        return 'Center Notes';
      case InputMode.coloring:
        return 'Coloring';
    }
  }
}