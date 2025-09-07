import 'package:flutter/material.dart';
import 'dart:async';
import '../models/sudoku_cell.dart';
import '../models/input_mode.dart';
import '../models/puzzle.dart';
import '../models/game_state.dart';
import '../widgets/sudoku_grid.dart';
import '../widgets/number_pad.dart';
import '../services/game_logic_service.dart';

class GameScreen extends StatefulWidget {
  final Puzzle? puzzle;

  const GameScreen({Key? key, this.puzzle}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late List<List<SudokuCell>> grid;
  int? selectedRow, selectedCol;
  Set<String> selectedCells = {};
  int? selectedNumber;
  
  // Always one mode active - default to normal
  InputMode currentInputMode = InputMode.normal;
  
  // Separate state for multi-selection
  bool isMultiSelectActive = false;
  
  bool isPuzzleSolved = false;

  // Undo/Redo system
  List<GameAction> undoStack = [];
  List<GameAction> redoStack = [];

  // Performance optimizations
  Timer? _debounceTimer;
  bool _isUpdating = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Drag state
  bool isDragging = false;

  @override
  void initState() {
    super.initState();
    _initGrid();
    _loadGameState();
    
    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _initGrid() {
    grid = List.generate(9, (i) => List.generate(9, (j) => SudokuCell()));

    final initialGrid =
        widget.puzzle?.initialGrid ??
        List.generate(9, (_) => List.generate(9, (_) => 0));

    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (initialGrid[r][c] != 0) {
          grid[r][c] = SudokuCell(digit: initialGrid[r][c], isGiven: true);
        }
      }
    }
  }

  Future<void> _loadGameState() async {
    if (widget.puzzle?.id != null) {
      final savedState = await GameState.loadFromStorage(widget.puzzle!.id);
      if (savedState != null) {
        _batchUpdate(() {
          grid = GameState.deepCopyGrid(savedState.grid);
          selectedRow = savedState.selectedRow;
          selectedCol = savedState.selectedCol;
          selectedCells = Set.from(savedState.selectedCells);
          isPuzzleSolved = savedState.isPuzzleSolved;
        });
      }
    }
  }

  void _batchUpdate(VoidCallback updates) {
    if (_isUpdating) {
      updates();
      return;
    }
    
    _isUpdating = true;
    updates();
    setState(() {});
    _isUpdating = false;
  }

