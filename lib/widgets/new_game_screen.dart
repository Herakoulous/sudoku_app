import 'package:flutter/material.dart';

class NewGameScreen extends StatefulWidget {
  const NewGameScreen({super.key});

  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen> {
  // Track which variant is currently expanded (null = none expanded)
  String? _expandedVariant;

  // Variant data structure
  final List<VariantData> _variants = [
    VariantData(
      id: 'classic',
      name: 'Classic',
      icon: '🟦',
      gradient: const [Color(0xFF1565C0), Color(0xFF0D47A1)],
      puzzles: [
        PuzzleData(id: 'classic_easy_1', name: 'Easy #1', difficulty: 3),
        PuzzleData(id: 'classic_easy_2', name: 'Easy #2', difficulty: 3),
        PuzzleData(id: 'classic_medium_1', name: 'Medium #1', difficulty: 5),
        PuzzleData(id: 'classic_medium_2', name: 'Medium #2', difficulty: 5),
        PuzzleData(id: 'classic_hard_1', name: 'Hard #1', difficulty: 8),
      ],
    ),
    VariantData(
      id: 'kropki',
      name: 'Kropki',
      icon: '⚫',
      gradient: const [Color(0xFF6A1B9A), Color(0xFF4A148C)],
      puzzles: [
        PuzzleData(id: 'kropki_easy_1', name: 'Easy #1', difficulty: 4),
        PuzzleData(id: 'kropki_medium_1', name: 'Medium #1', difficulty: 6),
        PuzzleData(id: 'kropki_hard_1', name: 'Hard #1', difficulty: 9),
      ],
    ),
    VariantData(
      id: 'thermo',
      name: 'Thermo',
      icon: '🔥',
      gradient: const [Color(0xFFD84315), Color(0xFFBF360C)],
      puzzles: [
        PuzzleData(id: 'thermo_easy_1', name: 'Easy #1', difficulty: 4),
        PuzzleData(id: 'thermo_medium_1', name: 'Medium #1', difficulty: 6),
        PuzzleData(id: 'thermo_hard_1', name: 'Hard #1', difficulty: 8),
      ],
    ),
    VariantData(
      id: 'german_whispers',
      name: 'German Whispers',
      icon: '🐍',
      gradient: const [Color(0xFF2E7D32), Color(0xFF1B5E20)],
      puzzles: [
        PuzzleData(id: 'whispers_easy_1', name: 'Easy #1', difficulty: 5),
        PuzzleData(id: 'whispers_medium_1', name: 'Medium #1', difficulty: 7),
        PuzzleData(id: 'whispers_hard_1', name: 'Hard #1', difficulty: 9),
      ],
    ),
    VariantData(
      id: 'xv',
      name: 'XV',
      icon: '❌',
      gradient: const [Color(0xFFC62828), Color(0xFFB71C1C)],
      puzzles: [
        PuzzleData(id: 'xv_easy_1', name: 'Easy #1', difficulty: 4),
        PuzzleData(id: 'xv_medium_1', name: 'Medium #1', difficulty: 6),
        PuzzleData(id: 'xv_hard_1', name: 'Hard #1', difficulty: 8),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Same gradient background as main menu
          _buildGradientBackground(),

          // Subtle Sudoku grid overlay
          _buildSudokuGridOverlay(),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                _buildAppBar(context),

                // Variant cards (scrollable)
                Expanded(
                  child: _buildVariantList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Background gradient (matching main menu)
  Widget _buildGradientBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A237E), // Deep indigo
            Color(0xFF0277BD), // Medium blue
            Color(0xFF4FC3F7), // Light cyan
          ],
        ),
      ),
    );
  }

  /// Subtle Sudoku grid pattern overlay
  Widget _buildSudokuGridOverlay() {
    return Positioned.fill(
      child: CustomPaint(
        painter: _SudokuGridPainter(),
      ),
    );
  }

  /// Custom AppBar with back button
  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          // Title
          Text(
            'Choose Variant',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.95),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Scrollable list of variant cards
  Widget _buildVariantList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive: 1 column on phones, 2 on tablets
        // final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
        // final childAspectRatio = constraints.maxWidth > 600 ? 1.2 : 1.5;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _variants.length,
          itemBuilder: (context, index) {
            final variant = _variants[index];
            final isExpanded = _expandedVariant == variant.id;

            return _VariantCard(
              variant: variant,
              isExpanded: isExpanded,
              onTap: () {
                setState(() {
                  // Toggle expansion
                  _expandedVariant = isExpanded ? null : variant.id;
                });
              },
              onPuzzleTap: (puzzle) => _onPuzzleSelected(variant, puzzle),
            );
          },
        );
      },
    );
  }

  /// Callback when a puzzle is selected
  void _onPuzzleSelected(VariantData variant, PuzzleData puzzle) {
    print('Selected: ${variant.name} - ${puzzle.name} (${puzzle.id})');
    // TODO: Navigate to game screen with puzzle data
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => GameScreen(
    //       puzzleId: puzzle.id,
    //       difficulty: puzzle.difficulty,
    //     ),
    //   ),
    // );
  }
}

