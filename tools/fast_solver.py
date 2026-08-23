"""
Bitmask solver for variant sudoku.

Same semantics as the reference implementation in variant_sudoku, rewritten
with integer bitmask candidate sets. Generation runs one uniqueness check per
candidate removal -- 81 solves per puzzle -- so solver speed is the whole
budget. Representing a cell's candidates as an int makes state copying a flat
list slice instead of 81 set copies.

Cells are flat indices 0..80. Candidate masks use bit d for digit d (1..9).
"""

from __future__ import annotations

from itertools import combinations

from variant_sudoku import (
    GERMAN_WHISPERS,
    PAIR_TYPES,
    SANDWICH,
    THERMO,
    Constraint,
    VariantPuzzle,
    pair_allows,
)

ALL = 0b1111111110

# ---------------------------------------------------------------------------
# PRECOMPUTED TABLES
# ---------------------------------------------------------------------------

BITS = [1 << d for d in range(10)]

# mask -> list of digits present
DIGITS_OF: dict[int, tuple[int, ...]] = {}
for _m in range(1 << 10):
    DIGITS_OF[_m] = tuple(d for d in range(1, 10) if _m & (1 << d))

PEERS: list[tuple[int, ...]] = []
for _i in range(81):
    _r, _c = divmod(_i, 9)
    _p = set()
    for _k in range(9):
        _p.add(_r * 9 + _k)
        _p.add(_k * 9 + _c)
    _br, _bc = (_r // 3) * 3, (_c // 3) * 3
    for _a in range(_br, _br + 3):
        for _b in range(_bc, _bc + 3):
            _p.add(_a * 9 + _b)
    _p.discard(_i)
    PEERS.append(tuple(_p))

UNITS: list[tuple[int, ...]] = []
for _r in range(9):
    UNITS.append(tuple(_r * 9 + c for c in range(9)))
for _c in range(9):
    UNITS.append(tuple(r * 9 + _c for r in range(9)))
for _br in range(0, 9, 3):
    for _bc in range(0, 9, 3):
        UNITS.append(
            tuple((_br + i) * 9 + (_bc + j) for i in range(3) for j in range(3))
        )

ORTHOGONAL: list[tuple[int, ...]] = []
for _i in range(81):
    _r, _c = divmod(_i, 9)
    _n = []
    if _r > 0:
        _n.append(_i - 9)
    if _r < 8:
        _n.append(_i + 9)
    if _c > 0:
        _n.append(_i - 1)
    if _c < 8:
        _n.append(_i + 1)
    ORTHOGONAL.append(tuple(_n))

# kind -> digit -> mask of partner digits that satisfy the relation
PARTNER_MASK: dict[str, list[int]] = {}
for _kind in PAIR_TYPES:
    _table = [0] * 10
    for _x in range(1, 10):
        _m = 0
        for _y in range(1, 10):
            if pair_allows(_kind, _x, _y):
                _m |= 1 << _y
        _table[_x] = _m
    PARTNER_MASK[_kind] = _table

_BETWEEN = [2, 3, 4, 5, 6, 7, 8]
SANDWICH_SUMS: dict[int, frozenset[int]] = {
    g: frozenset(sum(c) for c in combinations(_BETWEEN, g)) for g in range(8)
}
SANDWICH_SUMS[0] = frozenset({0})

# gap -> total -> tuple of digit-combinations that achieve it
SANDWICH_COMBOS: dict[tuple[int, int], tuple[tuple[int, ...], ...]] = {}
for _g in range(8):
    for _combo in combinations(_BETWEEN, _g):
        SANDWICH_COMBOS.setdefault((_g, sum(_combo)), ())
        SANDWICH_COMBOS[(_g, sum(_combo))] += (_combo,)


class FastSolver:
    def __init__(self, puzzle: VariantPuzzle):
        self.puzzle = puzzle

        # cell -> list of (partner cell, partner-mask table)
        self.links: list[list[tuple[int, list[int]]]] = [[] for _ in range(81)]
        self.thermos: list[tuple[int, ...]] = []
        self.sandwiches: list[tuple[tuple[int, ...], int]] = []

        marked: set[frozenset[int]] = set()

        for con in puzzle.constraints:
            if con.kind in PAIR_TYPES:
                a = con.cells[0][0] * 9 + con.cells[0][1]
                b = con.cells[1][0] * 9 + con.cells[1][1]
                table = PARTNER_MASK[con.kind]
                self.links[a].append((b, table))
                self.links[b].append((a, table))
                marked.add(frozenset((a, b)))
            elif con.kind == THERMO:
                self.thermos.append(tuple(r * 9 + c for (r, c) in con.cells))
            elif con.kind == SANDWICH:
                cells = (
                    tuple(con.line_index * 9 + c for c in range(9))
                    if con.line_is_row
                    else tuple(r * 9 + con.line_index for r in range(9))
                )
                self.sandwiches.append((cells, con.total))

        # Negative constraints: for each unmarked orthogonal adjacency, the two
        # cells must NOT satisfy the omitted relation.
        self.neg_links: list[list[tuple[int, list[int]]]] = [[] for _ in range(81)]

        kinds = []
        if puzzle.negative_kropki:
            kinds += ["KROPKI_WHITE", "KROPKI_BLACK"]
        if puzzle.negative_xv:
            kinds += ["XV_V", "XV_X"]

        if kinds:
            forbidden = [0] * 10
            for x in range(1, 10):
                m = 0
                for k in kinds:
                    m |= PARTNER_MASK[k][x]
                forbidden[x] = ALL & ~m  # partners that stay legal

            for i in range(81):
                for j in ORTHOGONAL[i]:
                    if frozenset((i, j)) not in marked:
                        self.neg_links[i].append((j, forbidden))

    # -- propagation -----------------------------------------------------

    def _initial(self) -> list[int] | None:
        grid = self.puzzle.grid
        state = [
            BITS[grid[i // 9][i % 9]] if grid[i // 9][i % 9] else ALL
            for i in range(81)
        ]

        for cells in self.thermos:
            n = len(cells)
            for pos, cell in enumerate(cells):
                lo, hi = pos + 1, 9 - (n - 1 - pos)
                allowed = 0
                for d in range(lo, hi + 1):
                    allowed |= BITS[d]
                state[cell] &= allowed
                if not state[cell]:
                    return None

        return state if self._propagate(state) else None

    def _propagate(self, state: list[int]) -> bool:
        changed = True
        while changed:
            changed = False

            # --- naked singles eliminate from peers ---
            for i in range(81):
                m = state[i]
                if m == 0:
                    return False
                if m & (m - 1):
                    continue  # more than one bit
                for p in PEERS[i]:
                    if state[p] & m:
                        state[p] &= ~m
                        if not state[p]:
                            return False
                        changed = True

            # --- hidden singles ---
            for unit in UNITS:
                for d in range(1, 10):
                    bit = BITS[d]
                    spot = -1
                    count = 0
                    for cell in unit:
                        if state[cell] & bit:
                            count += 1
                            if count > 1:
                                break
                            spot = cell
                    if count == 0:
                        return False
                    if count == 1 and state[spot] != bit:
                        state[spot] = bit
                        changed = True

            # --- marked pair relations ---
            for i in range(81):
                links = self.links[i]
                if not links:
                    continue
                m = state[i]
                for (j, table) in links:
                    other = state[j]
                    viable = 0
                    for d in DIGITS_OF[m]:
                        if table[d] & other:
                            viable |= BITS[d]
                    if viable != m:
                        if not viable:
                            return False
                        state[i] = m = viable
                        changed = True

            # --- negative (omitted marker) relations ---
            for i in range(81):
                links = self.neg_links[i]
                if not links:
                    continue
                m = state[i]
                for (j, table) in links:
                    other = state[j]
                    viable = 0
                    for d in DIGITS_OF[m]:
                        if table[d] & other:
                            viable |= BITS[d]
                    if viable != m:
                        if not viable:
                            return False
                        state[i] = m = viable
                        changed = True

            # --- thermometers ---
            for cells in self.thermos:
                floor = 0
                for cell in cells:
                    m = state[cell]
                    allowed = ALL & ~((1 << (floor + 1)) - 1)
                    nm = m & allowed
                    if nm != m:
                        if not nm:
                            return False
                        state[cell] = nm
                        changed = True
                    floor = (nm & -nm).bit_length() - 1

                ceiling = 10
                for cell in reversed(cells):
                    m = state[cell]
                    nm = m & ((1 << ceiling) - 1)
                    if nm != m:
                        if not nm:
                            return False
                        state[cell] = nm
                        changed = True
                    ceiling = nm.bit_length() - 1

            # --- sandwich clues ---
            for cells, total in self.sandwiches:
                if not self._propagate_sandwich(state, cells, total):
                    return False

        return True

    def _propagate_sandwich(self, state, cells, total) -> bool:
        """
        Prunes using the full crust-and-filling structure.

        For every viable placement of 1 and 9, the cells between them must hold
        a combination from {2..8} summing to the clue, and each of those cells
        must actually be able to take one of those digits. Checking the filling
        -- not just the gap width -- is what makes sandwich puzzles tractable to
        generate.
        """
        one, nine = BITS[1], BITS[9]

        allowed = [0] * 9
        feasible = False

        for i in range(9):
            if not (state[cells[i]] & one):
                continue
            for j in range(9):
                if i == j or not (state[cells[j]] & nine):
                    continue

                lo, hi = (i, j) if i < j else (j, i)
                gap = hi - lo - 1
                combos = SANDWICH_COMBOS.get((gap, total))
                if not combos:
                    continue

                inside = cells[lo + 1 : hi]

                for combo in combos:
                    # Every inside cell must be able to take some digit of the
                    # combination, and the combination must cover them all.
                    combo_mask = 0
                    for d in combo:
                        combo_mask |= BITS[d]

                    if any(state[cell] & combo_mask == 0 for cell in inside):
                        continue
                    if not self._matchable(state, inside, combo):
                        continue

                    feasible = True
                    allowed[i] |= one
                    allowed[j] |= nine
                    for pos in range(lo + 1, hi):
                        allowed[pos] |= combo_mask
                    # Cells outside the crust take whatever is left over.
                    outside_mask = ALL & ~one & ~nine & ~combo_mask
                    for pos in range(9):
                        if pos < lo or pos > hi:
                            allowed[pos] |= outside_mask

        if not feasible:
            return False

        changed = False
        for pos in range(9):
            cell = cells[pos]
            nm = state[cell] & allowed[pos]
            if nm != state[cell]:
                if not nm:
                    return False
                state[cell] = nm
                changed = True

        return True

    @staticmethod
    def _matchable(state, cells, combo) -> bool:
        """Does a perfect matching exist between these cells and these digits?"""
        n = len(cells)
        if n == 0:
            return True

        # n is at most 7; a plain augmenting-path matching is ample.
        match_digit = [-1] * n

        def try_assign(ci: int, seen: set[int]) -> bool:
            for di, d in enumerate(combo):
                if di in seen or not (state[cells[ci]] & BITS[d]):
                    continue
                seen.add(di)
                taken = next((k for k in range(n) if match_digit[k] == di), -1)
                if taken == -1 or try_assign(taken, seen):
                    match_digit[ci] = di
                    return True
            return False

        for ci in range(n):
            if not try_assign(ci, set()):
                return False
        return True

    # -- search ----------------------------------------------------------

    def count_solutions(self, limit: int = 2) -> tuple[int, list[list[int]] | None]:
        state = self._initial()
        if state is None:
            return 0, None

        self._found: list[list[int]] = []
        self._limit = limit
        self._search(state)

        if not self._found:
            return 0, None

        flat = self._found[0]
        grid = [[flat[r * 9 + c] for c in range(9)] for r in range(9)]
        return len(self._found), grid

    def is_unique(self) -> bool:
        count, _ = self.count_solutions(limit=2)
        return count == 1

    def solve(self):
        _, grid = self.count_solutions(limit=1)
        return grid

    def _search(self, state: list[int]) -> None:
        if len(self._found) >= self._limit:
            return

        target, best = -1, 10
        for i in range(81):
            n = state[i].bit_count()
            if 1 < n < best:
                best, target = n, i
                if n == 2:
                    break

        if target == -1:
            self._found.append([(m.bit_length() - 1) for m in state])
            return

        for d in DIGITS_OF[state[target]]:
            trial = state[:]
            trial[target] = BITS[d]
            if self._propagate(trial):
                self._search(trial)
            if len(self._found) >= self._limit:
                return
