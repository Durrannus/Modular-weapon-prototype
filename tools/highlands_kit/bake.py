#!/usr/bin/env python3
"""Cuts the Greystone Highlands land kit for the game out of the art thread's own drawing code.

The look lives in hl3.py (the land) and hl3_props.py (the things that stand on it), written by the art thread and kept in
/mnt/project-files/art/highlands-concept/v3/code/. This tool imports them, draws a small patch of land for every way a tile
can meet its eight neighbours, and cuts the pieces the game lays out again per map chunk (scripts/highlands/land_painter.gd).
So the game shows the art thread's pixels, and when the art changes this is run again:

    python3 tools/highlands_kit/bake.py            # writes art/highlands/
    python3 tools/highlands_kit/bake.py --only rock --variants 2 --out /tmp/kit   # a quick partial run
    python3 tools/highlands_kit/bake.py --snow     # writes art/highlands/snow/: the same kit with snow lying in it

The snow kit (version 62) is the Art builder's hl3_snow.py (beside hl3.py): every piece is drawn again with
hl3_snow.SnowWorld in place of hl3.World, and every thing gets hl3_snow.snowy(). The game paints it round the Hound Den
(scripts/highlands/snow.gd).

Needs numpy and Pillow. Nothing here runs in the game.
"""
import argparse, json, os, sys, time
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import look                 # the look of version 65 (the Art builder's concept v4): look.py

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
    def __init__(s, hl3, variants, SN=None, L=None):
        s.hl3 = hl3; s.V = variants
        s.SN = SN                                        # hl3_snow, for the snow kit (then every World has snow lying in it)
        s.World = SN.SnowWorld if SN else hl3.World
        s.L = L                                          # the look of version 65 (look.py): its rock has the detail pass
        if L is None:
            s.RockWorld = s.World
        elif SN:
            s.RockWorld = lambda rows, seed=1, tone=False: L.GR.GrowSnowWorld(rows, seed=seed, bold=False, tone=tone)
        else:
            s.RockWorld = lambda rows, seed=1, tone=False: L.GR.GrowWorld(rows, seed=seed, bold=False, tone=tone)
        s.x0 = s.y0 = C * T
        yy, xx = np.mgrid[0:N * T, 0:N * T]
        s.yy, s.xx = yy, xx
        s.own = (xx >= s.x0) & (xx < s.x0 + T) & (yy >= s.y0) & (yy < s.y0 + T)

    # ------------------------------------------------------------------ colour
    def rgb(s, W, drop=0):
        """The picture's colours; drop = how many ramp steps darker (a shadow is two, on water one; on dug floor one, and
        never down to the black of the undug rock's top: the art's FLOOR_SOFT rule of 22 November, so that a tunnel one
        tile wide shows its floor and whoever stands in it)."""
        hl3 = s.hl3
        st = W.step.astype(int)
        if drop:
            st = st - np.where(W.mat == hl3.MID["water"], 1, 2) * (drop // 2)
            if getattr(hl3, "FLOOR_SOFT", False):
                st = np.where(W.mat == hl3.MID["floor"], np.maximum(W.step.astype(int) - 1, 1), st)
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
        W = s.RockWorld(rows, seed=v + 1, tone=False)    # chisel marks, cracks, moss hanging from the lip, rubble at the foot
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
        # which of this piece's pixels are the lit face (red) and which the dark top (black): the game's ore veins
        # are bright on a face and fade out into the top, so it needs to know one from the other
        part_rgb = np.zeros(rgb.shape, np.uint8); part_rgb[..., 0] = np.where(W.face, 255, 0)
        part = s.cut(part_rgb, keep, ROCK_M)
        return piece, under, shadow, part

    def rock_core(s, n):
        """The heart of a hill: the cave's own dark wall top with a few strokes. Cut from one big block of rock."""
        hl3 = s.hl3
        W = s.RockWorld(["#" * 12] * 12, seed=3, tone=False)
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
        W = s.World(rows, seed=v + 1, tone=False)
        cells = [[c == ch for c in r] for r in rows]
        incell = cell_px(cells)
        changed = ~W.plain & ~((W.mat == hl3.MID["grass"]) & (W.step == 3))
        if s.SN: changed &= ~((W.mat == hl3.MID["snow"]) & (W.step == 4))     # the snow's plain ground (its README)
        if ch == "o": changed = W.floor
        if ch == "e" and s.L is not None and not s.SN:
            # The bold look's footpath (hl_detail.detail and hl_grow.land_pass): the path's own grass becomes worn earth,
            # and its edge blends into the grass over 2 to 3 px through a mixed band.
            GR, M = s.L.GR, hl3.MID
            pm = W.path & (W.mat == M["grass"]); W.mat[pm] = M["earth"]
            em = W.mat == M["earth"]
            GR.ragged(W, em & ~W.rock, [M["grass"]], M["mixe"], np.random.RandomState(v * 31 + cfg), out_p=(0.55, 0.25, 0.08), in_p=(0.5, 0.2))
            changed = changed | (W.mat == M["mixe"]) | (W.mat == M["earth"])
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
        if s.SN:                                         # under snow a hollow lies a step darker than the plain snow, a rise a step lighter
            g = s.SN.SNOW; step += 1
        lit = np.zeros(W.mat.shape + (3,), np.uint8); lit[:] = g[step]
        dark = np.zeros_like(lit); dark[:] = g[max(0, step - 2)]
        return s.cut(lit, keep, GROUND_M), s.cut(dark, keep, GROUND_M)


GRASS_FOOT = 3     # the grass step a thing's foot tufts are drawn for


class Things:
    """Everything that stands on the land, as a sprite with its foot point and the shadow it throws."""
    def __init__(s, hl3, PR, SN=None):
        s.hl3, s.PR = hl3, PR; s.items = {}
        s.SN = SN                       # hl3_snow: every thing added gets snow on it, unless snow=False

    def add(s, name, pair, foot="tuft", shadow=True, sink=0, slen=20.0, seed=0, solid=None, snow=True, drift=True):
        hl3 = s.hl3
        im, (fx, fy) = pair
        a = im.a.copy()
        if sink: a[max(0, fy - sink):] = 0
        pad = 6
        A = np.zeros((a.shape[0] + pad * 2, a.shape[1] + pad * 2, 4), np.uint8); A[pad:pad + a.shape[0], pad:pad + a.shape[1]] = a
        fx, fy = fx + pad, fy + pad + sink
        if s.SN and snow:
            # snow on its upward faces, its foot sunk in a little drift (and no grass tufts: they don't grow out of snow)
            o = s.PR.Im(A.shape[1], A.shape[0]); o.a = A
            o, (fx, fy) = s.SN.snowy((o, (fx, fy)), drift=drift, seed=seed)
            A = o.a; foot = "none"
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
        """Frames of one animal: the same canvas and foot, side by side. (An animal is never snowed on.)"""
        frames = []
        for k, pair in enumerate(pairs):
            s.add("%s#%d" % (name, k), pair, snow=False, **kw); frames.append(s.items.pop("%s#%d" % (name, k)))
        h = max(f["img"].shape[0] for f in frames); w = max(f["img"].shape[1] for f in frames)
        A = np.zeros((h, w * len(frames), 4), np.uint8)
        for k, f in enumerate(frames): A[:f["img"].shape[0], k * w:k * w + f["img"].shape[1]] = f["img"]
        item = {"img": A, "foot": frames[0]["foot"], "frames": len(frames), "frame_w": w}
        if "shadow_img" in frames[0]: item["shadow_img"] = frames[0]["shadow_img"]; item["shadow_at"] = frames[0]["shadow_at"]
        s.items[name] = item

    def decal(s, name, lit, shade, at):
        s.items[name] = {"img": lit, "foot": [0, 0], "at": at}; s.items[name + "~"] = {"img": shade, "foot": [0, 0], "at": at}

    def pack(s, path_png, width=768, keys=("img", "shadow_img")):
        """Shelves, tallest first. Returns where everything went. keys: which pictures of each thing go on this sheet
        (the marks go on a sheet of their own: they are numbers, not colours)."""
        todo = []
        for name, it in s.items.items():
            for key in keys:
                if key in it: todo.append((name, key, it[key]))
        todo.sort(key=lambda t: (-t[2].shape[0], t[0], t[1]))
        x = y = shelf = 0; places = []
        for name, key, a in todo:
            h, w = a.shape[:2]
            if x + w > width: x = 0; y += shelf + 1; shelf = 0
            places.append((name, key, x, y, a)); x += w + 1; shelf = max(shelf, h)
        out = np.zeros((max(1, y + shelf), width, 4), np.uint8); table = {}
        for name, key, x, y, a in places:
            h, w = a.shape[:2]; out[y:y + h, x:x + w] = a
            e = table.setdefault(name, {})
            if key == "img":
                e["rect"] = [x, y, w, h]; e["foot"] = s.items[name]["foot"]
                for k in ("frames", "frame_w", "solid", "at"):
                    if k in s.items[name]: e[k] = s.items[name][k]
            elif key == "shadow_img":
                e["shadow"] = [x, y, w, h]; e["shadow_at"] = s.items[name]["shadow_at"]
            elif key == "mark_img":
                e["mark"] = [x, y, w, h]; e["mark_at"] = s.items[name]["mark_at"]
        Image.fromarray(out, "RGBA").save(path_png)
        return table


def drop_snow(SN, hl3, a):
    """The same picture in shadow, for a thing that is snow and grass: each snow and grass colour two steps darker."""
    a = a.copy()
    for ramp in (SN.SNOW, hl3.PAL["grass"]):
        src = a[..., :3].copy()
        for k, c in enumerate(ramp):
            m = (src == np.array(c, np.uint8)).all(-1) & (a[..., 3] > 0)
            a[m, :3] = ramp[max(0, k - 2)]
    return a


def bake_things(hl3, PR, K, out, SN=None, L=None):
    import hl_flora as FL
    TH = Things(hl3, PR, SN)
    GR = L.GR; D = L.D; FO = L.FO
    snowy = SN is not None
    ground = "snow" if snowy else "grass"
    dress = (lambda pr, k=0: SN.snowy(pr, seed=k)) if snowy else (lambda pr, k=0: pr)

    def keep(name, P, solid=None, shadow=True, slen=20.0, ground_only=False):
        """What standing a thing on the patch left: its picture (unless it is drawn into the ground), its shadow, its mark."""
        item = {}
        pic = None if ground_only else P.picture()
        if pic is not None:
            item["img"], item["foot"] = pic
            if shadow:
                sh = look.sprite_shadow(item["img"], item["foot"], slen)
                if sh is not None: item["shadow_img"], item["shadow_at"] = sh
            if solid: item["solid"] = solid
        else:
            item["ground"] = True; item["foot"] = [0, 0]
        mk = P.mark()
        if mk is not None: item["mark_img"], item["mark_at"] = mk
        TH.items[name] = item

    def stand(pair, k, lip=False, sink=0, slen=20.0, on="grass"):
        """One thing seated in the land by the Art builder's own code (hl_grow.seat): a damp bed round its foot, and the
        ground's blades in front of it, or a lip of soil heaped against it."""
        P = look.Patch(L, ground=("snow" if snowy else on), seed=k)
        P.W.add(dress(pair, k), P.x, P.y, sink=sink, slen=slen)
        GR.seat(P.W, P.W.sprites[-1], np.random.RandomState(k * 13 + 5), green=not snowy and on == "grass", lip=lip, snow=snowy)
        return P

    # Trees: the Scots pine and the rowan, rooted, their canopy's shadow laid on the ground with litter under it
    # (hl_grow.tree); the juniper and gorse drawn into the ground like the small plants (hl_grow.bush).
    for k, tall in enumerate((84, 88, 80, 90, 78, 86)):
        P = look.Patch(L, ground=ground, seed=k)
        GR.tree(P.W, dress(D.pine2(k * 7 + 3, tall), k), P.x, P.y, np.random.RandomState(905 + k), "pine", green=not snowy, snow=snowy)
        keep("pine_%d" % k, P, solid=[6, 4], shadow=False)
    for k in range(3):
        P = look.Patch(L, ground=ground, seed=k + 10)
        GR.tree(P.W, dress(D.rowan(k * 5 + 2), k), P.x, P.y, np.random.RandomState(915 + k), "rowan", green=not snowy, snow=snowy)
        keep("rowan_%d" % k, P, solid=[6, 4], shadow=False)
    for name, fn in (("juniper", D.juniper), ("gorse", D.gorse2)):
        for k in range(3):
            P = look.Patch(L, ground=ground, seed=k + 20)
            GR.bush(P.W, dress(fn(k * 3 + 1), k), P.x, P.y, np.random.RandomState(925 + k), green=not snowy)
            keep("%s_%d" % (name, k), P, ground_only=True)
    # Stones and the rest that stand on the land: seated with a damp bed and blades, or a soil lip.
    for k, (w, h) in enumerate(((14, 10), (16, 11), (18, 12), (12, 8), (11, 8), (13, 9))):
        keep("boulder_%d" % k, stand(PR.boulder(k * 5 + 1, w, h), k, sink=2, slen=8.0), solid=[w - 2, 5], slen=8.0)
    for k in range(2): keep("stone_%d" % k, stand(PR.stone(k * 4 + 1), k + 6, sink=1, slen=8.0), solid=[8, 4], slen=8.0)
    for k in range(2): keep("cairn_%d" % k, stand(PR.cairn(k + 1), k + 8, lip=True), solid=[10, 4])
    keep("post", stand(PR.keeper_post(), 11, lip=True), solid=[5, 3])
    keep("stump", stand(PR.stump(), 12), solid=[6, 3])
    keep("barrel", stand(PR.barrel(), 13, lip=True), solid=[10, 5])
    keep("bones", stand(PR.bones(), 14, lip=True), shadow=False)
    keep("rubble", stand(PR.rubble(), 15, lip=True), shadow=False)
    TH.add("cave_mouth", PR.cave_mouth(), foot="peb", shadow=False)
    TH.add("lantern", PR.lantern(), foot="none")
    # Bracken, reeds and cotton grass: small plants, drawn into the ground with no outline (hl_grow.plant): the
    # ground's dark steps on their shaded side, a damp bed, blades over their foot, the lowest row lost in the turf.
    for name, fn, n in (("bracken", PR.bracken, 4), ("reeds", PR.reeds, 4), ("cotton", PR.cotton, 3)):
        for k in range(n):
            P = look.Patch(L, ground=ground, seed=k + 30)
            GR.plant(P.W, GR.strip_ink(fn(k + 1)), P.x, P.y, np.random.RandomState(935 + k), hide=1, green=not snowy)
            keep("%s_%d" % (name, k), P, ground_only=True)
    # Scrap heaps out in the Scrapyard's yard (v4.1): piled anyhow, half sunk in the trodden earth, rust in the soil
    # round them running downhill, weeds coming up out of the soil line, bits lying half buried round the foot.
    if not snowy:
        for k, (w, h) in enumerate(((66, 30), (56, 26), (44, 20))):
            P = look.Patch(L, ground="earth", seed=k + 40)
            GR.bury(P.W, GR.heap(w, h, k + 4), P.x, P.y, np.random.RandomState(945 + k))
            keep("heap_%d" % k, P, solid=[int(w * 0.62), 7], slen=10.0)
    for name, fn in (("cow", PR.cow), ("hare", PR.hare), ("crow", PR.crow)):
        order = []
        for f, _t in PR.ANIMALS[name]:
            if f not in order: order.append(f)
        TH.strip(name, [fn(f) for f in order], foot="none")
        TH.items[name]["order"] = order
    TH.items["cow"]["solid"] = [22, 6]

    def plant(cells, drop):
        """A heather or sage plant as sprigs (hl_detail.heath_sprigs, hl_grow.scrub_sprigs2) with no outline: the game
        draws it into the ground (land_grow.gd), its shaded side taking the ground's own dark steps. drop: in shadow."""
        xs = [c[0] for c in cells]; ys = [c[1] for c in cells]; x0, y0 = min(xs), min(ys)
        o = PR.Im(max(xs) - x0 + 1, max(ys) - y0 + 1)
        for (dx, dy), (mt, st_) in cells.items(): o.px(dx - x0, dy - y0, hl3.PAL[mt][max(0, st_ - drop)])
        return o, (-x0, -y0)
    for kind, gen in (("heath", D.heath_sprigs), ("scrub", GR.scrub_sprigs2)):
        for k in range(12):
            cells = gen(np.random.RandomState(k * 3 + 1))
            for suffix, drop in (("", 0), ("~", 2)):
                im, (fx, fy) = plant(cells, drop)
                a = im.a.copy()
                if suffix and snowy: a = drop_snow(SN, hl3, a)
                TH.items["%s_%d%s" % (kind, k, suffix)] = {"img": a, "foot": [int(fx), int(fy)]}
    # Taller wildflower clumps, one or two standing out of a drift of flower specks (hl_grow.flowerbed).
    if not snowy:
        with GR.Bare():
            for k in range(6):
                im, (fx, fy) = FO.wildflowers(k * 7 + 3)
                im, (fx, fy) = GR.strip_ink((im, (fx, fy)))
                for suffix, drop in (("", 0), ("~", 2)):
                    a = im.a.copy()
                    if drop:
                        for y in range(a.shape[0]):
                            for x in range(a.shape[1]):
                                if a[y, x, 3]:
                                    mid, st = GR.lookup(a[y, x, :3]); a[y, x, :3] = hl3.LUT[mid, max(0, st - drop)]
                    TH.items["flower_%d%s" % (k, suffix)] = {"img": a, "foot": [int(fx), int(fy)]}
    # scraps of the keepers' road: whole pieces, because its flagstones do not follow the tile grid
    roads = [[(2, 3), (8, 3)], [(2, 3), (7, 3), (7, 4), (2, 4)], [(3, 2), (3, 7)], [(2, 2), (5, 3), (8, 5)], [(2, 3), (4, 3), (4, 4), (2, 4)], [(2, 4), (6, 3), (10, 3)]]
    for k, pts in enumerate(roads):
        for sd in range(2):
            G = hl3.Grid(13, 10, fill="."); G.line(pts, "=", 1)
            W = K.World(G.rows(), seed=40 + k * 2 + sd, tone=False)
            m = W.road & ~((W.mat == hl3.MID["grass"]) & (W.step == 3))
            if SN: m &= ~((W.mat == hl3.MID["snow"]) & (W.step == 4))
            ys, xs = np.nonzero(m); x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
            st = np.clip(W.step.astype(int) - np.where(W.shadow, 2, 0), 0, hl3.TOPS[W.mat])
            lit = np.zeros((y1 - y0, x1 - x0, 4), np.uint8); lit[..., :3] = hl3.LUT[W.mat, st][y0:y1, x0:x1]; lit[..., 3] = np.where(m[y0:y1, x0:x1], 255, 0); lit[lit[..., 3] == 0] = 0
            sh = lit.copy(); sh[..., :3] = K.rgb(W, 2)[y0:y1, x0:x1]; sh[sh[..., 3] == 0] = 0
            cx, cy = (pts[0][0] + pts[-1][0]) * 8 + 8, (pts[0][1] + pts[-1][1]) * 8 + 8     # the middle of the run, in px
            TH.decal("road_%d" % (k * 2 + sd), lit, sh, [int(x0 - cx), int(y0 - cy)])
    if SN:
        # The Hound Den's mouth (the Art builder's hl3_snow.den(), snow on it already), with its foot moved to the middle
        # of the slab so that what stops you is the slab; the ground trodden to slush in front of it, and paw prints.
        im, (fx, fy) = SN.den()
        TH.add("den", (im, (31, fy)), foot="none", snow=False, solid=[52, 10], slen=14.0)
        tr = SN.trample()
        TH.decal("trample", tr, drop_snow(SN, hl3, tr), [-28, -11])
        for name, args in (("tracks_e", (7, 1, 7, 0)), ("tracks_se", (7, 2, 6, 2)), ("tracks_ne", (7, 3, 6, -2))):
            a = SN.tracks(*args)
            TH.decal(name, a, drop_snow(SN, hl3, a), [0, 0])
    table = TH.pack(os.path.join(out, "things.png"))
    marks = TH.pack(os.path.join(out, "marks.png"), width=512, keys=("mark_img",))
    for name, e in marks.items():
        table.setdefault(name, {}).update(e)
    for name, it in TH.items.items():
        if it.get("ground"):
            table.setdefault(name, {})["ground"] = True
    for name in ("cow", "hare", "crow"):
        table[name]["order"] = TH.items[name]["order"]; table[name]["times"] = [[f, t] for f, t in PR.ANIMALS[name]]
    return table


def palette(hl3):
    """Every ramp hl3 knows now (the bold ones swapped in, the turf, earth, foliage and mixed ones added by the look)."""
    hexs = lambda cs: ["%02x%02x%02x" % tuple(int(x) for x in c) for c in cs]
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
    ap.add_argument("--snow", action="store_true", help="the snow kit, into art/highlands/snow/ unless --out says")
    ap.add_argument("--snow-art", default="/mnt/project-files/art/highlands-snow-v1")
    ap.add_argument("--look", default=look.LOOK_CODE, help="the Art builder's concept v4 code (version 65's look)")
    a = ap.parse_args()
    sys.dont_write_bytecode = True
    sys.path.insert(0, a.art)
    LOOK = look.load(a.art, a.look)
    hl3, PR = LOOK.hl3, LOOK.PR
    SN = None
    if a.snow:
        SN = LOOK.SN
        if a.out == ap.get_default("out"): a.out = os.path.join(a.out, "snow")
    os.makedirs(a.out, exist_ok=True)
    K = Kit(hl3, a.variants, SN, LOOK); V = a.variants
    only = set(a.only.split(",")) - {""}
    info = {"tile": T, "cols": COLS, "variants": V, "rock_margins": ROCK_M, "ground_margins": GROUND_M,
            "bits": "N NE E SE S SW W NW", "sheets": {}}
    t0 = time.time()

    def want(name): return not only or name in only

    if want("rock"):
        for dug in (False, True):
            P, U, S, F = [], [], [], []
            for v in range(V):
                for cfg in range(256):
                    p, u, sh, part = K.rock(cfg, v, dug); P.append(p); U.append(u); S.append(sh); F.append(part)
                print("rock", "dug" if dug else "nat", v, round(time.time() - t0, 1), flush=True)
            tag = "dug" if dug else "nat"
            sheet(P).save(os.path.join(a.out, "rock_%s.png" % tag)); sheet(U).save(os.path.join(a.out, "rock_%s_foot.png" % tag))
            sheet(F).save(os.path.join(a.out, "rock_%s_part.png" % tag))
            if not dug: sheet(S).save(os.path.join(a.out, "rock_shadow.png"))
        sheet(K.rock_core(32), 8).save(os.path.join(a.out, "rock_core.png"))
        info["sheets"]["rock"] = ["rock_nat.png", "rock_dug.png", "rock_nat_foot.png", "rock_dug_foot.png", "rock_shadow.png", "rock_core.png",
                                  "rock_nat_part.png", "rock_dug_part.png"]
        # Ore is drawn by the game as veins through the rock (scripts/highlands/veins.gd, a port of hl3.vein_paths and
        # hl3.vein_step). These are the colours those veins use, straight from the art's own ramps: step 0 upward.
        info["vein"] = {name: ["%02x%02x%02x" % tuple(int(c) for c in hl3.LUT[hl3.MID[name], st]) for st in range(int(hl3.TOPS[hl3.MID[name]]) + 1)]
                        for name in ("tin", "copper", "verd", "face", "cap")}
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
        info["things"] = bake_things(hl3, PR, K, a.out, SN, LOOK)
        info["palette"] = palette(hl3)
        info["mats"] = list(hl3.MATS)               # a mark's material is its place in this list (marks.png, look.py)
        info["look"] = "v4"
        print("things", round(time.time() - t0, 1), flush=True)
    if SN:
        # The Art builder's own pictures, as they are: plain snowy ground (tileable, for the plain ground the game fills
        # itself) and the two layers of falling snow.
        import shutil
        for f in ("snow_ground.png", "snow_far.png", "snow_near.png"):
            shutil.copy(os.path.join(a.snow_art, f), os.path.join(a.out, f))
        info["snow"] = {"ground": "snow_ground.png", "far": "snow_far.png", "near": "snow_near.png",
                        "ramp": ["%02x%02x%02x" % tuple(c) for c in SN.SNOW]}
    kj = os.path.join(a.out, "kit.json"); old = {}
    if only and os.path.exists(kj):                 # a partial run keeps what the last full run wrote
        old = json.load(open(kj)); sheets = old.get("sheets", {}); sheets.update(info["sheets"]); info["sheets"] = sheets
    old.update(info)
    json.dump(old, open(kj, "w"), indent=1, sort_keys=True)
    print("done", round(time.time() - t0, 1))


if __name__ == "__main__":
    main()
