import 'package:flutter/material.dart';

import '../data/puzzles.dart';
import '../data/realm_config.dart';
import '../models/difficulty_tier.dart';
import '../services/save_service.dart';
import '../theme/app_theme.dart';
import 'common/app_chrome.dart';
import 'common/indicators.dart';
import 'common/pressable.dart';
import 'level_selection_widget.dart';

/// Whether puzzles unlock progressively.
///
/// The previous implementation computed an unlock count that always exceeded
/// every realm's puzzle count, so gating has never actually applied. Left off
/// so behaviour is unchanged; flip to true to gate each tier behind progress in
/// the tier before it.
const bool kProgressiveUnlock = false;

/// How many puzzles must be solved in a tier before the next tier opens.
const int kSolvesToAdvanceTier = 3;

/// Puzzle picker for one realm. Puzzles are grouped by difficulty tier rather
/// than listed as a flat run of numbers — players choose by how hard they want
/// to work, and a 52-item wall becomes five short, scannable sections.
class LevelSelectionScreen extends StatefulWidget {
  final String realmName;
  final List<dynamic> puzzles;

  const LevelSelectionScreen({
    super.key,
    required this.realmName,
    required this.puzzles,
  });

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> {
  List<PuzzleStatus> _statuses = [];
  bool _loading = true;

  List<PuzzleData> get _puzzles => widget.puzzles.cast<PuzzleData>();

  Color get _accent => RealmConfig.getPrimaryColor(widget.realmName);

  int get _completedCount => _statuses.where((s) => s.isCompleted).length;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  /// Reads every puzzle's saved state. Fanned out with Future.wait — a realm
  /// can hold 52 puzzles and reading them one at a time visibly delays the
  /// first paint.
  Future<void> _loadProgress() async {
    final saved = await Future.wait(
      _puzzles.map((p) => SaveService.loadGame(p.id)),
    );
    final bestTimes = await Future.wait(
      _puzzles.map((p) => SaveService.getBestTime(p.id)),
    );
    final completed = await Future.wait(
      _puzzles.map((p) => SaveService.isCompleted(p.id)),
    );

    if (!mounted) return;

    // Tier gating needs the per-tier completion counts, so tally first.
    final completedByTier = <DifficultyTier, int>{};
    for (var i = 0; i < _puzzles.length; i++) {
      if (!completed[i]) continue;
      final tier = DifficultyTier.fromRating(_puzzles[i].difficulty);
      completedByTier[tier] = (completedByTier[tier] ?? 0) + 1;
    }

    setState(() {
      _statuses = [
        for (var i = 0; i < _puzzles.length; i++)
          PuzzleStatus(
            puzzle: _puzzles[i],
            number: i + 1,
            savedGame: saved[i],
            bestTimeSeconds: bestTimes[i],
            isCompleted: completed[i],
            isLocked: _isLocked(
              DifficultyTier.fromRating(_puzzles[i].difficulty),
              completedByTier,
            ),
          ),
      ];
      _loading = false;
    });
  }

  bool _isLocked(
    DifficultyTier tier,
    Map<DifficultyTier, int> completedByTier,
  ) {
    if (!kProgressiveUnlock) return false;
    if (tier.index == 0) return false;

    final previous = DifficultyTier.values[tier.index - 1];
    return (completedByTier[previous] ?? 0) < kSolvesToAdvanceTier;
  }

  Future<void> _play(PuzzleStatus status) async {
    await Navigator.pushNamed(
      context,
      '/game',
      arguments: {'puzzle': status.puzzle, 'realmName': widget.realmName},
    );
    if (mounted) _loadProgress();
  }

  Future<void> _restart(PuzzleStatus status) async {
    await SaveService.clearSave(status.puzzle.id);
    await _play(status);
  }

  void _openDetail(PuzzleStatus status) {
    PuzzleDetailSheet.show(
      context: context,
      status: status,
      realmName: widget.realmName,
      onPlay: () => _play(status),
      onRestart: () => _restart(status),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _puzzles.length;

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: AppBackground(
        artAsset: RealmConfig.getArtForRealm(widget.realmName),
        artOpacity: 0.22,
        artBlur: 6,
        accentGlow: _accent,
        child: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                title: widget.realmName,
                subtitle: '$_completedCount of $total solved',
                displayTitle: true,
                onBack: () => Navigator.pop(context),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.xs,
                  AppSpace.gutter,
                  AppSpace.md,
                ),
                child: ProgressBar(
                  progress: total == 0 ? 0 : _completedCount / total,
                  color: _accent,
                ),
              ),

              Expanded(
                child: _loading
                    ? Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _accent,
                          ),
                        ),
                      )
                    : _buildTierSections(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierSections() {
    // Preserve puzzle order inside each tier so numbering still climbs.
    final byTier = <DifficultyTier, List<PuzzleStatus>>{};
    for (final status in _statuses) {
      final tier = DifficultyTier.fromRating(status.puzzle.difficulty);
      byTier.putIfAbsent(tier, () => []).add(status);
    }

    final sections = <Widget>[];
    var sectionIndex = 0;

    for (final tier in DifficultyTier.values) {
      final group = byTier[tier];
      if (group == null || group.isEmpty) continue;

      final solved = group.where((s) => s.isCompleted).length;

      sections.add(
        FadeSlideIn(
          delay: AppMotion.stagger(sectionIndex),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: tier.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: SectionLabel(
                        label: tier.label,
                        trailing: '$solved/${group.length}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: AppSpace.xs,
                    mainAxisSpacing: AppSpace.xs,
                  ),
                  itemCount: group.length,
                  itemBuilder: (context, i) => PuzzleTile(
                    status: group[i],
                    accent: _accent,
                    onTap: () => _openDetail(group[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      sectionIndex++;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        0,
        AppSpace.gutter,
        AppSpace.xxl,
      ),
      children: sections,
    );
  }
}
