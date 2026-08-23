import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/technique_syllabus.dart';
import '../models/position.dart';
import '../models/technique_lesson.dart';
import 'solver_step_parser.dart';

/// How far a student has got with one technique.
class TechniqueProgress {
  /// The worked example has been read to the end.
  final bool studied;

  /// How many practice positions have been solved.
  final int solved;

  const TechniqueProgress({this.studied = false, this.solved = 0});

  bool get started => studied || solved > 0;

  /// Studied the example and cleared at least three practice positions.
  bool passed(int available) =>
      studied && solved >= (available < 3 ? available : 3);

  TechniqueProgress copyWith({bool? studied, int? solved}) =>
      TechniqueProgress(
        studied: studied ?? this.studied,
        solved: solved ?? this.solved,
      );
}

/// Loads the classroom and remembers how far the student has got.
///
/// Content is bundled rather than fetched: the positions carry their own
/// candidate grids, so every lesson and every practice round works with no
/// network at all.
class ClassroomService {
  ClassroomService._();

  static const String _asset = 'assets/data/classroom.json';
  static const String _studiedKey = 'classroom_studied';
  static const String _solvedPrefix = 'classroom_solved_';
  static const String _guidesReadKey = 'classroom_guides_read';

  static List<TechniqueLesson>? _cache;

  /// Every technique in syllabus order, worked example and practice attached.
  static Future<List<TechniqueLesson>> lessons() async {
    final cached = _cache;
    if (cached != null) return cached;

    final byId = <String, Map<String, dynamic>>{};

    try {
      final raw = await rootBundle.loadString(_asset);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      for (final entry in (decoded['lessons'] as List<dynamic>)) {
        final lesson = entry as Map<String, dynamic>;
        byId[lesson['technique'] as String] = lesson;
      }
    } catch (_) {
      // A missing or corrupt asset must not take the classroom down; the list
      // simply shows techniques with no worked example yet.
    }

    final lessons = <TechniqueLesson>[];

    for (final info in TechniqueSyllabus.all) {
      final data = byId[info.id];

      lessons.add(
        TechniqueLesson(
          info: info,
          tutorial: _position(data?['tutorial']),
          practice: [
            for (final entry in (data?['practice'] as List<dynamic>? ?? []))
              if (_position(entry) case final position?) position,
          ],
        ),
      );
    }

    _cache = lessons;
    return lessons;
  }

  static TechniquePosition? _position(Object? entry) {
    if (entry is! Map<String, dynamic>) return null;

    final step = entry['step'];
    if (step is! Map<String, dynamic>) return null;

    // Reuses the same parser the live solver responses go through, so a bundled
    // position and a fetched hint can never diverge.
    final parsed = SolverStepParser.parseSingle(
      jsonEncode({'ok': true, 'hint': step}),
    );
    if (parsed == null) return null;

    // Accepted answers are stored as 0-based [row, col] pairs.
    final answers = <Set<Position>>[];
    for (final rawSet in (entry['answers'] as List<dynamic>? ?? const [])) {
      if (rawSet is! List) continue;
      final cells = <Position>{};
      for (final rawCell in rawSet) {
        if (rawCell is List && rawCell.length == 2) {
          cells.add(Position(rawCell[0] as int, rawCell[1] as int));
        }
      }
      if (cells.isNotEmpty) answers.add(cells);
    }

    return TechniquePosition(parsed, acceptedAnswers: answers);
  }

  // ---------------------------------------------------------------------------
  // PROGRESS
  // ---------------------------------------------------------------------------

  static Future<Map<String, TechniqueProgress>> progress() async {
    final prefs = await SharedPreferences.getInstance();
    final studied = (prefs.getStringList(_studiedKey) ?? const []).toSet();

    return {
      for (final info in TechniqueSyllabus.all)
        info.id: TechniqueProgress(
          studied: studied.contains(info.id),
          solved: prefs.getInt('$_solvedPrefix${info.id}') ?? 0,
        ),
    };
  }

  static Future<void> markStudied(String techniqueId) async {
    final prefs = await SharedPreferences.getInstance();
    final studied = (prefs.getStringList(_studiedKey) ?? const []).toSet()
      ..add(techniqueId);
    await prefs.setStringList(_studiedKey, studied.toList());
  }

  /// Records one solved practice position.
  ///
  /// Counts distinct positions rather than attempts, so replaying the same one
  /// cannot inflate the total.
  static Future<void> markPracticeSolved(
    String techniqueId,
    int positionIndex,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_solvedPrefix}set_$techniqueId';

    final solved = (prefs.getStringList(key) ?? const []).toSet()
      ..add('$positionIndex');

    await prefs.setStringList(key, solved.toList());
    await prefs.setInt('$_solvedPrefix$techniqueId', solved.length);
  }

  // ---------------------------------------------------------------------------
  // GUIDES (reading lessons)
  // ---------------------------------------------------------------------------

  /// The ids of the reading guides the student has finished.
  static Future<Set<String>> readGuides() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_guidesReadKey) ?? const []).toSet();
  }

  static Future<void> markGuideRead(String guideId) async {
    final prefs = await SharedPreferences.getInstance();
    final read = (await readGuides())..add(guideId);
    await prefs.setStringList(_guidesReadKey, read.toList());
  }

  static Future<Set<int>> solvedPositions(String techniqueId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('${_solvedPrefix}set_$techniqueId') ?? const [];
    return {
      for (final entry in raw)
        if (int.tryParse(entry) case final value?) value,
    };
  }

  /// The technique to nudge the student towards: the first in syllabus order
  /// they have not passed. Nothing is locked, so this is a suggestion only.
  static Future<TechniqueInfo?> suggestedNext() async {
    final all = await lessons();
    final marks = await progress();

    for (final lesson in all) {
      if (!lesson.isTeachable) continue;
      final mark = marks[lesson.info.id] ?? const TechniqueProgress();
      if (!mark.passed(lesson.practice.length)) return lesson.info;
    }
    return null;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_studiedKey);
    await prefs.remove(_guidesReadKey);
    for (final info in TechniqueSyllabus.all) {
      await prefs.remove('$_solvedPrefix${info.id}');
      await prefs.remove('${_solvedPrefix}set_${info.id}');
    }
  }
}
