// File path: lib/models/game_state.dart
import '../models/sudoku_cell.dart';
import '../models/action.dart' as game_action;
import '../models/position.dart';
import '../models/variant_constraint.dart';
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
  bool isCompleted; // 🔥 NEW: Track if puzzle is completed

  // Undo/Redo system
  List<game_action.Action> actionHistory;
  int currentActionIndex;

  // Variant constraints
  List<VariantConstraint> constraints;

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
    this.isCompleted = false, // 🔥 NEW: Default to false
    List<game_action.Action>? actionHistory,
    this.currentActionIndex = -1,
    List<VariantConstraint>? constraints,
  })  : grid = grid ?? GameState._createEmptyGrid(),
        selectedCells = selectedCells ?? <Position>{},
        highlightedCells = highlightedCells ?? <Position>{},
        actionHistory = actionHistory ?? <game_action.Action>[],
        constraints = constraints ?? <VariantConstraint>[];

  // 🔥 NEW: Getter for elapsed seconds (used by SaveService)
  int get elapsedSeconds => elapsedTime.inSeconds;

  // 🔥 NEW: Getter for current grid (used by level_selection_screen)
  List<List<int>> get currentGrid {
    return grid.map((row) {
      return row.map((cell) => cell.number ?? 0).toList();
    }).toList();
  }

  // Create empty grid helper
  static List<List<SudokuCell>> _createEmptyGrid() {
    return List.generate(
      9,
      (row) => List.generate(
        9,
        (col) => SudokuCell.empty(row: row, col: col),
      ),
    );
  }

  factory GameState.newGame(
    String puzzleId,
    int difficulty, {
    List<VariantConstraint>? constraints,
  }) {
    final puzzleData = Puzzles.getPuzzle(puzzleId);

    print('🔍 Creating new game for puzzle: $puzzleId');
    print('🔍 Puzzle data found: ${puzzleData != null}');

    if (puzzleData == null) {
      print('❌ Puzzle data is NULL!');
      return GameState(
        puzzleId: puzzleId,
        difficulty: difficulty,
        constraints: constraints,
      );
    }

    print('🔍 Puzzle has ${puzzleData.constraints.length} constraints');
    print('🔍 Constraints: ${puzzleData.constraints}');

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
      constraints: puzzleData.constraints,
    );
  }

  // 🔥 NEW: Method to mark puzzle as completed
  void markCompleted() {
    isCompleted = true;
    print('✅ Puzzle $puzzleId marked as completed!');
  }

  // 🔥 NEW: Check if grid is fully filled and valid
  bool isGridComplete() {
    // Check if all cells are filled
    for (var row in grid) {
      for (var cell in row) {
        if (cell.number == null || cell.number == 0) {
          return false;
        }
      }
    }

    // Check if there are any errors
    for (var row in grid) {
      for (var cell in row) {
        if (cell.isError) {
          return false;
        }
      }
    }

    return true;
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
      'isPaused': isPaused,
      'isCompleted': isCompleted, // 🔥 NEW
      'currentActionIndex': currentActionIndex,
      'actionHistory': actionHistory.map((action) => action.toJson()).toList(),
      'constraints': constraints.map((c) => c.toJson()).toList(),
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

    // Restore constraints
    final constraintsData = json['constraints'] as List? ?? [];
    final constraints = constraintsData
        .map((constraintJson) => VariantConstraint.fromJson(constraintJson))
        .toList();

    return GameState(
      difficulty: json['difficulty'],
      puzzleId: json['puzzleId'],
      grid: grid,
      currentMode: GameMode.values[json['currentMode'] ?? 0],
      selectionMode: SelectionMode.values[json['selectionMode'] ?? 0],
      elapsedTime: Duration(seconds: json['elapsedTime'] ?? 0),
      isPaused: json['isPaused'] ?? false,
      isCompleted: json['isCompleted'] ?? false, // 🔥 NEW
      currentActionIndex: json['currentActionIndex'] ?? -1,
      actionHistory: actionHistory,
      constraints: constraints,
    );
  }
}
