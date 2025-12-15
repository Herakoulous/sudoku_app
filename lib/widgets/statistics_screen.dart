import 'package:flutter/material.dart';
import '../services/save_service.dart';
import '../services/settings_service.dart';
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
  List<Achievement> achievements = [];
  bool isLoading = true;
  String _resolvedTheme = 'dark';

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadStatistics();
  }

  Future<void> _loadTheme() async {
    final theme = await SettingsService.getResolvedTheme(context);
    if (mounted) {
      setState(() => _resolvedTheme = theme);
    }
  }

  Future<void> _loadStatistics() async {
    List<String> allPuzzleIds = [];
    for (var realmName in RealmConfig.realmPuzzles.keys) {
      final puzzles = RealmConfig.getPuzzlesForRealm(realmName);
      allPuzzleIds.addAll(puzzles.map((p) => p.id));
    }

    int totalPuzzles = allPuzzleIds.length;
    int completedCount = 0;
    int totalTimeCompleted = 0;
    int totalStars = 0;
    List<Map<String, dynamic>> fastestCompletions = [];
    List<Map<String, dynamic>> slowestCompletions = [];
    Map<String, int> realmCompletions = {};

    for (String puzzleId in allPuzzleIds) {
      bool isCompleted = await SaveService.isCompleted(puzzleId);
      if (isCompleted) {
        completedCount++;
        int? bestTime = await SaveService.getBestTime(puzzleId);
        if (bestTime != null) {
          totalTimeCompleted += bestTime;

          final puzzle = Puzzles.getPuzzle(puzzleId);
          if (puzzle != null) {
            totalStars += puzzle.difficulty;

            String realmName = '';
            for (var realm in RealmConfig.realmPuzzles.entries) {
              if (realm.value.any((p) => p.id == puzzleId)) {
                realmName = realm.key;
                realmCompletions[realmName] =
                    (realmCompletions[realmName] ?? 0) + 1;
                break;
              }
            }

            fastestCompletions.add({
              'puzzleId': puzzleId,
              'realmName': realmName,
              'difficulty': puzzle.difficulty,
              'time': bestTime,
              'displayName': _getPuzzleDisplayName(puzzleId, realmName),
            });
          }
        }
      }
    }

    fastestCompletions.sort((a, b) => a['time'].compareTo(b['time']));
    slowestCompletions = List.from(fastestCompletions.reversed);

    int avgTime =
        completedCount > 0 ? (totalTimeCompleted / completedCount).round() : 0;
    int totalTimePlayed = await SaveService.getTotalPlayTime();
    int hintsUsed = await SaveService.getTotalHintsUsed();

    achievements = _calculateAchievements(
      completedCount: completedCount,
      totalPuzzles: totalPuzzles,
      avgTime: avgTime,
      totalStars: totalStars,
      hintsUsed: hintsUsed,
      fastestTime:
          fastestCompletions.isNotEmpty ? fastestCompletions.first['time'] : 0,
      realmCompletions: realmCompletions,
    );

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
        'hintsUsed': hintsUsed,
        'fastestCompletions': fastestCompletions.take(3).toList(),
        'slowestCompletions': slowestCompletions.take(3).toList(),
      };
      isLoading = false;
    });
  }

  String _getPuzzleDisplayName(String puzzleId, String realmName) {
    final parts = puzzleId.split('_');
    if (parts.length >= 2) {
      final type = parts[0];
      final number = parts[1];
      return '${type[0].toUpperCase()}${type.substring(1)} $number';
    }
    return puzzleId;
  }

  List<Achievement> _calculateAchievements({
    required int completedCount,
    required int totalPuzzles,
    required int avgTime,
    required int totalStars,
    required int hintsUsed,
    required int fastestTime,
    required Map<String, int> realmCompletions,
  }) {
    return [
      Achievement(
          icon: Icons.school,
          name: 'First Steps',
          description: 'Complete your first puzzle',
          unlocked: completedCount >= 1),
      Achievement(
          icon: Icons.looks_5,
          name: 'Getting Started',
          description: 'Complete 5 puzzles',
          unlocked: completedCount >= 5),
      Achievement(
          icon: Icons.filter_9,
          name: 'Puzzle Enthusiast',
          description: 'Complete 9 puzzles',
          unlocked: completedCount >= 9),
      Achievement(
          icon: Icons.looks_two,
          name: 'Quarter Master',
          description: 'Complete 25% of all puzzles',
          unlocked: (completedCount / totalPuzzles) >= 0.25),
      Achievement(
          icon: Icons.looks_3,
          name: 'Half Way There',
          description: 'Complete 50% of all puzzles',
          unlocked: (completedCount / totalPuzzles) >= 0.50),
      Achievement(
          icon: Icons.fort,
          name: 'Realm Conqueror',
          description: 'Complete 75% of all puzzles',
          unlocked: (completedCount / totalPuzzles) >= 0.75),
      Achievement(
          icon: Icons.collections_bookmark,
          name: 'Completionist',
          description: 'Complete all puzzles',
          unlocked: completedCount == totalPuzzles && totalPuzzles > 0),
      Achievement(
          icon: Icons.local_fire_department,
          name: 'Speed Demon',
          description: 'Average time under 5 minutes',
          unlocked: completedCount > 0 && avgTime < 300),
      Achievement(
          icon: Icons.flash_on,
          name: 'Lightning Fast',
          description: 'Complete a puzzle in under 2 minutes',
          unlocked: fastestTime > 0 && fastestTime < 120),
      Achievement(
          icon: Icons.star,
          name: 'Star Collector',
          description: 'Collect 100 stars',
          unlocked: totalStars >= 100),
      Achievement(
          icon: Icons.star_rate,
          name: 'Star Master',
          description: 'Collect 250 stars',
          unlocked: totalStars >= 250),
      Achievement(
          icon: Icons.diamond,
          name: 'Perfectionist',
          description: 'Complete 10 puzzles without hints',
          unlocked: completedCount >= 10 && hintsUsed == 0),
      Achievement(
          icon: Icons.psychology,
          name: 'Brain Teaser',
          description: 'Use less than 5 hints total',
          unlocked: hintsUsed < 5 && completedCount >= 5),
      Achievement(
          icon: Icons.castle,
          name: 'Realm Master',
          description: 'Complete all puzzles in any realm',
          unlocked: realmCompletions.values.any((count) => count >= 20)),
      Achievement(
          icon: Icons.wb_sunny,
          name: 'Early Bird',
          description: 'Play before 9 AM',
          unlocked: false),
      Achievement(
          icon: Icons.nightlight,
          name: 'Night Owl',
          description: 'Play after 10 PM',
          unlocked: false),
      Achievement(
          icon: Icons.trending_up,
          name: 'Consistent Player',
          description: 'Complete puzzles 3 days in a row',
          unlocked: false),
      Achievement(
          icon: Icons.emoji_events,
          name: 'Champion',
          description: 'Complete 50 puzzles',
          unlocked: completedCount >= 50),
      Achievement(
          icon: Icons.military_tech,
          name: 'Legend',
          description: 'Complete 100 puzzles',
          unlocked: completedCount >= 100),
    ];
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

  Color _getBackgroundColor() {
    return _resolvedTheme == 'dark' ? Colors.black : Color(0xFFF5F5F5);
  }

  Color _getCardColor() {
    return _resolvedTheme == 'dark' ? Color(0xFF1A1A1A) : Colors.white;
  }

  Color _getTextColor() {
    return _resolvedTheme == 'dark' ? Colors.white : Colors.black87;
  }

  Color _getBorderColor() {
    return Color(0xFFFFAE00).withOpacity(_resolvedTheme == 'dark' ? 0.3 : 0.5);
  }

  Color _getAccentColor() {
    return Color(0xFFFFAE00);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: _getBackgroundColor(),
        body: Center(
          child: CircularProgressIndicator(color: _getAccentColor()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    _buildOverallProgressCard(),
                    SizedBox(height: 24),
                    _buildStatsGrid(),
                    SizedBox(height: 24),
                    if (stats['fastestCompletions'].isNotEmpty)
                      _buildCompletionsList(
                          'Fastest Completions', stats['fastestCompletions']),
                    if (stats['fastestCompletions'].isNotEmpty)
                      SizedBox(height: 24),
                    if (stats['slowestCompletions'].isNotEmpty)
                      _buildCompletionsList(
                          'Slowest Completions', stats['slowestCompletions']),
                    if (stats['slowestCompletions'].isNotEmpty)
                      SizedBox(height: 24),
                    _buildAchievementsSection(),
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: _resolvedTheme == 'dark'
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getBorderColor()),
              ),
              child: Icon(
                Icons.arrow_back,
                color: _getAccentColor(),
                size: 24,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Statistics',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _getTextColor(),
                letterSpacing: 2,
                fontFamily: 'CinzelDecorative',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildOverallProgressCard() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getBorderColor()),
        boxShadow: _resolvedTheme == 'light'
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Text(
            'Overall Progress',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _getTextColor(),
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 24),
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
                    isDarkMode: _resolvedTheme == 'dark',
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
                        color: _getTextColor(),
                      ),
                    ),
                    Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getAccentColor().withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
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
                      color: _getTextColor(),
                    ),
                  ),
                  Text(
                    '${stats['completedCount']} / ${stats['totalPuzzles']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _getAccentColor(),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: _getAccentColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  widthFactor:
                      (stats['completionPercentage'] / 100).clamp(0.0, 1.0),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getAccentColor(),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: _getAccentColor().withOpacity(0.5),
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
        _buildFullWidthStatCard(Icons.timer, 'Average Time',
            _formatTime(stats['averageTime']), true),
        SizedBox(height: 16),
        _buildFullWidthStatCard(Icons.hourglass_top, 'Total Play Time',
            _formatTotalTime(stats['totalTime']), false),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildSmallStatCard(
                    Icons.star, 'Stars', '${stats['totalStars']}', true)),
            SizedBox(width: 16),
            Expanded(
                child: _buildSmallStatCard(Icons.lightbulb, 'Hints Used',
                    '${stats['hintsUsed']}', false)),
          ],
        ),
      ],
    );
  }

  Widget _buildFullWidthStatCard(
      IconData icon, String label, String value, bool glow) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getBorderColor()),
        boxShadow: _resolvedTheme == 'light'
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Icon(icon,
              color:
                  glow ? _getAccentColor() : _getAccentColor().withOpacity(0.7),
              size: 32),
          SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _getTextColor())),
          SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: _getTextColor())),
        ],
      ),
    );
  }

  Widget _buildSmallStatCard(
      IconData icon, String label, String value, bool glow) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getBorderColor()),
        boxShadow: _resolvedTheme == 'light'
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Icon(icon,
              color:
                  glow ? _getAccentColor() : _getAccentColor().withOpacity(0.7),
              size: 32),
          SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _getTextColor()),
              textAlign: TextAlign.center),
          SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _getTextColor())),
        ],
      ),
    );
  }

  Widget _buildCompletionsList(String title, List<Map<String, dynamic>> items) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getBorderColor()),
        boxShadow: _resolvedTheme == 'light'
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _getTextColor(),
                  letterSpacing: 1.5)),
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
        border: Border(bottom: BorderSide(color: _getBorderColor(), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  item['displayName'],
                  style: TextStyle(
                      fontSize: 12, color: _getTextColor().withOpacity(0.7)),
                ),
                SizedBox(width: 8),
                Row(
                  children: List.generate(
                    item['difficulty'],
                    (index) =>
                        Icon(Icons.star, size: 12, color: _getAccentColor()),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatTime(item['time']),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _getTextColor()),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection() {
    final unlockedCount = achievements.where((a) => a.unlocked).length;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getBorderColor()),
        boxShadow: _resolvedTheme == 'light'
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Achievements',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _getTextColor(),
                      letterSpacing: 1.5)),
              Text('$unlockedCount/${achievements.length}',
                  style: TextStyle(fontSize: 14, color: _getAccentColor())),
            ],
          ),
          SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: achievements.length,
            itemBuilder: (context, index) =>
                _buildAchievement(achievements[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievement(Achievement achievement) {
    return GestureDetector(
      onTap: () => _showAchievementDetails(achievement),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: achievement.unlocked
                  ? _getAccentColor().withOpacity(0.2)
                  : (_resolvedTheme == 'dark'
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05)),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: achievement.unlocked
                    ? _getAccentColor().withOpacity(0.5)
                    : (_resolvedTheme == 'dark'
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1)),
              ),
              boxShadow: achievement.unlocked
                  ? [
                      BoxShadow(
                          color: _getAccentColor().withOpacity(0.3),
                          blurRadius: 10)
                    ]
                  : [],
            ),
            child: Icon(
              achievement.icon,
              color: achievement.unlocked
                  ? _getAccentColor()
                  : _getTextColor().withOpacity(0.3),
              size: 24,
            ),
          ),
          SizedBox(height: 4),
          Text(
            achievement.name,
            style: TextStyle(
              fontSize: 8,
              color: achievement.unlocked
                  ? _getAccentColor().withOpacity(0.9)
                  : _getTextColor().withOpacity(0.4),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showAchievementDetails(Achievement achievement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _getCardColor(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _getBorderColor()),
        ),
        title: Row(
          children: [
            Icon(achievement.icon,
                color: achievement.unlocked
                    ? _getAccentColor()
                    : _getTextColor().withOpacity(0.3),
                size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(achievement.name,
                  style: TextStyle(color: _getTextColor(), fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(achievement.description,
                style: TextStyle(
                    color: _getTextColor().withOpacity(0.7), fontSize: 14)),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: achievement.unlocked
                    ? _getAccentColor().withOpacity(0.2)
                    : (_resolvedTheme == 'dark'
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(achievement.unlocked ? Icons.check_circle : Icons.lock,
                      color: achievement.unlocked
                          ? _getAccentColor()
                          : _getTextColor().withOpacity(0.3),
                      size: 16),
                  SizedBox(width: 8),
                  Text(achievement.unlocked ? 'UNLOCKED' : 'LOCKED',
                      style: TextStyle(
                          color: achievement.unlocked
                              ? _getAccentColor()
                              : _getTextColor().withOpacity(0.3),
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: _getAccentColor())),
          ),
        ],
      ),
    );
  }
}

class Achievement {
  final IconData icon;
  final String name;
  final String description;
  final bool unlocked;

  Achievement({
    required this.icon,
    required this.name,
    required this.description,
    required this.unlocked,
  });
}

class CircularProgressPainter extends CustomPainter {
  final double progress;
  final bool isDarkMode;

  CircularProgressPainter({required this.progress, required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final backgroundPaint = Paint()
      ..color = Color(0xFFFFAE00).withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawCircle(center, radius, backgroundPaint);

    final progressPaint = Paint()
      ..color = Color(0xFFFFAE00)
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
    return oldDelegate.progress != progress ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}
