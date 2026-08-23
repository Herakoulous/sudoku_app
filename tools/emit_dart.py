"""
Writes lib/data/puzzles.dart from the generated puzzle sets.

Classic puzzles are carried over from the existing file unchanged, ids included:
they audited clean, and their ids are the keys player progress is saved under.
Variant puzzles are replaced wholesale, since the shipped ones were broken.
"""

from __future__ import annotations

import io
import json
import os

from dart_puzzles import load_puzzles

ALPHABET = (
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "abcdefghijklmnopqrstuvwxyz"
    "0123456789"
    "!#%&()*+,-./:<=>?@["
)
assert len(ALPHABET) == 81, f"alphabet must be 81 chars, got {len(ALPHABET)}"
assert len(set(ALPHABET)) == 81, "alphabet has duplicates"

# Must mirror PuzzleCodec in lib/data/puzzle_codec.dart.
TOKEN_LETTER = {
    "KROPKI_WHITE": "W",
    "KROPKI_BLACK": "B",
    "XV_X": "X",
    "XV_V": "V",
    "GERMAN_WHISPERS": "G",
}

# family -> (dart variable prefix, id prefix, getter name)
FAMILIES = [
    ("classic", "classic", "classic ", "getClassicPuzzles"),
    ("kropki", "kropki", "kropki_", "getKropkiPuzzles"),
    ("thermo", "thermo", "thermo_", "getThermoPuzzles"),
    ("xv", "xv", "xv_", "getXvPuzzles"),
    ("germanwhispers", "germanwhispers", "germanwhispers_", "getGermanWhispersPuzzles"),
    ("sandwich", "sandwich", "sandwich_", "getSandwichPuzzles"),
]


def cell_char(row: int, col: int) -> str:
    return ALPHABET[row * 9 + col]


def encode_grid(grid) -> str:
    return "".join(str(v) for row in grid for v in row)


def encode_constraints(constraints) -> str:
    tokens = []

    for con in constraints:
        kind = con["kind"]

        if kind in TOKEN_LETTER:
            (r1, c1), (r2, c2) = con["cells"]
            tokens.append(
                TOKEN_LETTER[kind] + cell_char(r1, c1) + cell_char(r2, c2)
            )
        elif kind == "THERMO":
            tokens.append(
                "T" + "".join(cell_char(r, c) for r, c in con["cells"])
            )
        elif kind == "SANDWICH":
            letter = "R" if con["line_is_row"] else "C"
            tokens.append(
                letter + ALPHABET[con["line_index"]] + ALPHABET[con["total"]]
            )

    return ";".join(tokens)


def constraint_from_parsed(con) -> dict:
    """Converts a Constraint dataclass (from the old file) to the JSON shape."""
    if con.kind == "SANDWICH":
        return {
            "kind": con.kind,
            "line_is_row": con.line_is_row,
            "line_index": con.line_index,
            "total": con.total,
        }
    return {"kind": con.kind, "cells": [list(c) for c in con.cells]}


def read_existing_classic(path: str) -> list[dict]:
    """
    Reads the classic puzzles already in puzzles.dart.

    Handles both the original verbose form and the compact form this script
    emits, so re-running the emitter is idempotent rather than wiping classic on
    the second pass.
    """
    source = io.open(path, encoding="utf-8").read()

    if "grid: '" in source:
        from verify_emitted import decode_grid, parse_emitted

        return [
            {
                "id": p["id"],
                "difficulty": p["difficulty"],
                "grid": decode_grid(p["grid"]),
                "solution": decode_grid(p["solution"]) if p["solution"] else None,
                "constraints": [],
            }
            for p in parse_emitted(path)
            if p["id"].startswith("classic")
        ]

    return [
        {
            "id": p.puzzle_id,
            "difficulty": p.difficulty,
            "grid": p.grid,
            "solution": p.solution,
            "constraints": [],
        }
        for p in load_puzzles(path)
        if p.family == "classic"
    ]


def load_classic(path: str) -> list[dict]:
    """
    Existing classic puzzles plus any generated fill-ins.

    The originals keep their exact ids — those ids are the keys player progress
    is stored under, so renumbering them would silently orphan every save.
    New puzzles are appended with ids continuing the sequence.
    """
    out = []
    for p in read_existing_classic(path):
        out.append(p)

    extra_path = "generated/classic_extra.json"
    if os.path.exists(extra_path):
        extra = json.loads(io.open(extra_path, encoding="utf-8").read())
        next_number = len(out) + 1

        for p in sorted(extra["puzzles"], key=lambda x: x["difficulty"]):
            out.append(
                {
                    "id": f"classic {next_number}",
                    "difficulty": p["difficulty"],
                    "grid": p["grid"],
                    "solution": p["solution"],
                    "constraints": [],
                }
            )
            next_number += 1

    return out


