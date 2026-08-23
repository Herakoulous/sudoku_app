import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/position.dart';
import '../services/save_service.dart';
import '../models/sudoku_cell.dart';
import '../models/action.dart' as game_action;
import '../data/puzzles.dart';
import '../data/realm_config.dart';
import '../models/achievement.dart';
import '../models/solve_record.dart';
import '../services/achievement_service.dart';
import '../services/archive_service.dart';
import '../services/audio_service.dart';
import '../models/hint_lesson.dart';
import '../services/hint_lesson_builder.dart';
import '../services/progress_service.dart';
import '../services/solver_service.dart';
import '../services/settings_service.dart';
import '../services/validation_service.dart';

bool debug = true;

class GameController extends ChangeNotifier {
  GameState gameState;

  // Save current game state
  Future<void> saveProgress() async {
    if (ephemeral) return;
    await SaveService.saveGame(gameState);
    // Mirror into the archive so the game can be browsed and reopened later,
    // with its full undo history intact.
    await ArchiveService.record(gameState);
  }

  Future<void> loadProgress() async {
    final saved = await SaveService.loadGame(gameState.puzzleId);
    if (saved != null) {
      print('🔍 Loaded game has ${saved.constraints.length} constraints');
      print('🔍 New game has ${gameState.constraints.length} constraints');

      // 🔥 Only load if constraints match (or saved game is newer)
      if (saved.constraints.length == gameState.constraints.length) {
        gameState = saved;
        updateHighlights();
        notifyListeners();
      } else {
        print('⚠️ Constraint mismatch - using fresh puzzle instead');
      }
    }
  }

  /// When true, this controller never touches persistent storage — no saved
  /// game, no completion flag, no solve log entry — and answers no hints.
  ///
  /// The Dungeon reuses the board and number pad through this: a ranked attempt
  /// on a classic puzzle must not overwrite that puzzle's realm save or count as
  /// a realm completion, and ranked play offers no hints.
  final bool ephemeral;

  GameController({
    required String puzzleId,
    required int difficulty,
    this.ephemeral = false,
  }) : gameState = GameState.newGame(puzzleId, difficulty);
  void clearHint() {
    print('🧹 Clearing hint in GameController');
    if (gameState.hintCell != null || gameState.lastHintExplanation != null) {
      // 🔥 Use GameState's clearHint which properly clears everything
      gameState.clearHint();

      // 🔥 Also clear selection and highlights
      gameState.selectedCells.clear();
      gameState.highlightedCells.clear();

      updateHighlights();
      notifyListeners();
      print('✅ Hint cleared');
    } else {
      print('⏸️ No hint to clear');
    }
  }
// Add this to your game_controller.dart file
// Replace your existing getHint() method with this enhanced version

  /// Fetches the next solving step and turns it into a walkthrough.
  ///
  /// The lesson is stored on the game state rather than applied; the player
  /// reads the reasoning first and chooses to take the result.
  Future<void> getHint() async {
    // A wrong digit already on the board makes every downstream explanation
    // false, so it has to be fixed before any hint can be trusted.
    final validation = ValidationService.validateUserEntries(gameState);
    if (!validation.isValid) {
      ValidationService.markWrongCells(gameState, validation.wrongCells);

      gameState.activeLesson = null;
      gameState.lessonStage = 0;
      gameState.lastHintExplanation = validation.errorMessage;
      gameState.lastHintType = 'validation_error';
      gameState.hintCell = null;
      gameState.hintNumber = null;

      notifyListeners();
      return;
    }

    // Not counted yet — a failed request must not cost the player a hint.
    final step = await SolverService.nextStep(gameState.getCurrentGridState());

    if (step == null) {
      gameState.activeLesson = null;
      // Say which problem it is. "Check your connection" when the connection is
      // fine and the server is simply out of date sends the player hunting for
      // a fault that is not theirs.
      gameState.lastHintExplanation = SolverService.lastFailure?.message ??
          'No further hints are available for this position.';
      gameState.lastHintType = 'unavailable';
      notifyListeners();
      return;
    }

    SaveService.incrementHintsUsed();
    gameState.hintsUsedThisGame++;

    gameState.activeLesson = HintLessonBuilder.build(step);
    gameState.lessonStage = 0;
    gameState.lastHintExplanation = null;
    gameState.lastHintType = null;

    // Point the grid at the conclusion so the cell is findable even before the
    // player reaches the last stage.
    final placement = gameState.activeLesson!.placementCell;
    gameState.hintCell = placement;
    gameState.hintNumber = gameState.activeLesson!.placementValue;

    notifyListeners();
  }

