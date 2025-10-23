import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/position.dart';
import '../services/save_service.dart';
import '../models/sudoku_cell.dart';
import '../models/action.dart' as game_action;

bool debug = true;

class GameController extends ChangeNotifier {
  GameState gameState;

  // Save current game state
  Future<void> saveProgress() async {
    await SaveService.saveGame(gameState);
  }

  // Load saved game state
  Future<void> loadProgress() async {
    final savedState = await SaveService.loadGame(gameState.puzzleId);
    if (savedState != null) {
      gameState = savedState;
      updateHighlights();
      notifyListeners();
    }
  }

  GameController({
    required String puzzleId,
    required int difficulty,
  }) : gameState = GameState.newGame(puzzleId, difficulty);

  void handleCellTap(int row, int col) {
    final pos = Position(row, col);

    // Check selection mode
    if (gameState.selectionMode == SelectionMode.SINGLE) {
      // SINGLE selection mode
      if (gameState.selectedCells.contains(pos)) {
        // Tapping already selected cell - unselect it
        gameState.selectedCells.clear();
        print('🔘 Cell ($row, $col) unselected');
      } else {
        // Select new cell
        gameState.selectedCells.clear();
        gameState.selectedCells.add(pos);
        print('🔘 Cell ($row, $col) selected');
      }
    } else {
      // MULTIPLE selection mode
      if (gameState.selectedCells.contains(pos)) {
        gameState.selectedCells.remove(pos); // Deselect if already selected
        print('🔘 Cell ($row, $col) removed from selection');
      } else {
        gameState.selectedCells.add(pos); // Add to selection
        print('🔘 Cell ($row, $col) added to selection');
      }
    }

    updateHighlights(); // Update which cells are highlighted
    notifyListeners(); // Trigger UI rebuild
  }

