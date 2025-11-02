import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../utils/realm_theme.dart';

class CompletionDialog extends StatefulWidget {
  final String puzzleId;
  final int difficulty;
  final Duration elapsedTime;
  final Duration? previousBestTime;
  final RealmTheme theme;
  final VoidCallback onNextPuzzle;
  final VoidCallback onBackToLevels;
  final VoidCallback onPlayAgain;

  const CompletionDialog({
    Key? key,
    required this.puzzleId,
    required this.difficulty,
    required this.elapsedTime,
    this.previousBestTime,
    required this.theme,
    required this.onNextPuzzle,
    required this.onBackToLevels,
    required this.onPlayAgain,
  }) : super(key: key);

  @override
  State<CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<CompletionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  bool get isNewBestTime {
    if (widget.previousBestTime == null) return true;
    return widget.elapsedTime < widget.previousBestTime!;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          // Confetti effect
          ...List.generate(20, (index) => _buildConfetti(index)),

          // Main dialog content
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              constraints: BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: widget.theme.primaryColor.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with trophy
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.theme.primaryColor,
                          widget.theme.accentColor,
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Trophy icon
                        Icon(
                          Icons.emoji_events,
                          size: 80,
                          color: Colors.white,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Puzzle Complete!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          widget.puzzleId.toUpperCase(),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stats section
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Time
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timer,
                              color: widget.theme.primaryColor,
                              size: 32,
                            ),
                            SizedBox(width: 12),
                            Text(
                              _formatTime(widget.elapsedTime),
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),

                        // New best time badge
                        if (isNewBestTime) ...[
                          SizedBox(height: 12),
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'NEW BEST TIME!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else if (widget.previousBestTime != null) ...[
                          SizedBox(height: 8),
                          Text(
                            'Best: ${_formatTime(widget.previousBestTime!)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],

                        SizedBox(height: 24),

                        // Difficulty stars
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            widget.difficulty.clamp(1, 5),
                            (index) => Icon(
                              Icons.star,
                              color: widget.theme.primaryColor,
                              size: 24,
                            ),
                          ),
                        ),

                        SizedBox(height: 32),

                        // Action buttons
                        Column(
                          children: [
                            // Next Puzzle button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onNextPuzzle();
                                },
                                icon: Icon(Icons.arrow_forward),
                                label: Text(
                                  'Next Puzzle',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.theme.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 12),

                            // Play Again button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onPlayAgain();
                                },
                                icon: Icon(Icons.refresh),
                                label: Text(
                                  'Play Again',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: widget.theme.primaryColor,
                                  side: BorderSide(
                                    color: widget.theme.primaryColor,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 12),

                            // Back to Levels button
                            TextButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                widget.onBackToLevels();
                              },
                              icon: Icon(Icons.grid_view, size: 20),
                              label: Text('Back to Levels'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfetti(int index) {
    final random = math.Random(index);
    final size = random.nextDouble() * 8 + 4;
    final left = random.nextDouble() * 400;
    final top = -random.nextDouble() * 100;
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
    ];
    final color = colors[random.nextInt(colors.length)];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 2000 + random.nextInt(1000)),
      builder: (context, value, child) {
        return Positioned(
          left: left,
          top: top + (500 * value),
          child: Transform.rotate(
            angle: value * math.pi * 4,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: random.nextBool() ? BoxShape.circle : BoxShape.rectangle,
              ),
            ),
          ),
        );
      },
    );
  }
}
