import '../models/technique_lesson.dart';

/// The classroom syllabus.
///
/// Order is the suggested path — each entry assumes the ones above it. The
/// wording is deliberately about *what to scan for*, because that is the part
/// that turns a technique you can recognise in a diagram into one you can find
/// on your own board.
///
/// Ids are HoDoKu's type names, which is how these are matched to the generated
/// positions.
class TechniqueSyllabus {
  TechniqueSyllabus._();

  static const List<TechniqueInfo> all = [
    // ---------------- SINGLES ----------------
    TechniqueInfo(
      id: 'FULL_HOUSE',
      name: 'Full House',
      chapter: TechniqueChapter.singles,
      summary: 'The last empty cell in a row, column or box.',
      lookFor: 'A house with eight digits already placed. Whatever is missing '
          'goes in the gap.',
    ),
    TechniqueInfo(
      id: 'NAKED_SINGLE',
      name: 'Naked Single',
      chapter: TechniqueChapter.singles,
      summary: 'A cell with only one candidate left.',
      lookFor: 'A cell whose row, column and box between them account for '
          'eight of the nine digits.',
    ),
    TechniqueInfo(
      id: 'HIDDEN_SINGLE',
      name: 'Hidden Single',
      chapter: TechniqueChapter.singles,
      summary: 'A digit with only one place left in a house.',
      lookFor: 'Pick a digit and a house, then ask where it can go. If only '
          'one cell is left, it goes there — whatever else that cell could '
          'have been.',
    ),

    // ---------------- INTERSECTIONS ----------------
    TechniqueInfo(
      id: 'LOCKED_CANDIDATES_1',
      name: 'Pointing',
      chapter: TechniqueChapter.intersections,
      summary: 'A digit confined to one line inside a box.',
      lookFor: 'In a box, find a digit whose only cells all sit in the same '
          'row or column. It can then be cleared from the rest of that line.',
    ),
    TechniqueInfo(
      id: 'LOCKED_CANDIDATES_2',
      name: 'Claiming',
      chapter: TechniqueChapter.intersections,
      summary: 'A digit confined to one box along a line.',
      lookFor: 'The mirror image of pointing. Along a line, find a digit whose '
          'only cells all sit in one box, then clear it from the rest of that '
          'box.',
    ),

    // ---------------- SUBSETS ----------------
    TechniqueInfo(
      id: 'NAKED_PAIR',
      name: 'Naked Pair',
      chapter: TechniqueChapter.subsets,
      summary: 'Two cells in a house holding the same two candidates.',
      lookFor: 'Two cells with exactly two candidates each, and the same two. '
          'Between them they use both digits up.',
    ),
    TechniqueInfo(
      id: 'HIDDEN_PAIR',
      name: 'Hidden Pair',
      chapter: TechniqueChapter.subsets,
      summary: 'Two digits that can only go in the same two cells.',
      lookFor: 'Two digits in a house whose only homes are the same pair of '
          'cells. Those cells belong to them; everything else can go.',
    ),
    TechniqueInfo(
      id: 'NAKED_TRIPLE',
      name: 'Naked Triple',
      chapter: TechniqueChapter.subsets,
      summary: 'Three cells sharing three candidates between them.',
      lookFor: 'Three cells whose candidates, pooled together, come to exactly '
          'three digits. None of them needs to hold all three.',
    ),
    TechniqueInfo(
      id: 'HIDDEN_TRIPLE',
      name: 'Hidden Triple',
      chapter: TechniqueChapter.subsets,
      summary: 'Three digits confined to the same three cells.',
      lookFor: 'Three digits in a house that between them can only reach three '
          'cells. Often buried under other candidates.',
    ),

    // ---------------- SINGLE-DIGIT PATTERNS ----------------
    TechniqueInfo(
      id: 'X_WING',
      name: 'X-Wing',
      chapter: TechniqueChapter.singleDigit,
      summary: 'One digit, two rows, the same two columns.',
      lookFor: 'Two rows where a digit has exactly two spots, and both rows '
          'use the same pair of columns. Those columns are then used up.',
    ),
    TechniqueInfo(
      id: 'SWORDFISH',
      name: 'Swordfish',
      chapter: TechniqueChapter.singleDigit,
      summary: 'An X-Wing stretched to three rows and three columns.',
      lookFor: 'Three rows where a digit fits only within the same three '
          'columns. A row may use two of them rather than all three.',
    ),
    TechniqueInfo(
      id: 'SKYSCRAPER',
      name: 'Skyscraper',
      chapter: TechniqueChapter.singleDigit,
      summary: 'Two rows sharing a column, with the far ends covering the rest.',
      lookFor: 'Two rows where a digit has two spots each and one column is '
          'shared. Anything seeing both far ends loses the digit.',
    ),
    TechniqueInfo(
      id: 'TWO_STRING_KITE',
      name: '2-String Kite',
      chapter: TechniqueChapter.singleDigit,
      summary: 'A row and a column for one digit, meeting in a box.',
      lookFor: 'A row and a column where a digit has two spots each, with one '
          'end of each sharing a box.',
    ),
    TechniqueInfo(
      id: 'EMPTY_RECTANGLE',
      name: 'Empty Rectangle',
      chapter: TechniqueChapter.singleDigit,
      summary: 'A box where a digit fits only one row and one column.',
      lookFor: 'A box whose candidates for a digit all lie on one row and one '
          'column, turning the box into a hinge between them.',
    ),

    // ---------------- WINGS AND CHAINS ----------------
    TechniqueInfo(
      id: 'XY_WING',
      name: 'XY-Wing',
      chapter: TechniqueChapter.chains,
      summary: 'A two-candidate pivot with two wings sharing a digit.',
      lookFor: 'A cell holding exactly two candidates that sees two more '
          'two-candidate cells, all three drawing on just three digits.',
    ),
    TechniqueInfo(
      id: 'XYZ_WING',
      name: 'XYZ-Wing',
      chapter: TechniqueChapter.chains,
      summary: 'An XY-Wing whose hinge also holds the shared digit.',
      lookFor: 'A three-candidate hinge with two two-candidate wings. The '
          'target must see all three cells, not just the wings.',
    ),
    TechniqueInfo(
      id: 'W_WING',
      name: 'W-Wing',
      chapter: TechniqueChapter.chains,
      summary: 'Two identical pairs joined by a strong link.',
      lookFor: 'Two cells holding the same two candidates, with a line '
          'elsewhere forcing one of those digits into one of them.',
    ),
    TechniqueInfo(
      id: 'XY_CHAIN',
      name: 'XY-Chain',
      chapter: TechniqueChapter.chains,
      summary: 'A run of two-candidate cells passing a digit along.',
      lookFor: 'A chain of bivalue cells where each shares a digit with the '
          'next. The two ends then agree on a digit no onlooker can keep.',
    ),
  ];

  static TechniqueInfo? byId(String id) {
    for (final info in all) {
      if (info.id == id) return info;
    }
    return null;
  }

  static List<TechniqueInfo> inChapter(TechniqueChapter chapter) =>
      [for (final info in all) if (info.chapter == chapter) info];
}
