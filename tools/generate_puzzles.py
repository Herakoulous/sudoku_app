"""
Generates variant sudoku puzzles that are correct by construction.

The method is the opposite of what produced the shipped data. Constraints are
*derived from a real solution* rather than drawn at random and hoped to fit, so
a generated puzzle always has at least one solution. Givens are then removed one
at a time, keeping a cell whenever its removal would allow a second solution, so
the result is minimal and provably unique.

Every puzzle is verified again from scratch before it is emitted.
"""

from __future__ import annotations

import random
from dataclasses import dataclass

from fast_solver import FastSolver
from variant_sudoku import (
    GERMAN_WHISPERS,
    KROPKI_BLACK,
    KROPKI_WHITE,
    SANDWICH,
    THERMO,
    XV_V,
    XV_X,
    Constraint,
    VariantPuzzle,
    VariantSolver,
    random_solved_grid,
    sandwich_total,
)

CLASSIC = "classic"
KROPKI = "kropki"
THERMO_V = "thermo"
XV = "xv"
WHISPERS = "germanwhispers"
SANDWICH_V = "sandwich"


@dataclass
class GeneratedPuzzle:
    family: str
    grid: list[list[int]]
    solution: list[list[int]]
    constraints: list[Constraint]
    difficulty: int
    search_nodes: int
    propagation_only: bool


# ---------------------------------------------------------------------------
# CONSTRAINT DERIVATION
# ---------------------------------------------------------------------------


def _adjacent_pairs():
    for r in range(9):
        for c in range(9):
            if c < 8:
                yield (r, c), (r, c + 1)
            if r < 8:
                yield (r, c), (r + 1, c)


def derive_kropki(solution) -> list[Constraint]:
    """
    Every dot the solution implies, so no marker is ever missing.

    Showing the complete set is what makes the absence of a dot meaningful. A
    partial set turns "no dot here" into a trap rather than a clue.

    1 and 2 satisfy both rules at once; they are always drawn white, and the
    realm rule text says so, which keeps negative reasoning sound.
    """
    out = []
    for a, b in _adjacent_pairs():
        x, y = solution[a[0]][a[1]], solution[b[0]][b[1]]
        if abs(x - y) == 1:
            out.append(Constraint(kind=KROPKI_WHITE, cells=(a, b)))
        elif x == 2 * y or y == 2 * x:
            out.append(Constraint(kind=KROPKI_BLACK, cells=(a, b)))
    return out


def derive_xv(solution) -> list[Constraint]:
    """Every V (sum 5) and X (sum 10) the solution implies."""
    out = []
    for a, b in _adjacent_pairs():
        total = solution[a[0]][a[1]] + solution[b[0]][b[1]]
        if total == 5:
            out.append(Constraint(kind=XV_V, cells=(a, b)))
        elif total == 10:
            out.append(Constraint(kind=XV_X, cells=(a, b)))
    return out


def _grow_path(
    rng: random.Random,
    solution,
    used: set[tuple[int, int]],
    start: tuple[int, int],
    max_len: int,
    accept,
) -> list[tuple[int, int]]:
    """Walks orthogonally from `start` while `accept(prev_value, next_value)`."""
    path = [start]
    used.add(start)

    while len(path) < max_len:
        r, c = path[-1]
        options = []
        for nr, nc in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
            if not (0 <= nr < 9 and 0 <= nc < 9) or (nr, nc) in used:
                continue
            if accept(solution[r][c], solution[nr][nc]):
                options.append((nr, nc))

        if not options:
            break

        step = rng.choice(options)
        path.append(step)
        used.add(step)

    return path


def derive_thermos(rng, solution, count=7, max_len=6) -> list[Constraint]:
    """Thermometers that genuinely increase from bulb to tip in this solution."""
    used: set[tuple[int, int]] = set()
    out = []

    starts = [(r, c) for r in range(9) for c in range(9)]
    rng.shuffle(starts)

    for start in starts:
        if len(out) >= count:
            break
        if start in used:
            continue

        path = _grow_path(
            rng, solution, used, start, max_len, lambda a, b: b > a
        )

        # A two-cell thermometer says only "these differ", which any sudoku
        # already guarantees. Require three.
        if len(path) >= 3:
            out.append(Constraint(kind=THERMO, cells=tuple(path)))
        else:
            used.difference_update(path)

    return out


def derive_whispers(rng, solution, count=4, max_len=8) -> list[Constraint]:
    """
    German Whisper lines, emitted as consecutive cell pairs.

    The app models a line as a run of pairwise constraints, so a five-cell line
    becomes four adjacent-pair constraints.
    """
    used: set[tuple[int, int]] = set()
    out = []

    starts = [(r, c) for r in range(9) for c in range(9)]
    rng.shuffle(starts)

    for start in starts:
        if len(out) >= count:
            break
        if start in used:
            continue

        path = _grow_path(
            rng, solution, used, start, max_len, lambda a, b: abs(a - b) >= 5
        )

        if len(path) >= 3:
            for i in range(len(path) - 1):
                out.append(
                    Constraint(
                        kind=GERMAN_WHISPERS, cells=(path[i], path[i + 1])
                    )
                )
        else:
            used.difference_update(path)

    return out


def derive_sandwich(rng, solution, count=9) -> list[Constraint]:
    """Sandwich totals for a random selection of rows and columns."""
    lines = [(True, i) for i in range(9)] + [(False, i) for i in range(9)]
    rng.shuffle(lines)

    out = []
    for is_row, index in lines[:count]:
        line = (
            [solution[index][c] for c in range(9)]
            if is_row
            else [solution[r][index] for r in range(9)]
        )
        out.append(
            Constraint(
                kind=SANDWICH,
                line_is_row=is_row,
                line_index=index,
                total=sandwich_total(line),
            )
        )
    return out


