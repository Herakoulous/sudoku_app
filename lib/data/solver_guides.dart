import 'package:flutter/material.dart';

import '../models/guide_lesson.dart';

/// The classroom's reading guides: the fundamentals every solver needs that are
/// not a single named technique.
///
/// Written to match this app's board — it has two kinds of pencil mark, "Side"
/// notes along the edges and "Center" notes stacked in the middle, so the
/// notation guide teaches exactly those.
class SolverGuides {
  SolverGuides._();

  static const List<GuideLesson> all = [
    _readTheGrid,
    _pencilMarks,
    _scanning,
    _routine,
    _habits,
  ];

  static GuideLesson? byId(String id) {
    for (final guide in all) {
      if (guide.id == id) return guide;
    }
    return null;
  }

  // ===========================================================================

  static const _readTheGrid = GuideLesson(
    id: 'guide_read_the_grid',
    title: 'Reading the grid',
    summary: 'The vocabulary — houses, peers, and the one rule everything rests on.',
    icon: Icons.grid_on_rounded,
    color: Color(0xFF56A8E8),
    blocks: [
      GuideText(
        'Every technique you will ever learn is built on one rule, so it is '
        'worth stating plainly: each row, each column, and each 3×3 box must '
        'contain the digits 1 to 9 exactly once.',
      ),
      GuideHeading('The three houses'),
      GuideText(
        'A "house" is any group of nine cells that has to hold all nine digits '
        'once. There are three kinds — the 9 rows, the 9 columns, and the 9 '
        'boxes — 27 houses in all. Almost every deduction comes from asking '
        'what a single house still needs and where it can go.',
      ),
      GuideHeading('Peers and "seeing"'),
      GuideText(
        'Two cells are peers if they share a house — same row, same column, or '
        'same box. A cell "sees" every one of its peers, and no two peers can '
        'hold the same digit. Each cell has 20 peers: 8 in its row, 8 in its '
        'column, and 4 more in its box.',
      ),
      GuideCallout(
        tone: GuideTone.key,
        title: 'THE ONE IDEA',
        text: 'A digit placed in a cell is banned from all 20 cells that see '
            'it. Nearly every step in sudoku is just this rule, applied '
            'somewhere clever.',
      ),
      GuideHeading('Candidates'),
      GuideText(
        'A candidate is a digit that could still legally go in a cell — one '
        'that none of its peers has taken yet. When a cell has just one '
        'candidate left, that digit must go there. Keeping track of candidates '
        'is what pencil marks are for, which is the next guide.',
      ),
    ],
  );

  // ===========================================================================

  static const _pencilMarks = GuideLesson(
    id: 'guide_pencil_marks',
    title: 'Pencil marks: noting cells the right way',
    summary: 'Side notes vs. centre notes, and when to use each.',
    icon: Icons.edit_note_rounded,
    color: Color(0xFFE0A93B),
    blocks: [
      GuideText(
        'Pencil marks are how you record what a cell could be so you do not '
        'have to keep it all in your head. This app gives you two kinds, and '
        'using them for different jobs is what keeps a grid readable.',
      ),
      GuideHeading('Centre notes — a cell\'s candidates'),
      GuideText(
        'Tap "Center" and the digits stack in the middle of the cell. Use these '
        'for the full list of what a cell can still be. When a cell drops to a '
        'single centre note, that is a naked single — you can promote it '
        'straight to the answer.',
      ),
      GuideDemo(
        GuideDemoKind.centreNotes,
        caption: 'Centre notes: this cell can still be 2, 5 or 8.',
      ),
      GuideHeading('Side notes — scanning one digit'),
      GuideText(
        'Tap "Side" and the digits sit along the top and bottom edges. These '
        'are lighter marks, best for tracking where a single digit can go '
        'inside a box or line while you scan — the Snyder style: mark a digit '
        'only in the two or three cells of a box where it still fits.',
      ),
      GuideDemo(
        GuideDemoKind.notesSideBySide,
        caption: 'Same cell, two jobs: edge marks for scanning, centre marks '
            'for the full candidate list.',
      ),
      GuideCallout(
        tone: GuideTone.warning,
        title: 'KEEP THEM HONEST',
        text: 'A pencil mark is only useful if it is true. The moment you place '
            'a digit, remove it from every peer\'s notes. One stale mark and '
            'you will trust a candidate that is already dead.',
      ),
      GuideDosDonts(
        dos: [
          'Mark a house fully before hunting pairs and triples in it.',
          'Use centre notes for candidates, side notes for a single-digit scan.',
          'Clear a candidate the instant a placement rules it out.',
        ],
        donts: [
          'Pencil-mark the whole grid before you have taken the easy singles.',
          'Mix both note types for the same purpose — it turns to noise.',
          'Leave marks behind after you write a digit in.',
        ],
      ),
      GuideCallout(
        tone: GuideTone.tip,
        title: 'DON\'T MARK TOO EARLY',
        text: 'Scan for the free singles first. Filling candidates into a cell '
            'you could have solved by eye is wasted work — and a cluttered grid '
            'hides the very patterns you are looking for.',
      ),
    ],
  );

