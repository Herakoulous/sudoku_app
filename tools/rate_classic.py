"""
Re-rates the classic puzzles using HoDoKu's own solve path.

The shipped difficulties look assigned rather than measured — the ratings run 1
to 10 in an even sweep across every realm, which no real generator produces. A
puzzle's honest difficulty is the hardest technique actually needed to crack it,
and HoDoKu tells us that directly.

Requires a compiled HoDoKuCLI (see the sibling hodokuCLI project).
"""

from __future__ import annotations

import io
import json
import os
import subprocess
import sys

from emit_dart import read_existing_classic

HODOKU_DIR = "../../hodokuCLI"

# Technique -> difficulty on the app's 1-10 scale. Grouped by what a player has
# to know, not by HoDoKu's internal scores: everything a beginner can do sits at
# 1-2, and the jump to fish and chains is where the scale should climb steeply.
TECHNIQUE_LEVEL = {
    # Singles only — a beginner finishes these.
    "FULL_HOUSE": 1,
    "HIDDEN_SINGLE": 1,
    "NAKED_SINGLE": 1,
    # Intersections and small subsets.
    "LOCKED_CANDIDATES": 3,
    "LOCKED_CANDIDATES_1": 3,
    "LOCKED_CANDIDATES_2": 3,
    "NAKED_PAIR": 3,
    "HIDDEN_PAIR": 3,
    "LOCKED_PAIR": 3,
    "NAKED_TRIPLE": 4,
    "HIDDEN_TRIPLE": 4,
    "LOCKED_TRIPLE": 4,
    "NAKED_QUADRUPLE": 5,
    "HIDDEN_QUADRUPLE": 5,
    # Basic fish and single-digit patterns.
    "X_WING": 6,
    "SKYSCRAPER": 6,
    "TWO_STRING_KITE": 6,
    "EMPTY_RECTANGLE": 6,
    "TURBOT_FISH": 6,
    "SWORDFISH": 7,
    "JELLYFISH": 8,
    "FINNED_X_WING": 7,
    "SASHIMI_X_WING": 7,
    "FINNED_SWORDFISH": 8,
    "SASHIMI_SWORDFISH": 8,
    "FINNED_JELLYFISH": 9,
    "SASHIMI_JELLYFISH": 9,
    "FINNED_FRANKEN_SWORDFISH": 9,
    "FRANKEN_SWORDFISH": 9,
    "FINNED_MUTANT_SWORDFISH": 10,
    # Wings and uniqueness.
    "XY_WING": 7,
    "XYZ_WING": 7,
    "W_WING": 7,
    "REMOTE_PAIR": 7,
    "UNIQUENESS_1": 7,
    "UNIQUENESS_2": 7,
    "UNIQUENESS_3": 7,
    "UNIQUENESS_4": 7,
    "UNIQUENESS_5": 7,
    "UNIQUENESS_6": 7,
    "HIDDEN_RECTANGLE": 7,
    "AVOIDABLE_RECTANGLE_1": 7,
    "AVOIDABLE_RECTANGLE_2": 7,
    "BUG_PLUS_1": 7,
    # Colouring, ALS and finned fish.
    "SIMPLE_COLORS": 8,
    "SIMPLE_COLORS_1": 8,
    "SIMPLE_COLORS_2": 8,
    "MULTI_COLORS": 8,
    "MULTI_COLORS_1": 8,
    "MULTI_COLORS_2": 8,
    "SUE_DE_COQ": 8,
    "ALS_XZ": 8,
    "ALS_XY": 8,
    "ALS_XY_WING": 9,
    # Chains and everything past them.
    "XY_CHAIN": 9,
    "X_CHAIN": 9,
    "DISCONTINUOUS_NICE_LOOP": 9,
    "CONTINUOUS_NICE_LOOP": 9,
    "GROUPED_DISCONTINUOUS_NICE_LOOP": 10,
    "GROUPED_CONTINUOUS_NICE_LOOP": 10,
    "AIC": 9,
    "GROUPED_AIC": 10,
    "FORCING_CHAIN": 10,
    "FORCING_CHAIN_CONTRADICTION": 10,
    "FORCING_CHAIN_VERITY": 10,
    "FORCING_NET": 10,
    "FORCING_NET_CONTRADICTION": 10,
    "FORCING_NET_VERITY": 10,
    "TEMPLATE_SET": 10,
    "TEMPLATE_DEL": 10,
    "BRUTE_FORCE": 10,
}

# Anything HoDoKu reports that is not mapped above. Treated as hard rather than
# silently ignored, and printed so the table can be extended.
DEFAULT_LEVEL = 9


def solve_path(puzzle_string: str) -> list[str] | None:
    """Technique names along HoDoKu's solve path, hardest-first ordering lost."""
    result = subprocess.run(
        [
            "java",
            "-cp",
            f".{os.pathsep}Hodoku.jar",
            "HoDoKuCLI",
            puzzle_string,
            "all",
        ],
        cwd=HODOKU_DIR,
        capture_output=True,
        text=True,
        timeout=120,
    )

    line = (result.stdout or "").strip().split("\n")[-1] if result.stdout else ""
    if not line:
        return None

    try:
        data = json.loads(line)
    except json.JSONDecodeError:
        return None

    if not data.get("ok"):
        return None

    return [step["type"] for step in data.get("steps", [])]


def grade(levels: list[int]) -> int:
    """
    Turns a solve path into a 1-10 rating.

    The hardest technique required sets the ceiling, but a puzzle that needs one
    clever move and is otherwise routine does not play as hard as one that needs
    the same move repeatedly. Backing off a step in that case both reflects how
    it feels to solve and fills in the scale, which pure max-technique rating
    leaves full of gaps.
    """
    if not levels:
        return 1

    top = max(levels)
    at_top = levels.count(top)
    below = max((lv for lv in levels if lv < top), default=1)

    if at_top == 1 and top - below >= 2:
        return max(1, top - 1)
    return top


def main() -> None:
    # Reads whichever format puzzles.dart is currently in.
    puzzles = read_existing_classic("../lib/data/puzzles.dart")

    ratings: dict[str, int] = {}
    unmapped: set[str] = set()

    for p in puzzles:
        line = "".join(str(v) for row in p["grid"] for v in row)
        techniques = solve_path(line)

        if techniques is None:
            print(f'{p["id"]:<14} SOLVER FAILED (keeping {p["difficulty"]})')
            ratings[p["id"]] = p["difficulty"]
            continue

        levels = []
        for name in techniques:
            if name not in TECHNIQUE_LEVEL:
                unmapped.add(name)
            levels.append(TECHNIQUE_LEVEL.get(name, DEFAULT_LEVEL))

        hardest_name = max(
            techniques, key=lambda n: TECHNIQUE_LEVEL.get(n, DEFAULT_LEVEL)
        )
        hardest = grade(levels)

        ratings[p["id"]] = hardest
        print(
            f'{p["id"]:<14} was {p["difficulty"]:>2} -> {hardest:>2}  '
            f"({len(techniques):>3} steps, hardest: {hardest_name})",
            flush=True,
        )

    os.makedirs("generated", exist_ok=True)
    io.open("generated/classic_ratings.json", "w", encoding="utf-8", newline="\n").write(
        json.dumps(ratings, indent=1)
    )

    from collections import Counter

    print("\nrating distribution:", dict(sorted(Counter(ratings.values()).items())))
    if unmapped:
        print("UNMAPPED techniques (rated as hard):", sorted(unmapped))


if __name__ == "__main__":
    sys.exit(main())
