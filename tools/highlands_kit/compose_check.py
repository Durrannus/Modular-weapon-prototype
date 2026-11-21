#!/usr/bin/env python3
"""Lays a test map out from the cut kit the way the game does, and puts it beside the art thread's own drawing of the same
map, so the two can be compared by eye. It checks the pieces themselves: rock, dug floor, water, yard, and the grass's tone
patches. (The game's painter, scripts/highlands/land_painter.gd, does the same and then adds footpaths, ore, tufts, plants
and lamplight; tools/highlands_shots.gd draws pictures with it.)

    python3 tools/highlands_kit/compose_check.py --kit art/highlands --out /tmp/check.png
"""
import argparse, os, sys
import numpy as np
from PIL import Image

T = 16
ORDER = [(0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)]
ROCKS = "#TC"


def hsh(x, y, salt=0):
    return ((x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)) & 0x7fffffff


class Sheet:
    def __init__(s, path, w, h, cols=32):
        s.a = np.asarray(Image.open(path).convert("RGBA")); s.w, s.h, s.cols = w, h, cols
    def piece(s, k):
        x, y = (k % s.cols) * s.w, (k // s.cols) * s.h
        return s.a[y:y + s.h, x:x + s.w]


def paste(dst, src, x, y):
    """Copy the solid pixels of src onto dst with its top left at x, y."""
    h, w = src.shape[:2]; H, W = dst.shape[:2]
    x0, y0, x1, y1 = max(x, 0), max(y, 0), min(x + w, W), min(y + h, H)
    if x1 <= x0 or y1 <= y0: return
    s = src[y0 - y:y1 - y, x0 - x:x1 - x]; m = s[..., 3] > 0
    dst[y0:y1, x0:x1][m] = s[m]


def compose(rows, tone, kit, V=4):
    H, W = len(rows), len(rows[0])
    def at(x, y): return rows[y][x] if 0 <= x < W and 0 <= y < H else "#"
    def is_rock(x, y): return at(x, y) in ROCKS
    def bits(x, y, same):
        c = 0
        for k, (dx, dy) in enumerate(ORDER):
            if same(x + dx, y + dy): c |= 1 << k
        return c
    G = [(0x4a, 0x3a, 0x3a), (0x6a, 0x56, 0x42), (0x8a, 0x74, 0x48), (0xa6, 0x8e, 0x52), (0xc2, 0xaa, 0x64), (0xdc, 0xc8, 0x88)]
    FLOOR = [(0x19, 0x14, 0x2a), (0x23, 0x22, 0x38)]
    lit = np.zeros((H * T, W * T, 4), np.uint8); lit[..., :3] = G[3]; lit[..., 3] = 255
    shade = lit.copy(); shade[..., :3] = G[1]
    gm, rm = 4, (4, 6, 12, 12)
    S = lambda n, m=24: Sheet(os.path.join(kit, n), m, m)
    def lay(name, same_of):
        A, B = S(name + ".png"), S(name + "_shade.png")
        for y in range(H):
            for x in range(W):
                if not same_of(x, y): continue
                k = (hsh(x, y, 1) % V) * 256 + bits(x, y, same_of)
                paste(lit, A.piece(k), x * T - gm, y * T - gm); paste(shade, B.piece(k), x * T - gm, y * T - gm)
    def tn(x, y): return tone[y][x] if 0 <= x < W and 0 <= y < H else 1
    lay("hollow", lambda x, y: tn(x, y) == 0)
    lay("rise", lambda x, y: tn(x, y) == 2)
    lay("yard", lambda x, y: at(x, y) == "y")
    lay("water", lambda x, y: at(x, y) == "w")
    # dug floor: a flat bed first, so no grass shows between a floor and the rock beside it
    def bed(x0, y0, x1, y1):
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, W * T), min(y1, H * T)
        if x1 > x0 and y1 > y0: lit[y0:y1, x0:x1, :3] = FLOOR[1]; shade[y0:y1, x0:x1, :3] = FLOOR[0]
    for y in range(H):
        for x in range(W):
            c = at(x, y); px, py = x * T, y * T
            if c == "o":
                x0, y0, x1, y1 = px, py, px + T, py + T
                opn = lambda dx, dy: not is_rock(x + dx, y + dy) and at(x + dx, y + dy) != "o"
                if opn(-1, 0): x0 += 5
                if opn(1, 0): x1 -= 5
                if opn(0, -1): y0 += 5
                if opn(0, 1): y1 -= 5
                bed(x0, y0, x1, y1)
            elif is_rock(x, y):
                f = lambda dx, dy: at(x + dx, y + dy) == "o"
                if f(0, -1): bed(px, py, px + T, py + 6)
                if f(0, 1): bed(px, py + T - 6, px + T, py + T)
                if f(-1, 0): bed(px, py, px + 6, py + T)
                if f(1, 0): bed(px + T - 6, py, px + T, py + T)
                if f(-1, -1): bed(px, py, px + 6, py + 6)
                if f(1, -1): bed(px + T - 6, py, px + T, py + 6)
                if f(-1, 1): bed(px, py + T - 6, px + 6, py + T)
                if f(1, 1): bed(px + T - 6, py + T - 6, px + T, py + T)
    lay("floor", lambda x, y: at(x, y) == "o")
    # rock: its shadow first, then the stones at its foot, then the rock itself, top row first
    RW, RH = 16 + rm[0] + rm[2], 16 + rm[1] + rm[3]
    R = {False: Sheet(os.path.join(kit, "rock_nat.png"), RW, RH), True: Sheet(os.path.join(kit, "rock_dug.png"), RW, RH)}
    F = {False: Sheet(os.path.join(kit, "rock_nat_foot.png"), RW, RH), True: Sheet(os.path.join(kit, "rock_dug_foot.png"), RW, RH)}
    SH = Sheet(os.path.join(kit, "rock_shadow.png"), RW, RH); CORE = Sheet(os.path.join(kit, "rock_core.png"), 16, 16, 8)
    M = np.zeros((H * T, W * T, 4), np.uint8)
    info = {}
    for y in range(-1, H + 1):
        for x in range(-1, W + 1):
            if not is_rock(x, y): continue
            cfg = bits(x, y, is_rock); v = hsh(x, y, 2) % V
            dug = any(at(x + dx, y + dy) == "o" for dx, dy in ORDER)
            info[(x, y)] = (cfg, v, dug)
            if cfg != 255: paste(M, SH.piece(v * 256 + cfg), x * T - rm[0], y * T - rm[1])
    m = M[..., 3] > 0
    lit[m] = shade[m]
    for (x, y), (cfg, v, dug) in info.items():
        if cfg != 255: paste(lit, F[dug].piece(v * 256 + cfg), x * T - rm[0], y * T - rm[1])
    for y in range(-1, H + 1):
        for x in range(-1, W + 1):
            if (x, y) not in info: continue
            cfg, v, dug = info[(x, y)]
            if cfg == 255: paste(lit, CORE.piece(hsh(x, y, 3) % 32), x * T, y * T)
            else: paste(lit, R[dug].piece(v * 256 + cfg), x * T - rm[0], y * T - rm[1])
    return lit[..., :3]


