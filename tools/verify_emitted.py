"""
End-to-end check of the emitted lib/data/puzzles.dart.

Decodes the compact strings exactly as the Dart codec does, then re-solves every
puzzle from scratch. This is the gate that matters: it catches an encoder bug, a
codec mismatch, or a puzzle that slipped through generation, all of which would
otherwise only show up as a player stuck on an unsolvable board.
"""

from __future__ import annotations

import io
import re
import sys
from collections import defaultdict

from emit_dart import ALPHABET, TOKEN_LETTER
from fast_solver import FastSolver
from variant_sudoku import (
    GERMAN_WHISPERS,
    SANDWICH,
    THERMO,
    Constraint,
    VariantPuzzle,
)

KIND_BY_LETTER = {v: k for k, v in TOKEN_LETTER.items()}


def cell_of(char: str) -> tuple[int, int]:
    index = ALPHABET.index(char)
    return index // 9, index % 9


def decode_grid(encoded: str) -> list[list[int]]:
    return [
        [int(encoded[row * 9 + col]) for col in range(9)] for row in range(9)
    ]


def decode_constraints(encoded: str) -> list[Constraint]:
    if not encoded:
        return []

    out: list[Constraint] = []

    for token in encoded.split(";"):
        if len(token) < 2:
            continue

        letter, body = token[0], token[1:]

        if letter in KIND_BY_LETTER:
            out.append(
                Constraint(
                    kind=KIND_BY_LETTER[letter],
                    cells=(cell_of(body[0]), cell_of(body[1])),
                )
            )
        elif letter == "T":
            out.append(
                Constraint(
                    kind=THERMO,
                    cells=tuple(cell_of(ch) for ch in body),
                )
            )
        elif letter in ("R", "C"):
            out.append(
                Constraint(
                    kind=SANDWICH,
                    line_is_row=(letter == "R"),
                    line_index=ALPHABET.index(body[0]),
                    total=ALPHABET.index(body[1]),
                )
            )

    return out


def parse_emitted(path: str) -> list[dict]:
    source = io.open(path, encoding="utf-8").read()

    puzzles = []
    for block in re.findall(
        r"static final PuzzleData \w+ = PuzzleData\((.*?)\n  \);", source, re.S
    ):
        def field(name: str) -> str | None:
            m = re.search(rf"{name}:\s*'([^']*)'", block)
            return m.group(1) if m else None

        diff = re.search(r"difficulty:\s*(\d+)", block)

        puzzles.append(
            {
                "id": field("id"),
                "difficulty": int(diff.group(1)) if diff else 0,
                "grid": field("grid"),
                "solution": field("solution"),
                "constraints": field("constraints") or "",
            }
        )

    return puzzles


def main() -> int:
    path = "../lib/data/puzzles.dart"
    puzzles = parse_emitted(path)

    print(f"parsed {len(puzzles)} puzzles from {path}\n")

    stats = defaultdict(lambda: defaultdict(int))
    problems = []

    for p in puzzles:
        family = re.sub(r"[\s_]*\d+$", "", p["id"])

        grid = decode_grid(p["grid"])
        solution = decode_grid(p["solution"]) if p["solution"] else None
        constraints = decode_constraints(p["constraints"])

        vp = VariantPuzzle(grid=grid, constraints=constraints)
        count, found = FastSolver(vp).count_solutions(limit=2)

        stats[family]["n"] += 1
        stats[family]["givens"] += sum(1 for row in grid for v in row if v)
        stats[family]["constraints"] += len(constraints)

        if count == 1:
            stats[family]["unique"] += 1
        elif count == 0:
            stats[family]["none"] += 1
            problems.append((p["id"], "no solution"))
        else:
            stats[family]["multi"] += 1
            problems.append((p["id"], "multiple solutions"))

        if solution is None:
            stats[family]["no stored solution"] += 1
            problems.append((p["id"], "missing solution"))
        elif found is not None and found != solution:
            stats[family]["wrong solution"] += 1
            problems.append((p["id"], "stored solution does not match"))

    header = (
        f"{'family':<16}{'n':>4}{'unique':>8}{'multi':>7}{'none':>6}"
        f"{'bad sol':>9}{'givens':>8}{'cons':>7}"
    )
    print(header)
    print("-" * len(header))

    for family, s in stats.items():
        n = max(s["n"], 1)
        print(
            f"{family:<16}{s['n']:>4}{s['unique']:>8}{s['multi']:>7}{s['none']:>6}"
            f"{s['wrong solution'] + s['no stored solution']:>9}"
            f"{s['givens'] / n:>8.1f}{s['constraints'] / n:>7.1f}"
        )

    if problems:
        print(f"\n{len(problems)} PROBLEM(S):")
        for pid, why in problems[:40]:
            print(f"  {pid}: {why}")
        return 1

    print("\nAll puzzles verified: exactly one solution, stored solution correct.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
