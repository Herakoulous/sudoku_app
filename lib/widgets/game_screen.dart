import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import 'game_header.dart';
import 'sudoku_grid.dart';
import 'number_pad.dart';
import '../utils/realm_theme.dart'; // 🔥 ADD THIS
import '../widgets/completion_dialogue.dart';
import '../services/save_service.dart';
import 'rules_popup.dart'; // 🔥 ADD

class GameScreen extends StatefulWidget {
  final String puzzleId;
  final int difficulty;
  final String realmName; // 🔥 ADDED

  const GameScreen({
    super.key,
    required this.puzzleId,
    required this.difficulty,
    required this.realmName, // 🔥 ADDED
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController controller;
  late RealmTheme theme; // 🔥 ADD THIS
  Timer? _timer;
  final ValueNotifier<Duration> _timerNotifier = ValueNotifier(Duration.zero);
  bool _hasShownRules = false; // 🔥 ADD

  @override
  void initState() {
    super.initState();
    theme = RealmTheme.fromRealm(widget.realmName);
    controller = GameController(
      puzzleId: widget.puzzleId,
      difficulty: widget.difficulty,
    );

    controller.addListener(_onGameStateChanged);
    _loadSavedGame();
    _startTimer();

    // 🔥 ADD: Show rules popup after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRulesIfNeeded();
    });
  }

  // 🔥 ADD: Show rules popup on first load
  void _showRulesIfNeeded() {
    if (_hasShownRules) return;

    // Check if game has any user input (if not, show rules)
    bool hasUserInput = false;
    for (var row in controller.gameState.grid) {
      for (var cell in row) {
        if (cell.hasUserInput) {
          hasUserInput = true;
          break;
        }
      }
      if (hasUserInput) break;
    }

    // Only show rules if puzzle is fresh (no user input)
    if (!hasUserInput && !controller.gameState.isCompleted) {
      _hasShownRules = true;
      _showRulesPopup();
    }
  }

  // 🔥 ADD: Show rules popup and pause timer
  void _showRulesPopup() {
    // Pause the timer
    controller.pauseTimer();

    // Get constraint types from game state
    final constraintTypes =
        controller.gameState.constraints.map((c) => c.type).toList();

    RulesPopup.show(
      context,
      constraintTypes,
      theme,
      () {
        // Resume timer when popup closes
        controller.startTimer();
      },
    );
  }

  // 🔥 ADD THIS METHOD
  void _onGameStateChanged() {
    // Check if puzzle just completed
    if (controller.gameState.isCompleted && mounted) {
      _checkAndShowCompletion();
    }
  }

  Future<void> _checkAndShowCompletion() async {
    // Prevent showing multiple times
    if (!controller.gameState.isCompleted) return;

    final bestTime = await SaveService.getBestTime(widget.puzzleId);

    // 🔥 NEW: Clear the saved game (keep best time)
    await SaveService.clearSave(widget.puzzleId);
    print('🗑️ Cleared saved game for ${widget.puzzleId}');

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CompletionDialog(
        puzzleId: widget.puzzleId,
        difficulty: widget.difficulty,
        elapsedTime: controller.gameState.elapsedTime,
        previousBestTime: bestTime != null ? Duration(seconds: bestTime) : null,
        theme: theme,
        onNextPuzzle: () {
          Navigator.pop(context); // Close dialog
          Navigator.pop(context); // Return to level selection
          // TODO: Navigate to next puzzle in sequence
        },
        onBackToLevels: () {
          Navigator.pop(context); // Close dialog
          Navigator.pop(context); // Close game screen
        },
        onPlayAgain: () {
          Navigator.pop(context); // Close dialog
          controller.restartPuzzle();
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerNotifier.dispose();
    controller.removeListener(_onGameStateChanged); // 🔥 REMOVE LISTENER
    controller.saveProgress();
    controller.dispose();
    super.dispose();
  }

  Future<void> _loadSavedGame() async {
    await controller.loadProgress();
    _timerNotifier.value = controller.gameState.elapsedTime;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!controller.gameState.isPaused) {
        controller.gameState.elapsedTime += const Duration(seconds: 1);
        _timerNotifier.value =
            controller.gameState.elapsedTime; // Only update timer
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      backgroundColor: Color(0xFF0A101A),
      body: SafeArea(
        child: Column(
          children: [
            ValueListenableBuilder<Duration>(
              valueListenable: _timerNotifier,
              builder: (context, elapsedTime, child) {
                return GameHeader(
                  difficulty: widget.difficulty,
                  puzzleId: widget.puzzleId,
                  elapsedTime: elapsedTime,
                  onRestart: () => controller.restartPuzzle(),
                  onExit: () => Navigator.pop(context),
                  theme: theme,
                );
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child: RepaintBoundary(
                child: SudokuGrid(
                  controller: controller,
                  theme: theme,
                ),
              ),
            ),
            NumberPad(
              controller: controller,
              theme: theme,
              onShowRules: _showRulesPopup, // 🔥 ADD
            ),
          ],
        ),
      ),
    );
  }
}
