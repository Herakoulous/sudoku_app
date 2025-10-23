// File path: lib/models/game_state.dart
import '../models/sudoku_cell.dart';
import '../models/action.dart' as game_action;
import '../models/position.dart';
import '../data/puzzles.dart';

enum GameMode { NORMAL, SIDE_NOTES, CENTER_NOTES, COLORING }

enum SelectionMode { SINGLE, MULTIPLE }

class GameState {
  // Grid data
  List<List<SudokuCell>> grid;

  // Current modes
  GameMode currentMode;
  SelectionMode selectionMode;

  // Selection tracking
  Set<Position> selectedCells;
  Set<Position> highlightedCells;

  // Game info
  int difficulty;
  String puzzleId;
  Duration elapsedTime;
  bool isPaused;

  // Undo/Redo system
  List<game_action.Action> actionHistory;
  int currentActionIndex;

  GameState({
    required this.difficulty,
    required this.puzzleId,
    List<List<SudokuCell>>? grid,
    this.currentMode = GameMode.NORMAL,
    this.selectionMode = SelectionMode.SINGLE,
    Set<Position>? selectedCells,
    Set<Position>? highlightedCells,
    this.elapsedTime = Duration.zero,
    this.isPaused = false,
    List<game_action.Action>? actionHistory,
    this.currentActionIndex = -1,
  })  : grid = grid ?? GameState._createEmptyGrid(),
        selectedCells = selectedCells ?? <Position>{},
        highlightedCells = highlightedCells ?? <Position>{},
        actionHistory = actionHistory ?? <game_action.Action>[];

  // ADD THIS METHOD:
  static List<List<SudokuCell>> _createEmptyGrid() {
    return List.generate(
      9,
      (row) => List.generate(
        9,
        (col) => SudokuCell.empty(row: row, col: col),
      ),
    );
  }

// Then replace the GameState.newGame factory with this:
  factory GameState.newGame(String puzzleId, int difficulty) {
    final puzzleData = Puzzles.getPuzzle(puzzleId);

    if (puzzleData == null) {
      return GameState(
        puzzleId: puzzleId,
        difficulty: difficulty,
      );
    }

    final grid = List.generate(9, (row) {
      return List.generate(9, (col) {
        final value = puzzleData.grid[row][col];
        if (value != 0) {
          return SudokuCell.given(row: row, col: col, number: value);
        } else {
          return SudokuCell.empty(row: row, col: col);
        }
      });
    });

    return GameState(
      puzzleId: puzzleId,
      difficulty: puzzleData.difficulty,
      grid: grid,
    );
  }

  // JSON serialization methods
  Map<String, dynamic> toJson() {
    return {
      'difficulty': difficulty,
      'puzzleId': puzzleId,
      'grid':
          grid.map((row) => row.map((cell) => cell.toJson()).toList()).toList(),
      'currentMode': currentMode.index,
      'selectionMode': selectionMode.index,
      'elapsedTime': elapsedTime.inSeconds,
      'currentActionIndex': currentActionIndex,
      'actionHistory':
          actionHistory.map((action) => action.toJson()).toList(), // THIS LINE
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    final gridData = json['grid'] as List;
    final grid = gridData
        .map((row) => (row as List)
            .map((cellJson) => SudokuCell.fromJson(cellJson))
            .toList())
        .toList();

    // Restore action history
    final actionHistoryData = json['actionHistory'] as List? ?? [];
    final actionHistory = actionHistoryData
        .map((actionJson) => game_action.Action.fromJson(actionJson))
        .toList();

    return GameState(
      difficulty: json['difficulty'],
      puzzleId: json['puzzleId'],
      grid: grid,
      currentMode: GameMode.values[json['currentMode'] ?? 0],
      selectionMode: SelectionMode.values[json['selectionMode'] ?? 0],
      elapsedTime: Duration(seconds: json['elapsedTime'] ?? 0),
      currentActionIndex: json['currentActionIndex'] ?? -1,
      actionHistory: actionHistory, // THIS LINE
    );
  }
}