  // ===========================================================================

  static const _scanning = GuideLesson(
    id: 'guide_scanning',
    title: 'Scanning without marks',
    summary: 'Cross-hatching and counting to place digits by eye.',
    icon: Icons.center_focus_strong_rounded,
    color: Color(0xFF5DD39E),
    blocks: [
      GuideText(
        'Before you pencil-mark anything, you can place a surprising number of '
        'digits just by looking. Two habits do most of the work.',
      ),
      GuideHeading('Cross-hatching'),
      GuideText(
        'Pick a digit and a box. Any row or column that already holds that '
        'digit "crosses out" the cells it passes through in the box. If that '
        'leaves the box only one empty cell for the digit, it goes there — a '
        'hidden single.',
      ),
      GuideDemo(
        GuideDemoKind.houseHiddenSingle,
        caption: 'Only one cell in this row can still take the 4 — the rest '
            'are blocked. That is a hidden single.',
      ),
      GuideHeading('Counting a house'),
      GuideText(
        'When a row, column, or box has just one or two empty cells, name the '
        'digits it is missing and place them. The last empty cell in a house is '
        'a full house — the fastest placement in the game.',
      ),
      GuideCallout(
        tone: GuideTone.tip,
        title: 'WORK THE CROWDED AREAS',
        text: 'Digits that already appear many times, and boxes that are nearly '
            'full, give up their secrets first. Start where the grid is '
            'busiest.',
      ),
      GuideText(
        'Scanning is not just for the opening. Every time you place a digit, '
        'scan the row, column, and box it just joined — one placement often '
        'triggers the next.',
      ),
    ],
  );

  // ===========================================================================

  static const _routine = GuideLesson(
    id: 'guide_routine',
    title: 'A solving routine',
    summary: 'The order to work in so you never reach for a hard tool too soon.',
    icon: Icons.format_list_numbered_rounded,
    color: Color(0xFFF08A43),
    blocks: [
      GuideText(
        'Good solvers are not just pattern-spotters — they are tidy. They work '
        'in an order that squeezes every easy placement out of the grid before '
        'reaching for anything clever. A rough loop:',
      ),
      GuideBullets([
        'Scan for singles — full houses, naked singles, hidden singles.',
        'When scanning dries up, pencil in candidates for the tight houses.',
        'Look for locked candidates (pointing and claiming) to trim marks.',
        'Then subsets — naked and hidden pairs and triples.',
        'Only then the single-digit patterns and chains.',
        'After every placement or elimination, go back to the top.',
      ]),
      GuideCallout(
        tone: GuideTone.key,
        title: 'ALWAYS RE-SCAN',
        text: 'The most common mistake is pressing on with a hard technique '
            'when a placement you just made has opened up three easy singles. '
            'One digit changes the whole board — start over from the cheapest '
            'step each time.',
      ),
      GuideHeading('Cheap before expensive'),
      GuideText(
        'The techniques in this classroom are ordered from cheapest to most '
        'expensive to spot. That order is the routine: a hidden single costs a '
        'glance, an XY-chain costs real work. Never pay for the second when the '
        'first is still on the board.',
      ),
    ],
  );

  // ===========================================================================

  static const _habits = GuideLesson(
    id: 'guide_habits',
    title: 'Habits of a good solver',
    summary: 'Never guess, stay tidy, and how to get unstuck.',
    icon: Icons.self_improvement_rounded,
    color: Color(0xFFB07CE8),
    blocks: [
      GuideHeading('Never guess'),
      GuideText(
        'A proper sudoku has exactly one solution reachable by logic. If you '
        'find yourself guessing and hoping, there is a deduction you have '
        'missed — stop and look again. Guessing may finish this grid, but it '
        'teaches you nothing and falls apart on the next one.',
      ),
      GuideCallout(
        tone: GuideTone.warning,
        title: 'CHECK BEFORE YOU WRITE',
        text: 'A wrong digit written as if it were certain poisons everything '
            'that follows, and it can be a long way back before you notice. '
            'Make sure each placement is forced, not just likely.',
      ),
      GuideHeading('Getting unstuck'),
      GuideText(
        'When the board goes quiet, change what you are looking at:',
      ),
      GuideBullets([
        'Pick one digit and track it across all nine boxes.',
        'Find every cell that is down to two candidates — pairs power most '
            'mid-level techniques.',
        'Re-read the houses that are nearly full; a hidden single may be '
            'hiding under other marks.',
        'Take a break. Fresh eyes find in seconds what tired ones miss for '
            'minutes.',
      ]),
      GuideHeading('Stay tidy'),
      GuideText(
        'Consistent, up-to-date pencil marks are the difference between a '
        'grid you can read and one that fights you. Keep them honest, keep '
        'them in the right place, and the patterns will show themselves.',
      ),
      GuideCallout(
        tone: GuideTone.tip,
        title: 'IT IS NOT A RACE',
        text: 'Speed comes from recognising patterns, and recognition comes '
            'from careful practice. Solve accurately first; fast follows on '
            'its own.',
      ),
    ],
  );
}
