"""
Builds the classroom content: one worked example plus a practice set per
technique.

Positions come from real solve paths, so every example genuinely arises in play
rather than being contrived.

Each position carries the solver's full step, **candidate grid included**. That
matters for two reasons. Practically, a position cannot be reproduced from its
digits alone — a Hidden Pair usually only becomes the next step after earlier
eliminations, and re-solving the bare grid surfaces something simpler instead.
Pedagogically it is also the honest presentation: nobody hunts for a Swordfish
on a board with no pencil marks, so the student is shown the candidates the
technique operates on.

Storing the whole step also means the app builds the walkthrough and grades the
practice entirely offline.

Usage:
    python build_classroom.py [per_technique] [max_generated]
"""

from __future__ import annotations

import io
import json
import os
import random
import subprocess
import sys
import time
from collections import defaultdict

from emit_dart import read_existing_classic
from generate_puzzles import CLASSIC, generate_one

HODOKU_DIR = "../../hodokuCLI"

# The syllabus. Order is the suggested path through the classroom, and the
# chapter grouping is how the list is broken up on screen.
SYLLABUS = [
    ("Singles", "FULL_HOUSE"),
    ("Singles", "NAKED_SINGLE"),
    ("Singles", "HIDDEN_SINGLE"),
    ("Intersections", "LOCKED_CANDIDATES_1"),
    ("Intersections", "LOCKED_CANDIDATES_2"),
    ("Subsets", "NAKED_PAIR"),
    ("Subsets", "HIDDEN_PAIR"),
    ("Subsets", "NAKED_TRIPLE"),
    ("Subsets", "HIDDEN_TRIPLE"),
    ("Single-digit patterns", "X_WING"),
    ("Single-digit patterns", "SWORDFISH"),
    ("Single-digit patterns", "SKYSCRAPER"),
    ("Single-digit patterns", "TWO_STRING_KITE"),
    ("Single-digit patterns", "EMPTY_RECTANGLE"),
    ("Wings and chains", "XY_WING"),
    ("Wings and chains", "XYZ_WING"),
    ("Wings and chains", "W_WING"),
    ("Wings and chains", "XY_CHAIN"),
]

WANTED = [technique for _, technique in SYLLABUS]


def solve_path(puzzle_line: str) -> list[dict] | None:
    try:
        result = subprocess.run(
            [
                "java",
                "-cp",
                f".{os.pathsep}Hodoku.jar",
                "HoDoKuCLI",
                puzzle_line,
                "all",
            ],
            cwd=HODOKU_DIR,
            capture_output=True,
            text=True,
            timeout=180,
        )
    except subprocess.TimeoutExpired:
        return None

    line = (result.stdout or "").strip().split("\n")[-1] if result.stdout else ""
    if not line:
        return None

    try:
        data = json.loads(line)
    except json.JSONDecodeError:
        return None

    return data.get("steps") if data.get("ok") else None


def _pattern_cells(step: dict) -> list[list[int]]:
    """Cells that define a step, 0-based [row, col], matching the app's
    TechniquePosition.patternCells."""
    cells = [[c["r"] - 1, c["c"] - 1] for c in step.get("cells", [])]
    if not cells:
        for chain in step.get("chains", []):
            for node in chain:
                cells.append([node["r"] - 1, node["c"] - 1])
    if not cells:
        for als in step.get("alses", []):
            for c in als.get("cells", []):
                cells.append([c["r"] - 1, c["c"] - 1])
    if not cells:
        for e in step.get("eliminations", []):
            cells.append([e["r"] - 1, e["c"] - 1])
        for pl in step.get("placements", []):
            cells.append([pl["r"] - 1, pl["c"] - 1])
    # dedupe, preserve order
    seen = set()
    out = []
    for rc in cells:
        key = (rc[0], rc[1])
        if key not in seen:
            seen.add(key)
            out.append(rc)
    return out


def accepted_answers(grid: str, technique: str, own_step: dict) -> list[list[list[int]]]:
    """Every valid instance of `technique` at `grid`, as a list of cell-sets.

    A board can hold more than one instance of a technique; any of them is a
    correct answer. The solver's own step is always included, so even a
    technique the enumerator does not cover still grades against something real.
    """
    answers: list[list[list[int]]] = []

    def add(cells: list[list[int]]) -> None:
        if not cells:
            return
        canonical = sorted(cells)
        if canonical not in [sorted(a) for a in answers]:
            answers.append(cells)

    try:
        result = subprocess.run(
            ["java", "-cp", f".{os.pathsep}Hodoku.jar", "HoDoKuCLI",
             grid, "instances", technique],
            cwd=HODOKU_DIR, capture_output=True, text=True, timeout=120,
        )
        stdout = result.stdout or ""
        line = stdout.strip().splitlines()[-1] if stdout.strip() else ""
        data = json.loads(line) if line else {}
        if data.get("ok"):
            for inst in data.get("instances", []):
                add(_pattern_cells(inst))
    except Exception:
        pass

    add(_pattern_cells(own_step))
    return answers


