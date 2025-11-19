import 'package:flutter/material.dart';
import '../data/puzzles.dart';
import '../models/game_state.dart';
import '../utils/realm_theme.dart';
import '../widgets/sudoku_grid.dart';

// =============================================================================
// PUZZLE GRID BUILDER - Main grid layout coordinator
// =============================================================================

class PuzzleGridBuilder extends StatelessWidget {
  final List<PuzzleData> puzzleList;
  final int? expandedPuzzleIndex;
  final Map<String, GameState?> savedGames;
  final Map<String, int?> bestTimes;
  final Map<String, bool> completedStatus;
  final String realmName;
  final int unlockedCount;
  final Function(int) onPuzzleTap;
  final Function(PuzzleData) onNavigateToGame;
  final Function(PuzzleData) onStartNewGame;
  final String Function(int) formatTime;
  final double Function(GameState?) calculateProgress;

  const PuzzleGridBuilder({
    Key? key,
    required this.puzzleList,
    required this.expandedPuzzleIndex,
    required this.savedGames,
    required this.bestTimes,
    required this.completedStatus,
    required this.realmName,
    required this.unlockedCount,
    required this.onPuzzleTap,
    required this.onNavigateToGame,
    required this.onStartNewGame,
    required this.formatTime,
    required this.calculateProgress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Widget> rows = [];
    int totalPuzzles = puzzleList.length;
    int currentIndex = 0;

    while (currentIndex < totalPuzzles) {
      // Add row of 4 puzzles
      List<Widget> rowPuzzles = [];
      int rowStartIndex = currentIndex;

      for (int col = 0; col < 4 && currentIndex < totalPuzzles; col++) {
        final capturedIndex = currentIndex; // Capture the current index
        rowPuzzles.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: PuzzleTile(
                index: capturedIndex,
                puzzle: puzzleList[capturedIndex],
                isLocked: capturedIndex >= unlockedCount,
                isExpanded: expandedPuzzleIndex == capturedIndex,
                savedGame: savedGames[puzzleList[capturedIndex].id],
                completedStatus:
                    completedStatus[puzzleList[capturedIndex].id] ?? false,
                realmName: realmName,
                difficulty: puzzleList[capturedIndex].difficulty,
                onTap: () => onPuzzleTap(capturedIndex),
                calculateProgress: calculateProgress,
              ),
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
        rows.add(
          ExpandedPuzzleView(
            puzzle: puzzleList[expandedPuzzleIndex!],
            savedGame: savedGames[puzzleList[expandedPuzzleIndex!].id],
            bestTime: bestTimes[puzzleList[expandedPuzzleIndex!].id],
            isCompleted:
                completedStatus[puzzleList[expandedPuzzleIndex!].id] ?? false,
            realmName: realmName,
            difficulty: puzzleList[expandedPuzzleIndex!].difficulty,
            onNavigateToGame: onNavigateToGame,
            onStartNewGame: onStartNewGame,
            formatTime: formatTime,
          ),
        );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}

// =============================================================================
// PUZZLE TILE - Individual puzzle card
// =============================================================================

class PuzzleTile extends StatelessWidget {
  final int index;
  final PuzzleData puzzle;
  final bool isLocked;
  final bool isExpanded;
  final GameState? savedGame;
  final bool completedStatus;
  final String realmName;
  final VoidCallback onTap;
  final double Function(GameState?) calculateProgress;
  final int difficulty;

  const PuzzleTile({
    Key? key,
    required this.index,
    required this.puzzle,
    required this.isLocked,
    required this.isExpanded,
    required this.savedGame,
    required this.completedStatus,
    required this.realmName,
    required this.onTap,
    required this.calculateProgress,
    required this.difficulty,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasProgress = savedGame != null;
    final isCompleted = completedStatus;

    // Calculate star size based on difficulty (1-10 stars)
    // More stars = smaller size to fit in box
    double starSize = difficulty <= 3 ? 18.0 : (difficulty <= 6 ? 14.0 : 12.0);

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: AspectRatio(
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
                      : isCompleted
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
          child: Stack(
            children: [
              // Main content
              Center(
                child: isLocked
                    ? Icon(Icons.lock, color: Color(0xFF78716c), size: 36)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: isCompleted
                                  ? Color(0xFFfef08a)
                                  : Color(0xFFd6d3d1),
                              fontFamily: 'CinzelDecorative',
                            ),
                          ),
                          SizedBox(height: 4),
                          // Stars - outlined if not completed, filled if completed
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 2,
                            runSpacing: 2,
                            children: List.generate(
                              difficulty,
                              (i) => Icon(
                                isCompleted ? Icons.star : Icons.star_border,
                                size: starSize,
                                color: Color(0xFFfbbf24),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),

              // Flag overlay (on top) - ONLY for in-progress (not completed)
              if (!isLocked && hasProgress && !isCompleted)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.flag,
                    color: RealmTheme.fromRealm(realmName).primaryColor,
                    size: 18,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// EXPANDED PUZZLE VIEW - Detailed puzzle preview with buttons
// =============================================================================

class ExpandedPuzzleView extends StatelessWidget {
  final PuzzleData puzzle;
  final GameState? savedGame;
  final int? bestTime;
  final bool isCompleted;
  final String realmName;
  final int difficulty;
  final Function(PuzzleData) onNavigateToGame;
  final Function(PuzzleData) onStartNewGame;
  final String Function(int) formatTime;

  const ExpandedPuzzleView({
    Key? key,
    required this.puzzle,
    required this.savedGame,
    required this.bestTime,
    required this.isCompleted,
    required this.realmName,
    required this.difficulty,
    required this.onNavigateToGame,
    required this.onStartNewGame,
    required this.formatTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = RealmTheme.fromRealm(realmName);
    final hasProgress = savedGame != null;

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
                child: SudokuPreviewGrid(
                  puzzle: puzzle,
                  savedGame: savedGame,
                  realmName: realmName,
                ),
              ),
            ),
          ),

          SizedBox(height: 16),

          // Stars display (if completed)
          if (isCompleted) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                difficulty,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Icon(
                    Icons.star,
                    size: 20,
                    color: Color(0xFFfbbf24),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
          ],

          // Time display and buttons
          Column(
            children: [
              // Best time (show if completed)
              if (isCompleted && bestTime != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events,
                        color: theme.accentColor, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Best Time: ${formatTime(bestTime!)}',
                      style: TextStyle(
                        color: theme.accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
              ],

              // Current time (show if there's progress AND not completed, OR if completed and restarted)
              if (hasProgress &&
                  savedGame != null &&
                  (!isCompleted || (isCompleted && hasProgress))) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer, color: Color(0xFFd6d3d1), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Current Time: ${formatTime(savedGame!.elapsedSeconds)}',
                      style: TextStyle(
                        color: Color(0xFFd6d3d1),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
              ],

              SizedBox(height: 8),

              // Buttons based on status
              if (!hasProgress && !isCompleted) ...[
                // Not started - Play button only
                SizedBox(
                  width: 200,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => onNavigateToGame(puzzle),
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
              ] else if (isCompleted && !hasProgress) ...[
                // Completed but not started again - New Game button only
                SizedBox(
                  width: 200,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => onStartNewGame(puzzle),
                    icon: Icon(Icons.refresh),
                    label: Text(
                      'New Game',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Has progress - Continue AND New Game
                SizedBox(
                  width: 200,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => onNavigateToGame(puzzle),
                    icon: Icon(Icons.play_arrow),
                    label: Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: 200,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => onStartNewGame(puzzle),
                    icon: Icon(Icons.refresh),
                    label: Text(
                      'New Game',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.primaryColor,
                      side: BorderSide(
                        color: theme.primaryColor,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SUDOKU PREVIEW GRID - Mini grid showing puzzle state
// =============================================================================

class SudokuPreviewGrid extends StatelessWidget {
  final PuzzleData puzzle;
  final GameState? savedGame;
  final String realmName;

  const SudokuPreviewGrid({
    Key? key,
    required this.puzzle,
    required this.savedGame,
    required this.realmName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final grid = savedGame?.currentGrid ?? puzzle.grid;
    final theme = RealmTheme.fromRealm(realmName);

    // DEBUG
    print('🎨 _buildSudokuGrid called for puzzle: ${puzzle.id}');
    print('🎨 Number of constraints: ${puzzle.constraints.length}');
    for (var constraint in puzzle.constraints) {
      print(
          '🎨 Constraint: ${constraint.type}, thermoCells: ${constraint.thermoCells?.length}');
    }

    return Stack(
      children: [
        // LAYER 1: Grid cells FIRST (just backgrounds and borders, no content)
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

            return Container(
              decoration: BoxDecoration(
                color: theme.backgroundColor,
                border: _getPreviewCellBorder(row, col, theme),
              ),
              // NO CHILD - just background and borders
            );
          },
        ),

        // LAYER 2: Constraints in the middle (above backgrounds, below numbers)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: ConstraintPainter(
                constraints: puzzle.constraints,
              ),
              child: Container(),
            ),
          ),
        ),

        // LAYER 3: Numbers on top
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
              color:
                  Colors.transparent, // Transparent so constraints show through
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
}

// =============================================================================
// KINGDOM PROGRESS FOOTER - Progress bar at bottom
// =============================================================================

class KingdomProgressFooter extends StatelessWidget {
  final int completedCount;
  final int totalPuzzles;

  const KingdomProgressFooter({
    Key? key,
    required this.completedCount,
    required this.totalPuzzles,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = completedCount / totalPuzzles;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Text(
            'Kingdom Progress',
            style: TextStyle(
              fontSize: 14,
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
          SizedBox(height: 6),
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Color(0xFFfde047).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
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
          SizedBox(height: 3),
          Text(
            'Completed $completedCount / $totalPuzzles',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFFd6d3d1),
            ),
          ),
        ],
      ),
    );
  }
}
