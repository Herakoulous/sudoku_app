import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'position.dart';
import 'solver_step.dart';

/// What a highlighted cell or candidate is doing in the pattern.
///
/// Roles carry colour, so the same idea always looks the same: the thing being
/// removed is always red, the thing that forces it is always gold.
enum HintRole {
  /// The cell the whole pattern hinges on.
  pivot,

  /// A supporting cell of the pattern.
  pattern,

  /// A digit or cell that will be eliminated.
  target,

  /// The answer being placed.
  solution,

  /// A fin, or an extra cell that makes an almost-pattern work.
  fin,

  /// Context: cells that merely block or explain, not part of the pattern.
  context;

  Color get color {
    switch (this) {
      case HintRole.pivot:
        return AppColors.gold;
      case HintRole.pattern:
        return const Color(0xFF56A8E8);
      case HintRole.target:
        return AppColors.danger;
      case HintRole.solution:
        return AppColors.success;
      case HintRole.fin:
        return const Color(0xFFB07CE8);
      case HintRole.context:
        return AppColors.textMuted;
    }
  }
}

/// One highlighted thing on the board during a lesson stage.
///
/// A mark with a [candidate] points at a single pencil mark; without one it
/// highlights the whole cell.
class HintMark {
  final Position cell;
  final int? candidate;
  final HintRole role;

  /// Draws a ring around the cell to pull the eye to it.
  final bool emphasise;

  const HintMark({
    required this.cell,
    required this.role,
    this.candidate,
    this.emphasise = false,
  });

  @override
  bool operator ==(Object other) =>
      other is HintMark &&
      other.cell == cell &&
      other.candidate == candidate &&
      other.role == role &&
      other.emphasise == emphasise;

  @override
  int get hashCode => Object.hash(cell, candidate, role, emphasise);
}

/// A drawn connection between two candidates, used for chains and fish.
class HintLink {
  final Position from;
  final Position to;
  final int? candidate;

  /// Strong links are solid, weak links dashed — the standard convention.
  final bool strong;

  const HintLink({
    required this.from,
    required this.to,
    this.candidate,
    this.strong = true,
  });
}

/// One beat of an explanation: something to read, and the board state that
/// illustrates it.
class HintStage {
  /// The narration. One idea per stage.
  final String text;

  final List<HintMark> marks;
  final List<HintLink> links;

  /// Houses to wash with colour, e.g. the row a hidden single lives in.
  final List<House> houses;

  const HintStage({
    required this.text,
    this.marks = const [],
    this.links = const [],
    this.houses = const [],
  });

  /// Candidates highlighted here, for the grid to render.
  Set<int> get candidateFocus => {
        for (final mark in marks)
          if (mark.candidate != null) mark.candidate!,
      };
}

/// Which pencil-mark style a technique's reasoning is expressed in.
///
/// The two note styles carry different meanings, and a hint should write into
/// whichever one matches how it reasons:
///
///  * [centre] — "this cell can only be one of these digits". Cell-centric
///    techniques (naked subsets, wings, ALS) argue about a cell's whole
///    candidate set.
///  * [side] — "this digit could go here". Digit-centric techniques (hidden
///    subsets, pointing, fish) track one digit across a region.
enum NoteStyle { centre, side }

/// A hint presented as a short lesson rather than an answer.
///
/// The point is the [stages]: the player walks the same reasoning a solver
/// would, one step at a time, with the board illustrating each claim. The
/// answer arrives at the end as a conclusion, not as a handout.
class HintLesson {
  /// Display name of the technique, e.g. "XY-Wing".
  final String technique;

  /// One line naming what this step achieves.
  final String headline;

  final List<HintStage> stages;

  /// The general principle, shown after the walkthrough.
  final String? takeaway;

  /// True when the app knows the technique specifically, false when it fell
  /// back to a generic description.
  final bool isSpecific;

  /// Which note style this technique's reasoning belongs in.
  final NoteStyle noteStyle;

  /// The step this was built from, for applying the result.
  final SolverStep step;

  const HintLesson({
    required this.technique,
    required this.headline,
    required this.stages,
    required this.step,
    this.takeaway,
    this.isSpecific = true,
    this.noteStyle = NoteStyle.centre,
  });

  int get stageCount => stages.length;

  bool get isPlacement => step.isPlacement;

  Position? get placementCell =>
      step.placements.isEmpty ? null : step.placements.first.cell;

  int? get placementValue =>
      step.placements.isEmpty ? null : step.placements.first.value;

  /// Digits this lesson reasons about, used when writing side notes.
  ///
  /// Includes the digits being struck as well as the ones the pattern is built
  /// from. A Hidden Pair argues about where 6 and 7 can go but *eliminates*
  /// other digits from those cells — leave those out and the hint would strike
  /// candidates it never wrote down.
  Set<int> get focusDigits => {...step.values, ...step.eliminatedValues};

  /// The pencil marks that have to be on the board for this lesson to make
  /// sense.
  ///
  /// An elimination hint is meaningless against a blank grid — "remove 3 from
  /// r7c2" says nothing if no 3 was ever written there. So before applying an
  /// elimination the app fills in the candidates the solver reasoned over, in
  /// the note style that matches the technique.
  ///
  /// Scope is deliberately the region the lesson talks about — the cells it
  /// marks plus any house it highlights — rather than the whole board, which
  /// would bury the player in notes they did not ask for.
  List<CandidateRef> notesToReveal() {
    if (isPlacement) return const [];

    final cells = <Position>{};
    for (final stage in stages) {
      for (final mark in stage.marks) {
        cells.add(mark.cell);
      }
      for (final house in stage.houses) {
        cells.addAll(house.cells);
      }
    }
    for (final elimination in step.eliminations) {
      cells.add(elimination.cell);
    }

    final digits = focusDigits;
    final notes = <CandidateRef>[];

    for (final cell in cells) {
      if (step.valueAt(cell) != 0) continue;
      final candidates = step.candidatesOf(cell);

      if (noteStyle == NoteStyle.centre) {
        for (final value in candidates) {
          notes.add(CandidateRef(cell, value));
        }
      } else {
        // Only the digit under discussion, wherever it can still go.
        for (final value in digits) {
          if (candidates.contains(value)) notes.add(CandidateRef(cell, value));
        }
      }
    }

    return notes;
  }
}