def harvest(steps: list[dict], buckets: dict[str, list[dict]], per: int) -> int:
    """Files any wanted step into its bucket. Returns how many were kept."""
    kept = 0

    for step in steps:
        technique = step["type"]
        if technique not in WANTED:
            continue
        if len(buckets[technique]) >= per:
            continue

        # Two positions are the same lesson if the board is the same; a puzzle
        # can hit the same technique twice on nearly identical grids.
        if any(e["step"]["grid"] == step["grid"] for e in buckets[technique]):
            continue

        buckets[technique].append({"step": step})
        kept += 1

    return kept


def main() -> None:
    per = int(sys.argv[1]) if len(sys.argv) > 1 else 7
    max_generated = int(sys.argv[2]) if len(sys.argv) > 2 else 400

    buckets: dict[str, list[dict]] = defaultdict(list)

    # --- 1. Harvest from the bundled classic puzzles ---
    print("walking bundled classic puzzles...", flush=True)

    for index, puzzle in enumerate(read_existing_classic("../lib/data/puzzles.dart")):
        if all(len(buckets[t]) >= per for t in WANTED):
            break

        line = "".join(str(v) for row in puzzle["grid"] for v in row)
        steps = solve_path(line)
        if steps:
            harvest(steps, buckets, per)

        if (index + 1) % 15 == 0:
            filled = sum(1 for t in WANTED if len(buckets[t]) >= per)
            print(f"  ...{index + 1} puzzles, {filled}/{len(WANTED)} full",
                  flush=True)

    # --- 2. Top up the short ones with freshly generated puzzles ---
    short = [t for t in WANTED if len(buckets[t]) < per]
    if short:
        print("\nstill short: " + ", ".join(short), flush=True)
        print(f"generating up to {max_generated} puzzles\n", flush=True)

        rng = random.Random("classroom")
        started = time.time()

        for attempt in range(max_generated):
            if all(len(buckets[t]) >= per for t in WANTED):
                break

            # Harder boards are where the interesting techniques live; an easy
            # puzzle falls to singles long before a Swordfish can appear.
            puzzle = generate_one(rng, CLASSIC, {}, rng.randint(22, 28))
            if puzzle is None:
                continue

            line = "".join(str(v) for row in puzzle.grid for v in row)
            steps = solve_path(line)
            if not steps:
                continue

            if harvest(steps, buckets, per):
                remaining = [t for t in WANTED if len(buckets[t]) < per]
                print(
                    f"  [{attempt + 1:>4}] {len(remaining)} short: "
                    f"{', '.join(remaining[:4])}"
                    f"{'...' if len(remaining) > 4 else ''}  "
                    f"{time.time() - started:>5.0f}s",
                    flush=True,
                )

    # --- 3. Emit ---
    print("computing accepted answer-sets...", flush=True)
    content = []
    for chapter, technique in SYLLABUS:
        entries = buckets[technique]

        def with_answers(entry: dict) -> dict:
            step = entry["step"]
            grid = step["grid"]
            return {
                "step": step,
                "answers": accepted_answers(grid, technique, step),
            }

        content.append(
            {
                "technique": technique,
                "chapter": chapter,
                "tutorial": with_answers(entries[0]) if entries else None,
                "practice": [with_answers(e) for e in entries[1:]],
            }
        )
        if entries:
            counts = [len(with_answers(e)["answers"]) for e in entries[:1]]
            print(f"  {technique:<24} answer-sets in tutorial: {counts[0]}",
                  flush=True)

    os.makedirs("generated", exist_ok=True)
    io.open(
        "generated/classroom.json", "w", encoding="utf-8", newline="\n"
    ).write(json.dumps({"lessons": content}, separators=(",", ":")))

    print(f"\n{'technique':<24}{'tutorial':>9}{'practice':>10}")
    print("-" * 43)
    for lesson in content:
        print(
            f"{lesson['technique']:<24}"
            f"{'yes' if lesson['tutorial'] else 'MISSING':>9}"
            f"{len(lesson['practice']):>10}"
        )


if __name__ == "__main__":
    main()
