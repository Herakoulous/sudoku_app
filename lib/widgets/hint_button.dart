// File path: lib/widgets/hint_button.dart
import 'package:flutter/material.dart';
import '../utils/realm_theme.dart';

class HintButton extends StatelessWidget {
  final RealmTheme theme;
  final VoidCallback onPressed;
  final bool isVisible;

  const HintButton({
    super.key,
    required this.theme,
    required this.onPressed,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 80, // Below the game header
      right: 16,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.accentColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.accentColor.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            Icons.lightbulb,
            color: Colors.black,
            size: 28,
          ),
        ),
      ),
    );
  }
}
