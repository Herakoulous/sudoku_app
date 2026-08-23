import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import '../services/settings_service.dart';
import 'game_header.dart';
import 'sudoku_grid.dart';
import 'number_pad.dart';
import '../utils/realm_theme.dart';
import '../widgets/completion_dialogue.dart';
import '../widgets/achievement_notification.dart';
import '../widgets/hint_explanation_bubble.dart';
import '../theme/app_theme.dart';
import '../widgets/hint_lesson_panel.dart';
import '../services/save_service.dart';
import 'rules_popup.dart';
import '../data/realm_config.dart';
import '../widgets/hint_button.dart';
import '../widgets/hint_loading_indicator.dart';
import '../services/warmup_sercvice.dart';

class GameScreen extends StatefulWidget {
  final String puzzleId;
  final int difficulty;
  final String realmName;

  /// An unranked, throwaway session: no realm save, no achievement, no best
  /// time. Used by the Dungeon's "replay with hints", where the point is to
  /// learn the puzzle without it counting for anything.
  final bool ephemeral;

  const GameScreen({
    super.key,
    required this.puzzleId,
    required this.difficulty,
    required this.realmName,
    this.ephemeral = false,
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

  // 🔥 NEW: Track if user has manually dismissed the bubble
  bool _bubbleDismissedByUser = false;

  // 🔥 NEW: Track when bubble was shown for tap delay
  DateTime? _bubbleShownTime;

  /// The controller notifies on every state change, so without this a single
  /// finish would open the completion dialog more than once.
  bool _completionHandled = false;

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
      ephemeral: widget.ephemeral,
    );

    if (!widget.ephemeral) {
      SaveService.startSession(widget.puzzleId);
    }
    controller.addListener(_onGameStateChanged);
    // A throwaway replay starts fresh every time — never resume an old save.
    if (!widget.ephemeral) _loadSavedGame();
    _startTimer();

    if (_isClassicPuzzle) {
      SolverWarmupService.warmup();
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
    // Drop any banner still waiting its turn, so it does not surface over the
    // level list after the player has already left the puzzle.
    AchievementNotification.clearQueue();
    controller.saveProgress(); // no-op when ephemeral
    if (!widget.ephemeral) SaveService.endSession(widget.puzzleId);
    controller.dispose();
    super.dispose();
  }

  void _onHintButtonPressed() async {
    setState(() {
      _showHintButton = false;
      _isLoadingHint = true;
      // 🔥 NEW: Reset dismissal flag when user requests a new hint
      _bubbleDismissedByUser = false;
    });

    await controller.getHint();

    // 🔥 CRITICAL: Set loading to false BEFORE notifyListeners gets called
    if (mounted) {
      setState(() {
        _isLoadingHint = false;
      });
      // Now _updateHintExplanation will work properly
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
    print('   _isLoadingHint: $_isLoadingHint');
    print('   _bubbleDismissedByUser: $_bubbleDismissedByUser');
    print(
        '   gameState.lastHintExplanation: ${controller.gameState.lastHintExplanation != null ? "SET" : "NULL"}');

    // 🔥 Check if hint just loaded (explanation exists but we're marked as loading)
    final hintJustLoaded =
        _isLoadingHint && controller.gameState.lastHintExplanation != null;

    if (hintJustLoaded) {
      print('✅ Hint just loaded - showing bubble');
      setState(() {
        _isLoadingHint = false;
        _currentHintExplanation = controller.gameState.lastHintExplanation;
        _showHintButton = false;
        _bubbleShownTime = DateTime.now();
        print('⏰ Bubble shown at $_bubbleShownTime');
      });
      return;
    }

    // 🔥 Don't update if still loading (prevents dismissal during loading)
    if (_isLoadingHint) {
      print('⏳ Still loading hint - ignoring state change');
      return;
    }

    // 🔥 Don't update if within 500ms protection window
    if (_bubbleShownTime != null && _currentHintExplanation != null) {
      final timeSinceShown = DateTime.now().difference(_bubbleShownTime!);
      if (timeSinceShown.inMilliseconds < 500) {
        print(
            '⏱️ Within protection window (${timeSinceShown.inMilliseconds}ms) - ignoring state change');
        return;
      }
    }

    // 🔥 Don't show bubble if user dismissed it
    if (_bubbleDismissedByUser) {
      print('⏸️ Bubble was dismissed by user - not showing');
      setState(() {
        _currentHintExplanation = null;
        _showHintButton = true;
      });
      return;
    }

    setState(() {
      _currentHintExplanation = controller.gameState.lastHintExplanation;

      if (_currentHintExplanation == null) {
        _showHintButton = true;
      } else {
        _showHintButton = false;
        // Record when bubble was shown
        _bubbleShownTime = DateTime.now();
        print('⏰ Bubble shown at $_bubbleShownTime');
      }
    });
  }

  bool get _isClassicPuzzle {
    return widget.realmName == 'Classic Kingdom';
  }

  Future<void> _showRulesIfNeeded() async {
    if (_hasShownRules) return;

    // A player who has already cleared a puzzle in this realm knows its rules —
    // don't interrupt them. The card stays available from the header.
    if (await _realmRulesKnown()) {
      _hasShownRules = true;
      return;
    }
    if (!mounted) return;

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

  /// Whether the player already knows this realm's rules: either an explicit
  /// flag set on their first finish, or an existing completion in the realm
  /// (covers progress made before the flag existed).
  Future<bool> _realmRulesKnown() async {
    if (await SaveService.areRulesKnown(widget.realmName)) return true;

    final realmPuzzles = RealmConfig.getPuzzlesForRealm(widget.realmName);
    if (realmPuzzles.isEmpty) return false;
    final stats =
        await SaveService.getRealmStats(realmPuzzles.map((p) => p.id).toList());
    return (stats['completed'] as int? ?? 0) > 0;
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
        // getHint() records the hint itself once it actually returns one —
        // counting it here as well double-charged the player.
        controller.getHint();
        _updateHintExplanation();
        controller.startTimer();
      },
    );
  }

  Future<void> _checkAndShowCompletion() async {
    if (!controller.gameState.isCompleted) return;

    // Guard against the listener firing again for the same finish, which would
    // stack a second dialog on the first.
    if (_completionHandled) return;
    _completionHandled = true;

    final bestTime = await SaveService.getBestTime(widget.puzzleId);
    await SaveService.clearSave(widget.puzzleId);
    // They've cleared a puzzle here — the rules card need not open itself again.
    await SaveService.markRulesKnown(widget.realmName);

    final earned = await controller.collectNewAchievements();

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

    if (earned.isEmpty) return;

    // Order matters. Overlay entries stack in insertion order, and a dialog is
    // itself a route in the same overlay — so the banners have to go in *after*
    // the dialog is pushed, or its barrier would dim and swallow them. Waiting a
    // frame guarantees the route is in place first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AchievementNotification.showAll(context, earned);
    });
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
    // Re-arm the guard so finishing the fresh attempt shows its dialog.
    _completionHandled = false;
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