def load_generated(family: str) -> list[dict]:
    path = f"generated/{family}.json"
    if not os.path.exists(path):
        return []

    data = json.loads(io.open(path, encoding="utf-8").read())
    puzzles = sorted(data["puzzles"], key=lambda p: (p["difficulty"], p["givens"]))

    return [
        {
            "id": None,  # assigned below
            "difficulty": p["difficulty"],
            "grid": p["grid"],
            "solution": p["solution"],
            "constraints": p["constraints"],
        }
        for p in puzzles
    ]


def emit(out_path: str, ratings: dict[str, int] | None = None) -> None:
    sections: list[tuple[str, str, list[tuple[str, dict]]]] = []

    for family, var_prefix, id_prefix, getter in FAMILIES:
        if family == "classic":
            puzzles = load_classic("../lib/data/puzzles.dart")
            for p in puzzles:
                if ratings and p["id"] in ratings:
                    p["difficulty"] = ratings[p["id"]]
            named = [
                (f"{var_prefix}{i + 1}", p) for i, p in enumerate(puzzles)
            ]
        else:
            puzzles = load_generated(family)
            for i, p in enumerate(puzzles):
                p["id"] = f"{id_prefix}{i + 1}"
            named = [
                (f"{var_prefix}{i + 1}", p) for i, p in enumerate(puzzles)
            ]

        sections.append((family, getter, named))

    lines: list[str] = []
    add = lines.append

    add("// AUTO-GENERATED FILE - DO NOT EDIT MANUALLY")
    add("//")
    add("// Regenerate with:")
    add("//   cd tools")
    add("//   python build_puzzle_set.py <family> 5")
    add("//   python emit_dart.py")
    add("//")
    add("// Every puzzle below has been verified to have exactly one solution")
    add("// under its own variant rules. See tools/audit_puzzles.py.")
    add("//")
    add("// Data is stored in the compact form described in puzzle_codec.dart;")
    add("// grids and constraints are decoded on first access.")
    add("")
    add("import 'puzzle_codec.dart';")
    add("")
    add("export 'puzzle_codec.dart' show PuzzleData;")
    add("")
    add("class Puzzles {")

    for family, getter, named in sections:
        total = len(named)
        add("")
        add(f"  // {'=' * 73}")
        add(f"  // {family.upper()} — {total} puzzles")
        add(f"  // {'=' * 73}")
        add("")

        for var_name, p in named:
            constraints = encode_constraints(p["constraints"])

            add(f"  static final PuzzleData {var_name} = PuzzleData(")
            add(f"    id: '{p['id']}',")
            add(f"    difficulty: {p['difficulty']},")
            add(f"    grid: '{encode_grid(p['grid'])}',")
            if p["solution"] is not None:
                add(f"    solution: '{encode_grid(p['solution'])}',")
            if constraints:
                add(f"    constraints: '{constraints}',")
            add("  );")

    # --- getters ---
    for family, getter, named in sections:
        add("")
        add(f"  static List<PuzzleData> {getter}() => [")
        for var_name, _ in named:
            add(f"        {var_name},")
        add("      ];")

    # --- lookup ---
    add("")
    add("  static PuzzleData? getPuzzle(String id) => allPuzzles[id];")
    add("")
    add("  static List<String> getAllPuzzleIds() => allPuzzles.keys.toList();")
    add("")
    add("  static final Map<String, PuzzleData> allPuzzles = {")
    for family, getter, named in sections:
        for var_name, p in named:
            add(f"    '{p['id']}': {var_name},")
    add("  };")
    add("}")
    add("")

    io.open(out_path, "w", encoding="utf-8", newline="\n").write("\n".join(lines))

    print(f"wrote {out_path}")
    for family, _, named in sections:
        print(f"  {family:<16} {len(named):>4} puzzles")


if __name__ == "__main__":
    ratings = None
    if os.path.exists("generated/classic_ratings.json"):
        ratings = json.loads(
            io.open("generated/classic_ratings.json", encoding="utf-8").read()
        )
        print(f"applying {len(ratings)} HoDoKu classic ratings")

    emit("../lib/data/puzzles.dart", ratings)