  /// Moves one beat forward through the current lesson.
  void nextLessonStage() {
    final lesson = gameState.activeLesson;
    if (lesson == null) return;
    if (gameState.lessonStage >= lesson.stages.length - 1) return;

    gameState.lessonStage++;
    notifyListeners();
  }

  void previousLessonStage() {
    if (gameState.activeLesson == null || gameState.lessonStage == 0) return;
    gameState.lessonStage--;
    notifyListeners();
  }

  void dismissLesson() {
    if (gameState.activeLesson == null) return;
    gameState.clearHint();
    notifyListeners();
  }

  /// Carries out what the lesson concluded: places the digit, or strikes the
  /// candidates it ruled out.
  Future<void> applyLesson() async {
    final lesson = gameState.activeLesson;
    if (lesson == null) return;

    final step = lesson.step;

    if (step.placements.isNotEmpty) {
      final placement = step.placements.first;
      final pos = Position(placement.cell.row, placement.cell.col);
      final cell = gameState.grid[pos.row][pos.col];

      if (!cell.isGiven && cell.number == null) {
        final oldCell = cell.copyWith();
        final newCell = cell.copyWith(
          number: placement.value,
          sideNotes: <int>{},
          centerNotes: <int>{},
        );
        gameState.grid[pos.row][pos.col] = newCell;

        final actions = <game_action.Action>[
          game_action.Action(
            type: game_action.ActionType.SET_NUMBER,
            position: pos,
            oldCell: oldCell,
            newCell: newCell,
          ),
        ];

        if (await SettingsService.getAutoNotes()) {
          actions.addAll(eraseNotesInRelatedCells(pos, placement.value));
        }

        if (actions.length == 1) {
          addAction(actions.first);
        } else {
          addGroupedActions(actions);
        }

        AudioService.playNumberPlaceSound();
      }
    } else {
      // Eliminations only touch pencil marks, and are recorded as one group so
      // a single undo puts them all back.
      final actions = <game_action.Action>[];

      // Write the candidates the solver reasoned over first. Striking a 3 out
      // of a cell means nothing if the player never pencilled a 3 there, so the
      // notes have to exist before they can be removed. Which style depends on
      // how the technique argues: a cell's full candidate set goes in the
      // centre, a single digit tracked across a region goes at the side.
      for (final note in lesson.notesToReveal()) {
        final pos = note.cell;
        final cell = gameState.grid[pos.row][pos.col];
        if (cell.number != null || cell.isGiven) continue;

        final side = Set<int>.from(cell.sideNotes);
        final centre = Set<int>.from(cell.centerNotes);

        if (lesson.noteStyle == NoteStyle.centre) {
          if (!centre.add(note.value)) continue;
        } else {
          if (!side.add(note.value)) continue;
        }

        final oldCell = cell.copyWith();
        final newCell = cell.copyWith(sideNotes: side, centerNotes: centre);
        gameState.grid[pos.row][pos.col] = newCell;

        actions.add(
          game_action.Action(
            type: lesson.noteStyle == NoteStyle.centre
                ? game_action.ActionType.TOGGLE_CENTER_NOTE
                : game_action.ActionType.TOGGLE_SIDE_NOTE,
            position: pos,
            oldCell: oldCell,
            newCell: newCell,
          ),
        );
      }

      for (final elimination in step.eliminations) {
        final pos =
            Position(elimination.cell.row, elimination.cell.col);
        final cell = gameState.grid[pos.row][pos.col];
        if (cell.number != null) continue;

        final side = Set<int>.from(cell.sideNotes)..remove(elimination.value);
        final centre =
            Set<int>.from(cell.centerNotes)..remove(elimination.value);

        if (side.length == cell.sideNotes.length &&
            centre.length == cell.centerNotes.length) {
          continue;
        }

        final oldCell = cell.copyWith();
        final newCell = cell.copyWith(sideNotes: side, centerNotes: centre);
        gameState.grid[pos.row][pos.col] = newCell;

        actions.add(
          game_action.Action(
            type: game_action.ActionType.TOGGLE_CENTER_NOTE,
            position: pos,
            oldCell: oldCell,
            newCell: newCell,
          ),
        );
      }

      if (actions.length == 1) {
        addAction(actions.first);
      } else if (actions.length > 1) {
        addGroupedActions(actions);
      }
    }

    // Move the cached path on, so asking again gives the following step rather
    // than repeating this one.
    SolverService.markApplied();

    gameState.clearHint();
    await validateGrid();
    updateHighlights();
    notifyListeners();
  }

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

