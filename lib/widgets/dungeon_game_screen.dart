import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../data/puzzles.dart';
import '../models/dungeon.dart';
import '../services/dungeon_service.dart';
import '../theme/app_theme.dart';
import '../utils/realm_theme.dart';
import 'common/app_button.dart';
import 'common/app_chrome.dart';
import 'common/indicators.dart';
import 'dungeon_result_screen.dart';
import 'number_pad.dart';
import 'sudoku_grid.dart';

/// One ranked attempt.
///
/// Reuses the board and number pad through an ephemeral controller, so a ranked
/// game on a classic puzzle never disturbs that puzzle's realm save. The screen
/// adds only what ranked play needs on top: the mode's clock, its mistake
/// budget, and a rating outcome at the end.
class DungeonGameScreen extends StatefulWidget {
  final DungeonMode mode;
  final PuzzleData puzzle;

  const DungeonGameScreen({
    super.key,
    required this.mode,
    required this.puzzle,
  });

  @override
  State<DungeonGameScreen> createState() => _DungeonGameScreenState();
}

class _DungeonGameScreenState extends State<DungeonGameScreen> {
  late final GameController _controller;
  final RealmTheme _theme = RealmTheme.fromRealmSync('Classic Kingdom');

  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _finished = false;

  @override
  void initState() {
    super.initState();

    _controller = GameController(
      puzzleId: widget.puzzle.id,
      difficulty: widget.puzzle.difficulty,
      ephemeral: true,
    )..forceShowMistakes = widget.mode.highlightsMistakes;

    _controller.addListener(_onChanged);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  Duration? get _limit => widget.mode.timeLimit;

  Duration get _remaining =>
      _limit == null ? Duration.zero : _limit! - _elapsed;

  int get _mistakes => _controller.gameState.mistakesThisGame;

  int get _livesLeft =>
      (widget.mode.mistakeLimit - _mistakes).clamp(0, widget.mode.mistakeLimit);

  void _tick() {
    if (_finished) return;
    setState(() => _elapsed += const Duration(seconds: 1));

    if (_limit != null && _elapsed >= _limit!) {
      _finish(won: false);
    }
  }

  void _onChanged() {
    if (_finished) return;

    if (_controller.gameState.isCompleted) {
      _finish(won: true);
      return;
    }

    // Survival ends the moment the mistake budget is spent.
    if (widget.mode.highlightsMistakes &&
        _mistakes >= widget.mode.mistakeLimit) {
      _finish(won: false);
    }
  }

  Future<void> _finish({required bool won}) async {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();

    final result = await DungeonService.recordOutcome(
      mode: widget.mode,
      won: won,
      difficulty: widget.puzzle.difficulty,
      elapsed: _elapsed,
      mistakes: _mistakes,
      puzzleId: widget.puzzle.id,
    );

    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DungeonResultScreen(
          result: result,
          puzzle: widget.puzzle,
        ),
      ),
    );
  }

  Future<bool> _confirmQuit() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.stroke),
        ),
        title: Text('Forfeit this run?', style: AppType.titleMedium),
        content: Text(
          'Leaving now counts as a loss and costs you rating.',
          style: AppType.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep playing',
                style: AppType.label.copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Forfeit',
                style: AppType.label.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (quit == true) {
      await _finish(won: false);
      return false; // _finish already navigated
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_finished) _confirmQuit();
      },
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: AppBackground(
          accentGlow: AppColors.gold,
          child: SafeArea(
            child: Column(
              children: [
                _header(),
                const SizedBox(height: AppSpace.xs),
                Expanded(
                  child: SingleChildScrollView(
                    child: SudokuGrid(controller: _controller, theme: _theme),
                  ),
                ),
                NumberPad(controller: _controller, theme: _theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.xs,
        AppSpace.md,
        0,
      ),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Forfeit',
            onPressed: _confirmQuit,
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(widget.mode.icon, size: 14, color: AppColors.gold),
                    const SizedBox(width: AppSpace.xxs),
                    Text(widget.mode.title,
                        style: AppType.label
                            .copyWith(color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    DifficultyMeter(
                      rating: widget.puzzle.difficulty,
                      showLabel: false,
                      segmentWidth: 9,
                    ),
                    const SizedBox(width: AppSpace.xs),
                    // The puzzle's own Elo, so the player can see what this run
                    // is worth as they solve it.
                    Icon(Icons.shield_rounded,
                        size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 2),
                    Text(
                      '${DungeonService.puzzleRating(widget.puzzle.difficulty)}',
                      style: AppType.numeric.copyWith(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _statusChip(),
        ],
      ),
    );
  }

  Widget _statusChip() {
    if (widget.mode == DungeonMode.timeRush) {
      final remaining = _remaining;
      final urgent = remaining.inMinutes < 5;
      return _clockChip(remaining, urgent);
    }

    // Survival: hearts for the mistake budget.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.mode.mistakeLimit; i++)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Icon(
              i < _livesLeft
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 18,
              color: i < _livesLeft ? AppColors.danger : AppColors.textMuted,
            ),
          ),
      ],
    );
  }

  Widget _clockChip(Duration remaining, bool urgent) {
    final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final colour = urgent ? AppColors.danger : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colour.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: colour),
          const SizedBox(width: AppSpace.xxs),
          Text('$minutes:$seconds',
              style: AppType.numeric.copyWith(fontSize: 14, color: colour)),
        ],
      ),
    );
  }
}
