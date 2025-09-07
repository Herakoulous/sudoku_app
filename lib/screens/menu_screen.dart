import 'package:flutter/material.dart';
import 'puzzle_list_screen.dart';
import '../models/puzzle_repository.dart';
import '../models/game_state.dart';
import '../models/puzzle.dart';
import '../models/variants/variant_constraint.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({Key? key}) : super(key: key);

  Future<void> _continuePlaying(BuildContext context) async {
    final puzzleId = await GameState.getMostRecentPuzzleId();
    if (puzzleId != null) {
      Navigator.pushNamed(context, '/game', arguments: puzzleId);
    }
  }

  void _showPuzzlePreview(BuildContext context, Puzzle puzzle) async {
    final savedState = await GameState.loadFromStorage(puzzle.id);
    final hasProgress = savedState != null && !savedState.isPuzzleSolved;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(20),
            // Made popup smaller to ensure square cells
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Text(
                  puzzle.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'by ${puzzle.author}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),

                // Puzzle info chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildInfoChip(puzzle.type, _getTypeColor(puzzle.type)),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      puzzle.difficulty,
                      _getDifficultyColor(puzzle.difficulty),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Progress info
                if (hasProgress) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Progress Found',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Time: ${_formatDuration(savedState.elapsedTime)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Grid preview with variants
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: _buildGridPreviewWithVariants(puzzle),
                ),

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (hasProgress) ...[
                      TextButton(
                        onPressed: () async {
                          // Restart puzzle
                          await GameState.clearSavedState(puzzle.id);
                          Navigator.of(context).pop();
                          Navigator.pushNamed(
                            context,
                            '/game',
                            arguments: puzzle.id,
                          );
                        },
                        child: const Text('Restart'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.pushNamed(
                            context,
                            '/game',
                            arguments: puzzle.id,
                          );
                        },
                        child: const Text('Continue'),
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.pushNamed(
                            context,
                            '/game',
                            arguments: puzzle.id,
                          );
                        },
                        child: const Text('Start'),
                      ),
                    ],
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridPreviewWithVariants(Puzzle puzzle) {
    return Stack(
      children: [
        // Base grid
        _buildGridPreview(puzzle.initialGrid),
        
        // Variant overlays
        if (puzzle.variantConstraints != null)
          ..._buildVariantOverlaysForPreview(puzzle.variantConstraints!),
      ],
    );
  }

  Widget _buildGridPreview(List<List<int>> initialGrid) {
    return Column(
      children: List.generate(
        9,
        (r) => Expanded(
          child: Row(
            children: List.generate(
              9,
              (c) => Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: Colors.black,
                        width: (c + 1) % 3 == 0 ? 1.5 : 0.5,
                      ),
                      bottom: BorderSide(
                        color: Colors.black,
                        width: (r + 1) % 3 == 0 ? 1.5 : 0.5,
                      ),
                    ),
                  ),
                  child: Center(
                    child: initialGrid[r][c] != 0
                        ? Text(
                            initialGrid[r][c].toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildVariantOverlaysForPreview(List<VariantConstraint> constraints) {
    final overlays = <Widget>[];
    const cellSize = 280.0 / 9;

    for (final constraint in constraints) {
      switch (constraint.type) {
        case 'thermometer':
          final thermo = constraint as ThermometerConstraint;
          overlays.add(_buildThermometerPreview(thermo, cellSize));
          break;
        case 'kropki':
          final kropki = constraint as KropkiConstraint;
          overlays.add(_buildKropkiPreview(kropki, cellSize));
          break;
        case 'xv':
          final xv = constraint as XVConstraint;
          overlays.add(_buildXVPreview(xv, cellSize));
          break;
        case 'killer':
          final killer = constraint as KillerConstraint;
          overlays.add(_buildKillerPreview(killer, cellSize));
          break;
        case 'german_whispers':
          final whispers = constraint as GermanWhispersConstraint;
          overlays.add(_buildGermanWhispersPreview(whispers, cellSize));
          break;
        case 'sandwich':
          final sandwich = constraint as SandwichConstraint;
          overlays.add(_buildSandwichPreview(sandwich, cellSize));
          break;
      }
    }

    return overlays;
  }

  Widget _buildThermometerPreview(ThermometerConstraint thermo, double cellSize) {
    return CustomPaint(
      size: const Size(280, 280),
      painter: ThermometerPreviewPainter(thermo, cellSize),
    );
  }

  Widget _buildKropkiPreview(KropkiConstraint kropki, double cellSize) {
    return CustomPaint(
      size: const Size(280, 280),
      painter: KropkiPreviewPainter(kropki, cellSize),
    );
  }

  Widget _buildXVPreview(XVConstraint xv, double cellSize) {
    return CustomPaint(
      size: const Size(280, 280),
      painter: XVPreviewPainter(xv, cellSize),
    );
  }

  Widget _buildKillerPreview(KillerConstraint killer, double cellSize) {
    return CustomPaint(
      size: const Size(280, 280),
      painter: KillerPreviewPainter(killer, cellSize),
    );
  }

  Widget _buildGermanWhispersPreview(GermanWhispersConstraint whispers, double cellSize) {
    return CustomPaint(
      size: const Size(280, 280),
      painter: GermanWhispersPreviewPainter(whispers, cellSize),
    );
  }

  Widget _buildSandwichPreview(SandwichConstraint sandwich, double cellSize) {
    return CustomPaint(
      size: const Size(280, 280),
      painter: SandwichPreviewPainter(sandwich, cellSize),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Beautiful Header with Animation
                const SizedBox(height: 40),
                _buildAnimatedHeader(),
                const SizedBox(height: 60),

                // Beautiful Menu Options
                _buildBeautifulMenuCard(
                  context,
                  icon: Icons.play_arrow_rounded,
                  title: 'Continue Playing',
                  subtitle: 'Resume your last puzzle',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  onTap: () => _continuePlaying(context),
                ),

                const SizedBox(height: 20),

                _buildBeautifulMenuCard(
                  context,
                  icon: Icons.grid_view_rounded,
                  title: 'All Puzzles',
                  subtitle: '${PuzzleRepository.getAllPuzzles().length} puzzles available',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PuzzleListScreen(
                          onPuzzleSelected: (puzzle) =>
                              _showPuzzlePreview(context, puzzle),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                _buildBeautifulMenuCard(
                  context,
                  icon: Icons.category_rounded,
                  title: 'Browse by Type',
                  subtitle: 'Classic, Thermo, and more',
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PuzzleListScreen(
                          filterByType: true,
                          onPuzzleSelected: (puzzle) =>
                              _showPuzzlePreview(context, puzzle),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                _buildBeautifulMenuCard(
                  context,
                  icon: Icons.speed_rounded,
                  title: 'By Difficulty',
                  subtitle: 'Easy to Expert challenges',
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PuzzleListScreen(
                          filterByDifficulty: true,
                          onPuzzleSelected: (puzzle) =>
                              _showPuzzlePreview(context, puzzle),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),

                // Beautiful Statistics Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Your Progress',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildBeautifulStat('Completed', '0', Icons.check_circle_rounded),
                          _buildBeautifulStat('Best Time', '--:--', Icons.timer_rounded),
                          _buildBeautifulStat('Streak', '0', Icons.local_fire_department_rounded),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Beautiful Settings Button
                GestureDetector(
                  onTap: () {
                    // TODO: Add settings screen
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6B7280), Color(0xFF4B5563)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.settings_rounded, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                        'Settings',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader() {
    return Column(
      children: [
        // Beautiful gradient title
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF06B6D4)],
          ).createShader(bounds),
          child: Text(
            'CTC Sudoku',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Beautiful subtitle
        Builder(
          builder: (context) => Text(
            'Challenge yourself with puzzle variants',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBeautifulMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeautifulStat(String label, String value, IconData icon) {
    return Builder(
      builder: (context) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'classic':
        return Colors.blue;
      case 'thermo':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      case 'expert':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

// Custom painters for variant previews
class ThermometerPreviewPainter extends CustomPainter {
  final ThermometerConstraint thermo;
  final double cellSize;

  ThermometerPreviewPainter(this.thermo, this.cellSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (thermo.line.length < 2) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = Colors.grey.shade600;

    // Draw thermometer line
    for (int i = 0; i < thermo.line.length - 1; i++) {
      final fromCell = thermo.line[i];
      final toCell = thermo.line[i + 1];

      final fromPoint = Offset(
        (fromCell[1] + 0.5) * cellSize,
        (fromCell[0] + 0.5) * cellSize,
      );
      final toPoint = Offset(
        (toCell[1] + 0.5) * cellSize,
        (toCell[0] + 0.5) * cellSize,
      );

      canvas.drawLine(fromPoint, toPoint, paint);
    }

    // Draw bulb at start
    final startCell = thermo.line[0];
    final center = Offset(
      (startCell[1] + 0.5) * cellSize,
      (startCell[0] + 0.5) * cellSize,
    );
    canvas.drawCircle(center, 4, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class KropkiPreviewPainter extends CustomPainter {
  final KropkiConstraint kropki;
  final double cellSize;

  KropkiPreviewPainter(this.kropki, this.cellSize);

  @override
  void paint(Canvas canvas, Size size) {
    final center1 = Offset(
      (kropki.col1 + 0.5) * cellSize,
      (kropki.row1 + 0.5) * cellSize,
    );
    final center2 = Offset(
      (kropki.col2 + 0.5) * cellSize,
      (kropki.row2 + 0.5) * cellSize,
    );

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = kropki.isBlack ? Colors.black : Colors.white;

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.black;

    // Draw dot between cells
    final dotCenter = Offset(
      (center1.dx + center2.dx) / 2,
      (center1.dy + center2.dy) / 2,
    );

    canvas.drawCircle(dotCenter, 3, paint);
    canvas.drawCircle(dotCenter, 3, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class XVPreviewPainter extends CustomPainter {
  final XVConstraint xv;
  final double cellSize;

  XVPreviewPainter(this.xv, this.cellSize);

  @override
  void paint(Canvas canvas, Size size) {
    final center1 = Offset(
      (xv.col1 + 0.5) * cellSize,
      (xv.row1 + 0.5) * cellSize,
    );
    final center2 = Offset(
      (xv.col2 + 0.5) * cellSize,
      (xv.row2 + 0.5) * cellSize,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: xv.symbol,
        style: const TextStyle(
          color: Colors.red,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    final dotCenter = Offset(
      (center1.dx + center2.dx) / 2,
      (center1.dy + center2.dy) / 2,
    );

    textPainter.paint(
      canvas,
      Offset(
        dotCenter.dx - textPainter.width / 2,
        dotCenter.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class KillerPreviewPainter extends CustomPainter {
  final KillerConstraint killer;
  final double cellSize;

  KillerPreviewPainter(this.killer, this.cellSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (killer.cells.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.purple.shade600;

    // Draw cage outline
    final path = Path();
    bool first = true;

    for (final cell in killer.cells) {
      final x = cell[1] * cellSize;
      final y = cell[0] * cellSize;

      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);

    // Draw sum if available
    if (killer.sum != null) {
      final firstCell = killer.cells.first;
      final textPainter = TextPainter(
        text: TextSpan(
          text: killer.sum.toString(),
          style: const TextStyle(
            color: Colors.purple,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          firstCell[1] * cellSize + 2,
          firstCell[0] * cellSize + 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GermanWhispersPreviewPainter extends CustomPainter {
  final GermanWhispersConstraint whispers;
  final double cellSize;

  GermanWhispersPreviewPainter(this.whispers, this.cellSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (whispers.line.length < 2) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = Colors.green.shade600;

    for (int i = 0; i < whispers.line.length - 1; i++) {
      final fromCell = whispers.line[i];
      final toCell = whispers.line[i + 1];

      final fromPoint = Offset(
        (fromCell[1] + 0.5) * cellSize,
        (fromCell[0] + 0.5) * cellSize,
      );
      final toPoint = Offset(
        (toCell[1] + 0.5) * cellSize,
        (toCell[0] + 0.5) * cellSize,
      );

      canvas.drawLine(fromPoint, toPoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SandwichPreviewPainter extends CustomPainter {
  final SandwichConstraint sandwich;
  final double cellSize;

  SandwichPreviewPainter(this.sandwich, this.cellSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (sandwich.clue == null) return;

    Offset position;
    const clueSize = 16.0;

    switch (sandwich.position) {
      case 'top':
        position = Offset(
          (sandwich.index + 0.5) * cellSize - clueSize / 2,
          0,
        );
        break;
      case 'left':
        position = Offset(
          0,
          (sandwich.index + 0.5) * cellSize - clueSize / 2,
        );
        break;
      default:
        return;
    }

    // Draw background circle
    final backgroundPaint = Paint()
      ..color = Colors.yellow.shade100
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.orange.shade600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(
      position.dx + clueSize / 2,
      position.dy + clueSize / 2,
    );
    canvas.drawCircle(center, clueSize / 2, backgroundPaint);
    canvas.drawCircle(center, clueSize / 2, borderPaint);

    // Draw clue text
    final textPainter = TextPainter(
      text: TextSpan(
        text: sandwich.clue.toString(),
        style: TextStyle(
          color: Colors.orange.shade800,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        position.dx + (clueSize - textPainter.width) / 2,
        position.dy + (clueSize - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
