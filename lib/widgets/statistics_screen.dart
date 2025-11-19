import 'package:flutter/material.dart';
import '../services/save_service.dart';
import '../data/realm_config.dart';
import '../data/puzzles.dart';
import 'dart:math' as math;

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, dynamic> stats = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    // Get all puzzle IDs from all realms
    List<String> allPuzzleIds = [];
    for (var realmName in RealmConfig.realmPuzzles.keys) {
      final puzzles = RealmConfig.getPuzzlesForRealm(realmName);
      allPuzzleIds.addAll(puzzles.map((p) => p.id));
    }

    // Calculate statistics
    int totalPuzzles = allPuzzleIds.length;
    int completedCount = 0;
    int totalTimeCompleted = 0; // Only for completed puzzles (for average)
    int totalTimePlayed = 0; // Total time including in-progress
    int totalUndos = 0;
    int totalStars = 0;
    List<Map<String, dynamic>> fastestCompletions = [];
    List<Map<String, dynamic>> slowestCompletions = [];

    for (String puzzleId in allPuzzleIds) {
      // Check for saved game (in-progress or completed)
      final savedGame = await SaveService.loadGame(puzzleId);
      if (savedGame != null) {
        // Add time from in-progress games
        totalTimePlayed += savedGame.elapsedSeconds;
      }

      bool isCompleted = await SaveService.isCompleted(puzzleId);
      if (isCompleted) {
        completedCount++;
        int? bestTime = await SaveService.getBestTime(puzzleId);
        if (bestTime != null) {
          totalTimeCompleted += bestTime;

          // If no saved game but completed, add best time to total played
          if (savedGame == null) {
            totalTimePlayed += bestTime;
          }

          // Get puzzle data for realm and difficulty
          final puzzle = Puzzles.getPuzzle(puzzleId);
          if (puzzle != null) {
            totalStars += puzzle.difficulty;

            // Find realm name
            String realmName = '';
            for (var realm in RealmConfig.realmPuzzles.entries) {
              if (realm.value.any((p) => p.id == puzzleId)) {
                realmName = realm.key;
                break;
              }
            }

            fastestCompletions.add({
              'puzzleId': puzzleId,
              'realmName': realmName,
              'difficulty': puzzle.difficulty,
              'time': bestTime,
            });
          }
        }
      }
    }

    // Sort and get top 3 fastest and slowest
    fastestCompletions.sort((a, b) => a['time'].compareTo(b['time']));
    slowestCompletions = List.from(fastestCompletions.reversed);

    // Calculate average time
    int avgTime =
        completedCount > 0 ? (totalTimeCompleted / completedCount).round() : 0;

    // Mock undos data (you can track this in SaveService if needed)
    totalUndos = completedCount * 5; // Approximate

    setState(() {
      stats = {
        'totalPuzzles': totalPuzzles,
        'completedCount': completedCount,
        'completionPercentage': totalPuzzles > 0
            ? ((completedCount / totalPuzzles) * 100).round()
            : 0,
        'averageTime': avgTime,
        'totalTime': totalTimePlayed,
        'totalStars': totalStars,
        'totalUndos': totalUndos,
        'fastestCompletions': fastestCompletions.take(3).toList(),
        'slowestCompletions': slowestCompletions.take(3).toList(),
      };
      isLoading = false;
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatTotalTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  String _getDifficultyLabel(int difficulty) {
    if (difficulty <= 3) return 'Easy';
    if (difficulty <= 6) return 'Medium';
    if (difficulty <= 8) return 'Hard';
    return 'Expert';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Color.fromARGB(255, 255, 174, 0),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Opacity(
              opacity: 0.2,
              child: Image.asset(
                'images/castle_background.png',
                fit: BoxFit.cover,
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
                  child: Row(
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Color.fromARGB(255, 255, 174, 0)
                                  .withOpacity(0.2),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: Color(0xFFF9E999),
                            size: 24,
                          ),
                        ),
                      ),

                      Expanded(
                        child: Text(
                          'Realm Statistics',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 2,
                            fontFamily: 'CinzelDecorative',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      SizedBox(width: 40), // Balance the back button
                    ],
                  ),
                ),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        // Overall Progress Card
                        _buildOverallProgressCard(),
                        SizedBox(height: 24),

                        // Stats Grid
                        _buildStatsGrid(),
                        SizedBox(height: 24),

                        // Fastest Completions
                        if (stats['fastestCompletions'].isNotEmpty)
                          _buildCompletionsList(
                            'Fastest Completions',
                            stats['fastestCompletions'],
                          ),
                        if (stats['fastestCompletions'].isNotEmpty)
                          SizedBox(height: 24),

                        // Slowest Completions
                        if (stats['slowestCompletions'].isNotEmpty)
                          _buildCompletionsList(
                            'Slowest Completions',
                            stats['slowestCompletions'],
                          ),
                        if (stats['slowestCompletions'].isNotEmpty)
                          SizedBox(height: 24),

                        // Achievements
                        _buildAchievements(),
                        SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallProgressCard() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color.fromARGB(255, 255, 174, 0).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Overall Progress',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 24),

          // Circular Progress
          SizedBox(
            height: 160,
            width: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(160, 160),
                  painter: CircularProgressPainter(
                    progress: stats['completionPercentage'] / 100,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${stats['completionPercentage']}%',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFF9E999).withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24),

          // Progress bar
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Puzzles Completed',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${stats['completedCount']} / ${stats['totalPuzzles']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFF9E999),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 255, 174, 0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  widthFactor: stats['completionPercentage'] / 100,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color.fromARGB(255, 255, 174, 0),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Color.fromARGB(255, 255, 174, 0).withOpacity(0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        // Average Solving Time
        _buildStatCard(
          Icons.timer,
          'Average Solving Time',
          _formatTime(stats['averageTime']),
          true,
        ),
        SizedBox(height: 16),

        // Total Play Time
        _buildStatCard(
          Icons.hourglass_top,
          'Total Play Time',
          _formatTotalTime(stats['totalTime']),
          false,
        ),
        SizedBox(height: 16),

        // Stars and Undos Row
        Row(
          children: [
            Expanded(
              child: _buildSmallStatCard(
                Icons.star,
                'Stars Collected',
                '${stats['totalStars']}',
                true,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildSmallStatCard(
                Icons.undo,
                'Undos Used',
                '${stats['totalUndos']}',
                false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, bool glow) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color.fromARGB(255, 255, 174, 0).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: glow ? Color.fromARGB(255, 255, 174, 0) : Color(0xFFF9E999),
            size: 32,
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStatCard(
      IconData icon, String label, String value, bool glow) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color.fromARGB(255, 255, 174, 0).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: glow ? Color.fromARGB(255, 255, 174, 0) : Color(0xFFF9E999),
            size: 32,
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionsList(String title, List<Map<String, dynamic>> items) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color.fromARGB(255, 255, 174, 0).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 16),
          ...items.map((item) => _buildCompletionItem(item)).toList(),
        ],
      ),
    );
  }

  Widget _buildCompletionItem(Map<String, dynamic> item) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color.fromARGB(255, 255, 174, 0).withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '${item['realmName']} - ${_getDifficultyLabel(item['difficulty'])}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          Text(
            _formatTime(item['time']),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievements() {
    int completed = stats['completedCount'];
    bool firstPuzzle = completed >= 1;
    bool speedSolver = stats['averageTime'] < 300; // Under 5 minutes
    bool realmConqueror = stats['completionPercentage'] >= 50;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color.fromARGB(255, 255, 174, 0).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Achievements',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildAchievement(Icons.school, 'First Puzzle', firstPuzzle),
              _buildAchievement(
                  Icons.local_fire_department, 'Speed Solver', speedSolver),
              _buildAchievement(Icons.fort, 'Realm Conqueror', realmConqueror),
              _buildAchievement(Icons.diamond, 'Perfect Game', false),
              _buildAchievement(Icons.star_rate, '100 Stars', false),
              _buildAchievement(
                  Icons.collections_bookmark, 'Completionist', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAchievement(IconData icon, String label, bool unlocked) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: unlocked
                ? Color.fromARGB(255, 255, 174, 0).withOpacity(0.2)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: unlocked
                  ? Color.fromARGB(255, 255, 174, 0).withOpacity(0.5)
                  : Colors.white.withOpacity(0.2),
            ),
            boxShadow: unlocked
                ? [
                    BoxShadow(
                      color: Color.fromARGB(255, 255, 174, 0).withOpacity(0.3),
                      blurRadius: 10,
                    ),
                  ]
                : [],
          ),
          child: Icon(
            icon,
            color: unlocked ? Color.fromARGB(255, 255, 174, 0) : Colors.white,
            size: 32,
          ),
        ),
        SizedBox(height: 4),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: unlocked
                  ? Color.fromARGB(255, 255, 174, 0).withOpacity(0.9)
                  : Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class CircularProgressPainter extends CustomPainter {
  final double progress;

  CircularProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background circle
    final backgroundPaint = Paint()
      ..color = Color.fromARGB(255, 255, 174, 0).withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = Color.fromARGB(255, 255, 174, 0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
