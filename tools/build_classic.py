"""
Generates extra classic puzzles to fill gaps in the difficulty curve.

The 52 shipped classic puzzles audit clean, but measured honestly they cluster:
plenty of beginner and expert boards, almost nothing in the middle. A player
working through the realm hits a wall where Apprentice should hand over to
Adept.

Puzzles here are dug with the same uniqueness guarantee as the variants, then
rated by HoDoKu so their difficulty is directly comparable to the existing ones
rather than measured on a different scale.

Usage:
    python build_classic.py [target_per_level] [levels...]
"""

from __future__ import annotations

import io
import json
import os
import random
import sys
import time
from collections import defaultdict

from generate_puzzles import CLASSIC, generate_one
from rate_classic import grade, DEFAULT_LEVEL, TECHNIQUE_LEVEL, solve_path


def hodoku_level(grid) -> int | None:
    """HoDoKu's verdict on a grid, on the app's 1-10 scale."""
    line = "".join(str(v) for row in grid for v in row)
    techniques = solve_path(line)
    if techniques is None:
        return None

    return grade(
        [TECHNIQUE_LEVEL.get(name, DEFAULT_LEVEL) for name in techniques]
    )


def main() -> None:
    per_level = int(sys.argv[2]) if len(sys.argv) > 2 else 10
    wanted = (
        [int(a) for a in sys.argv[3:]] if len(sys.argv) > 3 else [5, 6]
    )

    rng = random.Random("classic-fill")
    buckets: dict[int, list[dict]] = defaultdict(list)

    started = time.time()
    attempts = 0
    stall = 0

    while stall < 300:
        if all(len(buckets[lv]) >= per_level for lv in wanted):
            break

        attempts += 1
        stall += 1

        # Mid-difficulty classic puzzles need givens left in; a fully minimal
        # grid almost always lands in the hardest tiers.
        min_givens = rng.randint(24, 34)

        puzzle = generate_one(rng, CLASSIC, {}, min_givens)
        if puzzle is None:
            continue

        level = hodoku_level(puzzle.grid)
        if level is None or level not in wanted:
            continue
        if len(buckets[level]) >= per_level:
            continue

        stall = 0
        buckets[level].append(
            {
                "grid": puzzle.grid,
                "solution": puzzle.solution,
                "difficulty": level,
                "givens": sum(1 for row in puzzle.grid for v in row if v),
                "constraints": [],
            }
        )

        total = sum(len(v) for v in buckets.values())
        print(
            f"[classic] {total:>3} kept  attempt {attempts:>4}  level {level}  "
            f"givens {buckets[level][-1]['givens']:>2}  "
            f"{time.time() - started:>5.0f}s",
            flush=True,
        )

    puzzles = [p for lv in sorted(buckets) for p in buckets[lv]]

    os.makedirs("generated", exist_ok=True)
    io.open(
        "generated/classic_extra.json", "w", encoding="utf-8", newline="\n"
    ).write(json.dumps({"puzzles": puzzles}, indent=1))

    print(f"\n[classic] wrote {len(puzzles)} extra puzzles")
    print(f"[classic] per level: {({lv: len(buckets[lv]) for lv in sorted(buckets)})}")


if __name__ == "__main__":
    main()
