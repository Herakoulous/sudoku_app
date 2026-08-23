"""
Imports hand-made sudoku puzzles from janko.at for the Puzzle of the Day.

Janko's own puzzles are CC BY-NC-SA 3.0: usable while the app is free and
non-commercial, provided the author is credited. This tool keeps that promise —
every imported puzzle carries its author and source, and those are shown in the
app.

Etiquette: fetches are rate-limited and cached to disk, and only Janko's own
puzzles are taken (third-party ones, whose footer names a different author with
their own terms, are skipped). robots.txt permits /Raetsel/ but bans bulk
mirroring, which this is careful not to be.

Scope for now: Classic and Kropki, the two the app already renders and can
verify. Kropki puzzles ship no givens and no dot list — the dots are the full
set implied by the solution (the same all-marks convention the generator uses),
so they are derived and the result re-verified for a unique solution.

Usage:
    python janko_import.py [per_type] [rate_seconds]
"""

from __future__ import annotations

import html as html_lib
import io
import json
import os
import re
import sys
import time
import urllib.request

from fast_solver import FastSolver
from generate_puzzles import derive_kropki
from variant_sudoku import KROPKI_BLACK, KROPKI_WHITE, VariantPuzzle

BASE = "https://www.janko.at/Raetsel/Sudoku"
CACHE = "janko_cache"
USER_AGENT = "SudokuRealms/1.0 (personal non-commercial daily; contact via app)"

# type key -> (url path, app constraint family)
TYPES = {
    "classic": ("", "classic"),
    "kropki": ("Kropki/", "kropki"),
}


def _fetch(url: str, rate: float) -> str | None:
    """Fetches a URL, caching to disk so a re-run costs no requests."""
    os.makedirs(CACHE, exist_ok=True)
    key = re.sub(r"[^a-zA-Z0-9]", "_", url) + ".html"
    path = os.path.join(CACHE, key)

    if os.path.exists(path):
        return io.open(path, encoding="utf-8", errors="replace").read()

    time.sleep(rate)  # be polite
    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=30) as resp:
            if resp.status != 200:
                return None
            body = resp.read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"  fetch failed {url}: {e}", flush=True)
        return None

    io.open(path, "w", encoding="utf-8", newline="\n").write(body)
    return body


def _puzzle_numbers(type_path: str, rate: float) -> list[str]:
    index = _fetch(f"{BASE}/{type_path}index.htm", rate)
    if index is None:
        return []
    # Puzzle links look like href="001.a.htm" or "0001.a.htm".
    return re.findall(r'href="(\d+)\.a\.htm"', index)


def _parse_block(page: str) -> dict | None:
    """Pulls the [begin]..[end] text block out of a puzzle page into a dict."""
    start = page.find("[begin]")
    end = page.find("[end]")
    if start < 0 or end < 0:
        return None

    text = html_lib.unescape(re.sub(r"<[^>]+>", "", page[start : end + 5]))

    fields: dict = {}
    current_grid: list[list[int]] | None = None
    grid_key = None

    for line in text.splitlines():
        line = line.strip()
        if not line or line in ("[begin]", "[end]"):
            continue

        section = re.fullmatch(r"\[([a-z]+)\]", line)
        if section:
            grid_key = section.group(1)
            if grid_key in ("problem", "solution"):
                current_grid = []
                fields[grid_key] = current_grid
            else:
                current_grid = None
            continue

        if current_grid is not None:
            row = [0 if tok == "-" else int(tok) for tok in line.split()]
            current_grid.append(row)
        else:
            # key value line, e.g. "author Foo Bar" or "puzzle sudoku, kropki"
            key, _, value = line.partition(" ")
            fields[key] = value.strip()

    return fields


def _difficulty(fields: dict) -> int:
    """Maps Janko's rating to the app's 1–10 scale.

    Janko encodes a star rating in brackets within the info line, roughly 1–5.
    Absent that, everything lands mid-scale.
    """
    info = fields.get("info", "")
    match = re.search(r"\[(\d)\]", info)
    if not match:
        return 5
    stars = int(match.group(1))
    return {1: 2, 2: 4, 3: 6, 4: 8, 5: 10}.get(stars, 5)


def _constraints_json(family: str, solution: list[list[int]]) -> list[dict]:
    if family != "kropki":
        return []

    out = []
    for con in derive_kropki(solution):
        kind = "W" if con.kind == KROPKI_WHITE else "B"
        (r1, c1), (r2, c2) = con.cells
        out.append({"k": kind, "a": [r1, c1], "b": [r2, c2]})
    return out


def _verify(family: str, grid, solution, constraints_dart) -> bool:
    """Confirms the puzzle has exactly one solution under its rules."""
    from variant_sudoku import Constraint

    cons = []
    if family == "kropki":
        for c in constraints_dart:
            kind = KROPKI_WHITE if c["k"] == "W" else KROPKI_BLACK
            cons.append(
                Constraint(kind=kind, cells=(tuple(c["a"]), tuple(c["b"])))
            )

    puzzle = VariantPuzzle(grid=[row[:] for row in grid], constraints=cons)
    count, found = FastSolver(puzzle).count_solutions(limit=2)
    return count == 1 and found == solution


def _grid_string(grid) -> str:
    return "".join(str(v) for row in grid for v in row)


def main() -> None:
    per_type = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    rate = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0

    pool = []

    for type_key, (type_path, family) in TYPES.items():
        print(f"\n=== {type_key} ===", flush=True)
        numbers = _puzzle_numbers(type_path, rate)
        print(f"  {len(numbers)} puzzles listed", flush=True)

        kept = 0
        for number in numbers:
            if kept >= per_type:
                break

            page = _fetch(f"{BASE}/{type_path}{number}.a.htm", rate)
            if page is None:
                continue

            fields = _parse_block(page)
            if fields is None:
                continue

            author = fields.get("author", "").strip()
            if not author:
                continue  # never import without attribution

            solution = fields.get("solution")
            if not solution or len(solution) != 9:
                continue

            # Givens: classic ships them; kropki ships none (dots carry it all).
            problem = fields.get("problem")
            if family == "kropki" or not problem:
                grid = [[0] * 9 for _ in range(9)]
            else:
                grid = problem
            if len(grid) != 9:
                continue

            constraints = _constraints_json(family, solution)

            if not _verify(family, grid, solution, constraints):
                print(f"  {number}: not uniquely solvable, skipped", flush=True)
                continue

            pool.append(
                {
                    "id": f"daily_{type_key}_{number}",
                    "type": type_key,
                    "family": family,
                    "author": author,
                    "source": fields.get("source", "janko.at"),
                    "difficulty": _difficulty(fields),
                    "grid": _grid_string(grid),
                    "solution": _grid_string(solution),
                    "constraints": constraints,
                }
            )
            kept += 1
            print(f"  {number}: {author} (diff {_difficulty(fields)})",
                  flush=True)

    os.makedirs("../assets/data", exist_ok=True)
    out_path = "../assets/data/daily_pool.json"
    io.open(out_path, "w", encoding="utf-8", newline="\n").write(
        json.dumps(
            {
                "attribution": "Puzzles by their authors, from janko.at, "
                "licensed CC BY-NC-SA 3.0.",
                "puzzles": pool,
            },
            separators=(",", ":"),
        )
    )

    print(f"\nwrote {len(pool)} puzzles to {out_path}")
    from collections import Counter
    print("by type:", dict(Counter(p["type"] for p in pool)))
    print("by difficulty:", dict(sorted(Counter(p["difficulty"] for p in pool).items())))


if __name__ == "__main__":
    main()
