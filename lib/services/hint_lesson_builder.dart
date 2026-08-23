import '../models/hint_lesson.dart';
import '../models/position.dart';
import '../models/solver_step.dart';

/// Turns a solver step into a walkthrough.
///
/// This is the difference between a hint and a lesson. The solver says "XY-Wing:
/// 1/6/3 in r7c15,r8c3 => r7c2<>3"; a player learns nothing from that. Here the
/// same step becomes: this cell holds only 1 or 6, so if it is 1 then that cell
/// must be 3, and if it is 6 then this other cell must be 3 — either way one of
/// them is 3, so nothing that sees both can be.
///
/// Every claim is derived from the candidate grid the solver actually reasoned
/// over, so the wording can name real cells and real digits rather than
/// gesturing at "the pivot".
class HintLessonBuilder {
  HintLessonBuilder._();

  static HintLesson build(SolverStep step) {
    final builder = _builderFor(step.type);
    if (builder != null) {
      final lesson = builder(step);
      if (lesson != null) return lesson;
    }
    // A step with a chain can always be narrated node by node, whatever its
    // name, which covers the whole loop/AIC/forcing family in one go.
    if (step.chains.isNotEmpty) {
      final lesson = _chain(step);
      if (lesson != null) return lesson;
    }
    return _generic(step);
  }

  static HintLesson? Function(SolverStep)? _builderFor(String type) {
    switch (type) {
      case 'FULL_HOUSE':
        return _fullHouse;
      case 'NAKED_SINGLE':
        return _nakedSingle;
      case 'HIDDEN_SINGLE':
        return _hiddenSingle;

      case 'LOCKED_CANDIDATES_1':
        return _pointing;
      case 'LOCKED_CANDIDATES_2':
        return _claiming;

      case 'NAKED_PAIR':
      case 'NAKED_TRIPLE':
      case 'NAKED_QUADRUPLE':
      case 'LOCKED_PAIR':
      case 'LOCKED_TRIPLE':
        return _nakedSubset;

      case 'HIDDEN_PAIR':
      case 'HIDDEN_TRIPLE':
      case 'HIDDEN_QUADRUPLE':
        return _hiddenSubset;

      case 'X_WING':
      case 'SWORDFISH':
      case 'JELLYFISH':
      case 'FINNED_X_WING':
      case 'FINNED_SWORDFISH':
      case 'FINNED_JELLYFISH':
      case 'SASHIMI_X_WING':
      case 'SASHIMI_SWORDFISH':
      case 'SASHIMI_JELLYFISH':
        return _fish;

      case 'SKYSCRAPER':
        return _skyscraper;
      case 'TWO_STRING_KITE':
        return _kite;
      case 'EMPTY_RECTANGLE':
        return _emptyRectangle;

      case 'XY_WING':
        return _xyWing;
      case 'XYZ_WING':
        return _xyzWing;
      case 'W_WING':
        return _wWing;
      case 'REMOTE_PAIR':
        return _remotePair;

      case 'UNIQUENESS_1':
      case 'UNIQUENESS_2':
      case 'UNIQUENESS_3':
      case 'UNIQUENESS_4':
      case 'UNIQUENESS_5':
      case 'UNIQUENESS_6':
      case 'HIDDEN_RECTANGLE':
        return _uniqueness;

      case 'ALS_XZ':
      case 'ALS_XY':
      case 'ALS_XY_WING':
        return _als;

      // A net branches; narrating it as a single line of reasoning would be a
      // lie, so it gets an honest summary instead of a fake walkthrough.
      case 'FORCING_NET_CONTRADICTION':
      case 'FORCING_NET_VERITY':
      case 'GROUPED_FORCING_NET_CONTRADICTION':
      case 'GROUPED_FORCING_NET_VERITY':
        return _forcingNet;

      case 'BRUTE_FORCE':
        return _bruteForce;

      default:
        return null;
    }
  }

  // ===========================================================================
  // SINGLES
  // ===========================================================================

  static HintLesson? _fullHouse(SolverStep step) {
    if (step.placements.isEmpty) return null;
    final placement = step.placements.first;
    final cell = placement.cell;

    final house = _houseWithOneEmptyCell(step, cell) ?? House.of(cell).first;
    final present = _digitsIn(step, house);

    return HintLesson(
      technique: step.name,
      headline: 'Place ${placement.value} in ${cell.label}',
      step: step,
      takeaway: 'A Full House is the last gap in a row, column or box. '
          'Whatever digit is missing has nowhere else to go.',
      stages: [
        HintStage(
          text: 'Look at ${house.label}. Eight of its nine cells are already '
              'filled.',
          houses: [house],
          marks: [
            for (final c in house.cells)
              if (step.valueAt(c) != 0)
                HintMark(cell: c, role: HintRole.context),
          ],
        ),
        HintStage(
          text: '${cell.label} is the only empty cell left in ${house.label}.',
          houses: [house],
          marks: [
            HintMark(cell: cell, role: HintRole.pivot, emphasise: true),
          ],
        ),
        HintStage(
          text: '${_capitalise(house.label)} already holds '
              '${_numberList(present)}. The only digit missing is '
              '${placement.value}.',
          houses: [house],
          marks: [
            HintMark(cell: cell, role: HintRole.pivot, emphasise: true),
          ],
        ),
        HintStage(
          text: 'So ${cell.label} must be ${placement.value}.',
          marks: [
            HintMark(
              cell: cell,
              candidate: placement.value,
              role: HintRole.solution,
              emphasise: true,
            ),
          ],
        ),
      ],
    );
  }

  static HintLesson? _nakedSingle(SolverStep step) {
    if (step.placements.isEmpty) return null;
    final placement = step.placements.first;
    final cell = placement.cell;
    final value = placement.value;

    // Naming an actual blocker for each ruled-out digit is what teaches the
    // technique; "the others are blocked" teaches nothing.
    final blockers = _blockers(step, cell, value);

    final stages = <HintStage>[
      HintStage(
        text: 'Look at ${cell.label}, and at the row, column and box it sits '
            'in.',
        houses: House.of(cell),
        marks: [HintMark(cell: cell, role: HintRole.pivot, emphasise: true)],
      ),
    ];

    if (blockers.isNotEmpty) {
      stages.add(
        HintStage(
          text: _blockerSentence(blockers),
          houses: House.of(cell),
          marks: [
            HintMark(cell: cell, role: HintRole.pivot, emphasise: true),
            for (final entry in blockers.entries.take(6))
              HintMark(
                cell: entry.value.cell,
                candidate: entry.key,
                role: HintRole.context,
              ),
          ],
        ),
      );
    }

    stages.add(
      HintStage(
        text: 'That rules out every digit except $value, so ${cell.label} '
            'must be $value.',
        marks: [
          HintMark(
            cell: cell,
            candidate: value,
            role: HintRole.solution,
            emphasise: true,
          ),
        ],
      ),
    );

    return HintLesson(
      technique: step.name,
      headline: 'Place $value in ${cell.label}',
      step: step,
      takeaway: 'A Naked Single is a cell with one candidate left. Whenever you '
          'fill a cell, re-check its neighbours for these.',
      stages: stages,
    );
  }

