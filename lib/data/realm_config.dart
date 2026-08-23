import 'package:flutter/material.dart';

import 'puzzles.dart';

/// Everything the UI needs to describe a realm in one place: its artwork, its
/// accent colour, how to explain its rule to a player who has never seen the
/// variant, and which puzzles belong to it.
class Realm {
  final String name;

  /// Short line under the realm name on the selection card.
  final String tagline;

  /// One sentence explaining the variant's extra rule, in plain language.
  final String rule;

  final String art;
  final Color primary;
  final Color accent;

  const Realm({
    required this.name,
    required this.tagline,
    required this.rule,
    required this.art,
    required this.primary,
    required this.accent,
  });

  List<PuzzleData> get puzzles => RealmConfig.getPuzzlesForRealm(name);
}

class RealmConfig {
  RealmConfig._();

  static const String classicKingdom = 'Classic Kingdom';
  static const String kropkiForest = 'Kropki Forest';
  static const String thermoDesert = 'Thermo Desert';
  static const String germanWhispers = 'German Whispers Mountains';
  static const String xvSkyIslands = 'XV Sky Islands';
  static const String aquaLabyrinth = 'Aqua Labyrinth';

  /// Display order on the realm selection screen — classic first, then
  /// variants roughly by how much extra rule a player has to absorb.
  static const List<Realm> realms = [
    Realm(
      name: classicKingdom,
      tagline: 'Where every solver begins',
      rule: 'Pure sudoku. Fill every row, column and box with 1 to 9.',
      art: 'images/realms/classic_kingdom.png',
      primary: Color(0xFFECA413),
      accent: Color(0xFFFDE047),
    ),
    Realm(
      name: kropkiForest,
      tagline: 'Follow the dots through the dark',
      rule:
          'A white dot means the two cells differ by one; a black dot means one '
          'is double the other. Every dot is shown, so no dot between two cells '
          'rules both out. Where both could apply, the dot is white.',
      art: 'images/realms/kropki_forest.png',
      primary: Color(0xFF22C55E),
      accent: Color(0xFF86EFAC),
    ),
    Realm(
      name: xvSkyIslands,
      tagline: 'Sums written in the clouds',
      rule:
          'Cells joined by a V add up to 5; cells joined by an X add up to 10. '
          'Every marker is shown, so an unmarked pair sums to neither.',
      art: 'images/realms/xv_sky_islands.png',
      primary: Color(0xFF8B5CF6),
      accent: Color(0xFFC4B5FD),
    ),
    Realm(
      name: thermoDesert,
      tagline: 'Heat rises along every path',
      rule:
          'Numbers must increase as you move along a thermometer, starting from '
          'the bulb.',
      art: 'images/realms/thermo_desert.png',
      primary: Color(0xFFF97316),
      accent: Color(0xFFFBBF24),
    ),
    Realm(
      name: germanWhispers,
      tagline: 'Neighbours keep their distance',
      rule:
          'Along a green line, adjacent numbers must differ by at least five.',
      art: 'images/realms/german_whispers.png',
      primary: Color(0xFF06B6D4),
      accent: Color(0xFF67E8F9),
    ),
    Realm(
      name: aquaLabyrinth,
      tagline: 'What lies between the walls',
      rule:
          'A clue gives the sum of the cells sitting between the 1 and the 9 in '
          'that row or column.',
      art: 'images/realms/aqua_labyrinth.png',
      primary: Color(0xFF3B82F6),
      accent: Color(0xFF93C5FD),
    ),
  ];

  /// Classic puzzles, ordered so the shown number climbs with difficulty —
  /// Puzzle 1 the gentlest, the last the hardest.
  ///
  /// Sorted here rather than renumbered in the data on purpose: puzzle ids are
  /// the keys progress is saved under, so reordering the *display* while leaving
  /// the ids alone gives the ascending run without discarding anyone's history.
  /// The variant realms are already emitted in ascending order.
  static final List<PuzzleData> _classicByDifficulty = () {
    final puzzles = List<PuzzleData>.from(Puzzles.getClassicPuzzles());
    puzzles.sort((a, b) => a.difficulty.compareTo(b.difficulty));
    return puzzles;
  }();

  static final Map<String, List<PuzzleData>> realmPuzzles = {
    classicKingdom: _classicByDifficulty,
    kropkiForest: Puzzles.getKropkiPuzzles(),
    thermoDesert: Puzzles.getThermoPuzzles(),
    germanWhispers: Puzzles.getGermanWhispersPuzzles(),
    xvSkyIslands: Puzzles.getXvPuzzles(),
    aquaLabyrinth: Puzzles.getSandwichPuzzles(),
  };

  /// Reverse index from puzzle id to realm, built once. Lets any screen answer
  /// "which realm does this saved game belong to" without threading the realm
  /// name through storage.
  static final Map<String, String> _realmByPuzzleId = {
    for (final entry in realmPuzzles.entries)
      for (final puzzle in entry.value) puzzle.id: entry.key,
  };

  static Realm? getRealm(String realmName) {
    for (final realm in realms) {
      if (realm.name == realmName) return realm;
    }
    return null;
  }

  static String? realmForPuzzleId(String puzzleId) =>
      _realmByPuzzleId[puzzleId];

  static List<PuzzleData> getPuzzlesForRealm(String realmName) =>
      realmPuzzles[realmName] ?? const [];

  static Color getPrimaryColor(String realmName) =>
      getRealm(realmName)?.primary ?? const Color(0xFFECA413);

  static Color getAccentColor(String realmName) =>
      getRealm(realmName)?.accent ?? const Color(0xFFFDE047);

  /// Realm artwork. Every realm has art, so this never falls back to a missing
  /// asset the way the old background map did.
  static String getArtForRealm(String realmName) =>
      getRealm(realmName)?.art ?? 'images/castle_background.png';
}