  void handleNumberInput(int number) {
    print('\n🔢 ========== HANDLE NUMBER INPUT: $number ==========');
    print('Current mode: ${gameState.currentMode}');
    print('Selected cells: ${gameState.selectedCells.length}');

    if (gameState.selectedCells.isEmpty) {
      print('⚠️ No cells selected');
      print('====================================================\n');
      return;
    }

    List<game_action.Action> groupedActions = [];

    // Process each selected cell
    for (var pos in gameState.selectedCells) {
      final cell = gameState.grid[pos.row][pos.col];

      print('\nProcessing cell (${pos.row}, ${pos.col}):');

      // Don't modify given cells EXCEPT for coloring
      if (cell.isGiven && gameState.currentMode != GameMode.COLORING) {
        print('  ⚠️ Skipping - cell is given');
        continue;
      }

      // Create action based on current mode
      final oldCell = cell.copyWith();
      SudokuCell newCell;
      game_action.ActionType actionType;

      switch (gameState.currentMode) {
        case GameMode.NORMAL:
          // Set the main number
          final isSameNumber = cell.number == number;

          newCell = cell.copyWith(
            number: isSameNumber ? null : number,
            clearNumber: isSameNumber,
            sideNotes: <int>{}, // Clear notes when setting number
            centerNotes: <int>{},
          );
          actionType = game_action.ActionType.SET_NUMBER;
          print('  Mode: NORMAL - Setting number to ${newCell.number}');
          break;

        case GameMode.SIDE_NOTES:
          // Toggle side note - KEEP center notes
          final newSideNotes = Set<int>.from(cell.sideNotes);
          if (newSideNotes.contains(number)) {
            newSideNotes.remove(number);
            print('  Mode: SIDE_NOTES - Removing $number');
          } else {
            newSideNotes.add(number);
            print('  Mode: SIDE_NOTES - Adding $number');
          }
          newCell = cell.copyWith(
            sideNotes: newSideNotes,
            centerNotes: Set<int>.from(cell.centerNotes), // KEEP center notes
          );
          actionType = game_action.ActionType.TOGGLE_SIDE_NOTE;
          break;

        case GameMode.CENTER_NOTES:
          // Toggle center note - KEEP side notes
          final newCenterNotes = Set<int>.from(cell.centerNotes);
          if (newCenterNotes.contains(number)) {
            newCenterNotes.remove(number);
            print('  Mode: CENTER_NOTES - Removing $number');
          } else {
            newCenterNotes.add(number);
            print('  Mode: CENTER_NOTES - Adding $number');
          }
          newCell = cell.copyWith(
            sideNotes: Set<int>.from(cell.sideNotes), // KEEP side notes
            centerNotes: newCenterNotes,
          );
          actionType = game_action.ActionType.TOGGLE_CENTER_NOTE;
          break;

        case GameMode.COLORING:
          // Determine if we're toggling off
          final color = _getColorForNumber(number);
          final isSameColor = cell.cellColor == color;

          newCell = cell.copyWith(
            cellColor: isSameColor ? null : color,
            clearColor: isSameColor,
          );
          actionType = game_action.ActionType.SET_COLOR;
          print('  Mode: COLORING - Setting color to $color');
          break;
      }

      // Check if this action actually changes the cell
      bool isNoOp = oldCell.number == newCell.number &&
          oldCell.sideNotes.length == newCell.sideNotes.length &&
          oldCell.sideNotes.difference(newCell.sideNotes).isEmpty &&
          oldCell.centerNotes.length == newCell.centerNotes.length &&
          oldCell.centerNotes.difference(newCell.centerNotes).isEmpty &&
          oldCell.cellColor?.value == newCell.cellColor?.value;

      if (isNoOp) {
        print('  ⚠️ No change - skipping');
        continue;
      }

      // Apply the change
      gameState.grid[pos.row][pos.col] = newCell;

      final action = game_action.Action(
        type: actionType,
        position: pos,
        oldCell: oldCell,
        newCell: newCell,
      );

      groupedActions.add(action);
      print('  ✅ Action created');

      // 🔥 NEW: If we just set a number (not erasing), auto-erase notes from related cells
      if (actionType == game_action.ActionType.SET_NUMBER &&
          newCell.number != null) {
        print('  🧹 Auto-erasing note ${newCell.number} from related cells...');
        final noteEraseActions = eraseNotesInRelatedCells(pos, newCell.number!);
        groupedActions.addAll(noteEraseActions);
      }
    }

    // Add all actions to history
    if (groupedActions.isEmpty) {
      print('\n⚠️ No changes made - no actions added to history');
    } else if (groupedActions.length == 1) {
      print('\n✅ Single action - adding normally');
      addAction(groupedActions[0]);
    } else {
      print(
          '\n✅ Multiple actions (${groupedActions.length}) - adding as group');
      addGroupedActions(groupedActions);
    }

    print('====================================================\n');
    validateGrid();
    updateHighlights();
    notifyListeners();
  }

  void addGroupedActions(List<game_action.Action> actions) {
    if (actions.isEmpty) return;

    print('\n📦 ========== ADD GROUPED ACTIONS ==========');
    print('Number of actions in group: ${actions.length}');

    // Generate a unique group ID
    final groupId = DateTime.now().millisecondsSinceEpoch.toString();

    // Remove redo history
    if (gameState.currentActionIndex < gameState.actionHistory.length - 1) {
      gameState.actionHistory.removeRange(
        gameState.currentActionIndex + 1,
        gameState.actionHistory.length,
      );
    }

    // Add all actions with the same group ID
    for (var action in actions) {
      final groupedAction = game_action.Action(
        type: action.type,
        position: action.position,
        oldCell: action.oldCell,
        newCell: action.newCell,
        timestamp: action.timestamp,
        groupId: groupId, // All actions in group have same ID
      );
      gameState.actionHistory.add(groupedAction);
      gameState.currentActionIndex++;
      print(
          '  Added action at (${action.position.row}, ${action.position.col}) with groupId: $groupId');
    }

    print('✅ Grouped actions added');
    print('   History size: ${gameState.actionHistory.length}');
    print('   Current index: ${gameState.currentActionIndex}');
    print('============================================\n');
  }

