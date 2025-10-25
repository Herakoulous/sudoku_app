# import os
# def gen(color,row1,col1,row2,col2):
#     if color == "w":
#         type = "KROPKI_WHITE"
#     elif color == "b":
#         type = "KROPKI_BLACK"
#     else :
#         return ""
#     return f"VariantConstraint(\ntype: ConstraintType.{type},\nrow1: {row1},\ncol1:{col1},\nrow2:{row2},\ncol2:{col2},\n),\n"

# b="b"
# w="w"
# dots = [
# ]

# crypted1 = "wwwweeeeeeeeebewbeewwbeeeeeeeeeeeeeeeebewweebeweeeebeeweeeweeweeeeeeeewe"
# crypted2 = "bebeeeebeweweeewweeeeewbeeeweeeewewwebeewbeeeeewebeweeeeebeeewebeewbeebe"
# print("=== crypted1 as grid (9 rows × 8 cols) ===")
# for row in range(9):
#     start = row * 8
#     end = start + 8
#     print(f"{row}: {crypted1[start:end]}")

# print("\n=== crypted2 as grid (9 cols × 8 rows) ===")
# for col in range(9):
#     col_chars = "".join(crypted2[col * 8 + r] for r in range(8))
#     print(f"{col}: {col_chars}")
# print(len(crypted1))
# print(len(crypted2))
# num=0
# col1 = 0
# col2 = 0
# row1 = 0
# row2 = 0
# puzzle= ""
# for k in range(2):
#     for j in range(8):
#         for i in range(9):
#             if k==1:
#                 row1= j 
#                 row2=j 
#                 col1 =i  
#                 col2 = i+1
#                 if (crypted1[row1*8+col1]=="b" or crypted1[row1*8+col1]=="w"):
#                     num+=1
#                     dots.append([crypted1[row1*8+col1],row1,col1,row1,col2])
#             elif k ==0 :
#                 col1= j 
#                 col2=j 
#                 row1 =i
#                 row2 = i+1
#                 if (crypted2[row1*8+col1]=="b" or crypted2[row1*8+col1]=="w"):
#                     num+=1
#                     dots.append([crypted2[row1*8+col1],row1,col1,row2,col1])

# for j in range(len(dots)):
#     print(j)
#     puzzle += gen(dots[j][0],dots[j][1],dots[j][2],dots[j][3],dots[j][4])


# # for row1 in range(9):
# #     for col1 in range(8):
# #         col2=col1 +1
# #         if (crypted1[row1*8+col1]=="b" or crypted1[row1*8+col1]=="w"):
# #             num+=1
# #             dots.append([crypted1[row1*8+col1],row1,col1,row1,col2])

# # puzzle1=""
# # for i in range(len(dots)):
# #     puzzle1 += gen(dots[i][0],dots[i][1],dots[i][2],dots[i][3],dots[i][4])

# # dots = [] 
# # for col1 in range(9):
# #     for row1 in range(8):
# #         row2=row1 +1
# #         if (crypted2[row1*8+col1]=="b" or crypted2[row1*8+col1]=="w"):
# #             num+=1
# #             dots.append([crypted2[row1*8+col1],row1,col1,row2,col1])

# # puzzle2 = ""
# # print(dots)
# # print(len(dots))


# path = os.path.abspath(r"C:\Users\LAPTOP\OneDrive\projects\sudoku_app\lib\fin.txt")
# with open(path, "w") as file:
#     file.write(f"{puzzle}")
# print("number of dots: ",num)

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