import '../utils/realm_theme.dart';
import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../widgets/settings_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: Exit button, Title, and action buttons
          Row(
            children: [
              buildExitButton(),
              const SizedBox(width: 8),
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
              buildSettingsButton(),
              const SizedBox(width: 4),
              if (_showTimer) ...[
                buildTimer(),
                const SizedBox(width: 2),
              ],
              buildRestartButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildExitButton() {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: widget.theme.primaryColor, size: 20),
      onPressed: widget.onExit,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      iconSize: 20,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget buildSettingsButton() {
    return IconButton(
      icon: Icon(Icons.settings, color: widget.theme.primaryColor, size: 20),
      onPressed: _openSettings,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      tooltip: 'Settings',
      iconSize: 20,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget buildRestartButton() {
    return IconButton(
      icon: Icon(Icons.refresh, color: widget.theme.primaryColor, size: 20),
      onPressed: widget.onRestart,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      iconSize: 20,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget buildTimer() {
    return Text(
      _formatDuration(widget.elapsedTime),
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: widget.theme.accentColor,
      ),
    );
  }

  Widget buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(10, (index) {
        return Icon(
          index < widget.difficulty ? Icons.star : Icons.star_border,
          color: widget.theme.primaryColor,
          size: 14,
        );
      }),
    );
  }

  Widget buildTitle() {
    return Text(
      widget.puzzleId,
      style: TextStyle(
        fontSize: 18,
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
