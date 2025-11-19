import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../utils/realm_theme.dart';

class CompletionDialog extends StatefulWidget {
  static const bool debugShowCheckedModeBanner = false;
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
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
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
    final screenHeight = MediaQuery.of(context).size.height;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              ...List.generate(
                  30, (index) => _buildParticle(index, constraints.maxWidth)),
              _buildDialogContent(screenHeight),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialogContent(double screenHeight) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: screenHeight - 48,
          ),
          decoration: _buildDialogDecoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Material(
              color: Colors.transparent,
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    _buildStatsSection(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildDialogDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0A101A),
          Color(0xFF1a2030),
          Color(0xFF0A101A),
        ],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: widget.theme.primaryColor.withOpacity(0.3),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: widget.theme.primaryColor.withOpacity(0.2),
          blurRadius: 40,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.5),
          blurRadius: 20,
          spreadRadius: 5,
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.theme.primaryColor.withOpacity(0.15),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
      ),
      child: Column(
        children: [
          _buildAnimatedTrophy(),
          SizedBox(height: 12),
          _buildTitle(),
          SizedBox(height: 4),
          _buildPuzzleId(),
        ],
      ),
    );
  }

  Widget _buildAnimatedTrophy() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (value * 0.2),
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.theme.accentColor.withOpacity(0.3),
                  widget.theme.primaryColor.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
            child: Icon(
              Icons.emoji_events,
              size: 50,
              color: widget.theme.accentColor,
              shadows: [
                Shadow(
                  color: widget.theme.accentColor.withOpacity(0.5),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [
          widget.theme.primaryColor,
          widget.theme.accentColor,
        ],
      ).createShader(bounds),
      child: Text(
        'PUZZLE COMPLETE',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 2,
          fontFamily: 'CinzelDecorative',
        ),
      ),
    );
  }

  Widget _buildPuzzleId() {
    return Text(
      widget.puzzleId.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        color: Colors.white.withOpacity(0.6),
        letterSpacing: 3,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Column(
              children: [
                _buildTimeDisplay(),
                SizedBox(height: 8),
                _buildBestTimeBadge(),
                SizedBox(height: 14),
                _buildDifficultyStars(),
                SizedBox(height: 18),
                _buildActionButtons(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeDisplay() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 18),
      decoration: BoxDecoration(
        color: widget.theme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.theme.primaryColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timer_outlined,
            color: widget.theme.primaryColor,
            size: 22,
          ),
          SizedBox(width: 8),
          Text(
            _formatTime(widget.elapsedTime),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: widget.theme.primaryColor,
              letterSpacing: 1,
              shadows: [
                Shadow(
                  color: widget.theme.primaryColor.withOpacity(0.3),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestTimeBadge() {
    if (isNewBestTime) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 800),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.theme.accentColor,
                    widget.theme.accentColor.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: widget.theme.accentColor.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: Color(0xFF0A101A),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'NEW BEST TIME!',
                    style: TextStyle(
                      color: Color(0xFF0A101A),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else if (widget.previousBestTime != null) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              color: widget.theme.accentColor.withOpacity(0.6),
              size: 16,
            ),
            SizedBox(width: 6),
            Text(
              'Best: ${_formatTime(widget.previousBestTime!)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox.shrink();
  }

  Widget _buildDifficultyStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.difficulty.clamp(1, 5),
        (index) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            Icons.star_rounded,
            color: widget.theme.accentColor,
            size: 20,
            shadows: [
              Shadow(
                color: widget.theme.accentColor.withOpacity(0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildNextPuzzleButton(),
        SizedBox(height: 8),
        _buildPlayAgainButton(),
        SizedBox(height: 6),
        _buildBackToLevelsButton(),
      ],
    );
  }

  Widget _buildNextPuzzleButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: () {
          Navigator.of(context).pop();
          widget.onNextPuzzle();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.theme.primaryColor,
          foregroundColor: Color(0xFF0A101A),
          elevation: 0,
          shadowColor: widget.theme.primaryColor.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'NEXT PUZZLE',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(width: 6),
            Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayAgainButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
        onPressed: () {
          Navigator.of(context).pop();
          widget.onPlayAgain();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: widget.theme.primaryColor,
          side: BorderSide(
            color: widget.theme.primaryColor.withOpacity(0.5),
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh_rounded, size: 18),
            SizedBox(width: 6),
            Text(
              'PLAY AGAIN',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackToLevelsButton() {
    return TextButton(
      onPressed: () {
        Navigator.of(context).pop();
        widget.onBackToLevels();
      },
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withOpacity(0.5),
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.grid_view_rounded, size: 16),
          SizedBox(width: 6),
          Text(
            'Back to Levels',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticle(int index, double maxWidth) {
    final random = math.Random(index);
    final size = random.nextDouble() * 6 + 3;
    final left = random.nextDouble() * maxWidth;
    final top = -random.nextDouble() * 150;

    final colors = [
      widget.theme.primaryColor,
      widget.theme.accentColor,
      widget.theme.primaryColor.withOpacity(0.6),
      widget.theme.accentColor.withOpacity(0.6),
    ];
    final color = colors[random.nextInt(colors.length)];
    final duration = 2500 + random.nextInt(1500);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: duration),
      builder: (context, value, child) {
        return Positioned(
          left: left + (random.nextDouble() * 40 - 20) * value,
          top: top + (600 * value),
          child: Opacity(
            opacity: (1 - value).clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: value * math.pi * 6,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle, // Always circle for particles
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
