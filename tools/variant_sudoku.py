"""
Variant sudoku core: constraint model, propagating solver, and solution counter.

This is the engine both the auditor and the generator run on. It has to be
*exact* -- a generator built on a solver that accepts too much will happily
produce puzzles with multiple solutions, which is the single worst defect a
puzzle can ship with.

Cells are addressed as (row, col), both 0-based. Digits are 1..9, 0 means empty.
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field
from itertools import combinations
from typing import Iterable, Sequence

ALL_DIGITS = frozenset(range(1, 10))
FULL_MASK = 0b1111111110  # bits 1..9


# ---------------------------------------------------------------------------
# CONSTRAINTS
# ---------------------------------------------------------------------------

KROPKI_WHITE = "KROPKI_WHITE"
KROPKI_BLACK = "KROPKI_BLACK"
THERMO = "THERMO"
XV_X = "XV_X"
XV_V = "XV_V"
GERMAN_WHISPERS = "GERMAN_WHISPERS"
SANDWICH = "SANDWICH"

PAIR_TYPES = {KROPKI_WHITE, KROPKI_BLACK, XV_X, XV_V, GERMAN_WHISPERS}


def pair_allows(kind: str, a: int, b: int) -> bool:
    """Whether digits a, b may sit either side of a `kind` marker, in order."""
    if kind == KROPKI_WHITE:
        return abs(a - b) == 1
    if kind == KROPKI_BLACK:
        return a == 2 * b or b == 2 * a
    if kind == XV_V:
        return a + b == 5
    if kind == XV_X:
        return a + b == 10
    if kind == GERMAN_WHISPERS:
        return abs(a - b) >= 5
    raise ValueError(f"not a pair constraint: {kind}")


@dataclass(frozen=True)
class Constraint:
    kind: str

    # Pair constraints (kropki, XV, whispers) use the two cells.
    cells: tuple[tuple[int, int], ...] = ()

    # Sandwich clues.
    line_is_row: bool = True
    line_index: int = 0
    total: int = 0

    def as_dart_fields(self) -> dict:
        """Field values matching the app's VariantConstraint."""
        if self.kind == SANDWICH:
            return {
                "row1": self.line_index if self.line_is_row else 0,
                "col1": 0 if self.line_is_row else self.line_index,
                "row2": self.line_index if self.line_is_row else 8,
                "col2": 8 if self.line_is_row else self.line_index,
            }
        (r1, c1), (r2, c2) = self.cells[0], self.cells[-1]
        return {"row1": r1, "col1": c1, "row2": r2, "col2": c2}


# Digits that may sit strictly between the 1 and the 9 of a sandwich line.
_BETWEEN_DIGITS = [2, 3, 4, 5, 6, 7, 8]

# gap length -> set of achievable sums, so an impossible clue is rejected at
# once instead of after a full line assignment.
_SANDWICH_SUMS: dict[int, frozenset[int]] = {
    gap: frozenset(
        sum(combo) for combo in combinations(_BETWEEN_DIGITS, gap)
    )
    for gap in range(0, 8)
}
_SANDWICH_SUMS[0] = frozenset({0})


def sandwich_total(line: Sequence[int]) -> int | None:
    """Sum strictly between 1 and 9 in a complete line, or None if incomplete."""
    if 0 in line:
        return None
    i, j = line.index(1), line.index(9)
    lo, hi = min(i, j), max(i, j)
    return sum(line[lo + 1 : hi])


# ---------------------------------------------------------------------------
# PUZZLE
# ---------------------------------------------------------------------------


@dataclass
class VariantPuzzle:
    grid: list[list[int]]
    constraints: list[Constraint] = field(default_factory=list)

    # Kropki and XV are conventionally drawn with *every* marker shown, so the
    # absence of a dot is itself information: those two cells are neither
    # consecutive nor in a 2:1 ratio. Puzzles that omit markers are far weaker
    # and often not unique.
    negative_kropki: bool = False
    negative_xv: bool = False

    def clone_grid(self) -> list[list[int]]:
        return [row[:] for row in self.grid]

    @property
    def given_count(self) -> int:
        return sum(1 for r in range(9) for c in range(9) if self.grid[r][c])


