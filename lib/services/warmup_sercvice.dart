// File path: lib/services/solver_warmup_service.dart
import 'dart:async';
import 'package:http/http.dart' as http;

import 'solver_config.dart';

class SolverWarmupService {
  static final Uri _warmupUri = SolverConfig.warmup();
  static const Duration _warmupTimeout = Duration(seconds: 40);
  static const Duration _keepAliveInterval = Duration(minutes: 10);

  static bool _isWarmedUp = false;
  static bool _isWarmingUp = false;
  static Timer? _keepAliveTimer;
  static DateTime? _lastWarmupTime;

  /// Check if solver is ready
  static bool get isWarmedUp => _isWarmedUp;

  /// Check if warmup is in progress
  static bool get isWarmingUp => _isWarmingUp;

  /// Start warmup process and keep-alive timer
  static Future<void> startWarmup() async {
    // Do initial warmup
    await warmup();

    // Start keep-alive timer to ping every 10 minutes
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(_keepAliveInterval, (timer) {
      print('🔄 Keep-alive: Pinging server...');
      warmup();
    });
  }

  /// Perform warmup request
  static Future<void> warmup() async {
    if (_isWarmingUp) {
      print('🔥 Warmup already in progress');
      return;
    }

    _isWarmingUp = true;
    print('🔥 Warming up solver at ${DateTime.now()}...');

    try {
      final response =
          await http.get(_warmupUri).timeout(_warmupTimeout);

      if (response.statusCode == 200) {
        _isWarmedUp = true;
        _isWarmingUp = false;
        _lastWarmupTime = DateTime.now();
        print('✅ Solver ready: ${response.body}');
      } else {
        _isWarmingUp = false;
        print('⚠️ Warmup returned status: ${response.statusCode}');
      }
    } on TimeoutException {
      _isWarmingUp = false;
      print('⏱️ Warmup timed out');
    } catch (e) {
      _isWarmingUp = false;
      print('❌ Warmup error: $e');
    }
  }

  /// Ensure server is warm before getting hint
  static Future<void> ensureWarm() async {
    // If never warmed up or last warmup was more than 10 minutes ago
    if (!_isWarmedUp ||
        _lastWarmupTime == null ||
        DateTime.now().difference(_lastWarmupTime!) > _keepAliveInterval) {
      print('🔥 Server may be cold, warming up before hint...');
      await warmup();
    } else {
      print('✅ Server is warm, proceeding with hint');
    }
  }

  /// Stop keep-alive timer (call when app goes to background)
  static void stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    print('⏸️ Keep-alive stopped');
  }

  /// Reset warmup state
  static void reset() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _isWarmedUp = false;
    _isWarmingUp = false;
    _lastWarmupTime = null;
  }
}
