"""
Audits the shipped puzzle data.

Reports, per puzzle: whether it has any solution at all, whether that solution
is unique, how many givens it carries, and whether the stored solution (if any)
actually matches.
"""

from __future__ import annotations

import sys
from collections import defaultdict

from dart_puzzles import load_puzzles
from variant_sudoku import VariantPuzzle, VariantSolver

# Kropki and XV are conventionally drawn with every marker present. Auditing
# both ways shows whether these puzzles were built expecting that rule.
NEGATIVE_BY_FAMILY = {
    "kropki": ("negative_kropki",),
    "xv": ("negative_xv",),
}


def audit(path: str, families: list[str] | None, limit: int | None) -> None:
    puzzles = load_puzzles(path)
    if families:
        puzzles = [p for p in puzzles if p.family in families]
    if limit:
        puzzles = puzzles[:limit]

    stats = defaultdict(lambda: defaultdict(int))
    failures = []

    for p in puzzles:
        flags = {}
        for attr in NEGATIVE_BY_FAMILY.get(p.family, ()):
            flags[attr] = True

        vp = VariantPuzzle(
            grid=[row[:] for row in p.grid],
            constraints=p.constraints,
            **flags,
        )

        count, solution = VariantSolver(vp).count_solutions(limit=2)

        if count == 0:
            verdict = "NO SOLUTION"
        elif count == 1:
            verdict = "unique"
        else:
            verdict = "MULTIPLE"

        stats[p.family][verdict] += 1
        stats[p.family]["givens"] += sum(1 for r in p.grid for v in r if v)
        stats[p.family]["n"] += 1

        if p.solution is not None and solution is not None:
            if p.solution != solution and count == 1:
                stats[p.family]["STORED SOLUTION WRONG"] += 1

        if verdict != "unique":
            failures.append((p.puzzle_id, verdict, len(p.constraints)))

        print(
            f"{p.puzzle_id:<20} {verdict:<12} "
            f"givens={sum(1 for r in p.grid for v in r if v):>2} "
            f"constraints={len(p.constraints):>3}",
            flush=True,
        )

    print("\n" + "=" * 62)
    print(f"{'family':<16}{'n':>4}{'unique':>8}{'multi':>8}{'none':>7}{'avg givens':>12}")
    print("=" * 62)

    for family, s in stats.items():
        n = s["n"]
        print(
            f"{family:<16}{n:>4}{s['unique']:>8}{s['MULTIPLE']:>8}"
            f"{s['NO SOLUTION']:>7}{s['givens'] / max(n, 1):>12.1f}"
        )
        if s["STORED SOLUTION WRONG"]:
            print(f"  !! stored solution mismatch: {s['STORED SOLUTION WRONG']}")

    if failures:
        print(f"\n{len(failures)} puzzle(s) not uniquely solvable.")


if __name__ == "__main__":
    args = sys.argv[1:]
    fams = [a for a in args if not a.isdigit() and not a.startswith("../")]
    nums = [int(a) for a in args if a.isdigit()]
    audit("../lib/data/puzzles.dart", fams or None, nums[0] if nums else None)