  /// Commits the lone remaining note in a cell as its answer.
  ///
  /// Bound to a double tap. Once a cell is pencilled down to a single
  /// candidate, that candidate *is* the answer, and making the player switch
  /// out of notes mode and hunt for the digit on the pad is busywork.
  ///
  /// Does nothing unless the cell is empty, editable, and holds exactly one
  /// note across both note styles.
  Future<void> promoteSingleNote(int row, int col) async {
    final cell = gameState.grid[row][col];

    if (cell.isGiven || cell.number != null) return;

    final notes = {...cell.sideNotes, ...cell.centerNotes};
    if (notes.length != 1) return;

    final number = notes.first;
    final pos = Position(row, col);
    final oldCell = cell.copyWith();

    final newCell = cell.copyWith(
      number: number,
      sideNotes: <int>{},
      centerNotes: <int>{},
    );

    gameState.grid[row][col] = newCell;

    final actions = <game_action.Action>[
      game_action.Action(
        type: game_action.ActionType.SET_NUMBER,
        position: pos,
        oldCell: oldCell,
        newCell: newCell,
      ),
    ];

    // Same follow-up as a normal placement, so a promoted note behaves
    // identically to one typed on the number pad — including undo.
    if (await SettingsService.getAutoNotes()) {
      actions.addAll(eraseNotesInRelatedCells(pos, number));
    }

    if (actions.length == 1) {
      addAction(actions.first);
    } else {
      addGroupedActions(actions);
    }

    AudioService.playNumberPlaceSound();
    _countMistakeIfWrong(row, col, number);
    ProgressService.recordNotePromotion();

    await validateGrid();
    updateHighlights();
    notifyListeners();
  }

