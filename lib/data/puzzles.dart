class PuzzleData {
  final String id;
  final int difficulty;
  final List<List<int>> grid; // 0 = empty, 1-9 = given numbers

  const PuzzleData({
    required this.id,
    required this.difficulty,
    required this.grid,
  });
}

class Puzzles {
  // Easy puzzles
  static const easy1 = PuzzleData(
    id: "easy_001",
    difficulty: 3,
    grid: [
      [5, 3, 0, 0, 7, 0, 0, 0, 0],
      [6, 0, 0, 1, 9, 5, 0, 0, 0],
      [0, 9, 8, 0, 0, 0, 0, 6, 0],
      [8, 0, 0, 0, 6, 0, 0, 0, 3],
      [4, 0, 0, 8, 0, 3, 0, 0, 1],
      [7, 0, 0, 0, 2, 0, 0, 0, 6],
      [0, 6, 0, 0, 0, 0, 2, 8, 0],
      [0, 0, 0, 4, 1, 9, 0, 0, 5],
      [0, 0, 0, 0, 8, 0, 0, 7, 9],
    ],
  );

  static const easy2 = PuzzleData(
    id: "easy_002",
    difficulty: 3,
    grid: [
      [0, 0, 0, 2, 6, 0, 7, 0, 1],
      [6, 8, 0, 0, 7, 0, 0, 9, 0],
      [1, 9, 0, 0, 0, 4, 5, 0, 0],
      [8, 2, 0, 1, 0, 0, 0, 4, 0],
      [0, 0, 4, 6, 0, 2, 9, 0, 0],
      [0, 5, 0, 0, 0, 3, 0, 2, 8],
      [0, 0, 9, 3, 0, 0, 0, 7, 4],
      [0, 4, 0, 0, 5, 0, 0, 3, 6],
      [7, 0, 3, 0, 1, 8, 0, 0, 0],
    ],
  );

  static const medium1 = PuzzleData(
    id: "medium_001",
    difficulty: 5,
    grid: [
      [0, 0, 0, 6, 0, 0, 4, 0, 0],
      [7, 0, 0, 0, 0, 3, 6, 0, 0],
      [0, 0, 0, 0, 9, 1, 0, 8, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 5, 0, 1, 8, 0, 0, 0, 3],
      [0, 0, 0, 3, 0, 6, 0, 4, 5],
      [0, 4, 0, 2, 0, 0, 0, 6, 0],
      [9, 0, 3, 0, 0, 0, 0, 0, 0],
      [0, 2, 0, 0, 0, 0, 1, 0, 0],
    ],
  );

  static const hard1 = PuzzleData(
    id: "hard_001",
    difficulty: 8,
    grid: [
      [0, 0, 0, 0, 0, 0, 0, 1, 2],
      [0, 0, 0, 0, 0, 0, 0, 0, 3],
      [0, 0, 2, 3, 0, 0, 4, 0, 0],
      [0, 0, 1, 8, 0, 0, 0, 0, 5],
      [0, 6, 0, 0, 7, 0, 8, 0, 0],
      [0, 0, 0, 0, 0, 9, 0, 0, 0],
      [0, 0, 8, 5, 0, 0, 0, 0, 0],
      [9, 0, 0, 0, 4, 0, 5, 0, 0],
      [4, 7, 0, 0, 0, 6, 0, 0, 0],
    ],
  );

  static final Map<String, PuzzleData> allPuzzles = {
    easy1.id: easy1,
    easy2.id: easy2,
    medium1.id: medium1,
    hard1.id: hard1,
  };

  static PuzzleData? getPuzzle(String puzzleId) {
    return allPuzzles[puzzleId];
  }

  static List<String> getAllPuzzleIds() {
    return allPuzzles.keys.toList();
  }
}
