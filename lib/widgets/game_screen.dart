import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import 'game_header.dart';
import 'sudoku_grid.dart';
import 'number_pad.dart';
import '../utils/realm_theme.dart';
import '../widgets/completion_dialogue.dart';
import '../services/save_service.dart';
import 'rules_popup.dart';
import '../data/realm_config.dart'; // 🔥 ADD THIS

class GameScreen extends StatefulWidget {
  final String puzzleId;
  final int difficulty;
  final String realmName;

  const GameScreen({
    super.key,
    required this.puzzleId,
    required this.difficulty,
    required this.realmName,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController controller;
  late RealmTheme theme;
  Timer? _timer;
  final ValueNotifier<Duration> _timerNotifier = ValueNotifier(Duration.zero);
  bool _hasShownRules = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRulesIfNeeded();
    });
  }

  void _showRulesIfNeeded() {
    if (_hasShownRules) return;

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

    if (!hasUserInput && !controller.gameState.isCompleted) {
      _hasShownRules = true;
      _showRulesPopup();
    }
  }

  void _showRulesPopup() {
    controller.pauseTimer();

    final constraintTypes =
        controller.gameState.constraints.map((c) => c.type).toList();

    RulesPopup.show(
      context,
      constraintTypes,
      theme,
      () {
        controller.startTimer();
      },
    );
  }

  void _onGameStateChanged() {
    if (controller.gameState.isCompleted && mounted) {
      _checkAndShowCompletion();
    }
  }

  Future<void> _checkAndShowCompletion() async {
    if (!controller.gameState.isCompleted) return;

    final bestTime = await SaveService.getBestTime(widget.puzzleId);

    // Clear the saved game (keep best time)
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
        onNextPuzzle: _handleNextPuzzle,
        onBackToLevels: _handleBackToLevels,
        onPlayAgain: _handlePlayAgain,
      ),
    );
  }

  // 🔥 NEW: Handle next puzzle navigation
  void _handleNextPuzzle() {
    // Get all puzzles for this realm
    final realmPuzzles = RealmConfig.getPuzzlesForRealm(widget.realmName);

    // Find current puzzle index
    final currentIndex =
        realmPuzzles.indexWhere((p) => p.id == widget.puzzleId);

    if (currentIndex == -1) {
      print('❌ Current puzzle not found in realm');
      Navigator.of(context).pop(); // Close game screen
      return;
    }

    // Check if there's a next puzzle
    if (currentIndex >= realmPuzzles.length - 1) {
      // Last puzzle - show message and go back to levels
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '🎉 Congratulations! You completed all puzzles in this realm!'),
          duration: Duration(seconds: 3),
          backgroundColor: theme.primaryColor,
        ),
      );
      Navigator.of(context).pop(); // Close game screen
      return;
    }

    // Navigate to next puzzle
    final nextPuzzle = realmPuzzles[currentIndex + 1];
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GameScreen(
          puzzleId: nextPuzzle.id,
          difficulty: nextPuzzle.difficulty,
          realmName: widget.realmName,
        ),
      ),
    );
  }

  // 🔥 NEW: Handle back to levels
  void _handleBackToLevels() {
    Navigator.of(context).pop(); // Close game screen
  }

  // 🔥 NEW: Handle play again
  void _handlePlayAgain() {
    controller.restartPuzzle();
    // Dialog stays open until restart is complete
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerNotifier.dispose();
    controller.removeListener(_onGameStateChanged);
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
        _timerNotifier.value = controller.gameState.elapsedTime;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          // Save before going back
          print('💾 Saving game before navigation...');
          await controller.saveProgress();
          print('✅ Save complete, allowing navigation');
          return true; // Allow the pop
        },
        child: Scaffold(
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
                      onExit: () async {
                        print('💾 Saving game before exit...');
                        await controller.saveProgress();
                        print('✅ Save complete');
                        Navigator.pop(context);
                      },
                      onPause: () => controller.pauseTimer(), // ADD THIS LINE
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
                  onShowRules: _showRulesPopup,
                ),
              ],
            ),
          ),
        ));
  }
}