  static HintLesson? _hiddenSingle(SolverStep step) {
    if (step.placements.isEmpty) return null;
    final placement = step.placements.first;
    final cell = placement.cell;
    final value = placement.value;

    final house = step.house ?? _hiddenSingleHouse(step, cell, value);
    if (house == null) return null;

    // Empty cells of the house that cannot take the digit, and why.
    final rejected = <Position, Position>{};
    for (final other in house.cells) {
      if (other == cell || step.valueAt(other) != 0) continue;
      if (step.candidatesOf(other).contains(value)) continue;

      final blocker = _findBlocker(step, other, value);
      if (blocker != null) rejected[other] = blocker;
    }

    final stages = <HintStage>[
      HintStage(
        text: 'Ask where $value can go in ${house.label}.',
        houses: [house],
        marks: [
          for (final c in house.cells)
            if (step.valueAt(c) == 0)
              HintMark(cell: c, role: HintRole.context),
        ],
      ),
    ];

    if (rejected.isNotEmpty) {
      final examples = rejected.entries.take(3).toList();
      final sentence = _join([
        for (final e in examples)
          '${e.key.label} is blocked by the $value in ${e.value.label}',
      ]);

      stages.add(
        HintStage(
          text: 'Of the empty cells, $sentence'
              '${rejected.length > 3 ? ', and so on for the rest' : ''}.',
          houses: [house],
          marks: [
            for (final e in examples) ...[
              HintMark(cell: e.key, role: HintRole.target),
              HintMark(
                cell: e.value,
                candidate: value,
                role: HintRole.context,
              ),
            ],
          ],
        ),
      );
    }

    stages.add(
      HintStage(
        text: '${cell.label} is the only cell in ${house.label} that can still '
            'take $value.',
        houses: [house],
        marks: [
          HintMark(
            cell: cell,
            candidate: value,
            role: HintRole.pivot,
            emphasise: true,
          ),
        ],
      ),
    );

    stages.add(
      HintStage(
        text: 'Every digit has to appear in ${house.label} somewhere, so '
            '${cell.label} must be $value — even though it may still show '
            'other candidates.',
        marks: [
          HintMark(
            cell: cell,
            candidate: value,
            role: HintRole.solution,
            emphasise: true,
          ),
        ],
      ),
    );

    return HintLesson(
      technique: step.name,
      headline: 'Place $value in ${cell.label}',
      step: step,
      noteStyle: NoteStyle.side,
      takeaway: 'A Hidden Single hides behind other candidates. Instead of '
          'asking what a cell can be, ask where a digit can go.',
      stages: stages,
    );
  }

  // ===========================================================================
  // LOCKED CANDIDATES
  // ===========================================================================

  static HintLesson? _pointing(SolverStep step) {
    if (step.values.isEmpty || step.cells.isEmpty) return null;
    final value = step.values.first;
    final box = step.house ?? _sharedHouse(step.cells, HouseType.box);
    final line = _sharedHouse(step.cells, HouseType.row) ??
        _sharedHouse(step.cells, HouseType.col);
    if (box == null || line == null) return null;

    return HintLesson(
      technique: step.name,
      headline: 'Remove $value from ${_cellList(step.eliminationCells)}',
      step: step,
      noteStyle: NoteStyle.side,
      takeaway: 'When a digit is confined to one line inside a box, it must '
          'appear on that line — so it can be cleared from the rest of the '
          'line outside the box.',
      stages: [
        HintStage(
          text: 'Inside ${box.label}, $value can only go in '
              '${_cellList(step.cells)}.',
          houses: [box],
          marks: [
            for (final c in step.cells)
              HintMark(cell: c, candidate: value, role: HintRole.pivot),
          ],
        ),
        HintStage(
          text: 'Those cells all lie on ${line.label}.',
          houses: [box, line],
          marks: [
            for (final c in step.cells)
              HintMark(
                cell: c,
                candidate: value,
                role: HintRole.pivot,
                emphasise: true,
              ),
          ],
        ),
        HintStage(
          text: '${_capitalise(box.label)} must contain a $value somewhere, and '
              'every option is on ${line.label} — so the $value of '
              '${line.label} is inside ${box.label}.',
          houses: [box, line],
          marks: [
            for (final c in step.cells)
              HintMark(cell: c, candidate: value, role: HintRole.pivot),
          ],
        ),
        HintStage(
          text: 'That leaves no room for $value elsewhere on ${line.label}: '
              'remove it from ${_cellList(step.eliminationCells)}.',
          houses: [line],
          marks: [
            for (final c in step.cells)
              HintMark(cell: c, candidate: value, role: HintRole.pivot),
            for (final e in step.eliminations)
              HintMark(
                cell: e.cell,
                candidate: e.value,
                role: HintRole.target,
                emphasise: true,
              ),
          ],
        ),
      ],
    );
  }

