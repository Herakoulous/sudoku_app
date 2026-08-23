"""
Surveys which HoDoKu techniques actually occur in the bundled classic puzzles.

A classroom is only as good as its examples: a technique with no real position to
show cannot be taught, and one that appears twice in the whole puzzle set cannot
support a practice round. This walks every classic solve path and records, for
each technique, the grid state at the moment it applies.

Those captured positions are the raw material for both the tutorial and the
practice sets.
"""

from __future__ import annotations

import io
import json
import os
import subprocess
import sys
from collections import defaultdict

from emit_dart import read_existing_classic

HODOKU_DIR = "../../hodokuCLI"


def solve_path(puzzle_line: str) -> list[dict] | None:
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

    line = (result.stdout or "").strip().split("\n")[-1] if result.stdout else ""
    if not line:
        return None

    try:
        data = json.loads(line)
    except json.JSONDecodeError:
        return None

    return data.get("steps") if data.get("ok") else None


def main() -> None:
    puzzles = read_existing_classic("../lib/data/puzzles.dart")
    print(f"surveying {len(puzzles)} classic puzzles\n", flush=True)

    # technique -> list of {puzzleId, grid, notation}
    positions: dict[str, list[dict]] = defaultdict(list)

    for index, puzzle in enumerate(puzzles):
        line = "".join(str(v) for row in puzzle["grid"] for v in row)
        steps = solve_path(line)

        if steps is None:
            print(f"  {puzzle['id']}: solver failed", flush=True)
            continue

        for step in steps:
            positions[step["type"]].append(
                {
                    "puzzleId": puzzle["id"],
                    # The grid as it stood when this technique applied — this is
                    # the position a student would be shown.
                    "grid": step["grid"],
                    "notation": step["notation"],
                    "difficulty": puzzle["difficulty"],
                }
            )

        if (index + 1) % 10 == 0:
            print(f"  ...{index + 1}/{len(puzzles)}", flush=True)

    os.makedirs("generated", exist_ok=True)
    io.open(
        "generated/technique_positions.json", "w", encoding="utf-8", newline="\n"
    ).write(json.dumps(positions, indent=1))

    print(f"\n{'technique':<38}{'positions':>10}{'puzzles':>9}")
    print("-" * 57)

    for technique in sorted(positions, key=lambda t: -len(positions[t])):
        entries = positions[technique]
        distinct = len({e["puzzleId"] for e in entries})
        print(f"{technique:<38}{len(entries):>10}{distinct:>9}")

    print(f"\n{len(positions)} distinct techniques")


if __name__ == "__main__":
    sys.exit(main())
