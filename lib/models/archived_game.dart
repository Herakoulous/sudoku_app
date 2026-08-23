import 'game_state.dart';

/// A game kept in the archive: the full board the player built, plus enough
/// metadata to list and describe it without decoding the whole state.
///
/// The [state] carries everything — the current grid, the notes, and the entire
/// action history — so an archived game can be resumed exactly where it was left
/// or stepped through with undo and redo. Serialising the action list is what
/// makes that history survive a restart.
class ArchivedGame {
  final String puzzleId;
  final String realmName;

  final bool completed;

  /// When this snapshot was last written, for ordering the archive.
  final DateTime savedAt;

  final int elapsedSeconds;

  /// Wrong digits currently on the board, measured against the solution. Zero
  /// for a clean board or a puzzle with no stored solution.
  final int mistakes;

  /// Non-given cells the player has filled, for a progress read at a glance.
  final int filled;

  /// The complete, resumable game state.
  final GameState state;

  const ArchivedGame({
    required this.puzzleId,
    required this.realmName,
    required this.completed,
    required this.savedAt,
    required this.elapsedSeconds,
    required this.mistakes,
    required this.filled,
    required this.state,
  });

  bool get inProgress => !completed;

  bool get hasMistakes => mistakes > 0;

  Map<String, dynamic> toJson() => {
        'puzzleId': puzzleId,
        'realmName': realmName,
        'completed': completed,
        'savedAt': savedAt.millisecondsSinceEpoch,
        'elapsed': elapsedSeconds,
        'mistakes': mistakes,
        'filled': filled,
        'state': state.toJson(),
      };

  factory ArchivedGame.fromJson(Map<String, dynamic> json) => ArchivedGame(
        puzzleId: json['puzzleId'] as String,
        realmName: json['realmName'] as String? ?? '',
        completed: json['completed'] as bool? ?? false,
        savedAt: DateTime.fromMillisecondsSinceEpoch(json['savedAt'] as int? ?? 0),
        elapsedSeconds: json['elapsed'] as int? ?? 0,
        mistakes: json['mistakes'] as int? ?? 0,
        filled: json['filled'] as int? ?? 0,
        state: GameState.fromJson(json['state'] as Map<String, dynamic>),
      );
}
