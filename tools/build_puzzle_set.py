"""
Builds a difficulty-balanced set of verified puzzles for one family.

Generation is a sampling problem, not a targeting problem: the difficulty of a
dug puzzle is only known after it is dug. So we generate with randomised
parameters, measure each result, and keep it if its difficulty bucket still has
room. Buckets fill unevenly, which is why this runs until every level is full
rather than for a fixed number of attempts.

Usage:
    python build_puzzle_set.py <family> [per_level] [max_attempts]
"""

from __future__ import annotations

import io
import json
import random
import sys
import time
from collections import defaultdict

from generate_puzzles import generate_one, random_params
from variant_sudoku import SANDWICH, THERMO

OUT_DIR = "generated"


def constraint_to_json(con) -> dict:
    if con.kind == SANDWICH:
        return {
            "kind": con.kind,
            "line_is_row": con.line_is_row,
            "line_index": con.line_index,
            "total": con.total,
        }
    return {"kind": con.kind, "cells": [list(c) for c in con.cells]}


def build(family: str, per_level: int, max_attempts: int, stall_limit: int = 400) -> dict:
    rng = random.Random(f"{family}-v2")

    buckets: dict[int, list[dict]] = defaultdict(list)
    attempts = 0
    failures = 0
    since_progress = 0
    started = time.time()

    while attempts < max_attempts:
        if all(len(buckets[d]) >= per_level for d in range(1, 11)):
            break

        # The very hardest bucket is genuinely rare for some variants. Rather
        # than burn hours hunting it, give up once nothing new has landed for a
        # long stretch and ship a slightly thinner top level.
        if since_progress >= stall_limit:
            print(
                f"[{family}] no new puzzle in {stall_limit} attempts, stopping",
                flush=True,
            )
            break

        attempts += 1
        since_progress += 1

        params = random_params(rng, family)
        # Leaving givens in is the main lever for an easier puzzle; a floor of 0
        # yields the minimal, hardest version of the same constraint set.
        min_givens = rng.choice(
            [0, 0, 0, 4, 8, 12, 16, 20, 24, 28, 32, 36]
        )

        puzzle = generate_one(rng, family, params, min_givens)
        if puzzle is None:
            failures += 1
            continue

        level = puzzle.difficulty
        if len(buckets[level]) >= per_level:
            continue

        since_progress = 0
        buckets[level].append(
            {
                "grid": puzzle.grid,
                "solution": puzzle.solution,
                "difficulty": level,
                "nodes": puzzle.search_nodes,
                "givens": sum(1 for row in puzzle.grid for v in row if v),
                "constraints": [
                    constraint_to_json(c) for c in puzzle.constraints
                ],
            }
        )

        total = sum(len(v) for v in buckets.values())
        print(
            f"[{family}] {total:>4} kept  attempt {attempts:>5}  "
            f"level {level:>2}  givens {puzzle.grid and sum(1 for r in puzzle.grid for v in r if v):>2}  "
            f"{time.time() - started:>6.0f}s",
            flush=True,
        )

    puzzles = [p for level in range(1, 11) for p in buckets[level]]

    return {
        "family": family,
        "per_level": per_level,
        "attempts": attempts,
        "failures": failures,
        "seconds": round(time.time() - started, 1),
        "counts": {str(d): len(buckets[d]) for d in range(1, 11)},
        "puzzles": puzzles,
    }


def main() -> None:
    family = sys.argv[1]
    per_level = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    max_attempts = int(sys.argv[3]) if len(sys.argv) > 3 else 4000

    result = build(family, per_level, max_attempts)

    import os

    os.makedirs(OUT_DIR, exist_ok=True)
    path = f"{OUT_DIR}/{family}.json"
    io.open(path, "w", encoding="utf-8", newline="\n").write(
        json.dumps(result, indent=1)
    )

    print(f"\n[{family}] wrote {len(result['puzzles'])} puzzles to {path}")
    print(f"[{family}] per level: {result['counts']}")
    print(f"[{family}] {result['attempts']} attempts, {result['seconds']}s")


if __name__ == "__main__":
    main()
