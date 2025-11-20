import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import 'game_header.dart';
import 'sudoku_grid.dart';
import 'number_pad.dart';
import '../utils/realm_theme.dart';
import '../widgets/completion_dialogue.dart';
import '../widgets/hint_explanation_bubble.dart'; // 🔥 NEW
import '../services/save_service.dart';
import 'rules_popup.dart';
import '../data/realm_config.dart';

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
  String? _currentHintExplanation; // 🔥 NEW: Track hint explanation

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
      onGetHint: () {
        controller.getHint();
        // 🔥 NEW: Update hint explanation when hint is received
        _updateHintExplanation();
        controller.startTimer();
      },
    );
  }

  // 🔥 NEW: Method to update hint explanation from game state
  void _updateHintExplanation() {
    setState(() {
      _currentHintExplanation = controller.gameState.hintCell != null
          ? controller.gameState.lastHintExplanation
          : null;
    });
  }

  void _onGameStateChanged() {
    if (controller.gameState.isCompleted && mounted) {
      _checkAndShowCompletion();
    }
  }

  Future<void> _checkAndShowCompletion() async {
    if (!controller.gameState.isCompleted) return;

    final bestTime = await SaveService.getBestTime(widget.puzzleId);

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

  void _handleNextPuzzle() {
    final realmPuzzles = RealmConfig.getPuzzlesForRealm(widget.realmName);

    final currentIndex =
        realmPuzzles.indexWhere((p) => p.id == widget.puzzleId);

    if (currentIndex == -1) {
      print('❌ Current puzzle not found in realm');
      Navigator.of(context).pop();
      return;
    }

    if (currentIndex >= realmPuzzles.length - 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '🎉 Congratulations! You completed all puzzles in this realm!'),
          duration: Duration(seconds: 3),
          backgroundColor: theme.primaryColor,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

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

  void _handleBackToLevels() {
    Navigator.of(context).pop();
  }

  void _handlePlayAgain() {
    controller.restartPuzzle();
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
          print('💾 Saving game before navigation...');
          await controller.saveProgress();
          print('✅ Save complete, allowing navigation');
          return true;
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
                      onPause: () => controller.pauseTimer(),
                      theme: theme,
                    );
                  },
                ),
                const SizedBox(height: 20),
                // 🔥 UPDATED: Grid shrinks when hint is shown
                Expanded(
                  child: RepaintBoundary(
                    child: SingleChildScrollView(
                      reverse: _currentHintExplanation != null,
                      child: SudokuGrid(
                        controller: controller,
                        theme: theme,
                      ),
                    ),
                  ),
                ),
                // 🔥 NEW: Hint explanation bubble (flexible height)
                if (_currentHintExplanation != null)
                  HintExplanationBubble(
                    explanation: _currentHintExplanation,
                    theme: theme,
                    onClose: () {
                      setState(() {
                        _currentHintExplanation = null;
                      });
                    },
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
