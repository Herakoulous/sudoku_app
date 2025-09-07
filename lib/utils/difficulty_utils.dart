// utils/difficulty_utils.dart
import 'package:flutter/material.dart';

class DifficultyUtils {
  /// Convert difficulty string to star rating (1-10 stars)
  static int getStarRating(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'very easy':
        return 1;
      case 'easy':
        return 2;
      case 'medium':
        return 4;
      case 'hard':
        return 6;
      case 'very hard':
        return 8;
      case 'expert':
        return 10;
      default:
        return 3; // Default to medium
    }
  }

  /// Build a star rating widget
  static Widget buildStarRating(int stars, {double size = 16.0}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(10, (index) {
        return Icon(
          index < stars ? Icons.star : Icons.star_border,
          color: index < stars ? Colors.amber : Colors.grey.shade300,
          size: size,
        );
      }),
    );
  }

  /// Get difficulty color based on star rating
  static Color getDifficultyColor(int stars) {
    if (stars <= 2) return Colors.green;
    if (stars <= 4) return Colors.blue;
    if (stars <= 6) return Colors.orange;
    if (stars <= 8) return Colors.red;
    return Colors.purple;
  }
}
