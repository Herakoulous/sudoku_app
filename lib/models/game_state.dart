import 'sudoku_cell.dart';
import 'input_mode.dart';

class GameState {
  final String puzzleName;
  final List<List<SudokuCell>> grid;
  final Duration gameTime;
  final List<GameAction> undoStack;
  final List<GameAction> redoStack;

  GameState({
    required this.puzzleName,
    required this.grid,
    required this.gameTime,
    required this.undoStack,
    required this.redoStack,
  });

  Map<String, dynamic> toJson() {
    return {
      'puzzleName': puzzleName,
      'grid': grid.map((row) => row.map((cell) => cell.toJson()).toList()).toList(),
      'gameTime': gameTime.inSeconds,
      'undoStack': undoStack.map((action) => action.toJson()).toList(),
      'redoStack': redoStack.map((action) => action.toJson()).toList(),
    };
  }

  static GameState fromJson(Map<String, dynamic> json) {
    return GameState(
      puzzleName: json['puzzleName'],
      grid: (json['grid'] as List).map((row) => 
        (row as List).map((cell) => SudokuCell.fromJson(cell)).toList()
      ).toList(),
      gameTime: Duration(seconds: json['gameTime']),
      undoStack: (json['undoStack'] as List).map((action) => GameAction.fromJson(action)).toList(),
      redoStack: (json['redoStack'] as List).map((action) => GameAction.fromJson(action)).toList(),
    );
  }

  bool get isPuzzleSolved {
    // Simple check - in a real implementation, this would verify the grid is complete and valid
    return false;
  }

  Duration get elapsedTime => gameTime;
}

class GameAction {
  final ActionType type;
  final List<String> cells;
  final InputMode mode;
  final int number;
  final DateTime timestamp;

  GameAction({
    required this.type,
    required this.cells,
    required this.mode,
    required this.number,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'cells': cells,
      'mode': mode.toString(),
      'number': number,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  static GameAction fromJson(Map<String, dynamic> json) {
    return GameAction(
      type: ActionType.values.firstWhere((e) => e.toString() == json['type']),
      cells: List<String>.from(json['cells']),
      mode: InputMode.values.firstWhere((e) => e.toString() == json['mode']),
      number: json['number'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

enum ActionType {
  input,
  clear,
}