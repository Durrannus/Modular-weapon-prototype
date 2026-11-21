#!/usr/bin/env python3
"""Cuts the Greystone Highlands land kit for the game out of the art thread's own drawing code.

The look lives in hl3.py (the land) and hl3_props.py (the things that stand on it), written by the art thread and kept in
/mnt/project-files/art/highlands-concept/v3/code/. This tool imports them, draws a small patch of land for every way a tile
can meet its eight neighbours, and cuts the pieces the game lays out again per map chunk (scripts/highlands/land_painter.gd).
So the game shows the art thread's pixels, and when the art changes this is run again:

    python3 tools/highlands_kit/bake.py            # writes art/highlands/
    python3 tools/highlands_kit/bake.py --only rock --variants 2 --out /tmp/kit   # a quick partial run

Needs numpy and Pillow. Nothing here runs in the game.
"""
import argparse, json, os, sys, time
import numpy as np
from PIL import Image

ART_CODE = "/mnt/project-files/art/highlands-concept/v3/code"
T = 16                      # one tile, in art pixels
N, C = 7, 3                 # a patch is 7x7 tiles; the tile being cut is the middle one
ORDER = [(0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)]   # bit 0..7: N NE E SE S SW W NW (1 = same kind)
ROCK_M = (4, 6, 12, 12)     # how far a rock piece reaches past its tile: left, top, right, bottom (the far sides hold its shadow)
GROUND_M = (4, 4, 4, 4)
COLS = 32                   # pieces per atlas row; piece number = variant * 256 + neighbour bits


def rows_for(cfg, own, other):
    """A 7x7 patch: the middle tile is `own`, its eight neighbours follow the bits, the rest repeat the nearest of those."""
    out = []
    for j in range(N):
        r = ""
        for i in range(N):
            dx, dy = min(max(i, C - 1), C + 1) - C, min(max(j, C - 1), C + 1) - C
            r += own if (dx == 0 and dy == 0) or (cfg >> ORDER.index((dx, dy))) & 1 else other
        out.append(r)
    return out


def cell_px(m):
    """Tiles to pixels."""
    return np.kron(np.asarray(m), np.ones((T, T), bool)).astype(bool)


