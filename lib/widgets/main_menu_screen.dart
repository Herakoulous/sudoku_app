import 'package:flutter/material.dart';

import '../data/puzzles.dart';
import '../data/realm_config.dart';
import '../models/game_state.dart';
import '../services/save_service.dart';
import '../theme/app_theme.dart';
import 'common/app_button.dart';
import 'common/indicators.dart';
import 'common/pressable.dart';

/// The unfinished game surfaced by the Continue card.
class _ResumableGame {
  final PuzzleData puzzle;
  final String realmName;
  final double progress;
  final Duration elapsed;

  const _ResumableGame({
    required this.puzzle,
    required this.realmName,
    required this.progress,
    required this.elapsed,
  });

  Realm? get realm => RealmConfig.getRealm(realmName);
}

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  _ResumableGame? _resumable;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadResumableGame();
  }

  /// Finds the most recently played unfinished puzzle so the player can drop
  /// straight back into it instead of navigating three screens to find it.
  Future<void> _loadResumableGame() async {
    final puzzleId = await SaveService.getMostRecentSaveId();

    if (puzzleId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final puzzle = Puzzles.getPuzzle(puzzleId);
    final realmName = RealmConfig.realmForPuzzleId(puzzleId);
    final saved = await SaveService.loadGame(puzzleId);

    if (!mounted) return;

    // A save can outlive its puzzle if the puzzle data was regenerated.
    if (puzzle == null || realmName == null || saved == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _resumable = _ResumableGame(
        puzzle: puzzle,
        realmName: realmName,
        progress: _progressOf(saved),
        elapsed: saved.elapsedTime,
      );
      _loading = false;
    });
  }

  double _progressOf(GameState state) {
    var filled = 0;
    for (final row in state.currentGrid) {
      filled += row.where((value) => value != 0).length;
    }
    return filled / 81.0;
  }

  Future<void> _openRealms() async {
    await Navigator.pushNamed(context, '/realm-selection');
    _loadResumableGame();
  }

  Future<void> _resume() async {
    final game = _resumable;
    if (game == null) return;

    await Navigator.pushNamed(
      context,
      '/game',
      arguments: {'puzzle': game.puzzle, 'realmName': game.realmName},
    );
    _loadResumableGame();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- Hero artwork, bleeding into the page from the top ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.78,
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.35, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: Image.asset(
                'images/castle_background.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

          // Scrim: keeps the wordmark legible and sinks the art back.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.ink.withValues(alpha: 0.55),
                    AppColors.ink.withValues(alpha: 0.72),
                    AppColors.ink,
                  ],
                  stops: const [0.0, 0.5, 0.88],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: Column(
                children: [
                  const Spacer(flex: 5),
                  const FadeSlideIn(child: _Wordmark()),
                  const Spacer(flex: 4),

                  if (!_loading && _resumable != null)
                    FadeSlideIn(
                      delay: AppMotion.stagger(1),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.md),
                        child: _ContinueCard(
                          game: _resumable!,
                          onTap: _resume,
                        ),
                      ),
                    ),

                  // Classroom, Statistics and Settings used to live here as
                  // buttons; they are bottom-nav tabs now, so the Play tab is
                  // just the hero, the resume card and the one action that
                  // belongs to this tab.
                  FadeSlideIn(
                    delay: AppMotion.stagger(2),
                    child: AppButton(
                      label: _resumable == null ? 'Play' : 'Choose a Realm',
                      icon: Icons.auto_awesome_rounded,
                      size: AppButtonSize.large,
                      onPressed: _openRealms,
                    ),
                  ),

                  const SizedBox(height: AppSpace.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The app wordmark, gold-filled via a shader so it reads as forged metal
/// rather than flat coloured text.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.goldBright,
              AppColors.gold,
              AppColors.goldDeep,
            ],
            stops: [0.0, 0.55, 1.0],
          ).createShader(rect),
          child: const Column(
            children: [
              Text(
                'SUDOKU',
                textAlign: TextAlign.center,
                style: AppType.displayLarge,
              ),
              Text(
                'REALMS',
                textAlign: TextAlign.center,
                style: AppType.displayLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RuleLine(),
            const Flexible(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpace.sm),
                child: Text(
                  'SIX REALMS, SIX WAYS TO THINK',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppType.overline,
                ),
              ),
            ),
            _RuleLine(),
          ],
        ),
      ],
    );
  }
}

class _RuleLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 1,
      color: AppColors.gold.withValues(alpha: 0.5),
    );
  }
}

/// Resume affordance. Shows enough context — realm, puzzle, how far in, how
/// long spent — that returning feels like picking up a bookmark.
class _ContinueCard extends StatelessWidget {
  final _ResumableGame game;
  final VoidCallback onTap;

  const _ContinueCard({required this.game, required this.onTap});

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// "classic 12" and "kropki_24" both become "Puzzle 12".
  String _puzzleLabel(String id) {
    final match = RegExp(r'(\d+)$').firstMatch(id);
    return match == null ? id : 'Puzzle ${match.group(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = game.realm?.primary ?? AppColors.gold;
    final percent = (game.progress * 100).round();

    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
          boxShadow: AppShadow.soft,
        ),
        child: Row(
          children: [
            ProgressRing(
              progress: game.progress,
              size: 48,
              color: accent,
              center: Text(
                '$percent%',
                style: AppType.numeric.copyWith(fontSize: 12),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CONTINUE',
                    style: AppType.overline.copyWith(color: accent),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _puzzleLabel(game.puzzle.id),
                    style: AppType.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    game.realmName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Row(
                    children: [
                      DifficultyMeter(
                        rating: game.puzzle.difficulty,
                        showLabel: false,
                        segmentWidth: 10,
                      ),
                      const SizedBox(width: AppSpace.xs),
                      Text(
                        _formatDuration(game.elapsed),
                        style: AppType.numeric.copyWith(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.play_circle_fill_rounded,
              size: 34,
              color: accent,
            ),
          ],
        ),
      ),
    );
  }
}