def derive(rng, family: str, solution, params: dict) -> list[Constraint]:
    """Builds the constraint set for `family`, honouring generation params."""
    if family == CLASSIC:
        return []
    if family == KROPKI:
        return derive_kropki(solution)
    if family == XV:
        return derive_xv(solution)
    if family == THERMO_V:
        return derive_thermos(
            rng, solution,
            count=params.get("count", 7),
            max_len=params.get("max_len", 6),
        )
    if family == WHISPERS:
        return derive_whispers(
            rng, solution,
            count=params.get("count", 4),
            max_len=params.get("max_len", 8),
        )
    if family == SANDWICH_V:
        return derive_sandwich(rng, solution, count=params.get("count", 9))
    raise ValueError(family)


# Parameter ranges that produce a usable difficulty spread. Kropki and XV show
# every marker by rule, so their only free dial is how many givens remain.
PARAM_RANGES: dict[str, dict[str, tuple[int, int]]] = {
    CLASSIC: {},
    KROPKI: {},
    XV: {},
    THERMO_V: {"count": (3, 10), "max_len": (3, 7)},
    WHISPERS: {"count": (2, 7), "max_len": (3, 8)},
    SANDWICH_V: {"count": (5, 18)},
}


def random_params(rng: random.Random, family: str) -> dict:
    return {
        name: rng.randint(lo, hi)
        for name, (lo, hi) in PARAM_RANGES[family].items()
    }


# ---------------------------------------------------------------------------
# DIGGING
# ---------------------------------------------------------------------------


def dig(
    rng: random.Random,
    solution,
    constraints: list[Constraint],
    min_givens: int = 0,
) -> list[list[int]]:
    """
    Removes givens while the puzzle stays uniquely solvable.

    Cells are visited in random order and each removal is tested, so the result
    is minimal: no remaining given can be dropped without breaking uniqueness.
    """
    grid = [row[:] for row in solution]

    cells = [(r, c) for r in range(9) for c in range(9)]
    rng.shuffle(cells)

    givens = 81
    for (r, c) in cells:
        if givens <= min_givens:
            break

        saved = grid[r][c]
        grid[r][c] = 0

        puzzle = VariantPuzzle(grid=grid, constraints=constraints)
        if FastSolver(puzzle).is_unique():
            givens -= 1
        else:
            grid[r][c] = saved

    return grid


# ---------------------------------------------------------------------------
# DIFFICULTY
# ---------------------------------------------------------------------------


def measure(grid, constraints) -> tuple[bool, int]:
    """
    Returns (solved by propagation alone, search nodes needed).

    Search node count is a decent difficulty proxy for variants, where the named
    technique vocabulary of classic sudoku does not apply. A puzzle propagation
    can finish unaided is genuinely easy; one needing many branch points is not.
    """
    puzzle = VariantPuzzle(grid=grid, constraints=constraints)
    solver = FastSolver(puzzle)

    cands = solver._initial()
    if cands is None:
        return False, 10**6

    if all(m.bit_count() == 1 for m in cands):
        return True, 0

    nodes = _count_nodes(solver, cands)
    return False, nodes


def _count_nodes(solver: FastSolver, cands, budget: int = 4000) -> int:
    """Counts branch assignments made to reach the first complete solution."""
    from fast_solver import BITS, DIGITS_OF

    nodes = 0

    def search(state) -> bool:
        nonlocal nodes
        if nodes > budget:
            return True

        target, best = -1, 10
        for i in range(81):
            n = state[i].bit_count()
            if 1 < n < best:
                best, target = n, i

        if target == -1:
            return True

        for d in DIGITS_OF[state[target]]:
            nodes += 1
            trial = state[:]
            trial[target] = BITS[d]
            if solver._propagate(trial) and search(trial):
                return True
        return False

    search(cands)
    return nodes


def rate(propagation_only: bool, nodes: int, givens: int) -> int:
    """Maps the measurements onto the app's 1-10 scale."""
    if propagation_only:
        # Even a propagation-only solve gets harder as givens thin out.
        if givens >= 30:
            return 1
        if givens >= 26:
            return 2
        return 3

    if nodes <= 2:
        return 4
    if nodes <= 6:
        return 5
    if nodes <= 15:
        return 6
    if nodes <= 40:
        return 7
    if nodes <= 100:
        return 8
    if nodes <= 300:
        return 9
    return 10


# ---------------------------------------------------------------------------
# TOP LEVEL
# ---------------------------------------------------------------------------


def generate_one(
    rng: random.Random,
    family: str,
    params: dict | None = None,
    min_givens: int = 0,
) -> GeneratedPuzzle | None:
    """
    One verified puzzle, or None if this attempt did not produce a unique grid.

    `min_givens` stops the digger early, which is the main dial for making an
    easier puzzle out of the same constraint set.
    """
    solution = random_solved_grid(rng)
    constraints = derive(rng, family, solution, params or {})

    grid = dig(rng, solution, constraints, min_givens=min_givens)

    # Verify from scratch rather than trusting the digging loop.
    puzzle = VariantPuzzle(grid=grid, constraints=constraints)
    count, found = FastSolver(puzzle).count_solutions(limit=2)
    if count != 1 or found != solution:
        return None

    propagation_only, nodes = measure(grid, constraints)
    givens = sum(1 for r in range(9) for v in grid[r] if v)

    return GeneratedPuzzle(
        family=family,
        grid=grid,
        solution=solution,
        constraints=constraints,
        difficulty=rate(propagation_only, nodes, givens),
        search_nodes=nodes,
        propagation_only=propagation_only,
    )
