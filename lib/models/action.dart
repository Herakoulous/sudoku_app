// File path: lib/models/action.dart
import 'position.dart';
import "../models/sudoku_cell.dart";

enum ActionType {
  SET_NUMBER,
  CLEAR,
  TOGGLE_SIDE_NOTE,
  TOGGLE_CENTER_NOTE,
  SET_COLOR,
  GROUP,
  ERASE_NOTE
}

class Action {
  final ActionType type;
  final Position position;
  final SudokuCell oldCell;
  final SudokuCell newCell;
  final DateTime timestamp;
  final String? groupId; // Add this to track grouped actions

  Action({
    required this.type,
    required this.position,
    required this.oldCell,
    required this.newCell,
    DateTime? timestamp,
    this.groupId, // Add this
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'position': position.toJson(),
      'oldCell': oldCell.toJson(),
      'newCell': newCell.toJson(),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'groupId': groupId, // Add this
    };
  }

  factory Action.fromJson(Map<String, dynamic> json) {
    return Action(
      type: ActionType.values[json['type']],
      position: Position.fromJson(json['position']),
      oldCell: SudokuCell.fromJson(json['oldCell']),
      newCell: SudokuCell.fromJson(json['newCell']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      groupId: json['groupId'], // Add this
    );
  }
}

class ActionGroup {
  final List<Action> actions;
  final DateTime timestamp;

  ActionGroup({
    required this.actions,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
