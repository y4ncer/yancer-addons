"""Generate yancer-ui/Media/Shadow.tga.

A 64x64 white texture whose alpha falls off radially from the centre.
The addon slices it 9-patch style with SetTexCoord: the four quadrants are
the shadow corners and the centre row/column are the stretched edges.
Radial symmetry means TGA row order doesn't matter.

Usage: python tools/gen_shadow.py
"""
import math
import os
import struct

SIZE = 64
HALF = SIZE / 2
OUT = os.path.join(os.path.dirname(__file__), "..", "yancer-ui", "Media", "Shadow.tga")


def alpha(x, y):
    d = math.hypot(x + 0.5 - HALF, y + 0.5 - HALF)
    t = max(0.0, 1.0 - d / HALF)
    return round(255 * t * t)


def main():
    # Uncompressed true-colour TGA, 32bpp, 8 alpha bits.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8)
    pixels = bytearray()
    for y in range(SIZE):
        for x in range(SIZE):
            pixels += bytes((255, 255, 255, alpha(x, y)))  # BGRA
    with open(OUT, "wb") as f:
        f.write(header + pixels)
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
