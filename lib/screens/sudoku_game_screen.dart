import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/sudoku_cell.dart';
import '../models/input_mode.dart';
import '../models/game_state.dart';
import '../widgets/sudoku_grid_widget.dart';
import '../widgets/sudoku_number_pad.dart';
import '../widgets/difficulty_stars.dart';
import '../services/game_logic_service.dart';
import '../services/storage_service.dart';

class SudokuGameScreen extends StatefulWidget {
  final String puzzleName;
  final int difficulty;
  final List<List<int>> initialGrid;

  const SudokuGameScreen({
    Key? key,
    required this.puzzleName,
    required this.difficulty,
    required this.initialGrid,
  }) : super(key: key);

  @override
  State<SudokuGameScreen> createState() => _SudokuGameScreenState();
}

class _SudokuGameScreenState extends State<SudokuGameScreen> {
  late List<List<SudokuCell>> grid;
  late Set<String> selectedCells;
  late Set<String> highlightedCells;
  late InputMode currentMode;
  late Timer gameTimer;
  late Duration gameTime;
  late List<GameAction> undoStack;
  late List<GameAction> redoStack;
  
  bool isMultiSelectMode = false;
  bool isDragging = false;
  String? dragStartCell;

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _startTimer();
    _loadGameState();
  }

  @override
  void dispose() {
    gameTimer.cancel();
    _saveGameState();
    super.dispose();
  }

  void _initializeGame() {
    grid = List.generate(9, (row) => 
      List.generate(9, (col) => SudokuCell(
        digit: widget.initialGrid[row][col] == 0 ? null : widget.initialGrid[row][col],
        isGiven: widget.initialGrid[row][col] != 0,
      ))
    );
    
    selectedCells = <String>{};
    highlightedCells = <String>{};
    currentMode = InputMode.normal;
    gameTime = Duration.zero;
    undoStack = [];
    redoStack = [];
  }

  void _startTimer() {
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        gameTime = Duration(seconds: gameTime.inSeconds + 1);
      });
    });
  }

  void _loadGameState() async {
    final savedState = await StorageService.loadGameState(widget.puzzleName);
    if (savedState != null) {
      setState(() {
        gameTime = savedState.gameTime;
        grid = savedState.grid;
        undoStack = savedState.undoStack;
        redoStack = savedState.redoStack;
      });
    }
  }

  void _saveGameState() async {
    final gameState = GameState(
      puzzleName: widget.puzzleName,
      grid: grid,
      gameTime: gameTime,
      undoStack: undoStack,
      redoStack: redoStack,
    );
    await StorageService.saveGameState(gameState);
  }

  void _onCellTapped(int row, int col) {
    setState(() {
      if (isMultiSelectMode) {
        _toggleCellSelection(row, col);
      } else {
        _selectSingleCell(row, col);
      }
      _updateHighlightedCells();
    });
  }

  void _onCellDragStart(int row, int col) {
    setState(() {
      isDragging = true;
      dragStartCell = '$row-$col';
      _selectSingleCell(row, col);
      _updateHighlightedCells();
    });
  }

  void _onCellDragUpdate(int row, int col) {
    if (isDragging) {
      setState(() {
        _toggleCellSelection(row, col);
        _updateHighlightedCells();
      });
    }
  }

  void _onCellDragEnd() {
    setState(() {
      isDragging = false;
      dragStartCell = null;
    });
  }

  void _selectSingleCell(int row, int col) {
    selectedCells.clear();
    selectedCells.add('$row-$col');
  }

  void _toggleCellSelection(int row, int col) {
    final cellKey = '$row-$col';
    if (selectedCells.contains(cellKey)) {
      selectedCells.remove(cellKey);
    } else {
      selectedCells.add(cellKey);
    }
  }

  void _updateHighlightedCells() {
    highlightedCells.clear();
    for (final cellKey in selectedCells) {
      final parts = cellKey.split('-');
      final row = int.parse(parts[0]);
      final col = int.parse(parts[1]);
      
      // Add same row, column, and 3x3 box cells
      for (int r = 0; r < 9; r++) {
        highlightedCells.add('$r-$col');
      }
      for (int c = 0; c < 9; c++) {
        highlightedCells.add('$row-$c');
      }
      
      // Add 3x3 box
      final boxRow = (row ~/ 3) * 3;
      final boxCol = (col ~/ 3) * 3;
      for (int r = boxRow; r < boxRow + 3; r++) {
        for (int c = boxCol; c < boxCol + 3; c++) {
          highlightedCells.add('$r-$c');
        }
      }
    }
    
    // Remove selected cells from highlighted cells
    highlightedCells.removeAll(selectedCells);
  }

  void _onNumberPressed(int number) {
    if (selectedCells.isEmpty) return;
    
    final action = GameAction(
      type: ActionType.input,
      cells: List.from(selectedCells),
      mode: currentMode,
      number: number,
      timestamp: DateTime.now(),
    );
    
    _applyAction(action);
    _addToUndoStack(action);
    redoStack.clear();
  }

  void _applyAction(GameAction action) {
    setState(() {
      for (final cellKey in action.cells) {
        final parts = cellKey.split('-');
        final row = int.parse(parts[0]);
        final col = int.parse(parts[1]);
        final cell = grid[row][col];
        
        if (cell.isGiven) continue;
        
        GameLogicService.applyCellAction(cell, action.number, action.mode);
      }
    });
  }

  void _addToUndoStack(GameAction action) {
    undoStack.add(action);
    if (undoStack.length > 100) {
      undoStack.removeAt(0);
    }
  }

  void _undo() {
    if (undoStack.isEmpty) return;
    
    final action = undoStack.removeLast();
    redoStack.add(action);
    
    setState(() {
      for (final cellKey in action.cells) {
        final parts = cellKey.split('-');
        final row = int.parse(parts[0]);
        final col = int.parse(parts[1]);
        final cell = grid[row][col];
        
        if (cell.isGiven) continue;
        
        GameLogicService.undoCellAction(cell, action.number, action.mode);
      }
    });
  }

  void _redo() {
    if (redoStack.isEmpty) return;
    
    final action = redoStack.removeLast();
    undoStack.add(action);
    _applyAction(action);
  }

  void _clearSelectedCells() {
    setState(() {
      for (final cellKey in selectedCells) {
        final parts = cellKey.split('-');
        final row = int.parse(parts[0]);
        final col = int.parse(parts[1]);
        final cell = grid[row][col];
        
        if (cell.isGiven) continue;
        
        cell.digit = null;
        cell.cornerMarks.clear();
        cell.centerMarks.clear();
        cell.colorHighlight = 0;
      }
    });
  }

  void _restartPuzzle() {
    setState(() {
      _initializeGame();
      gameTime = Duration.zero;
      undoStack.clear();
      redoStack.clear();
    });
  }

  void _showRules() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sudoku Rules'),
        content: const Text(
          'Fill the 9×9 grid with digits so that each column, each row, '
          'and each of the nine 3×3 subgrids that compose the grid contain '
          'all of the digits from 1 to 9. Each number can only appear once '
          'in each row, column, and 3×3 box.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _saveGameState();
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.puzzleName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _restartPuzzle,
            ),
            Text(
              _formatTime(gameTime),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Difficulty stars
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DifficultyStars(difficulty: widget.difficulty),
          ),
          
          // Sudoku grid
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: SudokuGridWidget(
                grid: grid,
                selectedCells: selectedCells,
                highlightedCells: highlightedCells,
                onCellTapped: _onCellTapped,
                onCellDragStart: _onCellDragStart,
                onCellDragUpdate: _onCellDragUpdate,
                onCellDragEnd: _onCellDragEnd,
              ),
            ),
          ),
          
          // Number pad
          Expanded(
            flex: 2,
            child: SudokuNumberPad(
              currentMode: currentMode,
              isMultiSelectMode: isMultiSelectMode,
              onNumberPressed: _onNumberPressed,
              onModeChanged: (mode) => setState(() => currentMode = mode),
              onMultiSelectToggle: () => setState(() => isMultiSelectMode = !isMultiSelectMode),
              onUndo: _undo,
              onRedo: _redo,
              onClear: _clearSelectedCells,
              onRules: _showRules,
              canUndo: undoStack.isNotEmpty,
              canRedo: redoStack.isNotEmpty,
            ),
          ),
        ],
      ),
    );
  }
}
