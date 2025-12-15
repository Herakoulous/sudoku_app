# "wwwweeeeeeeeebewbeewwbeeeeeeeeeeeeeeeebewweebeweeeebeeweeeweeweeeeeeeewe" 
# "bebeeeebeweweeewweeeeewbeeeweeeewewwebeewbeeeeewebeweeeeebeeewebeewbeebe"

# "eewweweeeebeeewbewewwweewbeeeeeebeeeeeeewweweweeeeeeweebeeweweeebwebebee"
# "bbewwwweeeeweebebeebeeewwwebbeeeeeeeeeeeeeeeeweeeeeeweebewewbewewewweewe"

# "eeewewbeweweeewweeeeweeeeeebweweeeweeeeweeeeewbweeeebeewweeebeewebweeeee"
# "ebeeeeeeebeewweeeeewebewebweeweeeweebeweeeeebeeebeeeeweweeebeweeeebeeebe"

# "eeweweeebwebeweeeewweweewweeeeeeeweeeebbeewebbebbebeweeeeeeeeeeeeeewewee"
# "ewebeeweeeebweweeeweweeeeeeeeeeeeeeeweeeeeeeeeewewwebebeeweweewweewweeeb"

# "beebeeebeeeewebeeeeebeeeeeweebeeeeeeweweeweeebeeeeeeeeeeeeeebewebeeeeeee"
# "weweeeewwweweeeweeeweeeweewbweeeeewwbeebeebeeeewweeeweeeeweeweeeebeeweew"
import os

# --- Converts a color code ('w' or 'b') into a constraint string ---
def gen(color, col1, row1, col2, row2):
    if color == "w":
        type_ = "KROPKI_WHITE"
    elif color == "b":
        type_ = "KROPKI_BLACK"
    else:
        return ""  # no constraint for 'e'
    return (
        f"VariantConstraint(\n"
        f"  type: ConstraintType.{type_},\n"
        f"  row1: {row1},\n"
        f"  col1: {col1},\n"
        f"  row2: {row2},\n"
        f"  col2: {col2},\n"
        f"),\n"
    )

# --- Encoded data: 'w' = white dot, 'b' = black dot, 'e' = empty ---
crypted2 = "eweeebweeeebeeeeeeewweeewweeebeeeweebweeeweeeweweeeeeweeeeeweebeewebweee"    # horizontal
crypted1 = "eeeweeweewbeeeeeeeeewbeeeeeeewebweweweeeeeebeweeebeeeweeewewewweeebeeeew"  # vertical

print("crypted1 length:", len(crypted1))  # should be 72
print("crypted2 length:", len(crypted2))  # should be 72

# --- Horizontal constraints (row-wise) ---
dots = []
for row in range(9):        # 9 rows
    for col in range(8):    # 8 horizontal adjacencies
        idx = row * 8 + col
        color = crypted1[idx]
        if color in ("b", "w"):
            dots.append([color, row, col, row, col + 1])

# Generate puzzle1
puzzle1 = "".join(gen(*dot) for dot in dots)
print(f"Horizontal dots: {len(dots)}")

# --- Vertical constraints (column-wise) ---
dots = []
for col in range(9):        # 9 columns
    for row in range(8):    # 8 vertical adjacencies
        idx = col * 8 + row  # Correct indexing!
        color = crypted2[idx]
        if color in ("b", "w"):
            dots.append([color, row, col, row + 1, col])

# Generate puzzle2
puzzle2 = "".join(gen(*dot) for dot in dots)
print(f"Vertical dots: {len(dots)}")

# --- Write both to file ---
path = os.path.abspath(r"C:\Users\LAPTOP\OneDrive\projects\sudoku_app\lib\fin.txt")
with open(path, "w") as file:
    file.write(puzzle1)
    file.write("\n")
    file.write(puzzle2)

print(f"✅ Done! File written to: {path}")