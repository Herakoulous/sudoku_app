import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../data/puzzles.dart';
import '../models/archived_game.dart';
import '../models/position.dart';
import '../services/validation_service.dart';
import '../theme/app_theme.dart';
import '../utils/realm_theme.dart';
import 'common/app_button.dart';
import 'common/app_chrome.dart';
import 'sudoku_grid.dart';

/// A read-only look back at a finished game.
///
/// The board is shown exactly as it was solved, with any wrong digits flagged in
/// red. Because the whole move history was archived, the player can step back
/// and forth through their own solve with undo and redo — useful for seeing
/// where a mistake crept in.
class ArchiveReviewScreen extends StatefulWidget {
  final ArchivedGame game;

  const ArchiveReviewScreen({super.key, required this.game});

  @override
  State<ArchiveReviewScreen> createState() => _ArchiveReviewScreenState();
}

class _ArchiveReviewScreenState extends State<ArchiveReviewScreen> {
  late final GameController _controller;
  late final RealmTheme _theme;

  @override
  void initState() {
    super.initState();

    _theme = RealmTheme.fromRealmSync(
      widget.game.realmName.isEmpty ? 'Classic Kingdom' : widget.game.realmName,
    );

    // Ephemeral: reviewing must never write anything back. The archived state is
    // dropped straight in, action history and all, so undo/redo walk the real
    // solve.
    _controller = GameController(
      puzzleId: widget.game.puzzleId,
      difficulty: widget.game.state.difficulty,
      ephemeral: true,
    );
    _controller.gameState = widget.game.state;
    _controller.forceShowMistakes = false; // we mark mistakes ourselves

    _markMistakes();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    _markMistakes();
    if (mounted) setState(() {});
  }

  /// Flags every wrong digit against the solution. Recomputed after each undo or
  /// redo, so the red marks always match the board on screen.
  void _markMistakes() {
    final state = _controller.gameState;
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        state.grid[r][c].isError = false;
      }
    }

    final result = ValidationService.validateUserEntries(state);
    if (!result.isValid) {
      ValidationService.markWrongCells(state, result.wrongCells);
    }
  }

  int get _mistakeCount {
    final solution = Puzzles.getPuzzle(widget.game.puzzleId)?.solution;
    if (solution == null) return 0;

    var count = 0;
    final grid = _controller.gameState.grid;
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final cell = grid[r][c];
        if (!cell.isGiven &&
            cell.number != null &&
            cell.number != solution[r][c]) {
          count++;
        }
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final mistakes = _mistakeCount;

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: AppBackground(
        accentGlow: AppColors.gold,
        child: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                title: 'Review',
                subtitle: widget.game.realmName.isEmpty
                    ? 'Classic Kingdom'
                    : widget.game.realmName,
                onBack: () => Navigator.pop(context),
              ),
              _summary(mistakes),
              Expanded(
                child: SingleChildScrollView(
                  child: IgnorePointer(
                    // Read-only: taps must not edit an archived game.
                    child: SudokuGrid(controller: _controller, theme: _theme),
                  ),
                ),
              ),
              _controls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(int mistakes) {
    final clean = mistakes == 0;
    final colour = clean ? AppColors.success : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.gutter,
        vertical: AppSpace.xs,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colour.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(
              clean ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              size: 18,
              color: colour,
            ),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: Text(
                clean
                    ? 'A clean solve — no wrong digits on the board.'
                    : '$mistakes wrong ${mistakes == 1 ? 'digit is' : 'digits are'} '
                        'flagged in red.',
                style: AppType.body.copyWith(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.xs,
        AppSpace.gutter,
        AppSpace.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: AppButton(
              label: 'Undo',
              icon: Icons.undo_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: _controller.canUndo() ? _controller.undo : null,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: AppButton(
              label: 'Redo',
              icon: Icons.redo_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: _controller.canRedo() ? _controller.redo : null,
            ),
          ),
        ],
      ),
    );
  }
}