  void _debouncedSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveProgress();
    });
  }

  Future<void> _saveProgress() async {
    if (widget.puzzle?.id == null) return;

    final gameState = GameState(
      grid: grid,
      selectedRow: selectedRow,
      selectedCol: selectedCol,
      selectedCells: selectedCells,
      elapsedTime: Duration.zero,
      isCompleted: false,
      isPuzzleSolved: isPuzzleSolved,
      puzzleId: widget.puzzle!.id,
      lastPlayedAt: DateTime.now(),
    );

    await gameState.saveToStorage();
  }

  Future<void> _addToUndoStack(
    int row,
    int col,
    SudokuCell previousState,
    SudokuCell newState,
  ) async {
    final action = GameAction(
      row: row,
      col: col,
      previousState: previousState,
      newState: newState,
      type: ActionType.digit,
    );

    undoStack.add(action);
    if (undoStack.length > 100) {
      undoStack.removeAt(0);
    }
    redoStack.clear();
    _debouncedSave();
  }

  Future<void> _undo() async {
    if (undoStack.isEmpty) return;

    final action = undoStack.removeLast();
    redoStack.add(action);

    _batchUpdate(() {
      grid[action.row][action.col] = action.previousState.copy();
    });
    _debouncedSave();
  }

  Future<void> _redo() async {
    if (redoStack.isEmpty) return;

    final action = redoStack.removeLast();
    undoStack.add(action);

    _batchUpdate(() {
      grid[action.row][action.col] = action.newState.copy();
    });
    _debouncedSave();
  }

  void _onCellTapped(int row, int col) {
    if (_isUpdating || isDragging) return;
    
    _batchUpdate(() {
      if (isMultiSelectActive) {
        // In multi-select mode, toggle cell selection
        final cellKey = '$row-$col';
        if (selectedCells.contains(cellKey)) {
          selectedCells.remove(cellKey);
        } else {
          selectedCells.add(cellKey);
        }
        
        // Clear single selection when multi-selecting
        selectedRow = null;
        selectedCol = null;
      } else {
        // Normal single selection mode
        selectedCells.clear();
        
        if (selectedRow == row && selectedCol == col) {
          // Deselect if tapping same cell
          selectedRow = null;
          selectedCol = null;
        } else {
          selectedRow = row;
          selectedCol = col;
        }
      }
      
      _updateSelectedNumber();
    });
  }

  void _onCellDragStart(int row, int col) {
    if (_isUpdating) return;
    
    _batchUpdate(() {
      isDragging = true;
      
      // Always enter multi-select mode on drag
      isMultiSelectActive = true;
      selectedRow = null;
      selectedCol = null;
      selectedCells.clear();
      selectedCells.add('$row-$col');
      
      _updateSelectedNumber();
    });
  }

  void _onCellDragUpdate(int row, int col) {
    if (isDragging && !_isUpdating) {
      _batchUpdate(() {
        selectedCells.add('$row-$col');
        _updateSelectedNumber();
      });
    }
  }

  void _onCellDragEnd() {
    if (_isUpdating) return;
    
    _batchUpdate(() {
      isDragging = false;
      _updateSelectedNumber();
    });
  }

  void _updateSelectedNumber() {
    if (selectedRow != null && selectedCol != null) {
      final cell = grid[selectedRow!][selectedCol!];
      selectedNumber = cell.digit;
    } else if (selectedCells.isNotEmpty) {
      final firstCellKey = selectedCells.first;
      final parts = firstCellKey.split('-');
      final r = int.parse(parts[0]);
      final c = int.parse(parts[1]);
      selectedNumber = grid[r][c].digit;
    } else {
      selectedNumber = null;
    }
  }

  Future<void> _onNumberPressed(int number) async {
    if (isMultiSelectActive && selectedCells.isNotEmpty) {
      await _handleMultiSelect(number);
    } else if (selectedRow != null && selectedCol != null) {
      await _handleSingleCell(selectedRow!, selectedCol!, number);
    }

    _batchUpdate(() {
      selectedNumber = number;
    });
  }

  Future<void> _handleSingleCell(int row, int col, int number) async {
    final cell = grid[row][col];
    if (cell.isGiven) return;

    final previousState = cell.copy();
    
    // Use the game logic service to apply the action
    GameLogicService.applyCellAction(cell, number, currentInputMode);

    final newState = cell.copy();
    await _addToUndoStack(row, col, previousState, newState);

    _batchUpdate(() {});
    await _checkPuzzleCompletion();
  }

  Future<void> _handleMultiSelect(int number) async {
    for (final cellKey in selectedCells) {
      final parts = cellKey.split('-');
      final r = int.parse(parts[0]);
      final c = int.parse(parts[1]);
      await _handleSingleCell(r, c, number);
    }
  }

  Future<void> _onColorPressed(int colorIndex) async {
    // Only works in color mode
    if (currentInputMode != InputMode.color) return;
    
    await _onNumberPressed(colorIndex);
  }

  Future<void> _onClearPressed() async {
    if (isMultiSelectActive && selectedCells.isNotEmpty) {
      for (final cellKey in selectedCells) {
        final parts = cellKey.split('-');
        final r = int.parse(parts[0]);
        final c = int.parse(parts[1]);
        final cell = grid[r][c];
        if (!cell.isGiven) {
          final previousState = cell.copy();
          GameLogicService.clearCell(cell);
          final newState = cell.copy();
          await _addToUndoStack(r, c, previousState, newState);
        }
      }
    } else if (selectedRow != null && selectedCol != null) {
      final cell = grid[selectedRow!][selectedCol!];
      if (!cell.isGiven) {
        final previousState = cell.copy();
        GameLogicService.clearCell(cell);
        final newState = cell.copy();
        await _addToUndoStack(selectedRow!, selectedCol!, previousState, newState);
      }
    }

    _batchUpdate(() {});
  }

  void _onModeChanged(InputMode mode) {
    _batchUpdate(() {
      currentInputMode = mode;
    });
  }

  void _toggleMultiSelect() {
    _batchUpdate(() {
      isMultiSelectActive = !isMultiSelectActive;
      
      if (!isMultiSelectActive) {
        // Exiting multi-select mode - clear multiple selections
        selectedCells.clear();
      } else {
        // Entering multi-select mode - clear single selection
        selectedRow = null;
        selectedCol = null;
      }
      
      _updateSelectedNumber();
    });
  }

  Future<void> _checkPuzzleCompletion() async {
    bool isComplete = GameLogicService.isPuzzleSolved(grid);

    if (isComplete && !isPuzzleSolved) {
      _batchUpdate(() {
        isPuzzleSolved = true;
      });
      await _saveProgress();
      
      // Show completion dialog
      if (mounted) {
        _showCompletionDialog();
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🎉 Congratulations!'),
          content: const Text('You have successfully completed the puzzle!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Return to menu
              },
              child: const Text('Back to Menu'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _restartPuzzle();
              },
              child: const Text('Play Again'),
            ),
          ],
        );
      },
    );
  }

  void _restartPuzzle() {
    _batchUpdate(() {
      _initGrid();
      selectedRow = null;
      selectedCol = null;
      selectedCells.clear();
      selectedNumber = null;
      isMultiSelectActive = false;
      isPuzzleSolved = false;
      undoStack.clear();
      redoStack.clear();
      currentInputMode = InputMode.normal;
    });
    
    if (widget.puzzle?.id != null) {
      GameState.clearSavedState(widget.puzzle!.id);
    }
  }

  void _onBackPressed() {
    Navigator.of(context).pop();
  }

  Set<String> _getRelatedCells() {
    if (selectedRow == null || selectedCol == null) return {};
    return GameLogicService.getRelatedCells(selectedRow!, selectedCol!);
  }

  Set<String> _getCellsWithSameNumber() {
    if (selectedNumber == null) return {};
    return GameLogicService.getSameNumberCells(grid, selectedNumber!);
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = widget.puzzle;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 252, 252, 252),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _onBackPressed,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              puzzle?.title ?? 'Puzzle #1',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'by ${puzzle?.author ?? 'Unknown'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          // Current mode indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getModeColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              currentInputMode.displayName,
              style: TextStyle(
                color: _getModeColor(),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _restartPuzzle,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Puzzle info and status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (puzzle != null) ...[
                    _buildInfoChip(puzzle.type, _getTypeColor(puzzle.type)),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      puzzle.difficulty,
                      _getDifficultyColor(puzzle.difficulty),
                    ),
                  ],
                  if (isMultiSelectActive) ...[
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      '${selectedCells.length} selected',
                      Colors.purple,
                    ),
                  ],
                  if (isPuzzleSolved) ...[
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.check_circle, color: Colors.green),
                    ),
                  ],
                ],
              ),
            ),

            // Grid
            Expanded(
              flex: 7,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    child: SudokuGrid(
                      grid: grid,
                      selectedRow: selectedRow,
                      selectedCol: selectedCol,
                      relatedCells: _getRelatedCells(),
                      selectedCells: selectedCells,
                      sameNumberCells: _getCellsWithSameNumber(),
                      onCellTapped: _onCellTapped,
                      onCellDragStart: _onCellDragStart,
                      onCellDragUpdate: _onCellDragUpdate,
                      onCellDragEnd: _onCellDragEnd,
                      variantConstraints: puzzle?.variantConstraints,
                    ),
                  ),
                ),
              ),
            ),

            // Number pad
            Expanded(
              flex: 3,
              child: NumberPad(
                currentMode: currentInputMode,
                isMultiSelectActive: isMultiSelectActive,
                onNumberPressed: _onNumberPressed,
                onColorPressed: _onColorPressed,
                onClearPressed: _onClearPressed,
                onModeChanged: _onModeChanged,
                onMultiSelectToggle: _toggleMultiSelect,
                onUndo: _undo,
                onRedo: _redo,
                canUndo: undoStack.isNotEmpty,
                canRedo: redoStack.isNotEmpty,
                selectedCells: selectedCells,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getModeColor() {
    switch (currentInputMode) {
      case InputMode.normal:
        return Colors.blue;
      case InputMode.corner:
        return Colors.orange;
      case InputMode.center:
        return Colors.green;
      case InputMode.color:
        return Colors.purple;
      case InputMode.multiSelect:
        return Colors.teal;
    }
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'classic': return Colors.blue;
      case 'thermometer': return Colors.red;
      case 'kropki': return Colors.green;
      case 'killer': return Colors.purple;
      case 'xv': return Colors.orange;
      case 'german whispers': return Colors.teal;
      case 'sandwich': return Colors.brown;
      default: return Colors.grey;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy': return Colors.green;
      case 'medium': return Colors.orange;
      case 'hard': return Colors.red;
      case 'expert': return Colors.purple;
      default: return Colors.grey;
    }
  }
}