  Color _getColorForNumber(int number) {
    const colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.grey,
      Colors.brown
    ];
    return colors[(number - 1) % colors.length];
  }

  void changeMode(GameMode newMode) {
    print(
        'changeMode called: ${gameState.currentMode} -> $newMode'); // ← Add this
    gameState.currentMode = newMode;
    print('After change: ${gameState.currentMode}'); // ← And this
    notifyListeners();
  }

  void toggleMultipleSelection() {
    if (gameState.selectionMode == SelectionMode.SINGLE) {
      gameState.selectionMode = SelectionMode.MULTIPLE;
    } else {
      gameState.selectionMode = SelectionMode.SINGLE;
      if (gameState.selectedCells.isNotEmpty) {
        final first = gameState.selectedCells.first;
        gameState.selectedCells.clear();
        gameState.selectedCells.add(first);
      }
    }
    updateHighlights();
    notifyListeners();
  }

  void eraseSelectedCells() {
    print('\n🗑️ ========== ERASE SELECTED CELLS ==========');
    print('Selected cells count: ${gameState.selectedCells.length}');

    if (gameState.selectedCells.isEmpty) {
      print('⚠️ No cells selected to erase');
      print('============================================\n');
      return;
    }

    List<game_action.Action> groupedActions = [];

    for (var pos in gameState.selectedCells) {
      final cell = gameState.grid[pos.row][pos.col];

      print('\nProcessing cell (${pos.row}, ${pos.col}):');
      print('  isGiven: ${cell.isGiven}');
      print('  number: ${cell.number}');
      print('  sideNotes: ${cell.sideNotes}');
      print('  centerNotes: ${cell.centerNotes}');
      print('  cellColor: ${cell.cellColor}');

      // Don't erase given cells
      if (cell.isGiven) {
        print('  ⚠️ Skipping - cell is given');
        continue;
      }

      // Skip if cell is already empty
      if (cell.number == null &&
          cell.sideNotes.isEmpty &&
          cell.centerNotes.isEmpty &&
          cell.cellColor == null) {
        print('  ⚠️ Skipping - cell is already empty');
        continue;
      }

      // Create action
      final oldCell = cell.copyWith();
      final newCell = cell.copyWith(
        clearNumber: true, // Use flag to clear number
        sideNotes: <int>{},
        centerNotes: <int>{},
        clearColor: true, // Use flag to clear color
      );

      print('  ✅ Will erase cell');

      // Apply change
      gameState.grid[pos.row][pos.col] = newCell;

      // Add to group
      final action = game_action.Action(
        type: game_action.ActionType.CLEAR,
        position: pos,
        oldCell: oldCell,
        newCell: newCell,
      );

      groupedActions.add(action);
    }

    // Add all actions to history
    if (groupedActions.isEmpty) {
      print('\n⚠️ No cells erased - no actions added');
    } else if (groupedActions.length == 1) {
      print('\n✅ Single cell erased - adding action normally');
      addAction(groupedActions[0]);
    } else {
      print(
          '\n✅ Multiple cells erased (${groupedActions.length}) - adding as group');
      addGroupedActions(groupedActions);
    }

    print('============================================\n');
    validateGrid();
    updateHighlights();
    notifyListeners();
  }

  void restartPuzzle() {
    // Clear the grid AND reset cell states
    for (var row in gameState.grid) {
      for (var cell in row) {
        cell.clear();
        cell.isSelected = false; // 🔥 Clear selection
        cell.isHighlighted = false;
        cell.isError = false;
      }
    }

    // Clear selections
    gameState.selectedCells.clear();
    gameState.highlightedCells.clear();

    // Clear action history
    gameState.actionHistory.clear();
    gameState.currentActionIndex = -1;

    // Reset timer
    gameState.elapsedTime = Duration.zero;
    gameState.isPaused = false;

    notifyListeners();
  }

  bool validateCell(int row, int col, int number) {
    return true;
  }

  Set<Position> getRelatedCells(Position cell) {
    Set<Position> related = {};
    for (int c = 0; c < 9; c++) {
      related.add(Position(cell.row, c));
    }
    for (int r = 0; r < 9; r++) {
      related.add(Position(r, cell.col));
    }
    int boxRow = (cell.row ~/ 3) * 3;
    int boxCol = (cell.col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        related.add(Position(r, c));
      }
    }
    return related;
  }

  void updateHighlights() {
    gameState.highlightedCells.clear();

    if (gameState.selectedCells.isEmpty) {
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          gameState.grid[r][c].isSelected = false;
          gameState.grid[r][c].isHighlighted = false;
        }
      }
      return;
    }

    if (gameState.selectedCells.length == 1) {
      final selectedPos = gameState.selectedCells.first;
      gameState.highlightedCells.addAll(getRelatedCells(selectedPos));
    } else {
      Set<Position> candidates = {};
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          candidates.add(Position(r, c));
        }
      }

      for (var selectedPos in gameState.selectedCells) {
        Set<Position> relatedToThis = getRelatedCells(selectedPos);
        candidates = candidates.intersection(relatedToThis);
      }

      gameState.highlightedCells.addAll(candidates);
    }

    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final pos = Position(r, c);

        gameState.grid[r][c].isSelected = gameState.selectedCells.contains(pos);
        gameState.grid[r][c].isHighlighted =
            gameState.highlightedCells.contains(pos) &&
                !gameState.selectedCells.contains(pos);
      }
    }
  }

  void validateGrid() {
    print('\n🔍 ========== VALIDATE GRID ==========');

    // First, clear all errors
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        gameState.grid[r][c].isError = false;
      }
    }

    int errorCount = 0;

    // Check each cell for conflicts
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final cell = gameState.grid[r][c];

        // Skip empty cells
        if (cell.number == null) continue;

        bool hasError = false;

        // Check row for duplicates
        for (int col = 0; col < 9; col++) {
          if (col != c && gameState.grid[r][col].number == cell.number) {
            hasError = true;
            gameState.grid[r][col].isError = true;
            print(
                '  ❌ Duplicate ${cell.number} in row $r: cells ($r,$c) and ($r,$col)');
          }
        }

        // Check column for duplicates
        for (int row = 0; row < 9; row++) {
          if (row != r && gameState.grid[row][c].number == cell.number) {
            hasError = true;
            gameState.grid[row][c].isError = true;
            print(
                '  ❌ Duplicate ${cell.number} in col $c: cells ($r,$c) and ($row,$c)');
          }
        }

        // Check 3x3 box for duplicates
        int boxRow = (r ~/ 3) * 3;
        int boxCol = (c ~/ 3) * 3;
        for (int row = boxRow; row < boxRow + 3; row++) {
          for (int col = boxCol; col < boxCol + 3; col++) {
            if ((row != r || col != c) &&
                gameState.grid[row][col].number == cell.number) {
              hasError = true;
              gameState.grid[row][col].isError = true;
              print(
                  '  ❌ Duplicate ${cell.number} in box: cells ($r,$c) and ($row,$col)');
            }
          }
        }

        // Mark this cell as error if it has conflicts
        if (hasError) {
          gameState.grid[r][c].isError = true;
          errorCount++;
        }
      }
    }

    if (errorCount > 0) {
      print('⚠️ Found errors in $errorCount cells');
    } else {
      print('✅ No errors found - grid is valid so far');
    }
    print('=====================================\n');
  }

  void startTimer() {
    gameState.isPaused = false;
  }

  void pauseTimer() {
    gameState.isPaused = true;
  }

  void addAction(game_action.Action action) {
    print('\n📝 ========== ADD ACTION ==========');
    print('Action type: ${action.type}');
    print('Position: (${action.position.row}, ${action.position.col})');
    print(
        'Old cell - number: ${action.oldCell.number}, sideNotes: ${action.oldCell.sideNotes}, centerNotes: ${action.oldCell.centerNotes}, color: ${action.oldCell.cellColor}');
    print(
        'New cell - number: ${action.newCell.number}, sideNotes: ${action.newCell.sideNotes}, centerNotes: ${action.newCell.centerNotes}, color: ${action.newCell.cellColor}');

    // Check if action actually changes anything
    bool isNoOp = action.oldCell.number == action.newCell.number &&
        action.oldCell.sideNotes.length == action.newCell.sideNotes.length &&
        action.oldCell.centerNotes.length ==
            action.newCell.centerNotes.length &&
        action.oldCell.cellColor == action.newCell.cellColor;

    if (isNoOp) {
      print(
          '⚠️ WARNING: This action does nothing! Old and new cells are identical.');
      print('   SKIPPING this action - not adding to history');
      return; // Don't add no-op actions
    }

    // Remove any actions after current index (redo history is lost when new action is made)
    if (gameState.currentActionIndex < gameState.actionHistory.length - 1) {
      int removedCount =
          gameState.actionHistory.length - gameState.currentActionIndex - 1;
      gameState.actionHistory.removeRange(
        gameState.currentActionIndex + 1,
        gameState.actionHistory.length,
      );
      print('🗑️ Removed $removedCount redo actions');
    }

    // Add new action
    gameState.actionHistory.add(action);
    gameState.currentActionIndex++;

    print('✅ Action added to history');
    print(
        '   History size: ${gameState.actionHistory.length}, Current index: ${gameState.currentActionIndex}');
    print('   Can undo: ${canUndo()}, Can redo: ${canRedo()}');
    print('====================================\n');
  }

  void undo() {
    print('\n↶ ========== UNDO ==========');
    print('Current index: ${gameState.currentActionIndex}');
    print('History size: ${gameState.actionHistory.length}');
    print('Can undo: ${canUndo()}');

    if (!canUndo()) {
      print('❌ Cannot undo - no actions in history');
      print('============================\n');
      return;
    }

    final action = gameState.actionHistory[gameState.currentActionIndex];
    final groupId = action.groupId;

    print('Undoing action type: ${action.type}');
    print('Position: (${action.position.row}, ${action.position.col})');
    print('Group ID: $groupId');

    // If this action is part of a group, undo all actions in the group
    if (groupId != null) {
      print('📦 This is a grouped action - undoing entire group');

      // Collect all actions with the same group ID
      List<game_action.Action> groupActions = [];
      int currentIdx = gameState.currentActionIndex;

      while (currentIdx >= 0 &&
          gameState.actionHistory[currentIdx].groupId == groupId) {
        groupActions.add(gameState.actionHistory[currentIdx]);
        currentIdx--;
      }

      print('   Found ${groupActions.length} actions in group');

      // Undo all actions in the group
      for (var groupAction in groupActions) {
        final pos = groupAction.position;
        print('   Undoing cell (${pos.row}, ${pos.col})');
        gameState.grid[pos.row][pos.col] = groupAction.oldCell.copyWith();
        gameState.currentActionIndex--;
      }
    } else {
      // Single action - undo normally
      final pos = action.position;
      print(
          'Before undo - cell: number=${gameState.grid[pos.row][pos.col].number}');

      gameState.grid[pos.row][pos.col] = action.oldCell.copyWith();

      print(
          'After undo - cell: number=${gameState.grid[pos.row][pos.col].number}');
      gameState.currentActionIndex--;
    }

    print('✅ Undo completed');
    print('   New index: ${gameState.currentActionIndex}');
    print('   Can undo: ${canUndo()}, Can redo: ${canRedo()}');
    print('============================\n');
    validateGrid();
    updateHighlights();
    notifyListeners();
  }

  void redo() {
    print('\n↷ ========== REDO ==========');
    print('Current index: ${gameState.currentActionIndex}');
    print('History size: ${gameState.actionHistory.length}');
    print('Can redo: ${canRedo()}');

    if (!canRedo()) {
      print('❌ Cannot redo - no actions to redo');
      print('============================\n');
      return;
    }

    gameState.currentActionIndex++;
    final action = gameState.actionHistory[gameState.currentActionIndex];
    final groupId = action.groupId;

    print('Redoing action type: ${action.type}');
    print('Position: (${action.position.row}, ${action.position.col})');
    print('Group ID: $groupId');

    // If this action is part of a group, redo all actions in the group
    if (groupId != null) {
      print('📦 This is a grouped action - redoing entire group');

      // Collect all actions with the same group ID
      List<game_action.Action> groupActions = [action];
      int nextIdx = gameState.currentActionIndex + 1;

      while (nextIdx < gameState.actionHistory.length &&
          gameState.actionHistory[nextIdx].groupId == groupId) {
        groupActions.add(gameState.actionHistory[nextIdx]);
        nextIdx++;
        gameState.currentActionIndex++;
      }

      print('   Found ${groupActions.length} actions in group');

      // Redo all actions in the group
      for (var groupAction in groupActions) {
        final pos = groupAction.position;
        print('   Redoing cell (${pos.row}, ${pos.col})');
        gameState.grid[pos.row][pos.col] = groupAction.newCell.copyWith();
      }
    } else {
      // Single action - redo normally
      final pos = action.position;
      print(
          'Before redo - cell: number=${gameState.grid[pos.row][pos.col].number}');

      gameState.grid[pos.row][pos.col] = action.newCell.copyWith();

      print(
          'After redo - cell: number=${gameState.grid[pos.row][pos.col].number}');
    }

    print('✅ Redo completed');
    print('   New index: ${gameState.currentActionIndex}');
    print('   Can undo: ${canUndo()}, Can redo: ${canRedo()}');
    print('============================\n');
    validateGrid();
    updateHighlights();
    notifyListeners();
  }

  bool canUndo() {
    return gameState.currentActionIndex >= 0;
  }

  bool canRedo() {
    return gameState.currentActionIndex < gameState.actionHistory.length - 1;
  }

  int? getSelectedNumber() {
    if (gameState.selectedCells.length == 1) {
      final pos = gameState.selectedCells.first;
      return gameState.grid[pos.row][pos.col].number;
    }
    return null;
  }

