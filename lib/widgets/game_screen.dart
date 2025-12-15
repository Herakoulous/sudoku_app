import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import '../services/settings_service.dart';
import 'game_header.dart';
import 'sudoku_grid.dart';
import 'number_pad.dart';
import '../utils/realm_theme.dart';
import '../widgets/completion_dialogue.dart';
import '../widgets/hint_explanation_bubble.dart';
import '../services/save_service.dart';
import 'rules_popup.dart';
import '../data/realm_config.dart';
import '../widgets/hint_button.dart';
import '../widgets/hint_loading_indicator.dart';
import '../services/hodoku_hint_service.dart';

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
  late RealmTheme theme = RealmTheme.fromRealmSync(widget.realmName);
  Timer? _timer;
  final ValueNotifier<Duration> _timerNotifier = ValueNotifier(Duration.zero);
  bool _hasShownRules = false;
  String? _currentHintExplanation;
  bool _showHintButton = true;
  bool _isLoadingHint = false;
  String _resolvedTheme = 'dark';

  Future<void> _loadTheme() async {
    final loadedTheme = await RealmTheme.fromRealm(widget.realmName);
    final resolvedTheme = await SettingsService.getResolvedTheme(context);
    setState(() {
      theme = loadedTheme;
      _resolvedTheme = resolvedTheme;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadTheme();
    controller = GameController(
      puzzleId: widget.puzzleId,
      difficulty: widget.difficulty,
    );

    SaveService.startSession(widget.puzzleId);
    controller.addListener(_onGameStateChanged);
    _loadSavedGame();
    _startTimer();

    if (_isClassicPuzzle) {
      HoDoKuHintService.warmUpServer();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRulesIfNeeded();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerNotifier.dispose();
    controller.removeListener(_onGameStateChanged);
    controller.saveProgress();
    SaveService.endSession(widget.puzzleId);
    controller.dispose();
    super.dispose();
  }

  void _onHintButtonPressed() async {
    setState(() {
      _showHintButton = false;
      _isLoadingHint = true;
    });

    await controller.getHint();

    if (mounted) {
      setState(() {
        _isLoadingHint = false;
      });
    }
  }

  void _onGameStateChanged() {
    print('📢 _onGameStateChanged called');

    if (controller.gameState.isCompleted && mounted) {
      _checkAndShowCompletion();
    }

    if (mounted) {
      print('🔄 Calling _updateHintExplanation');
      _updateHintExplanation();
    }
  }

  void _updateHintExplanation() {
    print('🔄 _updateHintExplanation called');
    setState(() {
      _currentHintExplanation = controller.gameState.lastHintExplanation;
      _isLoadingHint = false;

      if (_currentHintExplanation == null) {
        _showHintButton = true;
      } else {
        _showHintButton = false;
      }
    });
  }

  bool get _isClassicPuzzle {
    return widget.realmName == 'Classic Kingdom';
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
        SaveService.incrementHintsUsed();
        controller.getHint();
        _updateHintExplanation();
        controller.startTimer();
      },
    );
  }

  Future<void> _checkAndShowCompletion() async {
    if (!controller.gameState.isCompleted) return;

    final bestTime = await SaveService.getBestTime(widget.puzzleId);
    await SaveService.clearSave(widget.puzzleId);

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

  Color _getBackgroundColor() {
    return _resolvedTheme == 'dark' ? Color(0xFF0A101A) : Color(0xFFF5F5F5);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await controller.saveProgress();
        return true;
      },
      child: Scaffold(
        appBar: null,
        backgroundColor: _getBackgroundColor(),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
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
                          await controller.saveProgress();
                          Navigator.pop(context);
                        },
                        onPause: () => controller.pauseTimer(),
                        theme: theme,
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        controller.clearHint();
                        setState(() {
                          _currentHintExplanation = null;
                          _showHintButton = true;
                          _isLoadingHint = false;
                        });
                      },
                      child: RepaintBoundary(
                        child: SingleChildScrollView(
                          reverse:
                              _currentHintExplanation != null || _isLoadingHint,
                          child: SudokuGrid(
                            controller: controller,
                            theme: theme,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_isLoadingHint) HintLoadingIndicator(theme: theme),
                  if (_currentHintExplanation != null && !_isLoadingHint)
                    HintExplanationBubble(
                      explanation: _currentHintExplanation,
                      theme: theme,
                      onClose: () {
                        setState(() {
                          _currentHintExplanation = null;
                          _showHintButton = true;
                        });
                      },
                      hintType: controller.gameState.lastHintType,
                    ),
                  NumberPad(
                    controller: controller,
                    theme: theme,
                    onShowRules: _showRulesPopup,
                  ),
                ],
              ),
              if (_isClassicPuzzle)
                HintButton(
                  theme: theme,
                  onPressed: _onHintButtonPressed,
                  isVisible: _showHintButton,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
