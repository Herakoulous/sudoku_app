// utils/performance_utils.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class PerformanceUtils {
  // Debounce function to limit frequent calls
  static Timer? _debounceTimer;
  
  static void debounce(VoidCallback callback, Duration delay) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, callback);
  }
  
  // Throttle function to limit call frequency
  static DateTime? _lastCallTime;
  static const Duration _throttleDelay = Duration(milliseconds: 16); // ~60fps
  
  static bool throttle() {
    final now = DateTime.now();
    if (_lastCallTime == null || 
        now.difference(_lastCallTime!) >= _throttleDelay) {
      _lastCallTime = now;
      return true;
    }
    return false;
  }
  
  // Batch multiple setState calls
  static void batchSetState(State<StatefulWidget> state, List<VoidCallback> updates) {
    if (updates.isEmpty) return;
    
    state.setState(() {
      for (final update in updates) {
        update();
      }
    });
  }
  
  // Optimize list generation with const constructors
  static List<Widget> generateOptimizedList<T>(
    List<T> items,
    Widget Function(T item, int index) builder,
  ) {
    return List.generate(
      items.length,
      (index) => builder(items[index], index),
    );
  }
  
  // Check if widget should rebuild
  static bool shouldRebuild<T>(T oldValue, T newValue) {
    return oldValue != newValue;
  }
  
  // Optimize color calculations
  static Color getOptimizedColor(Color baseColor, double opacity) {
    // Cache common colors to avoid repeated calculations
    if (opacity == 0.0) return Colors.transparent;
    if (opacity == 1.0) return baseColor;
    if (opacity == 0.5) return baseColor.withOpacity(0.5);
    if (opacity == 0.3) return baseColor.withOpacity(0.3);
    if (opacity == 0.1) return baseColor.withOpacity(0.1);
    
    return baseColor.withOpacity(opacity);
  }
  
  // Optimize string operations
  static String getCellKey(int row, int col) {
    // Use string interpolation for better performance
    return '$row-$col';
  }
  
  // Optimize set operations
  static Set<String> getOptimizedSet(List<String> items) {
    // Use Set.from for better performance than addAll
    return Set<String>.from(items);
  }
  
  // Memory management
  static void clearMemory() {
    // Clear any cached data
    _debounceTimer?.cancel();
    _lastCallTime = null;
  }
}

// Performance-aware widget mixin
mixin PerformanceWidgetMixin<T extends StatefulWidget> on State<T> {
  bool _isDisposed = false;
  Timer? _performanceTimer;
  
  @override
  void initState() {
    super.initState();
    _startPerformanceMonitoring();
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _performanceTimer?.cancel();
    super.dispose();
  }
  
  void _startPerformanceMonitoring() {
    if (kDebugMode) {
      _performanceTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!_isDisposed) {
          _logPerformanceMetrics();
        }
      });
    }
  }
  
  void _logPerformanceMetrics() {
    // Log performance metrics in debug mode
    if (kDebugMode) {
      debugPrint('Performance metrics for ${widget.runtimeType}');
    }
  }
  
  // Optimized setState with performance check
  void optimizedSetState(VoidCallback fn) {
    if (!_isDisposed) {
      setState(fn);
    }
  }
}

// Performance monitoring widget
class PerformanceMonitor extends StatelessWidget {
  final Widget child;
  final String? label;
  
  const PerformanceMonitor({
    Key? key,
    required this.child,
    this.label,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;
    
    return RepaintBoundary(
      child: child,
    );
  }
}

// Optimized grid cell widget
class OptimizedGridCell extends StatelessWidget {
  final int row;
  final int col;
  final Widget child;
  final VoidCallback? onTap;
  
  const OptimizedGridCell({
    Key? key,
    required this.row,
    required this.col,
    required this.child,
    this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: child,
      ),
    );
  }
}
