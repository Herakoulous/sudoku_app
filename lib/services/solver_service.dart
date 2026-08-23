import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/solver_step.dart';
import 'solver_config.dart';
import 'solver_step_parser.dart';
import 'warmup_sercvice.dart';

/// Talks to the HoDoKu solver and caches what it says.
///
/// The whole solve path is fetched in one request and kept, so walking through
/// hints costs no further network calls. The previous approach asked the server
/// for "step N" every time, which re-solved the puzzle from scratch on each tap
/// and paid a cold start for every hint.
class SolverService {
  SolverService._();

  static const Duration _timeout = Duration(seconds: 60);

  /// Why the last request produced nothing, so the UI can say something more
  /// useful than "check your connection".
  static SolverFailure? lastFailure;

  static String? _cachedGrid;
  static List<SolverStep> _path = const [];
  static int _cursor = 0;

  /// True when a request is in flight, so the UI can avoid firing a second one.
  static bool get isBusy => _inFlight != null;
  static Future<void>? _inFlight;

  /// The next step for [gridString], or null if the solver has nothing.
  ///
  /// [gridString] is 81 digits with 0 for empty.
  static Future<SolverStep?> nextStep(String gridString) async {
    if (gridString.length != 81) return null;

    if (_cachedGrid != gridString) {
      final completer = Completer<void>();
      _inFlight = completer.future;
      try {
        _path = await _fetchPath(gridString);
        _cachedGrid = gridString;
        _cursor = 0;
      } finally {
        completer.complete();
        _inFlight = null;
      }
    }

    if (_cursor >= _path.length) return null;
    return _path[_cursor];
  }

  /// Advances past the current step.
  ///
  /// Called once the player has taken the hint. An elimination leaves the grid
  /// string unchanged, so without this the same hint would be handed back
  /// forever; the cached path already accounts for earlier steps having been
  /// applied, which is exactly the state the player is now in.
  static void markApplied() {
    if (_cursor < _path.length) _cursor++;
  }

  /// Forgets the cache. Used when a puzzle is restarted or abandoned.
  static void reset() {
    _cachedGrid = null;
    _path = const [];
    _cursor = 0;
  }

  /// How many steps remain in the cached path, for progress display.
  static int get remainingSteps =>
      _path.isEmpty ? 0 : (_path.length - _cursor).clamp(0, _path.length);

  // ---------------------------------------------------------------------------
  // NETWORK
  // ---------------------------------------------------------------------------

  static Future<List<SolverStep>> _fetchPath(String gridString) async {
    await SolverWarmupService.ensureWarm();

    lastFailure = null;

    // Preferred: one request for the whole path.
    final path = await _get(SolverConfig.solve(gridString));
    if (path != null) {
      final steps = SolverStepParser.parseSolvePath(path);
      if (steps.isNotEmpty) return steps;
    }

    // Fallback for a server that predates /solve.
    final single = await _get(SolverConfig.hint(gridString, 1));
    if (single != null) {
      final step = SolverStepParser.parseSingle(single);
      if (step != null) return [step];

      // The server answered but not in JSON. That means an old build is
      // deployed — worth saying plainly, because "check your connection" would
      // send the player chasing a problem that is not theirs.
      lastFailure = SolverFailure.outdatedServer;
      return const [];
    }

    lastFailure = SolverFailure.unreachable;
    return const [];
  }

  static Future<String?> _get(Uri uri) async {
    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return null;
      return response.body;
    } on TimeoutException {
      debugPrint('Solver timed out: $uri');
      return null;
    } catch (e) {
      debugPrint('Solver request failed: $e');
      return null;
    }
  }
}

/// Why a solver request produced no usable hint.
enum SolverFailure {
  /// No response at all: offline, or the service is asleep and slow to wake.
  unreachable,

  /// A response arrived, but in the old plain-text format. The deployed server
  /// needs updating to the JSON build.
  outdatedServer;

  String get message {
    switch (this) {
      case SolverFailure.unreachable:
        return 'Could not reach the hint solver. Check your connection and '
            'try again in a moment.';
      case SolverFailure.outdatedServer:
        return 'The hint solver is running an old version and cannot explain '
            'steps yet. Redeploy it to enable hints.';
    }
  }
}