class Kit:
    def __init__(s, hl3, variants):
        s.hl3 = hl3; s.V = variants
        s.x0 = s.y0 = C * T
        yy, xx = np.mgrid[0:N * T, 0:N * T]
        s.yy, s.xx = yy, xx
        s.own = (xx >= s.x0) & (xx < s.x0 + T) & (yy >= s.y0) & (yy < s.y0 + T)

    # ------------------------------------------------------------------ colour
    def rgb(s, W, drop=0):
        """The picture's colours; drop = how many ramp steps darker (a shadow is two, on water one)."""
        hl3 = s.hl3
        st = W.step.astype(int)
        if drop:
            st = st - np.where(W.mat == hl3.MID["water"], 1, 2) * (drop // 2)
        st = np.clip(st, 0, hl3.TOPS[W.mat])
        return hl3.LUT[W.mat, st]

    def canvas(s, margins):
        l, t, r, b = margins
        return (s.x0 - l, s.y0 - t, s.x0 + T + r, s.y0 + T + b)

    def cut(s, rgb, mask, margins):
        x0, y0, x1, y1 = s.canvas(margins)
        out = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
        out[..., :3] = rgb[y0:y1, x0:x1]; out[..., 3] = np.where(mask[y0:y1, x0:x1], 255, 0)
        out[out[..., 3] == 0] = 0
        return out

    def nearest_own(s, kind_cells, reach):
        """Pixels outside the tile that belong to it: within `reach` px of it and no nearer to another tile of its kind."""
        d_own = np.maximum(np.maximum(s.x0 - s.xx, s.xx - (s.x0 + T - 1)), np.maximum(s.y0 - s.yy, s.yy - (s.y0 + T - 1))).clip(0)
        best = np.full(d_own.shape, 999)
        for j in range(N):
            for i in range(N):
                if (i, j) == (C, C) or not kind_cells[j][i]: continue
                d = np.maximum(np.maximum(i * T - s.xx, s.xx - (i * T + T - 1)), np.maximum(j * T - s.yy, s.yy - (j * T + T - 1))).clip(0)
                best = np.minimum(best, d)
        return (d_own <= reach) & (d_own <= best)

    # ------------------------------------------------------------------ rock
    def rock(s, cfg, v, dug):
        hl3 = s.hl3
        rows = rows_for(cfg, "#", "o" if dug else ".")
        W = hl3.World(rows, seed=v + 1, tone=False)
        cells = [[ch == "#" for ch in r] for r in rows]
        incell = cell_px(cells)
        mine = s.own | (~incell & s.nearest_own(cells, ROCK_M[0]))
        keep = W.rock & mine
        # the top of this tile's own face, and the dark line above it, where they reach into the rock tile above
        if not (cfg >> 4) & 1:
            face_top = np.where(W.face, W.hgt, -1).max(0)                      # per column: how tall the face is
            lip = W.capm & (W.hgt <= face_top[None, :] + 3) & (face_top[None, :] >= 0)
            over = (W.face | lip) & (s.xx >= s.x0) & (s.xx < s.x0 + T) & (s.yy < s.y0) & (s.yy >= s.y0 - ROCK_M[1])
            keep |= over & W.rock
        rgb = s.rgb(W)
        piece = s.cut(rgb, keep, ROCK_M)
        # the shadow this tile's rock throws (down and to the right), and the dark at its foot
        cast = np.zeros_like(keep)
        for d in range(1, 8): cast |= hl3.shiftm(keep, d, d)
        foot = keep & W.face & (W.hgt == 0)
        cast |= hl3.shiftm(foot, 1, 0) | hl3.shiftm(foot, 2, 0)
        # rubble at the foot of the face: small stones lying on the ground, already in their shadow
        rub = (~W.rock) & (W.mat == hl3.MID["face"]) & s.nearest_own(cells, ROCK_M[3] - 1) & ~s.own
        rub_sh = W.shadow | cast
        st = np.clip(W.step.astype(int) - np.where(rub_sh, 2, 0), 0, hl3.TOPS[W.mat])
        under = s.cut(hl3.LUT[W.mat, st], rub, ROCK_M)
        near = hl3.dil(rub, 2) & W.shadow & ~W.rock                              # the stones' own little shadows
        shadow = s.cut(np.full(rgb.shape, 255, np.uint8), (cast | near) & ~keep, ROCK_M)
        ores = [s.ore(W, keep, kind, cfg * 8 + v * 2 + n) for n, kind in enumerate(("tin", "copper"))]
        return piece, under, shadow, ores

    def ore(s, W, keep, kind, seed):
        """Ore showing in this tile's rock, as a layer over the rock piece. The art's own rule and pixels (hl3.py, "ore": white
        square tin crystals, round copper nuggets with a green crust, on a lit face or a lit rim, never on a dark top), kept
        inside this one tile so the game can lay it per tile and take it away when the tile is mined."""
        hl3 = s.hl3; MID = hl3.MID; R = np.random.RandomState(1000 + seed)
        mat = W.mat.copy(); step = W.step.astype(int).copy(); h, w = mat.shape
        def pix(x, y, m, st):
            if 0 <= x < w and 0 <= y < h: mat[y, x] = MID[m]; step[y, x] = st
        n = 0
        for _ in range(60):
            x, y = s.x0 + R.randint(1, T - 4), s.y0 + R.randint(-2, T - 3)
            if not keep[y:y + 3, x:x + 3].all(): continue
            onface = W.face[y:y + 3, x:x + 3].all()
            if not onface and (not W.capm[y:y + 3, x:x + 3].all() or W.step[y + 1, x + 1] < 2 or R.rand() < 0.7): continue
            if (mat[y - 1:y + 4, x - 1:x + 4] == MID[kind]).any(): continue
            if kind == "tin":
                z = 3 if R.rand() < 0.4 else 2
                mat[y:y + z, x:x + z] = MID["tin"]; step[y:y + z, x:x + z] = hl3.TIN_FACE[0] if onface else 1
                pix(x, y, "tin", hl3.TIN_FACE[1] if onface else hl3.TIN_FACE[0]); pix(x + z - 1, y + z - 1, "tin", 1 if onface else 0)
                pix(x + z, y + z, "face" if onface else "cap", 1 if onface else 0)
            else:
                for j in range(3):
                    for i in range(3):
                        if (j - 1) ** 2 + (i - 1) ** 2 < 2: pix(x + i, y + j, "copper", 3 if onface else 2)
                pix(x + 1, y, "copper", 4 if onface else 3); pix(x + 2, y + 2, "copper", 1)
                pix(x - 1, y + 1, "verd", 2 if onface else 1); pix(x + 1, y + 3, "verd", 1)
            n += 1
            if n >= 5: break
        changed = ((mat != W.mat) | (step != W.step)) & keep
        st = np.clip(step, 0, hl3.TOPS[mat])
        return s.cut(hl3.LUT[mat, st], changed, ROCK_M)

    def rock_core(s, n):
        """The heart of a hill: the cave's own dark wall top with a few strokes. Cut from one big block of rock."""
        hl3 = s.hl3
        W = hl3.World(["#" * 12] * 12, seed=3, tone=False)
        rgb = s.rgb(W); out = []
        k = 0
        for j in range(2, 10):
            for i in range(2, 10):
                if k >= n: break
                a = np.zeros((T, T, 4), np.uint8); a[..., :3] = rgb[j * T:(j + 1) * T, i * T:(i + 1) * T]; a[..., 3] = 255
                out.append(a); k += 1
        return out

    # ------------------------------------------------------------------ ground kinds laid on the grass
    def ground(s, cfg, v, ch):
        """Yard, water, dug floor, scree: whatever the kind changes in the picture, cut where it is not plain grass."""
        hl3 = s.hl3
        rows = rows_for(cfg, ch, ".")
        W = hl3.World(rows, seed=v + 1, tone=False)
        cells = [[c == ch for c in r] for r in rows]
        incell = cell_px(cells)
        changed = ~W.plain & ~((W.mat == hl3.MID["grass"]) & (W.step == 3))
        if ch == "o": changed = W.floor
        mine = s.own | (~incell & s.nearest_own(cells, GROUND_M[0]))
        keep = changed & mine
        return s.cut(s.rgb(W), keep, GROUND_M), s.cut(s.rgb(W, 2), keep, GROUND_M)

    def path(s, cfg, v):
        """A footpath. The art's own wander is by world position and cannot be cut into tiles, so it is switched off while
        these are drawn: in the game the path wanders because the map's route does, tile by tile."""
        np_sin = np.sin
        np.sin = lambda a: np.zeros(np.shape(a))
        try:
            return s.ground(cfg, v, "e")
        finally:
            np.sin = np_sin

    def tone(s, cfg, v, step):
        """A hollow (grass one step darker) or a rise (one lighter): only the shape matters."""
        hl3 = s.hl3
        W = hl3.World(["." * N] * N, seed=v + 1, tone=False)
        cells = np.array([[c == "x" for c in r] for r in rows_for(cfg, "x", ".")])
        m = W.mask(cells, 7, 1, 0.03)
        mine = s.own | (~cell_px(cells) & s.nearest_own(cells.tolist(), GROUND_M[0]))
        keep = m & mine
        g = hl3.PAL["grass"]
        lit = np.zeros(W.mat.shape + (3,), np.uint8); lit[:] = g[step]
        dark = np.zeros_like(lit); dark[:] = g[max(0, step - 2)]
        return s.cut(lit, keep, GROUND_M), s.cut(dark, keep, GROUND_M)


GRASS_FOOT = 3     # the grass step a thing's foot tufts are drawn for


class Things:
    """Everything that stands on the land, as a sprite with its foot point and the shadow it throws."""
    def __init__(s, hl3, PR):
        s.hl3, s.PR = hl3, PR; s.items = {}

    def add(s, name, pair, foot="tuft", shadow=True, sink=0, slen=20.0, seed=0, solid=None):
        hl3 = s.hl3
        im, (fx, fy) = pair
        a = im.a.copy()
        if sink: a[max(0, fy - sink):] = 0
        pad = 6
        A = np.zeros((a.shape[0] + pad * 2, a.shape[1] + pad * 2, 4), np.uint8); A[pad:pad + a.shape[0], pad:pad + a.shape[1]] = a
        fx, fy = fx + pad, fy + pad + sink
        solidm = A[..., 3] > 0
        if foot in ("tuft", "peb") and solidm.any():                     # the ground reaches up onto it
            R = np.random.RandomState(seed + 77)
            rows_ = np.nonzero(solidm.any(1))[0]; by = rows_[-1]; cols = np.nonzero(solidm[max(0, by - 2):by + 1].any(0))[0]
            x0, x1 = cols[0], cols[-1]; n = max(1, (x1 - x0 + 4) // 7); g = hl3.PAL["grass"]; b = GRASS_FOOT
            for i in range(n):
                x = x0 + int((i + 0.5) * (x1 - x0 + 1) / n) + R.randint(-1, 2) - 1; y = by - 1
                if foot == "tuft":
                    for (dx, dy, c) in ((0, 1, g[b]), (0, 0, g[b + 1]), (1, 1, g[b]), (2, 1, g[b]), (2, 0, g[b + 1]), (2, -1, g[min(5, b + 2)]), (3, 1, g[b]), (4, 1, g[b]), (4, 0, g[b + 1])):
                        if 0 <= y + dy < A.shape[0] and 0 <= x + dx < A.shape[1]: A[y + dy, x + dx] = (*c, 255)
                else:
                    for (dx, c) in ((0, hl3.ST[5]), (1, hl3.ST[3])):
                        if 0 <= y + 1 < A.shape[0] and 0 <= x + dx < A.shape[1]: A[y + 1, x + dx] = (*c, 255)
        item = {"img": A, "foot": [int(fx), int(fy)]}
        if solid: item["solid"] = solid
        if shadow and solidm.any():                                     # thrown down and to the right, and hugging the base
            ys, xs = np.nonzero(solidm)
            kq = np.clip(fy - 1 - ys, 0, 999) * min(1.0, slen / max(1, fy - ys.min()))
            X = xs - fx + (kq * 0.70).astype(int) + 1; Y = (kq * 0.42).astype(int) - 1
            pts = set(zip(X.tolist(), Y.tolist()))
            low = ys >= fy - 3
            for dx_, dy_ in ((0, 1), (1, 1), (1, 0), (2, 1)):
                pts |= set(zip((xs[low] - fx + dx_).tolist(), (ys[low] - fy + dy_).tolist()))
            xs_ = [p[0] for p in pts]; ys_ = [p[1] for p in pts]
            mx, my = min(xs_), min(ys_)
            M = np.zeros((max(ys_) - my + 1, max(xs_) - mx + 1, 4), np.uint8)
            for (x, y) in pts: M[y - my, x - mx] = 255
            item["shadow_img"] = M; item["shadow_at"] = [int(mx), int(my)]
        s.items[name] = item

    def low_shadow(s, name):
        """The thin shadow a bush lying on the ground throws: a line under it and a tick at its right (hl3.py, "plants")."""
        it = s.items[name]; a = it["img"][..., 3] > 0; fx, fy = it["foot"]
        xs = np.nonzero(a.any(0))[0]; x0, x1 = xs[0] + 1, xs[-1] - 1                # the bush itself, inside its outline
        pts = [(x - fx, 1) for x in range(x0 + 2, x1 + 4)] + [(x1 + 2 - fx, -1), (x1 + 2 - fx, 0)]
        mx = min(p[0] for p in pts); my = min(p[1] for p in pts)
        M = np.zeros((max(p[1] for p in pts) - my + 1, max(p[0] for p in pts) - mx + 1, 4), np.uint8)
        for (x, y) in pts: M[y - my, x - mx] = 255
        it["shadow_img"] = M; it["shadow_at"] = [int(mx), int(my)]

    def strip(s, name, pairs, **kw):
        """Frames of one animal: the same canvas and foot, side by side."""
        frames = []
        for k, pair in enumerate(pairs):
            s.add("%s#%d" % (name, k), pair, **kw); frames.append(s.items.pop("%s#%d" % (name, k)))
        h = max(f["img"].shape[0] for f in frames); w = max(f["img"].shape[1] for f in frames)
        A = np.zeros((h, w * len(frames), 4), np.uint8)
        for k, f in enumerate(frames): A[:f["img"].shape[0], k * w:k * w + f["img"].shape[1]] = f["img"]
        item = {"img": A, "foot": frames[0]["foot"], "frames": len(frames), "frame_w": w}
        if "shadow_img" in frames[0]: item["shadow_img"] = frames[0]["shadow_img"]; item["shadow_at"] = frames[0]["shadow_at"]
        s.items[name] = item

    def decal(s, name, lit, shade, at):
        s.items[name] = {"img": lit, "foot": [0, 0], "at": at}; s.items[name + "~"] = {"img": shade, "foot": [0, 0], "at": at}

    def pack(s, path_png, width=768):
        """Shelves, tallest first. Returns where everything went."""
        todo = []
        for name, it in s.items.items():
            todo.append((name, "img", it["img"]))
            if "shadow_img" in it: todo.append((name, "shadow_img", it["shadow_img"]))
        todo.sort(key=lambda t: (-t[2].shape[0], t[0], t[1]))
        x = y = shelf = 0; places = []
        for name, key, a in todo:
            h, w = a.shape[:2]
            if x + w > width: x = 0; y += shelf + 1; shelf = 0
            places.append((name, key, x, y, a)); x += w + 1; shelf = max(shelf, h)
        out = np.zeros((y + shelf, width, 4), np.uint8); table = {}
        for name, key, x, y, a in places:
            h, w = a.shape[:2]; out[y:y + h, x:x + w] = a
            e = table.setdefault(name, {})
            if key == "img":
                e["rect"] = [x, y, w, h]; e["foot"] = s.items[name]["foot"]
                for k in ("frames", "frame_w", "solid", "at"):
                    if k in s.items[name]: e[k] = s.items[name][k]
            else:
                e["shadow"] = [x, y, w, h]; e["shadow_at"] = s.items[name]["shadow_at"]
        Image.fromarray(out, "RGBA").save(path_png)
        return table


def bake_things(hl3, PR, K, out):
    import hl_flora as FL
    TH = Things(hl3, PR)
    for k, tall in enumerate((60, 62, 64, 66, 44, 46)): TH.add("pine_%d" % k, PR.pine(k * 7 + 3, tall), seed=k, solid=[6, 4])
    for k, (w, h) in enumerate(((14, 10), (16, 11), (18, 12), (12, 8), (11, 8), (13, 9))): TH.add("boulder_%d" % k, PR.boulder(k * 5 + 1, w, h), sink=1, seed=k, solid=[w - 2, 5])
    for k, fl in enumerate((None, True, False, True)): TH.add("bush_%d" % k, PR.bush(k * 3 + 2, fl), seed=k, solid=[14, 5])
    for k in range(2): TH.add("stone_%d" % k, PR.stone(k * 4 + 1), seed=k, solid=[8, 4])
    for k in range(2): TH.add("cairn_%d" % k, PR.cairn(k + 1), foot="peb", seed=k, solid=[10, 4])
    TH.add("post", PR.keeper_post(), solid=[5, 3]); TH.add("stump", PR.stump(), solid=[6, 3])
    for k in range(4): TH.add("bracken_%d" % k, PR.bracken(k + 1), foot="none", shadow=False)
    for k in range(4): TH.add("reeds_%d" % k, PR.reeds(k + 1), foot="none", shadow=False)
    for k in range(3): TH.add("cotton_%d" % k, PR.cotton(k + 1), foot="none", shadow=False)
    TH.add("bones", PR.bones(), foot="none", shadow=False)
    TH.add("cave_mouth", PR.cave_mouth(), foot="peb", shadow=False)
    TH.add("lantern", PR.lantern(), foot="none")
    TH.add("barrel", PR.barrel(), foot="peb", solid=[10, 5])
    TH.add("rubble", PR.rubble(), foot="none", shadow=False)
    for name, fn in (("cow", PR.cow), ("hare", PR.hare), ("crow", PR.crow)):
        order = []
        for f, _t in PR.ANIMALS[name]:
            if f not in order: order.append(f)
        TH.strip(name, [fn(f) for f in order], foot="none")
        TH.items[name]["order"] = order
    TH.items["cow"]["solid"] = [22, 6]
    def plant(kind, seed, drop):
        """The art's own bush (hl3_props.ground_plant), and the same bush two steps darker for when it stands in a shadow."""
        R = np.random.RandomState(seed); cells = (hl3.heath_plant if kind == "heath" else hl3.scrub_plant)(R)
        xs = [c[0] for c in cells]; ys = [c[1] for c in cells]; x0, y0 = min(xs), min(ys)
        o = PR.Im(max(xs) - x0 + 1, max(ys) - y0 + 1)
        for (dx, dy), (mt, st_) in cells.items(): o.px(dx - x0, dy - y0, hl3.PAL[mt][max(0, st_ - drop)])
        return PR.ink(o), (-x0 + 1, -y0 + 2)
    for kind in ("heath", "scrub"):
        for k in range(12):
            TH.add("%s_%d" % (kind, k), plant(kind, k * 3 + 1, 0), foot="none", shadow=False); TH.low_shadow("%s_%d" % (kind, k))
            TH.add("%s_%d~" % (kind, k), plant(kind, k * 3 + 1, 2), foot="none", shadow=False)
    # scraps of the keepers' road: whole pieces, because its flagstones do not follow the tile grid
    roads = [[(2, 3), (8, 3)], [(2, 3), (7, 3), (7, 4), (2, 4)], [(3, 2), (3, 7)], [(2, 2), (5, 3), (8, 5)], [(2, 3), (4, 3), (4, 4), (2, 4)], [(2, 4), (6, 3), (10, 3)]]
    for k, pts in enumerate(roads):
        for sd in range(2):
            G = hl3.Grid(13, 10, fill="."); G.line(pts, "=", 1)
            W = hl3.World(G.rows(), seed=40 + k * 2 + sd, tone=False)
            m = W.road & ~((W.mat == hl3.MID["grass"]) & (W.step == 3))
            ys, xs = np.nonzero(m); x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
            st = np.clip(W.step.astype(int) - np.where(W.shadow, 2, 0), 0, hl3.TOPS[W.mat])
            lit = np.zeros((y1 - y0, x1 - x0, 4), np.uint8); lit[..., :3] = hl3.LUT[W.mat, st][y0:y1, x0:x1]; lit[..., 3] = np.where(m[y0:y1, x0:x1], 255, 0); lit[lit[..., 3] == 0] = 0
            sh = lit.copy(); sh[..., :3] = K.rgb(W, 2)[y0:y1, x0:x1]; sh[sh[..., 3] == 0] = 0
            cx, cy = (pts[0][0] + pts[-1][0]) * 8 + 8, (pts[0][1] + pts[-1][1]) * 8 + 8     # the middle of the run, in px
            TH.decal("road_%d" % (k * 2 + sd), lit, sh, [int(x0 - cx), int(y0 - cy)])
    table = TH.pack(os.path.join(out, "things.png"))
    for name in ("cow", "hare", "crow"):
        table[name]["order"] = TH.items[name]["order"]; table[name]["times"] = [[f, t] for f, t in PR.ANIMALS[name]]
    return table


def palette(hl3):
    hexs = lambda cs: ["%02x%02x%02x" % tuple(c) for c in cs]
    return {k: hexs(v) for k, v in hl3.PAL.items()}


def sheet(pieces, cols=COLS):
    h, w = pieces[0].shape[:2]
    rows = (len(pieces) + cols - 1) // cols
    out = np.zeros((rows * h, cols * w, 4), np.uint8)
    for k, p in enumerate(pieces):
        out[(k // cols) * h:(k // cols + 1) * h, (k % cols) * w:(k % cols + 1) * w] = p
    return Image.fromarray(out, "RGBA")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--art", default=ART_CODE)
    ap.add_argument("--out", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "highlands"))
    ap.add_argument("--variants", type=int, default=4)
    ap.add_argument("--only", default="")
    # Ore as crystals dotted on the rock is the look Darren turned down on 21 November ("I want it like veins through
    # the rock"). The sheets are only written when asked for, and the game draws no ore without them.
    ap.add_argument("--ore-dots", action="store_true")
    a = ap.parse_args()
    sys.dont_write_bytecode = True
    sys.path.insert(0, a.art)
    import hl3, hl3_props as PR
    os.makedirs(a.out, exist_ok=True)
    K = Kit(hl3, a.variants); V = a.variants
    only = set(a.only.split(",")) - {""}
    info = {"tile": T, "cols": COLS, "variants": V, "rock_margins": ROCK_M, "ground_margins": GROUND_M,
            "bits": "N NE E SE S SW W NW", "sheets": {}}
    t0 = time.time()

    def want(name): return not only or name in only

    if want("rock"):
        for dug in (False, True):
            P, U, S, OT, OC = [], [], [], [], []
            for v in range(V):
                for cfg in range(256):
                    p, u, sh, ores = K.rock(cfg, v, dug); P.append(p); U.append(u); S.append(sh); OT.append(ores[0]); OC.append(ores[1])
                print("rock", "dug" if dug else "nat", v, round(time.time() - t0, 1), flush=True)
            tag = "dug" if dug else "nat"
            sheet(P).save(os.path.join(a.out, "rock_%s.png" % tag)); sheet(U).save(os.path.join(a.out, "rock_%s_foot.png" % tag))
            if a.ore_dots:
                sheet(OT).save(os.path.join(a.out, "ore_tin_%s.png" % tag)); sheet(OC).save(os.path.join(a.out, "ore_copper_%s.png" % tag))
            if not dug: sheet(S).save(os.path.join(a.out, "rock_shadow.png"))
        sheet(K.rock_core(32), 8).save(os.path.join(a.out, "rock_core.png"))
        info["sheets"]["rock"] = ["rock_nat.png", "rock_dug.png", "rock_nat_foot.png", "rock_dug_foot.png", "rock_shadow.png", "rock_core.png"]
        if a.ore_dots:
            info["sheets"]["rock"] += ["ore_tin_nat.png", "ore_tin_dug.png", "ore_copper_nat.png", "ore_copper_dug.png"]
    for name, ch in (("yard", "y"), ("water", "w"), ("floor", "o"), ("path", "e"), ("scree", ":")):
        if not want(name): continue
        L, D = [], []
        for v in range(V):
            for cfg in range(256):
                l, d = K.path(cfg, v) if ch == "e" else K.ground(cfg, v, ch); L.append(l); D.append(d)
            print(name, v, round(time.time() - t0, 1), flush=True)
        sheet(L).save(os.path.join(a.out, "%s.png" % name)); sheet(D).save(os.path.join(a.out, "%s_shade.png" % name))
        info["sheets"][name] = ["%s.png" % name, "%s_shade.png" % name]
    for name, step in (("hollow", 2), ("rise", 4)):
        if not want(name): continue
        L, D = [], []
        for v in range(V):
            for cfg in range(256):
                l, d = K.tone(cfg, v, step); L.append(l); D.append(d)
            print(name, v, round(time.time() - t0, 1), flush=True)
        sheet(L).save(os.path.join(a.out, "%s.png" % name)); sheet(D).save(os.path.join(a.out, "%s_shade.png" % name))
        info["sheets"][name] = ["%s.png" % name, "%s_shade.png" % name]
    if want("things"):
        info["things"] = bake_things(hl3, PR, K, a.out)
        info["palette"] = palette(hl3)
        print("things", round(time.time() - t0, 1), flush=True)
    kj = os.path.join(a.out, "kit.json"); old = {}
    if only and os.path.exists(kj):                 # a partial run keeps what the last full run wrote
        old = json.load(open(kj)); sheets = old.get("sheets", {}); sheets.update(info["sheets"]); info["sheets"] = sheets
    old.update(info)
    json.dump(old, open(kj, "w"), indent=1, sort_keys=True)
    print("done", round(time.time() - t0, 1))


if __name__ == "__main__":
    main()