// Count how many times a number appears in the grid
  int countNumber(int number) {
    int count = 0;
    for (var row in gameState.grid) {
      for (var cell in row) {
        if (cell.number == number) {
          count++;
        }
      }
    }
    return count;
  }

// Check if a number is complete (appears 9 times)
  bool isNumberComplete(int number) {
    return countNumber(number) >= 9;
  }

  /// Erases a specific number from notes in related cells
  /// Returns list of actions for cells that were modified
  List<game_action.Action> eraseNotesInRelatedCells(Position pos, int number) {
    print('\n🧹 ========== ERASE NOTES IN RELATED CELLS ==========');
    print(
        'Erasing note $number from cells related to (${pos.row}, ${pos.col})');

    List<game_action.Action> actions = [];
    final relatedCells = getRelatedCells(pos);

    for (var relatedPos in relatedCells) {
      // Skip the cell where we're placing the number
      if (relatedPos == pos) continue;

      final cell = gameState.grid[relatedPos.row][relatedPos.col];

      // Check if this cell has the number in notes
      final hasSideNote = cell.sideNotes.contains(number);
      final hasCenterNote = cell.centerNotes.contains(number);

      if (hasSideNote || hasCenterNote) {
        print(
            '  Found note $number in cell (${relatedPos.row}, ${relatedPos.col})');

        // Create new note sets without this number
        final newSideNotes = Set<int>.from(cell.sideNotes)..remove(number);
        final newCenterNotes = Set<int>.from(cell.centerNotes)..remove(number);

        final oldCell = cell.copyWith();
        final newCell = cell.copyWith(
          sideNotes: newSideNotes,
          centerNotes: newCenterNotes,
        );

        // Apply the change
        gameState.grid[relatedPos.row][relatedPos.col] = newCell;

        // Create action for undo
        final action = game_action.Action(
          type: game_action.ActionType.ERASE_NOTE,
          position: relatedPos,
          oldCell: oldCell,
          newCell: newCell,
        );

        actions.add(action);
        print('    ✅ Note erased');
      }
    }

    print('Total cells affected: ${actions.length}');
    print('====================================================\n');
    return actions;
  }
}
