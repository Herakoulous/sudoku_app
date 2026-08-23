// File path: lib/models/game_state.dart
import '../models/sudoku_cell.dart';
import '../models/action.dart' as game_action;
import '../models/position.dart';
import '../models/variant_constraint.dart';
import '../data/puzzles.dart';
import 'hint_lesson.dart';

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
  String? lastHintExplanation;
  // Variant constraints
  List<VariantConstraint> constraints;
  Position? hintCell; // Position of hinted cell (null if no hint)
  int? hintNumber; // Suggested number (null if no hint)
  String? lastHintType;

  // 🔥 NEW: Hint highlighting fields
  Set<Position>? hintHighlightRows;
  Set<Position>? hintHighlightColumns;
  Set<Position>? hintHighlightCells;
  Set<int>? hintHighlightNumbers;

  /// The hint currently being walked through, and how far into it the player
  /// has read.
  ///
  /// Deliberately not persisted: a lesson is tied to the exact candidate state
  /// the solver reasoned over, and reviving a stale one against a changed board
  /// would explain a position that no longer exists.
  HintLesson? activeLesson;
  int lessonStage = 0;

  /// Hints taken and wrong digits entered during THIS attempt.
  ///
  /// Achievements need to know whether a solve was clean, and the global
  /// counters cannot answer that — they only say how many hints were ever used.
  int hintsUsedThisGame;
  int mistakesThisGame;

  // Add these fields to GameState class:
  int currentHintStep = 1; // Track which hint step we're on
  String? lastGridState; // Track grid state to detect changes
  bool lastHintWasElimination = false; // Track if last hint was elimination

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
    this.hintCell,
    this.hintNumber,
    this.lastHintExplanation,
    this.lastHintType,
    // 🔥 NEW: Hint highlighting parameters
    this.hintHighlightRows,
    this.hintHighlightColumns,
    this.hintHighlightCells,
    this.hintHighlightNumbers,
    this.currentHintStep = 1,
    this.lastGridState,
    this.lastHintWasElimination = false,
    this.hintsUsedThisGame = 0,
    this.mistakesThisGame = 0,
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

// Update clearHint() method:
  void clearHint() {
    activeLesson = null;
    lessonStage = 0;
    hintCell = null;
    hintNumber = null;
    lastHintExplanation = null;
    lastHintType = null;
    hintHighlightRows = null;
    hintHighlightColumns = null;
    hintHighlightCells = null;
    hintHighlightNumbers = null;
    // DON'T reset currentHintStep here - only reset when grid changes
  }

  /// The stage of the lesson currently on screen, if any.
  HintStage? get activeStage {
    final lesson = activeLesson;
    if (lesson == null || lesson.stages.isEmpty) return null;
    return lesson.stages[lessonStage.clamp(0, lesson.stages.length - 1)];
  }

// Add method to get current grid state as string
  String getCurrentGridState() {
    final buffer = StringBuffer();
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        buffer.write(grid[row][col].number ?? 0);
      }
    }
    return buffer.toString();
  }

