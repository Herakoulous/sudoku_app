import 'package:flutter/material.dart';
import '../utils/realm_theme.dart';

class HintLoadingIndicator extends StatefulWidget {
  final RealmTheme theme;

  const HintLoadingIndicator({
    super.key,
    required this.theme,
  });

  @override
  State<HintLoadingIndicator> createState() => _HintLoadingIndicatorState();
}

class _HintLoadingIndicatorState extends State<HintLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.theme.primaryColor.withOpacity(0.1),
        border: Border.all(
          color: widget.theme.primaryColor.withOpacity(0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 2 * 3.14159,
                child: Icon(
                  Icons.lightbulb_outline,
                  size: 24,
                  color: widget.theme.primaryColor,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Text(
            'Finding hint...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.theme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