  static HintLesson? _claiming(SolverStep step) {
    if (step.values.isEmpty || step.cells.isEmpty) return null;
    final value = step.values.first;
    final line = step.house ??
        _sharedHouse(step.cells, HouseType.row) ??
        _sharedHouse(step.cells, HouseType.col);
    final box = _sharedHouse(step.cells, HouseType.box);
    if (line == null || box == null) return null;

    return HintLesson(
      technique: step.name,
      headline: 'Remove $value from ${_cellList(step.eliminationCells)}',
      step: step,
      noteStyle: NoteStyle.side,
      takeaway: 'The mirror image of pointing: when a digit is confined to one '
          'box along a line, it must be in that box, clearing it from the rest '
          'of the box.',
      stages: [
        HintStage(
          text: 'Along ${line.label}, $value can only go in '
              '${_cellList(step.cells)}.',
          houses: [line],
          marks: [
            for (final c in step.cells)
              HintMark(cell: c, candidate: value, role: HintRole.pivot),
          ],
        ),
        HintStage(
          text: 'All of those cells sit inside ${box.label}.',
          houses: [line, box],
          marks: [
            for (final c in step.cells)
              HintMark(
                cell: c,
                candidate: value,
                role: HintRole.pivot,
                emphasise: true,
              ),
          ],
        ),
        HintStage(
          text: '${_capitalise(line.label)} has to hold a $value, so it is one '
              'of these — meaning ${box.label} gets its $value from '
              '${line.label}.',
          houses: [line, box],
          marks: [
            for (final c in step.cells)
              HintMark(cell: c, candidate: value, role: HintRole.pivot),
          ],
        ),
        HintStage(
          text: 'So $value can be removed from the rest of ${box.label}: '
              '${_cellList(step.eliminationCells)}.',
          houses: [box],
          marks: [
            for (final c in step.cells)
              HintMark(cell: c, candidate: value, role: HintRole.pivot),
            for (final e in step.eliminations)
              HintMark(
                cell: e.cell,
                candidate: e.value,
                role: HintRole.target,
                emphasise: true,
              ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // SUBSETS
  // ===========================================================================

  static HintLesson? _nakedSubset(SolverStep step) {
    if (step.cells.length < 2 || step.values.isEmpty) return null;

    final house = _sharedHouse(step.cells, HouseType.row) ??
        _sharedHouse(step.cells, HouseType.col) ??
        _sharedHouse(step.cells, HouseType.box);
    if (house == null) return null;

    final n = step.cells.length;
    final digits = _numberList(step.values);

    return HintLesson(
      technique: step.name,
      headline: 'Remove ${_numberList(step.eliminatedValues)} from '
          '${_cellList(step.eliminationCells)}',
      step: step,
      takeaway: 'A Naked Subset is $n cells sharing exactly $n candidates. '
          'Those digits are trapped there, so no other cell in the house can '
          'use them.',
      stages: [
        HintStage(
          text: 'Look at ${_cellList(step.cells)} in ${house.label}.',
          houses: [house],
          marks: [
            for (final c in step.cells)
              HintMark(cell: c, role: HintRole.pivot, emphasise: true),
          ],
        ),
        HintStage(
          text: 'Between them they hold only $digits — '
              '${_cellCandidateSentence(step, step.cells)}.',
          houses: [house],
          marks: [
            for (final c in step.cells)
              for (final v in step.candidatesOf(c))
                HintMark(cell: c, candidate: v, role: HintRole.pivot),
          ],
        ),
        HintStage(
          text: 'That is $n cells for $n digits, so those $n cells will use up '
              '$digits between them, in some order.',
          houses: [house],
          marks: [
            for (final c in step.cells)
              for (final v in step.candidatesOf(c))
                HintMark(cell: c, candidate: v, role: HintRole.pivot),
          ],
        ),
        HintStage(
          text: 'No other cell in ${house.label} can take those digits: remove '
              '${_eliminationSentence(step)}.',
          houses: [house],
          marks: [
            for (final c in step.cells)
              HintMark(cell: c, role: HintRole.pivot),
            for (final e in step.eliminations)
              HintMark(
                cell: e.cell,
                candidate: e.value,
                role: HintRole.target,
                emphasise: true,
              ),
          ],
        ),
      ],
    );
  }

  static HintLesson? _hiddenSubset(SolverStep step) {
    if (step.cells.length < 2 || step.values.isEmpty) return null;

    final house = _sharedHouse(step.cells, HouseType.row) ??
        _sharedHouse(step.cells, HouseType.col) ??
        _sharedHouse(step.cells, HouseType.box);
    if (house == null) return null;

    final n = step.cells.length;
    final digits = _numberList(step.values);

    return HintLesson(
      technique: step.name,
      headline: 'Remove ${_numberList(step.eliminatedValues)} from '
          '${_cellList(step.eliminationCells)}',
      step: step,
      noteStyle: NoteStyle.side,
      takeaway: 'A Hidden Subset works the other way round: $n digits that can '
          'only appear in $n cells claim those cells, pushing everything else '
          'out.',
      stages: [
        HintStage(
          text: 'Ask where $digits can go in ${house.label}.',
          houses: [house],
          marks: [
            for (final c in house.cells)
              if (step.valueAt(c) == 0)
                HintMark(cell: c, role: HintRole.context),
          ],
        ),
        HintStage(
          text: 'Each of them is confined to ${_cellList(step.cells)} — '
              '$n digits with only $n places to go.',
          houses: [house],
          marks: [
            for (final c in step.cells)
              for (final v in step.values)
                if (step.candidatesOf(c).contains(v))
                  HintMark(
                    cell: c,
                    candidate: v,
                    role: HintRole.pivot,
                    emphasise: true,
                  ),
          ],
        ),
        HintStage(
          text: 'So those $n cells must hold $digits between them, leaving no '
              'space for anything else.',
          houses: [house],
          marks: [
            for (final c in step.cells)
              HintMark(cell: c, role: HintRole.pivot, emphasise: true),
          ],
        ),
        HintStage(
          text: 'Clear the other candidates out: ${_eliminationSentence(step)}.',
          houses: [house],
          marks: [
            for (final e in step.eliminations)
              HintMark(
                cell: e.cell,
                candidate: e.value,
                role: HintRole.target,
                emphasise: true,
              ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // FISH
  // ===========================================================================

  static HintLesson? _fish(SolverStep step) {
    if (step.values.isEmpty) return null;
    final value = step.values.first;

    var base = step.base;
    var cover = step.cover;

    // Older responses may not carry base/cover; recover them from the pattern
    // cells so the lesson still works.
    if (base.isEmpty || cover.isEmpty) {
      final rows = {for (final c in step.cells) c.row}.toList()..sort();
      final cols = {for (final c in step.cells) c.col}.toList()..sort();
      base = [for (final r in rows) House(HouseType.row, r + 1)];
      cover = [for (final c in cols) House(HouseType.col, c + 1)];
    }

    final baseLabel = _houseList(base);
    final coverLabel = _houseList(cover);
    final hasFins = step.fins.isNotEmpty;

    final stages = <HintStage>[
      HintStage(
        text: 'Track where $value can go in $baseLabel.',
        houses: base,
        marks: [
          for (final c in step.cells)
            HintMark(cell: c, candidate: value, role: HintRole.pattern),
        ],
      ),
      HintStage(
        text: 'In each of those, $value is confined to $coverLabel.',
        houses: [...base, ...cover],
        marks: [
          for (final c in step.cells)
            HintMark(
              cell: c,
              candidate: value,
              role: HintRole.pivot,
              emphasise: true,
            ),
        ],
        links: _gridLinks(step.cells, value),
      ),
      HintStage(
        text: 'Each of $baseLabel needs its own $value, and they all have to '
            'come from $coverLabel — that uses up every one of those lines.',
        houses: [...base, ...cover],
        marks: [
          for (final c in step.cells)
            HintMark(cell: c, candidate: value, role: HintRole.pivot),
        ],
      ),
    ];

    if (hasFins) {
      stages.add(
        HintStage(
          text: 'The pattern is not quite clean: '
              '${_cellList(step.fins.map((f) => f.cell))} '
              '${step.fins.length == 1 ? 'is an extra' : 'are extras'} — a fin. '
              'The conclusion only holds for cells that also see the fin.',
          marks: [
            for (final f in step.fins)
              HintMark(
                cell: f.cell,
                candidate: f.value,
                role: HintRole.fin,
                emphasise: true,
              ),
          ],
        ),
      );
    }

    stages.add(
      HintStage(
        text: 'So $value can be removed from '
            '${_cellList(step.eliminationCells)}.',
        houses: cover,
        marks: [
          for (final c in step.cells)
            HintMark(cell: c, candidate: value, role: HintRole.pivot),
          for (final e in step.eliminations)
            HintMark(
              cell: e.cell,
              candidate: e.value,
              role: HintRole.target,
              emphasise: true,
            ),
        ],
      ),
    );

    return HintLesson(
      technique: step.name,
      headline: 'Remove $value from ${_cellList(step.eliminationCells)}',
      step: step,
      noteStyle: NoteStyle.side,
      takeaway: 'A fish matches N lines against N crossing lines for one digit. '
          'The crossing lines get fully used up, so that digit clears out of '
          'them everywhere else.',
      stages: stages,
    );
  }

  // ===========================================================================
  // SINGLE-DIGIT CHAINS
  // ===========================================================================

  static HintLesson? _skyscraper(SolverStep step) =>
      _twoStrongLinks(step, 'Skyscraper',
          'Two rows (or columns) where a digit has just two spots, sharing one '
          'line. The far ends cover everything that sees both.');

  static HintLesson? _kite(SolverStep step) =>
      _twoStrongLinks(step, '2-String Kite',
          'A row and a column where a digit has two spots each, meeting in one '
          'box. Whatever sees both far ends cannot be that digit.');

  static HintLesson? _twoStrongLinks(
    SolverStep step,
    String label,
    String takeaway,
  ) {
    if (step.values.isEmpty || step.cells.length < 2) return null;
    final value = step.values.first;

    return HintLesson(
      technique: step.name,
      headline: 'Remove $value from ${_cellList(step.eliminationCells)}',
      step: step,
      noteStyle: NoteStyle.side,
      takeaway: takeaway,
      stages: [
        HintStage(
          text: 'For $value, look at ${_cellList(step.cells)} — two lines where '
              '$value has only two possible cells each.',
          marks: [
            for (final c in step.cells)
              HintMark(cell: c, candidate: value, role: HintRole.pattern),
          ],
          links: _gridLinks(step.cells, value),
        ),
        HintStage(
          text: 'On each line, one of the two must be $value. The two lines are '
              'joined, so between them at least one end is always $value.',
          marks: [
            for (final c in step.cells)
              HintMark(
                cell: c,
                candidate: value,
                role: HintRole.pivot,
                emphasise: true,
              ),
          ],
          links: _gridLinks(step.cells, value),
        ),
        HintStage(
          text: 'Whichever way it falls, ${_cellList(step.eliminationCells)} '
              'can see a $value — so $value can go.',
          marks: [
            for (final c in step.cells)
              HintMark(cell: c, candidate: value, role: HintRole.pivot),
            for (final e in step.eliminations)
              HintMark(
                cell: e.cell,
                candidate: e.value,
                role: HintRole.target,
                emphasise: true,
              ),
          ],
        ),
      ],
    );
  }

  static HintLesson? _emptyRectangle(SolverStep step) {
    if (step.values.isEmpty) return null;
    final value = step.values.first;

    return HintLesson(
      technique: step.name,
      headline: 'Remove $value from ${_cellList(step.eliminationCells)}',
      step: step,
      noteStyle: NoteStyle.side,
      takeaway: 'An Empty Rectangle uses a box where a digit fits only in one '
          'row and one column, turning the box into a hinge between them.',
      stages: [
        HintStage(
          text: 'Inside this box, $value only appears in one row and one '
              'column — the rest of the box is empty of it.',
          houses: [
            if (step.house != null) step.house!,
          ],
          marks: [
            for (final c in step.cells)
              HintMark(cell: c, candidate: value, role: HintRole.pattern),
          ],
        ),
        HintStage(
          text: 'That makes the box a hinge: a $value on one arm forces a '
              '$value on the other.',
          marks: [
            for (final c in step.cells)
              HintMark(
                cell: c,
                candidate: value,
                role: HintRole.pivot,
                emphasise: true,
              ),
          ],
          links: _gridLinks(step.cells, value),
        ),
        HintStage(
          text: 'Following that through, $value cannot survive in '
              '${_cellList(step.eliminationCells)}.',
          marks: [
            for (final e in step.eliminations)
              HintMark(
                cell: e.cell,
                candidate: e.value,
                role: HintRole.target,
                emphasise: true,
              ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // WINGS
  // ===========================================================================

  static HintLesson? _xyWing(SolverStep step) {
    if (step.cells.length < 3 || step.eliminations.isEmpty) return null;

    final z = step.eliminations.first.value;

    // The pivot is the one cell of the three that does NOT hold the eliminated
    // digit. Deriving it beats trusting the order the solver listed cells in.
    Position? pivot;
    final wings = <Position>[];
    for (final cell in step.cells) {
      if (step.candidatesOf(cell).contains(z)) {
        wings.add(cell);
      } else {
        pivot ??= cell;
      }
    }
    if (pivot == null || wings.length != 2) return null;

    final pivotCandidates = step.candidatesOf(pivot).toList()..sort();
    if (pivotCandidates.length != 2) return null;

    final wingA = wings[0];
    final wingB = wings[1];

    // Each wing shares its non-z digit with the pivot; that digit is the link.
    final linkA = step.candidatesOf(wingA).firstWhere(
          (v) => v != z && pivotCandidates.contains(v),
          orElse: () => pivotCandidates.first,
        );
    final linkB = step.candidatesOf(wingB).firstWhere(
          (v) => v != z && pivotCandidates.contains(v),
          orElse: () => pivotCandidates.last,
        );

    return HintLesson(
      technique: step.name,
      headline: 'Remove $z from ${_cellList(step.eliminationCells)}',
      step: step,
      takeaway: 'An XY-Wing is a pivot with two candidates and two wings that '
          'share one digit. Both branches end with the same digit somewhere, so '
          'anything seeing both wings loses it.',
      stages: [
        HintStage(
          text: '${pivot.label} holds only ${_numberList(pivotCandidates)}. '
              'It is the pivot.',
          marks: [
            for (final v in pivotCandidates)
              HintMark(cell: pivot, candidate: v, role: HintRole.pivot),
            HintMark(cell: pivot, role: HintRole.pivot, emphasise: true),
          ],
        ),
        HintStage(
          text: 'It sees ${wingA.label} '
              '(${_numberList(step.candidatesOf(wingA))}) and ${wingB.label} '
              '(${_numberList(step.candidatesOf(wingB))}). Both wings contain '
              '$z.',
          marks: [
            HintMark(cell: pivot, role: HintRole.pivot, emphasise: true),
            for (final w in wings)
              for (final v in step.candidatesOf(w))
                HintMark(
                  cell: w,
                  candidate: v,
                  role: v == z ? HintRole.target : HintRole.pattern,
                ),
          ],
          links: [
            HintLink(from: pivot, to: wingA, candidate: linkA),
            HintLink(from: pivot, to: wingB, candidate: linkB),
          ],
        ),
        HintStage(
          text: 'Suppose ${pivot.label} is $linkA. Then ${wingA.label} cannot '
              'be $linkA, so it must be $z.',
          marks: [
            HintMark(
              cell: pivot,
              candidate: linkA,
              role: HintRole.pivot,
              emphasise: true,
            ),
            HintMark(
              cell: wingA,
              candidate: z,
              role: HintRole.solution,
              emphasise: true,
            ),
          ],
          links: [HintLink(from: pivot, to: wingA, candidate: linkA)],
        ),
        HintStage(
          text: 'Now suppose ${pivot.label} is $linkB instead. Then '
              '${wingB.label} must be $z.',
          marks: [
            HintMark(
              cell: pivot,
              candidate: linkB,
              role: HintRole.pivot,
              emphasise: true,
            ),
            HintMark(
              cell: wingB,
              candidate: z,
              role: HintRole.solution,
              emphasise: true,
            ),
          ],
          links: [HintLink(from: pivot, to: wingB, candidate: linkB)],
        ),
        HintStage(
          text: 'The pivot has no other option, so one of ${wingA.label} and '
              '${wingB.label} is $z either way.',
          marks: [
            for (final w in wings)
              HintMark(
                cell: w,
                candidate: z,
                role: HintRole.pivot,
                emphasise: true,
              ),
          ],
        ),
        HintStage(
          text: 'Any cell seeing both wings therefore cannot be $z: remove it '
              'from ${_cellList(step.eliminationCells)}.',
          marks: [
            for (final w in wings)
              HintMark(cell: w, candidate: z, role: HintRole.pivot),
            for (final e in step.eliminations)
              HintMark(
                cell: e.cell,
                candidate: e.value,
                role: HintRole.target,
                emphasise: true,
              ),
          ],
          links: [
            for (final e in step.eliminations)
              for (final w in wings)
                HintLink(
                  from: w,
                  to: e.cell,
                  candidate: z,
                  strong: false,
                ),
          ],
        ),
      ],
    );
  }

  static HintLesson? _xyzWing(SolverStep step) {
    if (step.cells.length < 3 || step.eliminations.isEmpty) return null;
    final z = step.eliminations.first.value;

    // The hinge is the cell with all three digits.
    Position? hinge;
    final wings = <Position>[];
    for (final cell in step.cells) {
      if (step.candidatesOf(cell).length == 3) {
        hinge ??= cell;
      } else {
        wings.add(cell);
      }
    }
    if (hinge == null || wings.length != 2) return null;

    return HintLesson(
      technique: step.name,
      headline: 'Remove $z from ${_cellList(step.eliminationCells)}',
      step: step,
      takeaway: 'An XYZ-Wing is an XY-Wing whose pivot also holds the shared '
          'digit — so the target must see all three cells, not just the wings.',
      stages: [
        HintStage(
          text: '${hinge.label} holds all three of '
              '${_numberList(step.candidatesOf(hinge))}. It is the hinge.',
          marks: [
            for (final v in step.candidatesOf(hinge))
              HintMark(cell: hinge, candidate: v, role: HintRole.pivot),
            HintMark(cell: hinge, role: HintRole.pivot, emphasise: true),
          ],
        ),
        HintStage(
          text: 'The wings ${_cellList(wings)} each hold two of them, and both '
              'include $z.',
          marks: [
            HintMark(cell: hinge, role: HintRole.pivot),
            for (final w in wings)
              for (final v in step.candidatesOf(w))
                HintMark(
                  cell: w,
                  candidate: v,
                  role: v == z ? HintRole.target : HintRole.pattern,
                ),
          ],
          links: [for (final w in wings) HintLink(from: hinge, to: w)],
        ),
        HintStage(
          text: 'Whichever digit the hinge takes, one of the three cells ends '
              'up being $z.',
          marks: [
            HintMark(cell: hinge, candidate: z, role: HintRole.pivot),
            for (final w in wings)
              HintMark(
                cell: w,
                candidate: z,
                role: HintRole.pivot,
                emphasise: true,
              ),
          ],
        ),
        HintStage(
          text: 'So a cell seeing all three cannot be $z: remove it from '
              '${_cellList(step.eliminationCells)}.',
          marks: [
            HintMark(cell: hinge, candidate: z, role: HintRole.pivot),
            for (final w in wings)
              HintMark(cell: w, candidate: z, role: HintRole.pivot),
            for (final e in step.eliminations)
              HintMark(
                cell: e.cell,
                candidate: e.value,
                role: HintRole.target,
                emphasise: true,
              ),
          ],
        ),
      ],
    );
  }

  static HintLesson? _wWing(SolverStep step) {
    if (step.cells.length < 2 || step.eliminations.isEmpty) return null;
    final z = step.eliminations.first.value;

    final pair = step.cells
        .where((c) => step.candidatesOf(c).length == 2)
        .take(2)
        .toList();
    if (pair.length != 2) return null;

    final digits = step.candidatesOf(pair.first).toList()..sort();
    final other = digits.firstWhere((v) => v != z, orElse: () => z);

    return HintLesson(
      technique: step.name,
      headline: 'Remove $z from ${_cellList(step.eliminationCells)}',
      step: step,
      takeaway: 'A W-Wing pairs two identical two-candidate cells with a strong '
          'link on one digit, forcing the other digit into one of them.',
      stages: [
        HintStage(
          text: '${pair[0].label} and ${pair[1].label} both hold exactly '
              '${_numberList(digits)}.',
          marks: [
            for (final c in pair)
              for (final v in step.candidatesOf(c))
                HintMark(cell: c, candidate: v, role: HintRole.pivot),
          ],
          links: [HintLink(from: pair[0], to: pair[1], candidate: z)],
        ),
        HintStage(
          text: 'Elsewhere, a line forces $other into one of the two — they '
              'cannot both be $other.',
          marks: [
            for (final c in pair)
              HintMark(
                cell: c,
                candidate: other,
                role: HintRole.pattern,
                emphasise: true,
              ),
          ],
        ),
        HintStage(
          text: 'So at least one of them is $z, and anything seeing both loses '
              'it: ${_cellList(step.eliminationCells)}.',
          marks: [
            for (final c in pair)
              HintMark(cell: c, candidate: z, role: HintRole.pivot),
            for (final e in step.eliminations)
              HintMark(
                cell: e.cell,
                candidate: e.value,
                role: HintRole.target,
                emphasise: true,
              ),
          ],
        ),
      ],
    );
  }

  static HintLesson? _remotePair(SolverStep step) {
    if (step.cells.length < 2 || step.values.length < 2) return null;

    return HintLesson(
      technique: step.name,
      headline: 'Remove ${_numberList(step.eliminatedValues)} from '
          '${_cellList(step.eliminationCells)}',
      step: step,
      takeaway: 'A Remote Pair is a chain of identical two-candidate cells. '
          'They alternate, so cells an even number of steps apart hold opposite '
          'digits.',
      stages: [
        HintStage(
          text: 'These cells all hold exactly ${_numberList(step.values)}: '
              '${_cellList(step.cells)}.',
          marks: [
            for (final c in step.cells)
              for (final v in step.candidatesOf(c))
                HintMark(cell: c, candidate: v, role: HintRole.pivot),
          ],
          links: _gridLinks(step.cells, null),
        ),
        HintStage(
          text: 'Because each pair of neighbours sees each other, the digits '
              'alternate along the chain.',
          marks: [
            for (final c in step.cells)
              HintMark(cell: c, role: HintRole.pivot, emphasise: true),
          ],
          links: _gridLinks(step.cells, null),
        ),
        HintStage(
          text: 'The two ends therefore differ, so a cell seeing both loses '
              'both digits: ${_eliminationSentence(step)}.',
          marks: [
            for (final e in step.eliminations)
              HintMark(
                cell: e.cell,
                candidate: e.value,
                role: HintRole.target,
                emphasise: true,
              ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // UNIQUENESS
  // ===========================================================================

  static HintLesson? _uniqueness(SolverStep step) {
    if (step.cells.length < 4 || step.values.length < 2) return null;
    final digits = _numberList(step.values.take(2));

    return HintLesson(
      technique: step.name,
      headline: 'Remove ${_numberList(step.eliminatedValues)} from '
          '${_cellList(step.eliminationCells)}',
      step: step,
      takeaway: 'Uniqueness arguments rest on the puzzle having exactly one '
          'solution. A rectangle of the same two digits across two boxes could '
          'be swapped, giving two solutions — so it must be broken.',
      stages: [
        HintStage(
          text: 'Look at the rectangle ${_cellList(step.cells)}, spanning two '
              'rows, two columns and two boxes.',
          marks: [
            for (final c in step.cells)
              HintMark(cell: c, role: HintRole.pattern, emphasise: true),
          ],
        ),
        HintStage(
          text: 'All four corners can take $digits.',
          marks: [
            for (final c in step.cells)
              for (final v in step.values.take(2))
                if (step.candidatesOf(c).contains(v))
                  HintMark(cell: c, candidate: v, role: HintRole.pivot),
          ],
        ),
        HintStage(
          text: 'If those four cells held only $digits, the two arrangements '
              'would both work — and this puzzle has one solution, so that '
              'cannot happen.',
          marks: [
            for (final c in step.cells)
              HintMark(cell: c, role: HintRole.pivot, emphasise: true),
          ],
        ),
        HintStage(
          text: 'Avoiding the deadly pattern forces: '
              '${_eliminationSentence(step)}.',
          marks: [
            for (final e in step.eliminations)
              HintMark(
                cell: e.cell,
                candidate: e.value,
                role: HintRole.target,
                emphasise: true,
              ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // ALMOST LOCKED SETS
  // ===========================================================================

  static HintLesson? _als(SolverStep step) {
    if (step.alses.length < 2 || step.eliminations.isEmpty) return null;

    final a = step.alses[0];
    final b = step.alses[1];
    final z = step.eliminations.first.value;
    final shared = a.candidates.intersection(b.candidates)
      ..removeWhere((v) => v == z);
    final x = shared.isEmpty ? null : shared.first;

    return HintLesson(
      technique: step.name,
      headline: 'Remove $z from ${_cellList(step.eliminationCells)}',
      step: step,
      takeaway: 'An Almost Locked Set is n cells holding n+1 digits: fix one '
          'digit and the rest lock. Two ALSs sharing a digit constrain each '
          'other.',
      stages: [
        HintStage(
          text: 'Set A is ${_cellList(a.cells)} holding '
              '${_numberList(a.candidates)} — ${a.cells.length} cells for '
              '${a.candidates.length} digits.',
          marks: [
            for (final c in a.cells)
              for (final v in step.candidatesOf(c))
                HintMark(cell: c, candidate: v, role: HintRole.pivot),
          ],
        ),
        HintStage(
          text: 'Set B is ${_cellList(b.cells)} holding '
              '${_numberList(b.candidates)}.',
          marks: [
            for (final c in a.cells)
              HintMark(cell: c, role: HintRole.context),
            for (final c in b.cells)
              for (final v in step.candidatesOf(c))
                HintMark(cell: c, candidate: v, role: HintRole.pattern),
          ],
        ),
        HintStage(
          text: x == null
              ? 'The two sets share a digit, which cannot be in both.'
              : 'They share $x, and only one of the two sets can hold it.',
          marks: [
            for (final c in [...a.cells, ...b.cells])
              if (x != null && step.candidatesOf(c).contains(x))
                HintMark(
                  cell: c,
                  candidate: x,
                  role: HintRole.pivot,
                  emphasise: true,
                ),
          ],
        ),
        HintStage(
          text: 'Whichever set gives it up locks, and either way $z ends up '
              'inside one of them — so $z goes from '
              '${_cellList(step.eliminationCells)}.',
          marks: [
            for (final c in [...a.cells, ...b.cells])
              if (step.candidatesOf(c).contains(z))
                HintMark(cell: c, candidate: z, role: HintRole.pivot),
            for (final e in step.eliminations)
              HintMark(
                cell: e.cell,
                candidate: e.value,
                role: HintRole.target,
                emphasise: true,
              ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // FORCING NETS AND GUESSES
  // ===========================================================================

  /// Forcing nets branch, so they are summarised rather than walked.
  ///
  /// Pretending a net is a single line of reasoning would misteach it: the whole
  /// point is that *several* consequences converge. Better to name the technique
  /// honestly, show the cells involved, and say what it proves.
  static HintLesson? _forcingNet(SolverStep step) {
    if (step.placements.isEmpty && step.eliminations.isEmpty) return null;

    final isVerity = step.type.contains('VERITY');
    final start = step.chains.isEmpty || step.chains.first.isEmpty
        ? null
        : step.chains.first.first;

    final involved = <Position>{
      for (final chain in step.chains)
        for (final node in chain) node.cell,
    }.toList();

    final stages = <HintStage>[
      HintStage(
        text: 'This is a forcing net — not a single chain but several lines of '
            'consequence that have to be followed together.',
        marks: [
          for (final cell in involved.take(24))
            HintMark(cell: cell, role: HintRole.context),
        ],
      ),
    ];

    if (start != null) {
      stages.add(
        HintStage(
          text: 'It starts from ${start.cell.label} and traces what would '
              'follow across ${involved.length} cells.',
          marks: [
            HintMark(
              cell: start.cell,
              candidate: start.value,
              role: HintRole.pivot,
              emphasise: true,
            ),
            for (final cell in involved.take(24))
              if (cell != start.cell)
                HintMark(cell: cell, role: HintRole.context),
          ],
        ),
      );
    }

    if (step.placements.isNotEmpty) {
      final placement = step.placements.first;
      stages.add(
        HintStage(
          text: isVerity
              ? 'Every branch ends with the same conclusion, so '
                  '${placement.cell.label} must be ${placement.value}.'
              : 'Any other value leads to a contradiction, so '
                  '${placement.cell.label} must be ${placement.value}.',
          marks: [
            HintMark(
              cell: placement.cell,
              candidate: placement.value,
              role: HintRole.solution,
              emphasise: true,
            ),
          ],
        ),
      );
    } else {
      stages.add(
        HintStage(
          text: 'Every branch rules the same candidate out, so '
              '${_eliminationSentence(step)}.',
          marks: [
            for (final e in step.eliminations)
              HintMark(
                cell: e.cell,
                candidate: e.value,
                role: HintRole.target,
                emphasise: true,
              ),
          ],
        ),
      );
    }

    return HintLesson(
      technique: step.name,
      headline: step.placements.isNotEmpty
          ? 'Place ${step.placements.first.value} in '
              '${step.placements.first.cell.label}'
          : 'Remove ${_numberList(step.eliminatedValues)} from '
              '${_cellList(step.eliminationCells)}',
      step: step,
      takeaway: 'Forcing nets are near the limit of hand solving. If a puzzle '
          'needs one, it is fair to treat this cell as given and carry on.',
      stages: stages,
    );
  }

  /// The solver found nothing and consulted the solution.
  ///
  /// Said plainly rather than dressed up as a technique — claiming there is
  /// logic here when there is none would teach the player to look for something
  /// that is not there.
  static HintLesson? _bruteForce(SolverStep step) {
    if (step.placements.isEmpty) return null;
    final placement = step.placements.first;

    return HintLesson(
      technique: 'No technique available',
      headline: 'Place ${placement.value} in ${placement.cell.label}',
      step: step,
      isSpecific: false,
      takeaway: 'Nothing was missed here — this position is genuinely past what '
          'the solver can justify with a named technique.',
      stages: [
        HintStage(
          text: 'No standard technique applies to this position, so there is no '
              'reasoning to follow.',
          marks: [
            HintMark(
              cell: placement.cell,
              role: HintRole.pivot,
              emphasise: true,
            ),
          ],
        ),
        HintStage(
          text: '${placement.cell.label} is ${placement.value}. Take it and '
              'carry on — the position should open up again from here.',
          marks: [
            HintMark(
              cell: placement.cell,
              candidate: placement.value,
              role: HintRole.solution,
              emphasise: true,
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // GENERIC CHAIN WALKER
  // ===========================================================================

  /// Narrates any step that carries a chain, node by node.
  ///
  /// One implementation covers nice loops, AICs, forcing chains and X/XY
  /// chains — they differ in how the solver *found* the chain, not in how it
  /// reads once found.
  static HintLesson? _chain(SolverStep step) {
    final chain = step.chains.firstWhere(
      (c) => c.length >= 2,
      orElse: () => const [],
    );
    if (chain.length < 2) return null;
    if (step.eliminations.isEmpty && step.placements.isEmpty) return null;

    final start = chain.first;
    final stages = <HintStage>[
      HintStage(
        text: 'Start at ${start.cell.label} and suppose it is not '
            '${start.value}.',
        marks: [
          HintMark(
            cell: start.cell,
            candidate: start.value,
            role: HintRole.pivot,
            emphasise: true,
          ),
        ],
      ),
    ];

    // Walk the chain, adding a stage per link and keeping earlier nodes visible
    // so the player can see the reasoning accumulate.
    final travelled = <HintMark>[
      HintMark(
        cell: start.cell,
        candidate: start.value,
        role: HintRole.pattern,
      ),
    ];
    final links = <HintLink>[];

    for (var i = 1; i < chain.length && i <= 10; i++) {
      final previous = chain[i - 1];
      final node = chain[i];

      links.add(
        HintLink(
          from: previous.cell,
          to: node.cell,
          candidate: node.value,
          strong: previous.strong,
        ),
      );

      final sentence = previous.strong
          ? 'Then ${node.cell.label} must be ${node.value}.'
          : 'Since ${previous.cell.label} is ${previous.value}, '
              '${node.cell.label} cannot be ${node.value}.';

      stages.add(
        HintStage(
          text: sentence,
          marks: [
            ...travelled,
            HintMark(
              cell: node.cell,
              candidate: node.value,
              role: previous.strong ? HintRole.solution : HintRole.target,
              emphasise: true,
            ),
          ],
          links: List.of(links),
        ),
      );

      travelled.add(
        HintMark(
          cell: node.cell,
          candidate: node.value,
          role: HintRole.pattern,
        ),
      );
    }

    if (step.placements.isNotEmpty) {
      final placement = step.placements.first;
      stages.add(
        HintStage(
          text: 'Every branch of the chain leads to the same place, so '
              '${placement.cell.label} must be ${placement.value}.',
          marks: [
            ...travelled,
            HintMark(
              cell: placement.cell,
              candidate: placement.value,
              role: HintRole.solution,
              emphasise: true,
            ),
          ],
          links: links,
        ),
      );
    } else {
      stages.add(
        HintStage(
          text: 'Following the chain to the end contradicts the starting guess, '
              'so ${_eliminationSentence(step)}.',
          marks: [
            ...travelled,
            for (final e in step.eliminations)
              HintMark(
                cell: e.cell,
                candidate: e.value,
                role: HintRole.target,
                emphasise: true,
              ),
          ],
          links: links,
        ),
      );
    }

    return HintLesson(
      technique: step.name,
      headline: step.placements.isNotEmpty
          ? 'Place ${step.placements.first.value} in '
              '${step.placements.first.cell.label}'
          : 'Remove ${_numberList(step.eliminatedValues)} from '
              '${_cellList(step.eliminationCells)}',
      step: step,
      takeaway: 'A chain alternates strong links ("one of these two must be it") '
          'with weak links ("these two cannot both be it"). Follow it far enough '
          'and the starting assumption contradicts itself.',
      stages: stages,
    );
  }

  // ===========================================================================
  // FALLBACK
  // ===========================================================================

  /// Used when the technique has no dedicated walkthrough.
  ///
  /// Still points at the real cells and digits — vague is acceptable, wrong is
  /// not, so this states only what the step data guarantees.
  static HintLesson _generic(SolverStep step) {
    final stages = <HintStage>[];

    if (step.cells.isNotEmpty) {
      stages.add(
        HintStage(
          text: '${step.name} uses ${_cellList(step.cells)}'
              '${step.values.isEmpty ? '' : ' and the '
                  'digit${step.values.length == 1 ? '' : 's'} '
                  '${_numberList(step.values)}'}.',
          marks: [
            for (final c in step.cells)
              HintMark(cell: c, role: HintRole.pattern, emphasise: true),
          ],
        ),
      );
    }

    if (step.placements.isNotEmpty) {
      final placement = step.placements.first;
      stages.add(
        HintStage(
          text: 'It concludes that ${placement.cell.label} must be '
              '${placement.value}.',
          marks: [
            HintMark(
              cell: placement.cell,
              candidate: placement.value,
              role: HintRole.solution,
              emphasise: true,
            ),
          ],
        ),
      );
    } else if (step.eliminations.isNotEmpty) {
      stages.add(
        HintStage(
          text: 'It concludes that ${_eliminationSentence(step)}.',
          marks: [
            for (final e in step.eliminations)
              HintMark(
                cell: e.cell,
                candidate: e.value,
                role: HintRole.target,
                emphasise: true,
              ),
          ],
        ),
      );
    }

    if (stages.isEmpty) {
      stages.add(
        HintStage(text: step.notation.isEmpty ? step.name : step.notation),
      );
    }

    return HintLesson(
      technique: step.name,
      headline: step.placements.isNotEmpty
          ? 'Place ${step.placements.first.value} in '
              '${step.placements.first.cell.label}'
          : 'Remove ${_numberList(step.eliminatedValues)} from '
              '${_cellList(step.eliminationCells)}',
      step: step,
      isSpecific: false,
      takeaway: 'This is an advanced technique. The solver notation is: '
          '${step.notation}',
      stages: stages,
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  /// "r4c7", "r4c7 and r6c2", "r4c7, r6c2 and r8c9".
  static String _cellList(Iterable<Position> cells) {
    final unique = <Position>[];
    for (final cell in cells) {
      if (!unique.contains(cell)) unique.add(cell);
    }
    return _join(unique.map((c) => c.label).toList());
  }

  static String _numberList(Iterable<int> values) {
    final sorted = values.toSet().toList()..sort();
    return _join(sorted.map((v) => '$v').toList());
  }

  static String _houseList(Iterable<House> houses) =>
      _join(houses.map((h) => h.label).toList());

  /// Uppercases the first letter. Used for house labels that open a sentence —
  /// "Box 6 must contain..." reads correctly, whereas cell labels like r9c3 must
  /// stay lowercase.
  static String _capitalise(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  static String _join(List<String> parts) {
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  }

  /// "r7c2 loses 3", or a list when several cells are affected.
  static String _eliminationSentence(SolverStep step) {
    final byCell = <Position, List<int>>{};
    for (final e in step.eliminations) {
      byCell.putIfAbsent(e.cell, () => []).add(e.value);
    }

    final parts = byCell.entries
        .map((e) => '${e.key.label} loses ${_numberList(e.value)}')
        .toList();

    return _join(parts);
  }

  /// "r3c1 holds 2 and 5, r3c9 holds 2 and 7".
  static String _cellCandidateSentence(
    SolverStep step,
    Iterable<Position> cells,
  ) {
    return _join([
      for (final cell in cells)
        '${cell.label} holds ${_numberList(step.candidatesOf(cell))}',
    ]);
  }

  /// The house of [type] containing every cell, or null if they are spread out.
  static House? _sharedHouse(List<Position> cells, HouseType type) {
    if (cells.isEmpty) return null;

    int keyOf(Position cell) {
      switch (type) {
        case HouseType.row:
          return cell.row;
        case HouseType.col:
          return cell.col;
        case HouseType.box:
          return cell.boxIndex;
      }
    }

    final first = keyOf(cells.first);
    for (final cell in cells) {
      if (keyOf(cell) != first) return null;
    }
    return House(type, first + 1);
  }

  /// The house in which [value] has only one possible cell — what makes a
  /// hidden single hidden. HoDoKu does not report it, so it is derived.
  static House? _hiddenSingleHouse(SolverStep step, Position cell, int value) {
    for (final house in House.of(cell)) {
      var spots = 0;
      for (final other in house.cells) {
        if (step.valueAt(other) != 0) continue;
        if (step.candidatesOf(other).contains(value)) spots++;
      }
      if (spots == 1) return house;
    }
    return null;
  }

  static House? _houseWithOneEmptyCell(SolverStep step, Position cell) {
    for (final house in House.of(cell)) {
      final empty = house.cells.where((c) => step.valueAt(c) == 0).length;
      if (empty == 1) return house;
    }
    return null;
  }

  static List<int> _digitsIn(SolverStep step, House house) {
    final digits = <int>[];
    for (final cell in house.cells) {
      final value = step.valueAt(cell);
      if (value != 0) digits.add(value);
    }
    return digits;
  }

  /// For each digit this cell cannot take, a cell that already holds it.
  ///
  /// This is what lets a Naked Single explanation say *why* each digit is out,
  /// rather than asserting that it is.
  static Map<int, CandidateRef> _blockers(
    SolverStep step,
    Position cell,
    int keep,
  ) {
    final out = <int, CandidateRef>{};
    for (var value = 1; value <= 9; value++) {
      if (value == keep) continue;
      final blocker = _findBlocker(step, cell, value);
      if (blocker != null) out[value] = CandidateRef(blocker, value);
    }
    return out;
  }

  /// A filled cell sharing a house with [cell] that already holds [value].
  static Position? _findBlocker(SolverStep step, Position cell, int value) {
    for (final house in House.of(cell)) {
      for (final other in house.cells) {
        if (other == cell) continue;
        if (step.valueAt(other) == value) return other;
      }
    }
    return null;
  }

  /// Groups blocked digits by the cell that blocks them, so the sentence reads
  /// "2 and 5 in r5c1" rather than listing eight separate facts.
  static String _blockerSentence(Map<int, CandidateRef> blockers) {
    final byBlocker = <String, List<int>>{};
    for (final entry in blockers.entries) {
      byBlocker.putIfAbsent(entry.value.cell.label, () => []).add(entry.key);
    }

    final parts = byBlocker.entries
        .take(5)
        .map((e) => '${_numberList(e.value)} in ${e.key}')
        .toList();

    return 'Its neighbours already account for ${_join(parts)}'
        '${byBlocker.length > 5 ? ', among others' : ''}.';
  }

  /// Links joining consecutive pattern cells, for fish and single-digit chains.
  static List<HintLink> _gridLinks(List<Position> cells, int? candidate) {
    if (cells.length < 2) return const [];
    return [
      for (var i = 0; i < cells.length - 1; i++)
        HintLink(from: cells[i], to: cells[i + 1], candidate: candidate),
    ];
  }
}