  // 🔥 NEW: Handle grid tap to clear hint and dismiss bubble
  void _handleGridTap() {
    // 🔥 PREVENT dismissal while loading
    if (_isLoadingHint) {
      print('⏳ Hint is loading - ignoring tap');
      return;
    }

    if (_currentHintExplanation != null) {
      // 🔥 CHECK: Has 500ms passed since bubble appeared?
      if (_bubbleShownTime != null) {
        final timeSinceShown = DateTime.now().difference(_bubbleShownTime!);
        if (timeSinceShown.inMilliseconds < 500) {
          print(
              '⏱️ Too soon to dismiss (${timeSinceShown.inMilliseconds}ms) - ignoring tap');
          return;
        }
      }

      // A lesson has its own close button; tapping the board while reading it
      // must not dismiss it.
      if (controller.gameState.activeLesson != null) return;

      // User tapped grid while bubble is showing - dismiss it
      print('🔕 User tapped grid - dismissing bubble');
      controller.clearHint();
      setState(() {
        _currentHintExplanation = null;
        _showHintButton = true;
        _isLoadingHint = false;
        _bubbleDismissedByUser = true; // Mark as dismissed by user
        _bubbleShownTime = null; // Reset timer
      });
    }
  }

  // 🔥 NEW: Handle bubble close button
  void _handleBubbleClose() {
    print('❌ User closed bubble');
    controller.clearHint();
    setState(() {
      _currentHintExplanation = null;
      _showHintButton = true;
      _bubbleDismissedByUser = true; // Mark as dismissed by user
      _bubbleShownTime = null; // Reset timer
    });
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
                      onTap: _handleGridTap, // 🔥 CHANGED: Use new handler
                      child: RepaintBoundary(
                        child: SingleChildScrollView(
                          reverse: _currentHintExplanation != null ||
                              _isLoadingHint,
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
                      onClose:
                          _handleBubbleClose, // 🔥 CHANGED: Use new handler
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
                  isVisible: _showHintButton &&
                      controller.gameState.activeLesson == null,
                ),

              // The lesson sits over the number pad rather than in the column.
              // Inline, it stole height from the board and pushed the very
              // cells it was talking about out of view — and the pad is not
              // needed while reading a hint anyway.
              if (!_isLoadingHint && controller.gameState.activeLesson != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _LessonSheet(
                    child: HintLessonPanel(
                      lesson: controller.gameState.activeLesson!,
                      stageIndex: controller.gameState.lessonStage,
                      onNext: controller.nextLessonStage,
                      onBack: controller.previousLessonStage,
                      onApply: () async {
                        await controller.applyLesson();
                        if (mounted) {
                          setState(() {
                            _showHintButton = true;
                            _currentHintExplanation = null;
                          });
                        }
                      },
                      onClose: () {
                        controller.dismissLesson();
                        if (mounted) {
                          setState(() {
                            _showHintButton = true;
                            _currentHintExplanation = null;
                          });
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slides the lesson up over the number pad.
///
/// Opaque, because the pad underneath would otherwise show through and make the
/// text hard to read.
class _LessonSheet extends StatefulWidget {
  final Widget child;

  const _LessonSheet({required this.child});

  @override
  State<_LessonSheet> createState() => _LessonSheetState();
}

class _LessonSheetState extends State<_LessonSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _controller, curve: AppMotion.enter);

    return SlideTransition(
      position: Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curve),
      child: FadeTransition(
        opacity: curve,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.ink),
          child: SafeArea(top: false, child: widget.child),
        ),
      ),
    );
  }
}
