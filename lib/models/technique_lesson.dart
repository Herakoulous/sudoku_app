import 'package:flutter/material.dart';

import 'position.dart';
import 'solver_step.dart';

/// A group of techniques that belong together.
///
/// The order is the suggested path: each chapter assumes the one before it.
/// Nothing is locked, but a student following the list in order meets ideas in
/// the sequence that makes them easiest to absorb.
///
/// Each carries an icon and a colour so the chapters read as distinct places in
/// the classroom rather than one long undifferentiated list.
enum TechniqueChapter {
  singles(
    'Singles',
    'Finding cells that can only be one thing',
    Icons.looks_one_rounded,
    Color(0xFF5DD39E),
  ),
  intersections(
    'Intersections',
    'Where a box and a line constrain each other',
    Icons.grid_goldenratio_rounded,
    Color(0xFF56A8E8),
  ),
  subsets(
    'Subsets',
    'Groups of cells that own a group of digits',
    Icons.workspaces_rounded,
    Color(0xFFE0A93B),
  ),
  singleDigit(
    'Single-digit patterns',
    'Tracking one digit across the grid',
    Icons.blur_on_rounded,
    Color(0xFFF08A43),
  ),
  chains(
    'Wings and chains',
    'Following consequences from cell to cell',
    Icons.timeline_rounded,
    Color(0xFFB07CE8),
  );

  const TechniqueChapter(this.title, this.blurb, this.icon, this.color);

  final String title;
  final String blurb;
  final IconData icon;
  final Color color;
}

/// The editorial description of a technique: what it is and what to look for.
///
/// Separate from the worked positions, which are generated. This is the part a
/// person writes.
class TechniqueInfo {
  /// HoDoKu's type name, and the key everything is stored under.
  final String id;

  final String name;
  final TechniqueChapter chapter;

  /// One line, shown in the technique list.
  final String summary;

  /// What the student should be scanning for. Shown before the worked example
  /// and again during practice as a nudge.
  final String lookFor;

  const TechniqueInfo({
    required this.id,
    required this.name,
    required this.chapter,
    required this.summary,
    required this.lookFor,
  });
}

/// One position used by the classroom: the board, its candidates, and the step
/// the solver found there.
class TechniquePosition {
  final SolverStep step;

  /// Every cell-set that is a correct answer here.
  ///
  /// A board can contain more than one instance of a technique — two naked
  /// pairs, say — and a student who finds a different valid one than the solver
  /// happened to name is still right. These are enumerated at build time by the
  /// solver's own finders, so grading can never reject a genuine instance.
  final List<Set<Position>> acceptedAnswers;

  const TechniquePosition(this.step, {this.acceptedAnswers = const []});

  /// Cells the student has to find. Derived from the step rather than stored,
  /// so grading can never disagree with the explanation.
  ///
  /// For most techniques these are the pattern cells. Some steps report no
  /// pattern cells at all — chains describe themselves through their nodes, and
  /// ALS steps through their sets — so those fall back to whatever the step
  /// does name.
  Set<Position> get patternCells {
    final cells = <Position>{...step.cells};

    if (cells.isEmpty) {
      for (final chain in step.chains) {
        for (final node in chain) {
          cells.add(node.cell);
        }
      }
    }
    if (cells.isEmpty) {
      for (final als in step.alses) {
        cells.addAll(als.cells);
      }
    }
    if (cells.isEmpty) {
      cells.addAll(step.eliminationCells);
      if (step.placements.isNotEmpty) cells.add(step.placements.first.cell);
    }

    return cells;
  }

  /// All the cell-sets a student may be asked to find.
  ///
  /// Constrained to the size of the solver's own pattern, because the prompt
  /// names one cell count ("tap the 2 cells..."). Fish and chains can have
  /// instances of different lengths; accepting a shorter or longer one would
  /// make that count a lie. Every same-size instance still counts, which is what
  /// fixes the multiple-naked-pair case. The solver's own pattern is always
  /// included as a floor.
  List<Set<Position>> get answers {
    final own = patternCells;
    final sized = [
      for (final answer in acceptedAnswers)
        if (answer.length == own.length) answer,
    ];

    final hasOwn = sized.any(
      (a) => a.length == own.length && a.containsAll(own),
    );
    if (!hasOwn) sized.add(own);

    return sized.isEmpty ? [own] : sized;
  }

  /// How many cells the answer expects. Every accepted instance of one
  /// technique has the same size, so the prompt can name a single number.
  int get patternSize => answers.first.length;

  /// Whether [selection] is any accepted instance, in full and with nothing
  /// spare.
  bool accepts(Set<Position> selection) {
    for (final answer in answers) {
      if (selection.length == answer.length &&
          selection.containsAll(answer)) {
        return true;
      }
    }
    return false;
  }

  /// The accepted answer closest to what the student picked, for showing them
  /// the intended pattern after a wrong guess.
  Set<Position> closestAnswerTo(Set<Position> selection) {
    var best = answers.first;
    var bestOverlap = -1;
    for (final answer in answers) {
      final overlap = answer.intersection(selection).length;
      if (overlap > bestOverlap) {
        bestOverlap = overlap;
        best = answer;
      }
    }
    return best;
  }
}

/// A technique's full classroom entry: what it is, one worked example, and a
/// set of positions to practise on.
class TechniqueLesson {
  final TechniqueInfo info;
  final TechniquePosition? tutorial;
  final List<TechniquePosition> practice;

  const TechniqueLesson({
    required this.info,
    required this.tutorial,
    required this.practice,
  });

  /// A technique with no worked example cannot be taught; the UI hides these
  /// rather than offering a lesson that opens onto nothing.
  bool get isTeachable => tutorial != null;

  bool get hasPractice => practice.isNotEmpty;
}
