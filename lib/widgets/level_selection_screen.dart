import 'package:flutter/material.dart';
import '../data/puzzles.dart';
import '../services/save_service.dart';
import '../models/game_state.dart';
import '../utils/realm_theme.dart';
import '../models/variant_constraint.dart';

class LevelSelectionScreen extends StatefulWidget {
  final String realmName;
  final List<dynamic> puzzles;

  const LevelSelectionScreen({
    Key? key,
    required this.realmName,
    required this.puzzles,
  }) : super(key: key);

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> {
  int? expandedPuzzleIndex;
  Map<String, GameState?> savedGames = {};
  Map<String, int?> bestTimes = {};

  List<PuzzleData> get puzzleList => widget.puzzles.cast<PuzzleData>();

  @override
  void initState() {
    super.initState();
    print('🔍 LevelSelectionScreen initialized');
    print('🔍 Realm name: ${widget.realmName}');
    print('🔍 Puzzles received: ${widget.puzzles.length}');
    print('🔍 Puzzle list: ${puzzleList.length}');
    if (puzzleList.isNotEmpty) {
      print('🔍 First puzzle: ${puzzleList[0].id}');
    }
    _loadSavedGames();
  }

  Future<void> _loadSavedGames() async {
    for (var puzzle in puzzleList) {
      final saved = await SaveService.loadGame(puzzle.id);
      savedGames[puzzle.id] = saved;

      final bestTime = await SaveService.getBestTime(puzzle.id);
      if (bestTime != null) {
        bestTimes[puzzle.id] = bestTime;
      }
    }
    setState(() {});
  }

  void _togglePuzzle(int index) {
    setState(() {
      if (expandedPuzzleIndex == index) {
        expandedPuzzleIndex = null;
      } else {
        expandedPuzzleIndex = index;
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'images/classic_kingdom_background.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF0A101A),
                        Color(0xFF1a2030),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Gradient overlays
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0A101A).withOpacity(0.7),
                    Color(0xFF0A101A).withOpacity(0.4),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.3, 1.0],
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xFF0A101A).withOpacity(0.8),
                    Color(0xFF0A101A).withOpacity(0.4),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.3, 1.0],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    widget.realmName,
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          blurRadius: 8.0,
                          color: Colors.white.withOpacity(0.7),
                          offset: Offset(0, 0),
                        ),
                        Shadow(
                          blurRadius: 15.0,
                          color: Color(0xFFfde047).withOpacity(0.6),
                          offset: Offset(0, 0),
                        ),
                      ],
                      fontFamily: 'CinzelDecorative',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Scrollable puzzle grid
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: _buildPuzzleGrid(),
                  ),
                ),

                // Footer - Kingdom Progress
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzleGrid() {
    List<Widget> rows = [];
    int totalPuzzles = puzzleList.length;
    int currentIndex = 0;

    while (currentIndex < totalPuzzles) {
      // Add row of 4 puzzles
      List<Widget> rowPuzzles = [];
      int rowStartIndex = currentIndex;

      for (int col = 0; col < 4 && currentIndex < totalPuzzles; col++) {
        rowPuzzles.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: _buildPuzzleTile(currentIndex),
            ),
          ),
        );
        currentIndex++;
      }

      // Fill remaining columns if less than 4
      while (rowPuzzles.length < 4) {
        rowPuzzles.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: SizedBox(),
            ),
          ),
        );
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: rowPuzzles,
          ),
        ),
      );

      // Check if we need to insert expanded grid after this row
      int rowEndIndex = currentIndex - 1;

      if (expandedPuzzleIndex != null &&
          expandedPuzzleIndex! >= rowStartIndex &&
          expandedPuzzleIndex! <= rowEndIndex) {
        rows.add(_buildExpandedGrid(expandedPuzzleIndex!));
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  Widget _buildPuzzleTile(int index) {
    if (index >= puzzleList.length) {
      return SizedBox();
    }

    final puzzle = puzzleList[index];
    final isLocked = index >= 8;
    final isExpanded = expandedPuzzleIndex == index;
    final savedGame = savedGames[puzzle.id];
    final hasProgress = savedGame != null;

    int stars = 0;
    if (savedGame != null && savedGame.isCompleted) {
      stars = 3;
    } else if (hasProgress) {
      stars = 0;
    }

    return GestureDetector(
      onTap: isLocked ? null : () => _togglePuzzle(index),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: isLocked
                    ? Colors.black.withOpacity(0.6)
                    : isExpanded
                        ? Color(0xFFeca413).withOpacity(0.2)
                        : Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isLocked
                      ? Color(0xFF57534e).withOpacity(0.5)
                      : isExpanded
                          ? Color(0xFFeca413).withOpacity(0.6)
                          : stars == 3
                              ? Color(0xFFfde047).withOpacity(0.4)
                              : Color(0xFF57534e).withOpacity(0.5),
                  width: isExpanded ? 2 : 1,
                ),
                boxShadow: isExpanded
                    ? [
                        BoxShadow(
                          color: Color(0xFFeca413).withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: isLocked
                  ? Icon(Icons.lock, color: Color(0xFF78716c), size: 36)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: stars == 3
                                ? Color(0xFFfef08a)
                                : Color(0xFFd6d3d1),
                            fontFamily: 'CinzelDecorative',
                          ),
                        ),
                        if (stars == 3) ...[
                          SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              3,
                              (i) => Icon(
                                Icons.star,
                                size: 14,
                                color: Color(0xFFfbbf24),
                              ),
                            ),
                          ),
                        ],
                        if (hasProgress && stars == 0) ...[
                          SizedBox(height: 8),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _calculateProgress(savedGame),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Color(0xFFfbbf24),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  double _calculateProgress(GameState? game) {
    if (game == null) return 0.0;
    int filledCells = 0;
    for (var row in game.currentGrid) {
      filledCells += row.where((cell) => cell != 0).length;
    }
    return filledCells / 81.0;
  }

  Widget _buildExpandedGrid(int index) {
    final puzzle = puzzleList[index];
    final savedGame = savedGames[puzzle.id];
    final bestTime = bestTimes[puzzle.id];
    final theme = RealmTheme.fromRealm(widget.realmName);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      child: Column(
        children: [
          // Sudoku Grid
          Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                constraints: BoxConstraints(maxWidth: 400),
                child: _buildSudokuGrid(puzzle, savedGame),
              ),
            ),
          ),

          SizedBox(height: 16),

          // Time info
          if (bestTime != null || (savedGame != null && !savedGame.isCompleted))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  if (bestTime != null)
                    Text(
                      'Best Time: ${_formatTime(bestTime)}',
                      style: TextStyle(
                        color: theme.accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (savedGame != null && !savedGame.isCompleted)
                    Text(
                      'Current: ${_formatTime(savedGame.elapsedSeconds)} (In Progress)',
                      style: TextStyle(
                        color: Color(0xFFd6d3d1),
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),

          SizedBox(height: 16),

          // Play Button
          SizedBox(
            width: 200,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/game',
                  arguments: {
                    'puzzle': puzzle,
                    'realmName': widget.realmName,
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Play',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSudokuGrid(PuzzleData puzzle, GameState? savedGame) {
    final grid = savedGame?.currentGrid ?? puzzle.grid;
    final theme = RealmTheme.fromRealm(widget.realmName);

    return Stack(
      children: [
        // Grid of cells
        GridView.builder(
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 9,
            crossAxisSpacing: 0,
            mainAxisSpacing: 0,
          ),
          itemCount: 81,
          itemBuilder: (context, index) {
            final row = index ~/ 9;
            final col = index % 9;
            final value = grid[row][col];
            final isPrefilled = puzzle.grid[row][col] != 0;

            return Container(
              decoration: BoxDecoration(
                color: theme.backgroundColor,
                border: _getPreviewCellBorder(row, col, theme),
              ),
              child: Center(
                child: value != 0
                    ? Text(
                        '$value',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isPrefilled
                              ? theme.textPrimary
                              : theme.textSecondary,
                        ),
                      )
                    : null,
              ),
            );
          },
        ),

        // Kropki dots overlay
        if (puzzle.constraints.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: PreviewKropkiDotsPainter(
                  constraints: puzzle.constraints,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Border _getPreviewCellBorder(int row, int col, RealmTheme theme) {
    return Border(
      top: BorderSide(
        width: row % 3 == 0 ? 2 : 0.5,
        color: theme.borderColor,
      ),
      left: BorderSide(
        width: col % 3 == 0 ? 2 : 0.5,
        color: theme.borderColor,
      ),
      right: BorderSide(
        width: col == 8 ? 2 : 0.5,
        color: theme.borderColor,
      ),
      bottom: BorderSide(
        width: row == 8 ? 2 : 0.5,
        color: theme.borderColor,
      ),
    );
  }

  Widget _buildFooter() {
    int completedCount = savedGames.values
        .where((game) => game != null && game.isCompleted)
        .length;
    int totalPuzzles = puzzleList.length;
    double progress = completedCount / totalPuzzles;

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Kingdom Progress',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFFfef08a),
              letterSpacing: 1,
              shadows: [
                Shadow(
                  blurRadius: 8.0,
                  color: Colors.white.withOpacity(0.7),
                  offset: Offset(0, 0),
                ),
              ],
              fontFamily: 'CinzelDecorative',
            ),
          ),
          SizedBox(height: 8),
          Container(
            height: 16,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Color(0xFFfde047).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFeab308),
                        Color(0xFFeca413),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Completed $completedCount / $totalPuzzles',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFd6d3d1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for rendering Kropki dots in preview grid
class PreviewKropkiDotsPainter extends CustomPainter {
  final List<VariantConstraint> constraints;

  PreviewKropkiDotsPainter({required this.constraints});

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 9;
    final dotRadius = cellSize * 0.12;

    for (var constraint in constraints) {
      if (constraint.type != ConstraintType.KROPKI_WHITE &&
          constraint.type != ConstraintType.KROPKI_BLACK) {
        continue;
      }

      final dotColor = constraint.type == ConstraintType.KROPKI_WHITE
          ? Colors.white
          : Colors.black;

      Offset dotCenter;

      if (constraint.orientation == 'horizontal') {
        final x = (constraint.col1 + 1) * cellSize;
        final y = constraint.row1 * cellSize + cellSize / 2;
        dotCenter = Offset(x, y);
      } else {
        final x = constraint.col1 * cellSize + cellSize / 2;
        final y = (constraint.row1 + 1) * cellSize;
        dotCenter = Offset(x, y);
      }

      final paint = Paint()
        ..color = dotColor
        ..style = PaintingStyle.fill;

      if (constraint.type == ConstraintType.KROPKI_WHITE) {
        final borderPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(dotCenter, dotRadius, borderPaint);
      }

      canvas.drawCircle(dotCenter, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(PreviewKropkiDotsPainter oldDelegate) {
    return false;
  }
}
