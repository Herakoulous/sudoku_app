import 'dart:convert';

import '../models/position.dart';
import '../models/solver_step.dart';

/// Decodes the solver server's JSON into [SolverStep] objects.
///
/// The server emits 1-based rows and columns because that is how the notation
/// reads; everything inside the app is 0-based, so the conversion happens here
/// and exactly once.
class SolverStepParser {
  SolverStepParser._();

  /// Parses a `/solve/:puzzle` response: the whole solve path.
  ///
  /// Returns an empty list for a malformed or unsuccessful response rather than
  /// throwing — a broken hint must never break a game in progress.
  static List<SolverStep> parseSolvePath(String body) {
    final json = _decode(body);
    if (json == null || json['ok'] != true) return const [];

    final steps = json['steps'];
    if (steps is! List) return const [];

    final out = <SolverStep>[];
    for (final entry in steps) {
      if (entry is! Map<String, dynamic>) continue;
      final step = _step(entry);
      if (step != null) out.add(step);
    }
    return out;
  }

  /// Parses a `/hint/:puzzle/:step` response: a single step.
  static SolverStep? parseSingle(String body) {
    final json = _decode(body);
    if (json == null || json['ok'] != true) return null;

    final hint = json['hint'];
    return hint is Map<String, dynamic> ? _step(hint) : null;
  }

  static Map<String, dynamic>? _decode(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;

    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static SolverStep? _step(Map<String, dynamic> json) {
    try {
      return SolverStep(
        type: json['type'] as String? ?? 'UNKNOWN',
        name: json['name'] as String? ?? 'Hint',
        notation: json['notation'] as String? ?? '',
        cells: _cells(json['cells']),
        values: _ints(json['values']),
        placements: _candidates(json['placements']),
        eliminations: _candidates(json['eliminations']),
        house: House.parse(json['house'] as Map<String, dynamic>?),
        house2: House.parse(json['house2'] as Map<String, dynamic>?),
        base: _houses(json['base']),
        cover: _houses(json['cover']),
        fins: _candidates(json['fins']),
        endoFins: _candidates(json['endoFins']),
        cannibalistic: _candidates(json['cannibalistic']),
        chains: _chains(json['chains']),
        alses: _alses(json['alses']),
        grid: _grid(json['grid']),
        candidates: _candidateGrid(json['candidates']),
      );
    } catch (_) {
      return null;
    }
  }

  static Position _cell(Map<String, dynamic> json) =>
      Position((json['r'] as int) - 1, (json['c'] as int) - 1);

  static List<Position> _cells(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map<String, dynamic>) _cell(entry),
    ];
  }

  static List<CandidateRef> _candidates(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map<String, dynamic> && entry['v'] is int)
          CandidateRef(_cell(entry), entry['v'] as int),
    ];
  }

  static List<int> _ints(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is int) entry,
    ];
  }

  static List<House> _houses(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map<String, dynamic>)
          if (House.parse(entry) case final house?) house,
    ];
  }

  static List<List<ChainNode>> _chains(Object? raw) {
    if (raw is! List) return const [];

    final out = <List<ChainNode>>[];
    for (final chain in raw) {
      if (chain is! List) continue;

      // Only real digits. Group and ALS nodes inside forcing nets decode to a
      // candidate of 0, which would otherwise be drawn on the board as
      // "candidate 0". The server filters these too; this is belt and braces so
      // an older deployment cannot produce nonsense highlights.
      final nodes = <ChainNode>[
        for (final node in chain)
          if (node is Map<String, dynamic> &&
              node['v'] is int &&
              (node['v'] as int) >= 1 &&
              (node['v'] as int) <= 9)
            ChainNode(
              cell: _cell(node),
              value: node['v'] as int,
              strong: node['strong'] as bool? ?? false,
            ),
      ];

      if (nodes.isNotEmpty) out.add(nodes);
    }
    return out;
  }

  static List<AlsRef> _alses(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map<String, dynamic>)
          AlsRef(
            cells: _cells(entry['cells']),
            candidates: _ints(entry['candidates']).toSet(),
          ),
    ];
  }

  static List<int> _grid(Object? raw) {
    if (raw is! String || raw.length != 81) return List.filled(81, 0);
    return [
      for (var i = 0; i < 81; i++) raw.codeUnitAt(i) - 0x30,
    ];
  }

  /// The candidate grid arrives as 81 compact strings — "147" means 1, 4 and 7
  /// are still possible, "" means the cell is already solved.
  static List<Set<int>> _candidateGrid(Object? raw) {
    if (raw is! List || raw.length != 81) {
      return List.generate(81, (_) => <int>{});
    }

    return [
      for (final entry in raw)
        if (entry is String)
          {
            for (var i = 0; i < entry.length; i++) entry.codeUnitAt(i) - 0x30,
          }
        else
          <int>{},
    ];
  }
}