  Future<void> handleNumberInput(int number) async {
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

      // 🔥 NEW: If we just set a number (not erasing), auto-erase notes from related cells (if enabled)
      if (actionType == game_action.ActionType.SET_NUMBER &&
          newCell.number != null) {
        // A wrong digit gets the error tone, a right one the placement tone —
        // audible feedback that matches what the board shows.
        final wrong = _countMistakeIfWrong(pos.row, pos.col, newCell.number!);
        AudioService.play(wrong ? Sfx.error : Sfx.numberPlace);

        // ✅ Check if auto-notes setting is enabled
        final autoNotes = await SettingsService.getAutoNotes();
        if (autoNotes) {
          print(
              '  🧹 Auto-erasing note ${newCell.number} from related cells...');
          final noteEraseActions =
              eraseNotesInRelatedCells(pos, newCell.number!);
          groupedActions.addAll(noteEraseActions);
        } else {
          print('  ⚙️ Auto-erase disabled - keeping notes in related cells');
        }
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

    await validateGrid();
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

  Future<void> eraseSelectedCells() async {
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
    await validateGrid();
    updateHighlights();
    notifyListeners();
  }

  void restartPuzzle() {
    // Clear the grid AND reset cell states
    for (var row in gameState.grid) {
      for (var cell in row) {
        cell.clear();
        cell.isSelected = false;
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

    // A restart is a fresh attempt, so the hint and mistake tallies start over
    // — otherwise a clean re-solve could never earn a purity award.
    gameState.hintsUsedThisGame = 0;
    gameState.mistakesThisGame = 0;

    // ✅ ADD THIS LINE:
    gameState.isCompleted = false; // Reset completion status

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

  /// Overrides the "show mistakes" setting for this session.
  ///
  /// The Dungeon sets this per mode — always on for Survival, always off for
  /// Time Rush — without touching, or being touched by, the player's global
  /// preference. Null means follow the setting.
  bool? forceShowMistakes;

  Future<void> validateGrid() async {
    print('\n🔍 ========== VALIDATE GRID ==========');

    // ✅ Check if we should show mistakes
    final showMistakes =
        forceShowMistakes ?? await SettingsService.getShowMistakes();

    if (!showMistakes) {
      print('⚙️ Show mistakes is OFF - skipping validation display');
      // Still check if complete, but don't show errors
      await _checkIfComplete();
      print('=====================================\n');
      return;
    }

    // First, clear all errors
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        gameState.grid[r][c].isError = false;
      }
    }

    // Preferred check: compare against the real solution, so a wrong digit is
    // flagged the instant it is entered — even one that does not (yet) clash
    // with another cell. Every puzzle ships a solution; only if one is missing
    // do we fall back to conflict detection below.
    final solution = Puzzles.getPuzzle(gameState.puzzleId)?.solution;
    if (solution != null) {
      int wrong = 0;
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          final cell = gameState.grid[r][c];
          if (cell.isGiven || cell.number == null) continue;
          if (cell.number != solution[r][c]) {
            cell.isError = true;
            wrong++;
          }
        }
      }

      if (wrong > 0) {
        print('⚠️ $wrong wrong ${wrong == 1 ? 'digit' : 'digits'} vs solution');
      } else {
        await _checkIfComplete();
      }
      print('=====================================\n');
      return;
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
      await _checkIfComplete();
    }
    print('=====================================\n');
  }

  /// Counts a wrong digit against this attempt.
  ///
  /// Compared against the puzzle's own solution rather than against row/column
  /// conflicts: a digit can be conflict-free and still be wrong, and the purity
  /// awards would be trivially farmable if it were not checked properly.
  /// Records a wrong digit and returns whether it was one, so the caller can
  /// choose the matching sound. A puzzle with no stored solution can prove
  /// nothing wrong, so it is treated as correct.
  bool _countMistakeIfWrong(int row, int col, int number) {
    final solution = Puzzles.getPuzzle(gameState.puzzleId)?.solution;
    if (solution == null) return false;

    if (solution[row][col] != number) {
      gameState.mistakesThisGame++;
      print('❌ Mistake #${gameState.mistakesThisGame} at ($row, $col)');
      return true;
    }
    return false;
  }

  Future<void> _checkIfComplete() async {
    // Don't check if already completed
    if (gameState.isCompleted) return;

    // Check if all cells are filled
    bool isFilled = true;
    for (var row in gameState.grid) {
      for (var cell in row) {
        if (cell.number == null) {
          isFilled = false;
          break;
        }
      }
      if (!isFilled) break;
    }

    if (!isFilled) return;

    // A full grid is not a solved grid. Every puzzle now ships its solution, so
    // check against it — otherwise filling the board with wrong digits counted
    // as a win, awarded a best time, and unlocked achievements.
    final solution = Puzzles.getPuzzle(gameState.puzzleId)?.solution;
    if (solution != null) {
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (gameState.grid[r][c].number != solution[r][c]) {
            print('⚠️ Grid is full but not correct - not a completion');
            return;
          }
        }
      }
    }

    print('🎉 PUZZLE COMPLETED!');
    gameState.markCompleted();
    AudioService.play(Sfx.success);

    // Ranked play owns its own outcome (Elo, result screen) and must leave the
    // realm's saves and solve log untouched.
    if (ephemeral) return;

    // Keep the finished board in the archive. The normal save is cleared on
    // completion, so without this the solved grid would be lost.
    await ArchiveService.record(gameState);

    // 🔥 Save completion status and best time
    await saveProgress();

    // 🔥 Then immediately clear the grid save
    await SaveService.clearSave(gameState.puzzleId);
    print('🗑️ Cleared saved game grid for ${gameState.puzzleId}');

    await _recordSolve();

    // The listener in GameScreen will show the dialog
  }

  /// Appends this finish to the solve log, which is what every achievement is
  /// computed from.
  Future<void> _recordSolve() async {
    final realmName =
        RealmConfig.realmForPuzzleId(gameState.puzzleId) ?? 'Unknown';

    await ProgressService.recordSolve(
      SolveRecord(
        puzzleId: gameState.puzzleId,
        realmName: realmName,
        difficulty: gameState.difficulty,
        seconds: gameState.elapsedSeconds,
        hintsUsed: gameState.hintsUsedThisGame,
        mistakes: gameState.mistakesThisGame,
        finishedAt: DateTime.now(),
      ),
    );
  }

  /// Awards earned by the finish that just happened, already marked as seen.
  ///
  /// Exposed for the game screen to display; kept here so the controller owns
  /// all progress writes.
  Future<List<Achievement>> collectNewAchievements() =>
      AchievementService.collectNewlyUnlocked();

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

  Future<void> undo() async {
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
    await validateGrid();
    updateHighlights();
    notifyListeners();
  }

  Future<void> redo() async {
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
    await validateGrid();
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

  bool isNumberComplete(int number) {
    return countNumber(number) >= 9;
  }

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
