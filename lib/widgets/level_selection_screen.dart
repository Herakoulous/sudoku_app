import 'package:flutter/material.dart';
import '../data/puzzles.dart';
import '../services/save_service.dart';
import '../services/settings_service.dart';
import '../models/game_state.dart';
import '../utils/realm_theme.dart';
import 'level_selection_widget.dart';

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
  Map<String, bool> completedStatus = {};
  String _resolvedTheme = 'dark';

  List<PuzzleData> get puzzleList => widget.puzzles.cast<PuzzleData>();

  @override
  void initState() {
    super.initState();
    print('🔍 LevelSelectionScreen initialized');
    _loadTheme();
    _loadSavedGames();
  }

  Future<void> _loadTheme() async {
    final theme = await SettingsService.getResolvedTheme(context);
    if (mounted) {
      setState(() => _resolvedTheme = theme);
    }
  }

  Future<void> _loadSavedGames() async {
    print('🔄 Loading saved games...');
    for (var puzzle in puzzleList) {
      final saved = await SaveService.loadGame(puzzle.id);
      savedGames[puzzle.id] = saved;

      final bestTime = await SaveService.getBestTime(puzzle.id);
      if (bestTime != null) {
        bestTimes[puzzle.id] = bestTime;
      }

      final isCompleted = await SaveService.isCompleted(puzzle.id);
      completedStatus[puzzle.id] = isCompleted;
    }
    print('🔄 Saved games loaded. Calling setState...');
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

  double _calculateProgress(GameState? game) {
    if (game == null) return 0.0;
    int filledCells = 0;
    for (var row in game.currentGrid) {
      filledCells += row.where((cell) => cell != 0).length;
    }
    return filledCells / 81.0;
  }

  int _getCompletedCount() {
    return completedStatus.values.where((c) => c).length;
  }

  int _getUnlockedCount() {
    final completedCount = _getCompletedCount();
    return 52 + completedCount;
  }

  Future<void> _navigateToGame(PuzzleData puzzle) async {
    await Navigator.pushNamed(
      context,
      '/game',
      arguments: {
        'puzzle': puzzle,
        'realmName': widget.realmName,
      },
    );
    await Future.delayed(Duration(milliseconds: 100));
    await _loadSavedGames();
  }

  Future<void> _startNewGame(PuzzleData puzzle) async {
    await SaveService.clearSave(puzzle.id);
    await Navigator.pushNamed(
      context,
      '/game',
      arguments: {
        'puzzle': puzzle,
        'realmName': widget.realmName,
      },
    );
    await Future.delayed(Duration(milliseconds: 100));
    await _loadSavedGames();
  }

  Color _getBackgroundColor() {
    return _resolvedTheme == 'dark' ? Color(0xFF0A101A) : Color(0xFFF5F5F5);
  }

  Color _getOverlayColor() {
    return _resolvedTheme == 'dark'
        ? Color(0xFF0A101A).withOpacity(0.7)
        : Colors.white.withOpacity(0.8);
  }

  @override
  Widget build(BuildContext context) {
    final theme = RealmTheme.fromRealmSync(widget.realmName);

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              color: _getBackgroundColor(),
              child: _resolvedTheme == 'dark'
                  ? Image.asset(
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
                    )
                  : null,
            ),
          ),

          // Gradient overlays (only for dark mode)
          if (_resolvedTheme == 'dark') ...[
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
          ],

          // Content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back,
                          color: theme.primaryColor,
                          size: 24,
                        ),
                        tooltip: 'Back to Realms',
                      ),
                      Expanded(
                        child: Text(
                          widget.realmName,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: _resolvedTheme == 'dark'
                                ? Colors.white
                                : Colors.black87,
                            letterSpacing: 2,
                            shadows: _resolvedTheme == 'dark'
                                ? [
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
                                  ]
                                : null,
                            fontFamily: 'CinzelDecorative',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(width: 48),
                    ],
                  ),
                ),

                // Scrollable puzzle grid
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: PuzzleGridBuilder(
                      puzzleList: puzzleList,
                      expandedPuzzleIndex: expandedPuzzleIndex,
                      savedGames: savedGames,
                      bestTimes: bestTimes,
                      completedStatus: completedStatus,
                      realmName: widget.realmName,
                      unlockedCount: _getUnlockedCount(),
                      onPuzzleTap: _togglePuzzle,
                      onNavigateToGame: _navigateToGame,
                      onStartNewGame: _startNewGame,
                      formatTime: _formatTime,
                      calculateProgress: _calculateProgress,
                      isDarkMode: _resolvedTheme == 'dark',
                    ),
                  ),
                ),

                // Footer - Kingdom Progress
                KingdomProgressFooter(
                  completedCount: _getCompletedCount(),
                  totalPuzzles: puzzleList.length,
                  isDarkMode: _resolvedTheme == 'dark',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