# ---------------------------------------------------------------------------
# SOLVER
# ---------------------------------------------------------------------------


class VariantSolver:
    """
    Backtracking search with arc-consistency propagation.

    Propagation matters more here than in classic sudoku: a kropki grid with no
    givens at all is unsolvable in reasonable time by naive backtracking, but
    falls out quickly once dot constraints prune candidates.
    """

    def __init__(self, puzzle: VariantPuzzle):
        self.puzzle = puzzle
        self.pairs: dict[tuple[int, int], list[tuple[tuple[int, int], str]]] = {}
        self.thermos: list[tuple[tuple[int, int], ...]] = []
        self.sandwiches: list[Constraint] = []

        # Cell -> the neighbours it is *not* allowed to relate to, used for the
        # negative constraint on undotted adjacencies.
        for con in puzzle.constraints:
            if con.kind in PAIR_TYPES:
                a, b = con.cells[0], con.cells[1]
                self.pairs.setdefault(a, []).append((b, con.kind))
                self.pairs.setdefault(b, []).append((a, con.kind))
            elif con.kind == THERMO:
                self.thermos.append(con.cells)
            elif con.kind == SANDWICH:
                self.sandwiches.append(con)

        self.marked_pairs = {
            frozenset((con.cells[0], con.cells[1]))
            for con in puzzle.constraints
            if con.kind in PAIR_TYPES
        }

    # -- helpers ---------------------------------------------------------

    @staticmethod
    def _peers(r: int, c: int) -> Iterable[tuple[int, int]]:
        for i in range(9):
            if i != c:
                yield (r, i)
            if i != r:
                yield (i, c)
        br, bc = (r // 3) * 3, (c // 3) * 3
        for i in range(br, br + 3):
            for j in range(bc, bc + 3):
                if (i, j) != (r, c):
                    yield (i, j)

    @staticmethod
    def _orthogonal(r: int, c: int) -> Iterable[tuple[int, int]]:
        if r > 0:
            yield (r - 1, c)
        if r < 8:
            yield (r + 1, c)
        if c > 0:
            yield (r, c - 1)
        if c < 8:
            yield (r, c + 1)

    def _negative_kinds(self, a, b) -> list[str]:
        """Pair relations forbidden between two adjacent, unmarked cells."""
        if frozenset((a, b)) in self.marked_pairs:
            return []

        kinds = []
        if self.puzzle.negative_kropki:
            kinds += [KROPKI_WHITE, KROPKI_BLACK]
        if self.puzzle.negative_xv:
            kinds += [XV_V, XV_X]
        return kinds

    # -- propagation -----------------------------------------------------

    def _initial_candidates(self) -> list[list[set[int]]] | None:
        cands = [
            [
                {self.puzzle.grid[r][c]} if self.puzzle.grid[r][c] else set(ALL_DIGITS)
                for c in range(9)
            ]
            for r in range(9)
        ]

        # Thermometers bound each cell by its position along the chain: the nth
        # cell from the bulb is at least n+1 and at most 9-(len-1-n).
        for cells in self.thermos:
            length = len(cells)
            for i, (r, c) in enumerate(cells):
                lo, hi = i + 1, 9 - (length - 1 - i)
                cands[r][c] &= set(range(lo, hi + 1))
                if not cands[r][c]:
                    return None

        return cands if self._propagate(cands) else None

    def _propagate(self, cands: list[list[set[int]]]) -> bool:
        """Runs to fixpoint. False means a contradiction was reached."""
        changed = True
        while changed:
            changed = False

            # --- singles eliminate from peers ---
            for r in range(9):
                for c in range(9):
                    if len(cands[r][c]) == 0:
                        return False
                    if len(cands[r][c]) != 1:
                        continue
                    value = next(iter(cands[r][c]))
                    for (pr, pc) in self._peers(r, c):
                        if value in cands[pr][pc]:
                            cands[pr][pc].discard(value)
                            if not cands[pr][pc]:
                                return False
                            changed = True

            # --- hidden singles ---
            for unit in self._units():
                for digit in ALL_DIGITS:
                    spots = [(r, c) for (r, c) in unit if digit in cands[r][c]]
                    if not spots:
                        if not any(cands[r][c] == {digit} for (r, c) in unit):
                            return False
                    elif len(spots) == 1:
                        r, c = spots[0]
                        if len(cands[r][c]) > 1:
                            cands[r][c] = {digit}
                            changed = True

            # --- marked pair constraints ---
            for a, links in self.pairs.items():
                ar, ac = a
                for b, kind in links:
                    br_, bc_ = b
                    viable = {
                        x
                        for x in cands[ar][ac]
                        if any(pair_allows(kind, x, y) for y in cands[br_][bc_])
                    }
                    if viable != cands[ar][ac]:
                        cands[ar][ac] = viable
                        if not viable:
                            return False
                        changed = True

            # --- negative constraints on unmarked adjacencies ---
            if self.puzzle.negative_kropki or self.puzzle.negative_xv:
                for r in range(9):
                    for c in range(9):
                        for (nr, nc) in self._orthogonal(r, c):
                            kinds = self._negative_kinds((r, c), (nr, nc))
                            if not kinds:
                                continue
                            viable = {
                                x
                                for x in cands[r][c]
                                if any(
                                    not any(pair_allows(k, x, y) for k in kinds)
                                    for y in cands[nr][nc]
                                )
                            }
                            if viable != cands[r][c]:
                                cands[r][c] = viable
                                if not viable:
                                    return False
                                changed = True

            # --- thermometers must strictly increase ---
            for cells in self.thermos:
                # Forward pass: each cell exceeds the minimum before it.
                floor = 0
                for (r, c) in cells:
                    viable = {x for x in cands[r][c] if x > floor}
                    if viable != cands[r][c]:
                        cands[r][c] = viable
                        if not viable:
                            return False
                        changed = True
                    floor = min(viable)

                # Backward pass: each cell stays under the maximum after it.
                ceiling = 10
                for (r, c) in reversed(cells):
                    viable = {x for x in cands[r][c] if x < ceiling}
                    if viable != cands[r][c]:
                        cands[r][c] = viable
                        if not viable:
                            return False
                        changed = True
                    ceiling = max(viable)

            # --- sandwich clues ---
            for con in self.sandwiches:
                if not self._propagate_sandwich(cands, con):
                    return False

        return True

    def _propagate_sandwich(self, cands, con: Constraint) -> bool:
        """
        Rejects placements of 1 and 9 whose gap cannot produce the clue total.

        Only prunes the crust digits; the in-between sum is verified exactly
        once the line is complete.
        """
        line = self._line_cells(con)

        ones = [i for i, (r, c) in enumerate(line) if 1 in cands[r][c]]
        nines = [i for i, (r, c) in enumerate(line) if 9 in cands[r][c]]
        if not ones or not nines:
            return False

        feasible_one, feasible_nine = set(), set()
        for i in ones:
            for j in nines:
                if i == j:
                    continue
                gap = abs(i - j) - 1
                if gap <= 7 and con.total in _SANDWICH_SUMS[gap]:
                    feasible_one.add(i)
                    feasible_nine.add(j)

        if not feasible_one or not feasible_nine:
            return False

        for i, (r, c) in enumerate(line):
            if i not in feasible_one and 1 in cands[r][c]:
                cands[r][c].discard(1)
                if not cands[r][c]:
                    return False
            if i not in feasible_nine and 9 in cands[r][c]:
                cands[r][c].discard(9)
                if not cands[r][c]:
                    return False

        return True

    def _line_cells(self, con: Constraint) -> list[tuple[int, int]]:
        if con.line_is_row:
            return [(con.line_index, c) for c in range(9)]
        return [(r, con.line_index) for r in range(9)]

    @staticmethod
    def _units() -> list[list[tuple[int, int]]]:
        units = []
        for r in range(9):
            units.append([(r, c) for c in range(9)])
        for c in range(9):
            units.append([(r, c) for r in range(9)])
        for br in range(0, 9, 3):
            for bc in range(0, 9, 3):
                units.append(
                    [(br + i, bc + j) for i in range(3) for j in range(3)]
                )
        return units

    # -- search ----------------------------------------------------------

    def count_solutions(self, limit: int = 2) -> tuple[int, list[list[int]] | None]:
        """
        Returns (number of solutions found, first solution).

        Stops as soon as `limit` solutions are found -- uniqueness checking only
        ever needs to know whether a second one exists.
        """
        cands = self._initial_candidates()
        if cands is None:
            return 0, None

        self._found: list[list[list[int]]] = []
        self._limit = limit
        self._search(cands)

        return len(self._found), self._found[0] if self._found else None

    def solve(self) -> list[list[int]] | None:
        _, solution = self.count_solutions(limit=1)
        return solution

    def is_unique(self) -> bool:
        count, _ = self.count_solutions(limit=2)
        return count == 1

    def _search(self, cands) -> None:
        if len(self._found) >= self._limit:
            return

        # Most-constrained cell first.
        target = None
        best = 10
        for r in range(9):
            for c in range(9):
                size = len(cands[r][c])
                if 1 < size < best:
                    best, target = size, (r, c)
                    if size == 2:
                        break

        if target is None:
            grid = [[next(iter(cands[r][c])) for c in range(9)] for r in range(9)]
            if self._verify(grid):
                self._found.append(grid)
            return

        r, c = target
        for value in sorted(cands[r][c]):
            trial = [[set(cands[i][j]) for j in range(9)] for i in range(9)]
            trial[r][c] = {value}
            if self._propagate(trial):
                self._search(trial)
            if len(self._found) >= self._limit:
                return

    # -- verification ----------------------------------------------------

    def _verify(self, grid: list[list[int]]) -> bool:
        """
        Full check of a completed grid.

        Propagation is necessary but not sufficient -- sandwich totals in
        particular are only exactly checkable once every digit is placed.
        """
        for unit in self._units():
            if sorted(grid[r][c] for (r, c) in unit) != list(range(1, 10)):
                return False

        for con in self.puzzle.constraints:
            if con.kind in PAIR_TYPES:
                (ar, ac), (br_, bc_) = con.cells[0], con.cells[1]
                if not pair_allows(con.kind, grid[ar][ac], grid[br_][bc_]):
                    return False
            elif con.kind == THERMO:
                values = [grid[r][c] for (r, c) in con.cells]
                if any(values[i] >= values[i + 1] for i in range(len(values) - 1)):
                    return False
            elif con.kind == SANDWICH:
                line = [grid[r][c] for (r, c) in self._line_cells(con)]
                if sandwich_total(line) != con.total:
                    return False

        if self.puzzle.negative_kropki or self.puzzle.negative_xv:
            for r in range(9):
                for c in range(9):
                    for (nr, nc) in self._orthogonal(r, c):
                        for kind in self._negative_kinds((r, c), (nr, nc)):
                            if pair_allows(kind, grid[r][c], grid[nr][nc]):
                                return False

        return True


# ---------------------------------------------------------------------------
# SOLUTION GRID GENERATION
# ---------------------------------------------------------------------------


def random_solved_grid(rng: random.Random) -> list[list[int]]:
    """A uniformly shuffled complete sudoku solution."""
    grid = [[0] * 9 for _ in range(9)]

    def fill(pos: int) -> bool:
        if pos == 81:
            return True
        r, c = divmod(pos, 9)

        digits = list(range(1, 10))
        rng.shuffle(digits)

        for value in digits:
            if _safe(grid, r, c, value):
                grid[r][c] = value
                if fill(pos + 1):
                    return True
                grid[r][c] = 0
        return False

    fill(0)
    return grid


def _safe(grid, r: int, c: int, value: int) -> bool:
    for i in range(9):
        if grid[r][i] == value or grid[i][c] == value:
            return False
    br, bc = (r // 3) * 3, (c // 3) * 3
    for i in range(br, br + 3):
        for j in range(bc, bc + 3):
            if grid[i][j] == value:
                return False
    return True
