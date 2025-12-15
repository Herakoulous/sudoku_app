import cv2
import pytesseract
from PIL import Image
import os

# === CONFIGURE ===
# Path to your Tesseract executable
pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

# Input screenshot
IMAGE_PATH = r"C:\Users\LAPTOP\OneDrive\projects\sudoku_app\lib\screenshots\puzzle1.jpg"

# Output file
OUTPUT_FILE = r"C:\Users\LAPTOP\OneDrive\projects\sudoku_app\lib\puzzles.txt"

# === FUNCTIONS ===
def extract_sudoku_from_image(image_path):
    img = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
    # Resize to a standard 450x450 for easier splitting
    img = cv2.resize(img, (450, 450))
    h, w = img.shape
    cell_h, cell_w = h // 9, w // 9

    puzzle = ''
    for row in range(9):
        for col in range(9):
            cell = img[row*cell_h:(row+1)*cell_h, col*cell_w:(col+1)*cell_w]
            # Threshold for better OCR
            _, cell = cv2.threshold(cell, 180, 255, cv2.THRESH_BINARY_INV)
            cell_pil = Image.fromarray(cell)
            text = pytesseract.image_to_string(cell_pil, config='--psm 10 digits').strip()
            if text and text[0] in '123456789':
                puzzle += text[0]
            else:
                puzzle += '.'
    return puzzle

# === MAIN ===
puzzle = extract_sudoku_from_image(IMAGE_PATH)
if len(puzzle) == 81:
    print(f"Puzzle extracted successfully:\n{puzzle}")
    # Save to file
    with open(OUTPUT_FILE, 'w') as f:
        f.write(puzzle + '\n')
    print(f"Saved to {OUTPUT_FILE}")
else:
    print(f"[WARN] Puzzle has {len(puzzle)} characters, expected 81. Check the image quality.")
