import 'package:flutter/material.dart';

import '../utils/realm_theme.dart';
import 'common/indicators.dart';
import '../services/settings_service.dart';
import '../widgets/settings_screen.dart';
import '../widgets/statistics_screen.dart';

class GameHeader extends StatefulWidget {
  final int difficulty;
  final String puzzleId;
  final Duration elapsedTime;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  final RealmTheme theme;
  final VoidCallback? onPause;

  const GameHeader({
    super.key,
    required this.difficulty,
    required this.puzzleId,
    required this.elapsedTime,
    required this.onRestart,
    required this.onExit,
    required this.theme,
    this.onPause,
  });

  @override
  State<GameHeader> createState() => _GameHeaderState();
}

class _GameHeaderState extends State<GameHeader> {
  bool _showTimer = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final showTimer = await SettingsService.getShowTimer();
    if (mounted) {
      setState(() => _showTimer = showTimer);
    }
  }

  void _openSettings() async {
    widget.onPause?.call();

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );

    await _loadSettings();
  }

  void _openStatistics() async {
    widget.onPause?.call();

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StatisticsScreen()),
    );

    // No need to reload settings, just unpause
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: Exit button, Title, and action buttons
          Row(
            children: [
              // Exit button
              buildExitButton(),
              const SizedBox(width: 4),

              // Title and stars (flexible to prevent overflow)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildTitle(),
                    const SizedBox(height: 4),
                    buildStarRating(),
                  ],
                ),
              ),

              // Right side buttons group
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildStatisticsButton(),
                  const SizedBox(width: 2),
                  buildSettingsButton(),
                  const SizedBox(width: 2),
                  if (_showTimer) ...[
                    buildTimer(),
                    const SizedBox(width: 2),
                  ],
                  buildRestartButton(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildExitButton() {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: widget.theme.primaryColor, size: 22),
      onPressed: widget.onExit,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      iconSize: 18,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget buildStatisticsButton() {
    return IconButton(
      icon: Icon(Icons.bar_chart, color: widget.theme.primaryColor, size: 22),
      onPressed: _openStatistics,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: 'Statistics',
      iconSize: 18,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget buildSettingsButton() {
    return IconButton(
      icon: Icon(Icons.settings, color: widget.theme.primaryColor, size: 22),
      onPressed: _openSettings,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: 'Settings',
      iconSize: 18,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget buildRestartButton() {
    return IconButton(
      icon: Icon(Icons.refresh, color: widget.theme.primaryColor, size: 22),
      onPressed: widget.onRestart,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: 'Restart',
      iconSize: 18,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget buildTimer() {
    return Container(
      constraints: const BoxConstraints(minWidth: 44),
      child: Text(
        _formatDuration(widget.elapsedTime),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: widget.theme.accentColor,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Difficulty as a five-segment meter with the tier name, matching how it is
  /// shown everywhere else. Ten star icons at 12px were unreadable and forced a
  /// horizontal scroll view into the header just to fit.
  Widget buildStarRating() {
    // FittedBox: the meter's segments plus a long tier name like "Apprentice"
    // can be wider than the narrow title column between the two icon groups.
    // Scaling down keeps it on one line instead of overflowing to the right.
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: DifficultyMeter(rating: widget.difficulty, segmentWidth: 10),
      ),
    );
  }

  /// "classic 12" and "kropki_7" both read as "Puzzle 12".
  String get _title {
    final match = RegExp(r'(\d+)$').firstMatch(widget.puzzleId);
    return match == null ? widget.puzzleId : 'Puzzle ${match.group(1)}';
  }

  Widget buildTitle() {
    return Text(
      _title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: widget.theme.primaryColor,
      ),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes);
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
