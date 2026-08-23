import 'package:flutter/material.dart';

/// A reading lesson in the classroom.
///
/// The technique lessons teach one named pattern each, worked on a real board.
/// Guides cover the ground *around* the techniques — the things a good solver
/// just knows: how to read the grid, how to pencil-mark, the order to work in,
/// the habits that keep you out of trouble. They are prose with small worked
/// illustrations rather than a find-the-pattern drill.
class GuideLesson {
  final String id;
  final String title;

  /// One line, shown in the classroom list.
  final String summary;

  final IconData icon;
  final Color color;

  /// The lesson body, rendered top to bottom.
  final List<GuideBlock> blocks;

  const GuideLesson({
    required this.id,
    required this.title,
    required this.summary,
    required this.icon,
    required this.color,
    required this.blocks,
  });
}

/// One piece of a guide. A small, closed set of block kinds keeps the content
/// data-driven while the rendering stays simple.
sealed class GuideBlock {
  const GuideBlock();
}

/// A short section title within a lesson.
class GuideHeading extends GuideBlock {
  final String text;
  const GuideHeading(this.text);
}

/// A paragraph of body text.
class GuideText extends GuideBlock {
  final String text;
  const GuideText(this.text);
}

/// A bulleted list.
class GuideBullets extends GuideBlock {
  final List<String> items;
  const GuideBullets(this.items);
}

/// A highlighted aside — a tip, a warning, or the one thing to remember.
class GuideCallout extends GuideBlock {
  final GuideTone tone;
  final String title;
  final String text;
  const GuideCallout({
    required this.tone,
    required this.title,
    required this.text,
  });
}

/// A two-column "do this, not that" comparison.
class GuideDosDonts extends GuideBlock {
  final List<String> dos;
  final List<String> donts;
  const GuideDosDonts({required this.dos, required this.donts});
}

/// A small worked illustration of a notation or grid idea, drawn by the guide
/// screen so it matches the real board's look.
class GuideDemo extends GuideBlock {
  final GuideDemoKind kind;
  final String caption;
  const GuideDemo(this.kind, {this.caption = ''});
}

enum GuideTone { tip, warning, key }

/// The built-in illustrations a guide can drop in. Each maps to a small widget
/// in the guide screen.
enum GuideDemoKind {
  /// A cell showing its full candidate list as centre notes.
  centreNotes,

  /// A cell showing edge (side) notes, the Snyder-style scan marks.
  sideNotes,

  /// Side and centre notes side by side, labelled, so the difference is clear.
  notesSideBySide,

  /// A house (a row of nine cells) with a hidden single highlighted.
  houseHiddenSingle,

  /// Two cells sharing the same pair of candidates — a naked pair.
  nakedPair,
}