/// Reusable variant card with expand animation
class _VariantCard extends StatefulWidget {
  final VariantData variant;
  final bool isExpanded;
  final VoidCallback onTap;
  final Function(PuzzleData) onPuzzleTap;

  const _VariantCard({
    required this.variant,
    required this.isExpanded,
    required this.onTap,
    required this.onPuzzleTap,
  });

  @override
  State<_VariantCard> createState() => _VariantCardState();
}

class _VariantCardState extends State<_VariantCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.variant.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  offset: const Offset(0, 6),
                  blurRadius: 16,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  // Variant header (always visible)
                  _buildVariantHeader(),

                  // Puzzle list (animated expansion)
                  _buildPuzzleList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Variant header with icon and name
  Widget _buildVariantHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          // Icon/Emoji
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                widget.variant.icon,
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Variant name
          Expanded(
            child: Text(
              widget.variant.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Expand/Collapse icon
          AnimatedRotation(
            duration: const Duration(milliseconds: 300),
            turns: widget.isExpanded ? 0.5 : 0,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withOpacity(0.8),
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  /// Animated puzzle list
  Widget _buildPuzzleList() {
    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: Container(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 20),
        child: Column(
          children: widget.variant.puzzles.map((puzzle) {
            return _PuzzleButton(
              puzzle: puzzle,
              onTap: () => widget.onPuzzleTap(puzzle),
            );
          }).toList(),
        ),
      ),
      crossFadeState: widget.isExpanded
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 300),
      sizeCurve: Curves.easeInOut,
    );
  }
}

/// Reusable puzzle button
class _PuzzleButton extends StatefulWidget {
  final PuzzleData puzzle;
  final VoidCallback onTap;

  const _PuzzleButton({
    required this.puzzle,
    required this.onTap,
  });

  @override
  State<_PuzzleButton> createState() => _PuzzleButtonState();
}

class _PuzzleButtonState extends State<_PuzzleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _isPressed
                ? Colors.white.withOpacity(0.3)
                : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Puzzle name
              Expanded(
                child: Text(
                  widget.puzzle.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),

              // Difficulty stars
              Row(
                children: List.generate(10, (index) {
                  return Icon(
                    index < widget.puzzle.difficulty
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 14,
                  );
                }),
              ),

              const SizedBox(width: 8),

              // Arrow icon
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Data model for variants
class VariantData {
  final String id;
  final String name;
  final String icon;
  final List<Color> gradient;
  final List<PuzzleData> puzzles;

  const VariantData({
    required this.id,
    required this.name,
    required this.icon,
    required this.gradient,
    required this.puzzles,
  });
}

/// Data model for puzzles
class PuzzleData {
  final String id;
  final String name;
  final int difficulty; // 0-10 scale

  const PuzzleData({
    required this.id,
    required this.name,
    required this.difficulty,
  });
}

/// Custom painter for subtle Sudoku grid overlay (same as main menu)
class _SudokuGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final thickPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final gridSize = size.width * 0.8;
    final cellSize = gridSize / 9;
    final offsetX = (size.width - gridSize) / 2;
    final offsetY = (size.height - gridSize) / 2;

    // Draw horizontal lines
    for (int i = 0; i <= 9; i++) {
      final y = offsetY + i * cellSize;
      final currentPaint = i % 3 == 0 ? thickPaint : paint;

      canvas.drawLine(
        Offset(offsetX, y),
        Offset(offsetX + gridSize, y),
        currentPaint,
      );
    }

    // Draw vertical lines
    for (int i = 0; i <= 9; i++) {
      final x = offsetX + i * cellSize;
      final currentPaint = i % 3 == 0 ? thickPaint : paint;

      canvas.drawLine(
        Offset(x, offsetY),
        Offset(x, offsetY + gridSize),
        currentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
