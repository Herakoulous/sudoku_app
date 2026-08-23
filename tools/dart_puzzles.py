"""
Reads and writes lib/data/puzzles.dart.

The file is generated, so parsing it with regexes is acceptable: the shapes are
uniform because a script emitted them.
"""

from __future__ import annotations

import io
import re
from dataclasses import dataclass, field

from variant_sudoku import (
    GERMAN_WHISPERS,
    KROPKI_BLACK,
    KROPKI_WHITE,
    SANDWICH,
    THERMO,
    XV_V,
    XV_X,
    Constraint,
)

PUZZLES_DART = "lib/data/puzzles.dart"

_KIND_BY_NAME = {
    "KROPKI_WHITE": KROPKI_WHITE,
    "KROPKI_BLACK": KROPKI_BLACK,
    "THERMO": THERMO,
    "XV_X": XV_X,
    "XV_V": XV_V,
    "GERMAN_WHISPERS": GERMAN_WHISPERS,
    "SANDWICH": SANDWICH,
}


@dataclass
class ParsedPuzzle:
    var_name: str
    puzzle_id: str
    difficulty: int
    grid: list[list[int]]
    solution: list[list[int]] | None
    constraints: list[Constraint] = field(default_factory=list)

    @property
    def family(self) -> str:
        return re.sub(r"[\s_]*\d+$", "", self.puzzle_id)


def _parse_grid(block: str, key: str) -> list[list[int]] | None:
    match = re.search(rf"{key}:\s*\[(.*?)\n\s*\],", block, re.S)
    if not match:
        return None

    rows = re.findall(r"\[([0-9,\s]*)\]", match.group(1))
    grid = [
        [int(v) for v in re.findall(r"\d+", row)]
        for row in rows
    ]
    return grid if len(grid) == 9 and all(len(r) == 9 for r in grid) else None


def _parse_constraints(block: str) -> list[Constraint]:
    match = re.search(r"constraints:\s*\[(.*)\n\s*\],?\s*\);", block, re.S)
    if not match:
        return []

    body = match.group(1)
    out: list[Constraint] = []

    for raw in re.findall(r"VariantConstraint\((.*?)\n\s*\)", body, re.S):
        type_match = re.search(r"ConstraintType\.(\w+)", raw)
        if not type_match:
            continue

        kind = _KIND_BY_NAME.get(type_match.group(1))
        if kind is None:
            continue

        def num(field_name: str) -> int | None:
            m = re.search(rf"{field_name}:\s*(-?\d+)", raw)
            return int(m.group(1)) if m else None

        if kind == THERMO:
            cells = [
                (int(r), int(c))
                for r, c in re.findall(r"Position\((\d+),\s*(\d+)\)", raw)
            ]
            if len(cells) >= 2:
                out.append(Constraint(kind=THERMO, cells=tuple(cells)))
            continue

        if kind == SANDWICH:
            total = num("sandwichSum")
            row = num("sandwichRow")
            col = num("sandwichCol")
            if total is None:
                continue
            if row is not None:
                out.append(
                    Constraint(
                        kind=SANDWICH, line_is_row=True, line_index=row, total=total
                    )
                )
            elif col is not None:
                out.append(
                    Constraint(
                        kind=SANDWICH, line_is_row=False, line_index=col, total=total
                    )
                )
            continue

        r1, c1, r2, c2 = num("row1"), num("col1"), num("row2"), num("col2")
        if None in (r1, c1, r2, c2):
            continue
        out.append(Constraint(kind=kind, cells=((r1, c1), (r2, c2))))

    return out


def load_puzzles(path: str = PUZZLES_DART) -> list[ParsedPuzzle]:
    source = io.open(path, encoding="utf-8").read()
    chunks = source.split("static final PuzzleData ")[1:]

    puzzles: list[ParsedPuzzle] = []
    for chunk in chunks:
        var_name = chunk.split("=")[0].strip()

        id_match = re.search(r"id:\s*'([^']+)'", chunk)
        diff_match = re.search(r"difficulty:\s*(\d+)", chunk)
        grid = _parse_grid(chunk, "grid")

        if not id_match or not diff_match or grid is None:
            continue

        puzzles.append(
            ParsedPuzzle(
                var_name=var_name,
                puzzle_id=id_match.group(1),
                difficulty=int(diff_match.group(1)),
                grid=grid,
                solution=_parse_grid(chunk, "solution"),
                constraints=_parse_constraints(chunk),
            )
        )

    return puzzles