def test_rows(hl3):
    G = hl3.Grid(fill="#")
    road = [(0, 13), (8, 13), (14, 12), (22, 12), (30, 11), (39, 10)]; beck = [(33, 0), (32, 3), (34, 6), (35, 9), (35, 13), (34, 16), (33, 19), (32, 22)]
    G.line(road, ".", 3); G.ell(18, 12, 6.6, 4.4, "."); G.line(beck, ".", 3)
    G.ell(8, 4.5, 5.4, 3.3, "."); G.line([(11, 6), (13, 8)], ".", 2)
    G.line([(x + 1, y) for x, y in beck], "w", 1, "."); G.line([(35, 9), (36, 9)], "w", 1, ".")
    G.ell(14, 13, 3.2, 1.6, "y", ".")
    G.rect(22, 16, 23, 18, "o"); G.rect(21, 19, 27, 21, "o"); G.rect(28, 19, 29, 21, "C", "#"); G.rect(24, 22, 26, 22, "C", "#")
    G.rect(3, 10, 5, 11, "T", "#"); G.rect(24, 6, 26, 7, "T", "#")
    return G.rows()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--art", default="/mnt/project-files/art/highlands-concept/v3/code")
    ap.add_argument("--kit", default="art/highlands"); ap.add_argument("--out", default="/tmp/compose_check.png"); ap.add_argument("--variants", type=int, default=4)
    a = ap.parse_args(); sys.path.insert(0, a.art)
    import hl3
    rows = test_rows(hl3); seed = 12
    W = hl3.World(rows, seed)
    truth = np.asarray(W.image())
    R = np.random.RandomState(seed + 9); tn = hl3.blur(R.rand(W.H + 12, W.W + 12), 2.0)[6:-6, 6:-6]
    wet = hl3.dil(W.cells("w"), 1) & ~W.cells("w")
    dark = (tn < np.percentile(tn, 16)) | wet; light = (tn > np.percentile(tn, 74)) & ~dark
    tone = np.where(dark, 0, np.where(light, 2, 1))
    mine = compose(rows, tone, a.kit, a.variants)
    h = min(truth.shape[0], mine.shape[0]); gap = np.zeros((h, 8, 3), np.uint8)
    both = np.concatenate([truth[:h], gap, mine[:h]], 1)
    Image.fromarray(both).save(a.out); Image.fromarray(mine).resize((mine.shape[1] * 2, mine.shape[0] * 2), Image.NEAREST).save(a.out.replace(".png", "_kit2x.png"))
    Image.fromarray(truth).resize((truth.shape[1] * 2, truth.shape[0] * 2), Image.NEAREST).save(a.out.replace(".png", "_art2x.png"))
    print("wrote", a.out)


if __name__ == "__main__":
    main()
