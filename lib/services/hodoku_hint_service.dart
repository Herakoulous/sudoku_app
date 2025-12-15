import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/game_state.dart';
import '../models/hodoku_hint.dart';
import 'hodoku_hint_parser.dart';
import 'hodoku_hint_explainer.dart';

class HoDoKuHintService {
  // 🔥 SMART HINT: Automatically manages step progression
  static Future<HoDoKuHint?> getHint(GameState gameState) async {
    try {
      print('🌐 ===== HODOKU API CALL START =====');

      // Check if grid changed since last hint
      final gridChanged = gameState.hasGridChanged();
      print('📊 Grid changed: $gridChanged');

      // Determine which step to request
      int stepToRequest;

      if (gridChanged) {
        // Grid changed → reset to step 1
        stepToRequest = 1;
        gameState.currentHintStep = 1;
        print('🔄 Grid changed, resetting to step 1');
      } else if (gameState.lastHintWasElimination) {
        // Same grid + last was elimination → increment step
        stepToRequest = gameState.currentHintStep + 1;
        gameState.currentHintStep = stepToRequest;
        print(
            '➕ Last hint was elimination, incrementing to step $stepToRequest');
      } else {
        // Same grid + last was placement → keep same step
        stepToRequest = gameState.currentHintStep;
        print('⏸️ Last hint was placement, staying at step $stepToRequest');
      }

      print('📊 Requesting hint step: $stepToRequest');

      final gridString = _convertGridToHoDoKuFormat(gameState);
      print('📤 Grid string: $gridString');
      print('📤 Grid length: ${gridString.length} chars');

      final response = await _callHoDoKuAPI(gridString, stepToRequest);
      print('📥 API Response: $response');

      if (response == null || response.isEmpty) {
        print('❌ No response from API');
        print('===================================\n');
        return null;
      }

      print('✅ Parsing hint...');
      final hint = HoDoKuHintParser.parse(response);

      if (hint == null) {
        print('❌ Failed to parse hint');
        print('===================================\n');
        return null;
      }

      print('✅ Hint parsed: ${hint.techniqueName}');

      // 🔥 Track if this hint is an elimination or placement
      final isElimination =
          hint.cellToFill == null && hint.eliminations.isNotEmpty;
      gameState.lastHintWasElimination = isElimination;
      print('🏷️ Hint type: ${isElimination ? "ELIMINATION" : "PLACEMENT"}');

      print('===================================\n');
      return hint;
    } catch (e, stackTrace) {
      print('❌ ERROR in getHint: $e');
      print('Stack trace: $stackTrace');
      print('===================================\n');
      return null;
    }
  }

  static String _convertGridToHoDoKuFormat(GameState gameState) {
    final buffer = StringBuffer();

    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        final cell = gameState.grid[row][col];
        final value = cell.number ?? 0;
        buffer.write(value);
      }
    }

    return buffer.toString();
  }

  static Future<String?> _callHoDoKuAPI(String gridString, int step) async {
    try {
      // Build URL with step: /hint/{gridString}/{step}
      final uri =
          Uri.https('hodokucli.onrender.com', '/hint/$gridString/$step');
      print('🌐 Full URL: $uri');

      print('📤 Making GET request (may take up to 60s for cold start)...');

      final response = await http.get(uri).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('⏰ Request timed out after 60s');
          throw TimeoutException('HoDoKu API timed out');
        },
      );

      print('📥 Status code: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final hint = response.body.trim();
        print('✅ Got hint: $hint');
        return hint;
      } else if (response.statusCode == 500 &&
          response.body.contains('No output')) {
        print('⚠️ Server is awake but returned no hint');
        return null;
      } else {
        print('❌ API returned status ${response.statusCode}');
        return null;
      }
    } on TimeoutException catch (e) {
      print('❌ Timeout error: $e');
      return null;
    } catch (e, stackTrace) {
      print('❌ Network error: $e');
      print('Stack: $stackTrace');
      return null;
    }
  }

  static Future<void> warmUpServer() async {
    try {
      print('🔥 Warming up HoDoKu server...');

      const warmupGrid =
          '123456789456789123789123456231564897564897231897231564312645978645978312978312645';
      final uri = Uri.https('hodokucli.onrender.com', '/hint/$warmupGrid/1');

      await http.get(uri).timeout(
            const Duration(seconds: 60),
            onTimeout: () => http.Response('timeout', 408),
          );

      print('✅ Server warmed up');
    } catch (e) {
      print('⚠️ Warmup failed (server might still be cold): $e');
    }
  }

  static void applyHint(GameState gameState, HoDoKuHint hint) {
    print('🔧 ===== APPLYING HINT =====');

    gameState.clearHint();

    if (hint.cellToFill != null && hint.numberToFill != null) {
      print('📍 Cell: ${hint.cellToFill}');
      print('🔢 Number: ${hint.numberToFill}');
      gameState.hintCell = hint.cellToFill;
      gameState.hintNumber = hint.numberToFill;
    }

    gameState.hintHighlightCells = hint.highlightCells;
    gameState.hintHighlightNumbers = hint.highlightNumbers;

    for (final elimination in hint.eliminations) {
      _applyCellElimination(gameState, elimination);
    }

    final explanationParagraphs = HoDoKuHintExplainer.formatForBubble(hint);
    gameState.lastHintExplanation = explanationParagraphs.join('\n\n');
    gameState.lastHintType = hint.techniqueName;

    print(
        '📝 Explanation set: ${gameState.lastHintExplanation?.substring(0, 50)}...');
    print('🏷️ Type: ${gameState.lastHintType}');
    print('============================\n');
  }

  static void _applyCellElimination(
    GameState gameState,
    CellElimination elimination,
  ) {
    final pos = elimination.cell;
    final cell = gameState.grid[pos.row][pos.col];

    if (cell.number != null) return;

    final newSideNotes = Set<int>.from(cell.sideNotes);
    final newCenterNotes = Set<int>.from(cell.centerNotes);

    newSideNotes.removeAll(elimination.eliminatedCandidates);
    newCenterNotes.removeAll(elimination.eliminatedCandidates);

    gameState.grid[pos.row][pos.col] = cell.copyWith(
      sideNotes: newSideNotes,
      centerNotes: newCenterNotes,
    );
  }
}
