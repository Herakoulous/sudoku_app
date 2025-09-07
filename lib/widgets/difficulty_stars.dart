import 'package:flutter/material.dart';

class DifficultyStars extends StatelessWidget {
  final int difficulty;

  const DifficultyStars({
    Key? key,
    required this.difficulty,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(10, (index) {
        return Icon(
          index < difficulty ? Icons.star : Icons.star_border,
          color: index < difficulty ? Colors.amber : Colors.grey[300],
          size: 24,
        );
      }),
    );
  }
}
