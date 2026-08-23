import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku_realms/data/puzzles.dart';
import 'package:sudoku_realms/models/game_state.dart';
import 'package:sudoku_realms/services/archive_service.dart';

/// A game state for a real classic puzzle, optionally advanced and finished.
GameState _game(
  String id, {
  bool completed = false,
  int fill = 0,
  bool wrong = false,
  Duration elapsed = const Duration(minutes: 2),
}) {
  final puzzle = Puzzles.getPuzzle(id)!;
  final state = GameState.newGame(id, puzzle.difficulty);
  state.elapsedTime = elapsed;

  // Fill the first `fill` empty cells with the solution (or wrong digits).
  final solution = puzzle.solution!;
  var placed = 0;
  for (var r = 0; r < 9 && placed < fill; r++) {
    for (var c = 0; c < 9 && placed < fill; c++) {
      if (state.grid[r][c].number != null) continue;
      final correct = solution[r][c];
      state.grid[r][c].number = wrong ? (correct % 9) + 1 : correct;
      placed++;
    }
  }

  state.isCompleted = completed;
  return state;
}

String _classic(int n) =>
    Puzzles.allPuzzles.keys.firstWhere((k) => k == 'classic $n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('recording', () {
    test('an untouched, unfinished game is not archived', () async {
      await ArchiveService.record(_game(_classic(1)));
      expect(await ArchiveService.count(), 0);
    });

    test('a game with input is archived', () async {
      await ArchiveService.record(_game(_classic(1), fill: 5));
      expect(await ArchiveService.count(), 1);

      final games = await ArchiveService.all();
      expect(games.single.puzzleId, 'classic 1');
      expect(games.single.filled, 5);
      expect(games.single.inProgress, isTrue);
    });

    test('a completed game is archived even with no user fill counted', () async {
      // A finished board is worth keeping regardless.
      await ArchiveService.record(_game(_classic(1), completed: true));
      expect(await ArchiveService.count(), 1);
      expect((await ArchiveService.all()).single.completed, isTrue);
    });

    test('mistakes are counted against the solution', () async {
      await ArchiveService.record(_game(_classic(1), fill: 6, wrong: true));
      final game = (await ArchiveService.all()).single;
      expect(game.hasMistakes, isTrue);
      expect(game.mistakes, greaterThan(0));
    });

    test('re-recording a puzzle updates in place, newest first', () async {
      await ArchiveService.record(_game(_classic(1), fill: 3));
      await ArchiveService.record(_game(_classic(2), fill: 3));
      await ArchiveService.record(_game(_classic(1), fill: 8));

      final games = await ArchiveService.all();
      expect(games.length, 2, reason: 'classic 1 updated, not duplicated');
      expect(games.first.puzzleId, 'classic 1');
      expect(games.first.filled, 8);
    });
  });

  group('resume fidelity', () {
    test('the full state round-trips, action history included', () async {
      final state = _game(_classic(1), fill: 4);

      // Give it some undo history and a note.
      state.grid[8][8].centerNotes.addAll({1, 2, 3});
      state.currentActionIndex = 2;

      await ArchiveService.record(state);
      final loaded = await ArchiveService.load('classic 1');

      expect(loaded, isNotNull);
      expect(loaded!.state.grid[8][8].centerNotes, containsAll([1, 2, 3]));
      expect(loaded.state.currentActionIndex, 2);
      expect(loaded.state.elapsedSeconds, state.elapsedSeconds);
    });
  });

  group('deletion', () {
    test('a single game can be removed', () async {
      await ArchiveService.record(_game(_classic(1), fill: 3));
      await ArchiveService.record(_game(_classic(2), fill: 3));

      await ArchiveService.delete('classic 1');

      final games = await ArchiveService.all();
      expect(games.map((g) => g.puzzleId), ['classic 2']);
    });

    test('clear empties the archive', () async {
      await ArchiveService.record(_game(_classic(1), fill: 3));
      await ArchiveService.record(_game(_classic(2), fill: 3));

      await ArchiveService.clear();
      expect(await ArchiveService.count(), 0);
    });
  });

  group('eviction', () {
    test('never drops an in-progress game to make room', () async {
      // One in-progress game, then many completed ones over the cap.
      await ArchiveService.record(_game(_classic(1), fill: 5));

      for (var i = 2; i <= 70; i++) {
        // Only classic 1..72 exist; stay within range.
        final id = 'classic ${(i % 60) + 2}';
        if (Puzzles.getPuzzle(id) == null) continue;
        await ArchiveService.record(_game(id, completed: true, fill: 1));
      }

      final games = await ArchiveService.all();
      expect(games.length, lessThanOrEqualTo(60));
      expect(
        games.any((g) => g.puzzleId == 'classic 1' && g.inProgress),
        isTrue,
        reason: 'the in-progress game must survive eviction',
      );
    });
  });
}
