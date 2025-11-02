import '../utils/realm_theme.dart'; // 🔥 ADD THIS
import 'package:flutter/material.dart';

class GameHeader extends StatelessWidget {
  final int difficulty;
  final String puzzleId;
  final Duration elapsedTime;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  final RealmTheme theme; // 🔥 ADD THIS

  const GameHeader({
    super.key,
    required this.difficulty,
    required this.puzzleId,
    required this.elapsedTime,
    required this.onRestart,
    required this.onExit,
    required this.theme, // 🔥 ADD THIS
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
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
          const SizedBox(width: 8),
          buildTimer(),
          const SizedBox(width: 8),
          buildRestartButton(),
        ],
      ),
    );
  }

  Widget buildExitButton() {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: theme.primaryColor), // 🔥 CHANGED
      onPressed: onExit,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget buildRestartButton() {
    return IconButton(
      icon: Icon(Icons.refresh, color: theme.primaryColor), // 🔥 CHANGED
      onPressed: onRestart,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget buildTimer() {
    return Text(
      _formatDuration(elapsedTime),
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: theme.accentColor, // 🔥 CHANGED
      ),
    );
  }

  Widget buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(10, (index) {
        return Icon(
          index < difficulty ? Icons.star : Icons.star_border,
          color: theme.primaryColor, // 🔥 CHANGED (was Colors.amber)
          size: 15,
        );
      }),
    );
  }

  Widget buildTitle() {
    return Text(
      puzzleId,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: theme.primaryColor, // 🔥 CHANGED
      ),
      textAlign: TextAlign.center,
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes);
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
