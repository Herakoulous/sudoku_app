/// One completed puzzle.
///
/// Achievements need more history than a "completed" flag can carry — whether a
/// solve used hints, whether it was flawless, and when it happened. Every finish
/// appends a record, so a puzzle solved twice keeps both attempts and the player
/// gets credit for their best one.
class SolveRecord {
  final String puzzleId;
  final String realmName;
  final int difficulty;
  final int seconds;
  final int hintsUsed;
  final int mistakes;

  /// Wall-clock time of the finish, used for streaks and time-of-day awards.
  final DateTime finishedAt;

  const SolveRecord({
    required this.puzzleId,
    required this.realmName,
    required this.difficulty,
    required this.seconds,
    required this.hintsUsed,
    required this.mistakes,
    required this.finishedAt,
  });

  bool get usedNoHints => hintsUsed == 0;

  bool get wasFlawless => mistakes == 0;

  /// No hints and no wrong digits — the cleanest possible solve.
  bool get wasPerfect => usedNoHints && wasFlawless;

  /// Calendar day, for streak and distinct-day counting.
  DateTime get day =>
      DateTime(finishedAt.year, finishedAt.month, finishedAt.day);

  // Keys are single letters: the whole log lives in one SharedPreferences
  // string, and this is read and rewritten on every finish.
  Map<String, dynamic> toJson() => {
        'i': puzzleId,
        'r': realmName,
        'd': difficulty,
        's': seconds,
        'h': hintsUsed,
        'm': mistakes,
        't': finishedAt.millisecondsSinceEpoch,
      };

  factory SolveRecord.fromJson(Map<String, dynamic> json) => SolveRecord(
        puzzleId: json['i'] as String? ?? '',
        realmName: json['r'] as String? ?? '',
        difficulty: json['d'] as int? ?? 1,
        seconds: json['s'] as int? ?? 0,
        hintsUsed: json['h'] as int? ?? 0,
        mistakes: json['m'] as int? ?? 0,
        finishedAt: DateTime.fromMillisecondsSinceEpoch(json['t'] as int? ?? 0),
      );
}