// Add method to check if grid changed
  bool hasGridChanged() {
    final currentGrid = getCurrentGridState();
    if (lastGridState == null) {
      lastGridState = currentGrid;
      return false;
    }
    final changed = currentGrid != lastGridState;
    lastGridState = currentGrid;
    return changed;
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
      'isCompleted': isCompleted,
      'currentActionIndex': currentActionIndex,
      'actionHistory': actionHistory.map((action) => action.toJson()).toList(),
      'constraints': constraints.map((c) => c.toJson()).toList(),
      // ADD THESE:
      'hintCell': hintCell != null
          ? {'row': hintCell!.row, 'col': hintCell!.col}
          : null,
      'hintNumber': hintNumber,
      'lastHintExplanation': lastHintExplanation,
      'lastHintType': lastHintType,
      // 🔥 NEW: Hint highlighting serialization
      'hintHighlightRows': hintHighlightRows
          ?.map((pos) => {'row': pos.row, 'col': pos.col})
          .toList(),
      'hintHighlightColumns': hintHighlightColumns
          ?.map((pos) => {'row': pos.row, 'col': pos.col})
          .toList(),
      'hintHighlightCells': hintHighlightCells
          ?.map((pos) => {'row': pos.row, 'col': pos.col})
          .toList(),
      'hintHighlightNumbers': hintHighlightNumbers?.toList(),
      // Add to toJson():
      'currentHintStep': currentHintStep,
      'lastGridState': lastGridState,
      'lastHintWasElimination': lastHintWasElimination,
      'hintsUsedThisGame': hintsUsedThisGame,
      'mistakesThisGame': mistakesThisGame,
    };
  }

  // JSON serialization methods
  factory GameState.fromJson(Map<String, dynamic> json) {
    final gridData = json['grid'] as List;
    final grid = gridData
        .map((row) => (row as List)
            .map((cellJson) => SudokuCell.fromJson(cellJson))
            .toList())
        .toList();

    final actionHistoryData = json['actionHistory'] as List? ?? [];
    final actionHistory = actionHistoryData
        .map((actionJson) => game_action.Action.fromJson(actionJson))
        .toList();

    final constraintsData = json['constraints'] as List? ?? [];
    final constraints = constraintsData
        .map((constraintJson) => VariantConstraint.fromJson(constraintJson))
        .toList();

    // ADD THIS:
    Position? hintCell;
    if (json['hintCell'] != null) {
      final hintCellData = json['hintCell'];
      hintCell = Position(hintCellData['row'], hintCellData['col']);
    }

    // 🔥 NEW: Deserialize hint highlighting
    Set<Position>? hintHighlightRows;
    if (json['hintHighlightRows'] != null) {
      final rowsData = json['hintHighlightRows'] as List;
      hintHighlightRows = rowsData
          .map((posData) => Position(posData['row'], posData['col']))
          .toSet();
    }

    Set<Position>? hintHighlightColumns;
    if (json['hintHighlightColumns'] != null) {
      final colsData = json['hintHighlightColumns'] as List;
      hintHighlightColumns = colsData
          .map((posData) => Position(posData['row'], posData['col']))
          .toSet();
    }

    Set<Position>? hintHighlightCells;
    if (json['hintHighlightCells'] != null) {
      final cellsData = json['hintHighlightCells'] as List;
      hintHighlightCells = cellsData
          .map((posData) => Position(posData['row'], posData['col']))
          .toSet();
    }

    Set<int>? hintHighlightNumbers;
    if (json['hintHighlightNumbers'] != null) {
      final numbersData = json['hintHighlightNumbers'] as List;
      hintHighlightNumbers = numbersData.cast<int>().toSet();
    }
    return GameState(
      difficulty: json['difficulty'],
      puzzleId: json['puzzleId'],
      grid: grid,
      currentMode: GameMode.values[json['currentMode'] ?? 0],
      selectionMode: SelectionMode.values[json['selectionMode'] ?? 0],
      elapsedTime: Duration(seconds: json['elapsedTime'] ?? 0),
      isPaused: json['isPaused'] ?? false,
      isCompleted: json['isCompleted'] ?? false,
      currentActionIndex: json['currentActionIndex'] ?? -1,
      actionHistory: actionHistory,
      constraints: constraints,
      hintCell: hintCell,
      hintNumber: json['hintNumber'],
      lastHintType: json['lastHintType'],
      lastHintExplanation: json['lastHintExplanation'],
      hintHighlightRows: hintHighlightRows,
      hintHighlightColumns: hintHighlightColumns,
      hintHighlightCells: hintHighlightCells,
      hintHighlightNumbers: hintHighlightNumbers,
      // 🔥 NEW: Add these
      currentHintStep: json['currentHintStep'] ?? 1,
      lastGridState: json['lastGridState'],
      lastHintWasElimination: json['lastHintWasElimination'] ?? false,
      hintsUsedThisGame: json['hintsUsedThisGame'] ?? 0,
      mistakesThisGame: json['mistakesThisGame'] ?? 0,
    );
  }
}
