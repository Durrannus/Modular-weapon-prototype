#!/usr/bin/env python3
"""Bakes Rattlecrown's fight for the game out of the Art builder's own drawing code (version 50).

The look is the Art builder's round 2, which Darren shaped on 23 November ("He needs more spikes like actual scrap
armour", "Change the throne to match the scrap look too", "Make the chest golden and the gate better", "it has to look
part of the world and not just a thing placed onto", "put scrap piles around the arena") and asked for in the game on 24
November ("Add the new art for scrap boss fight"). It lives in hl_king3.py and hl_king2.py, in
/mnt/project-files/art/highlands-rattlecrown-v2-rough/code/, with the cave's kit (core.py, knight.py, props.py) and the
Highlands land (hl3.py). Darren also said "Don't animate yet as I might change more", so everything here is a STILL:
every strip of the king and the throne is one picture, held as long as the old strip lasted. Only the mechanisms move:
the spikes come up out of the floor and the hoard's portcullis goes up, which are the Art builder's own pieces moved.

What it writes (and what reads it):
  art/foes/rattlecrown.png, .json      the king on foot, crowned, and on his throne (scripts/foes/rattlecrown.gd, crown.gd)
  art/scrapyard/scrapyard.png, .json   the gate, the hoard's chest and portcullis, the scrap piles, the spikes, the
                                       stands and the watching goblins (crown.gd, crown_plan.gd)
  art/scrapyard/throne_floor.png, .json  the Throne Room's floor: paving, the traps' sunk slabs, soot, trodden scrap and
                                       the stands' planks, in pieces the land painter paints into the dug floor
                                       (land_painter.gd, CrownPlan.stamp)

    python3 tools/rattlecrown_kit/bake.py --godot /path/to/godot

Where things stand in the room comes from the game (CrownPlan.throne_layout, printed by layout.gd), so the floor is
painted to fit. Needs numpy and Pillow. Nothing here runs in the game.
"""
import argparse, json, os, subprocess, sys, tempfile
import numpy as np
from PIL import Image

ART = "/mnt/project-files/art/"
CODE = [ART + "highlands-rattlecrown-v2-rough/code", ART + "highlands-concept/v3/code", ART + "concept-art-3/code",
        ART + "highlands-scrapyard-v1/code", ART + "highlands-enemies-v1/code"]
GAME = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
T = 16
PIECE = 128                 # the floor is cut into pieces no bigger than this (a chunk of land is 256)
PILES = {                   # the Throne Room's scrap piles, as the Art builder's still has them: (wide, deep, seed)
    "scrap_pile_big": (64, 38, 2), "scrap_pile_mid": (46, 28, 4), "scrap_pile_side": (44, 26, 6), "scrap_pile_small": (32, 18, 8),
    "scrap_heap_large": (48, 30, 11), "scrap_heap_small": (32, 20, 12),     # the other rooms' (same names as before)
}
POSES = ("lean", "cheer", "fist", "drum")


def arr(im):
    return np.array(im.a, dtype=np.uint8)


class Sheet:
    """Strips laid out in rows, left to right, every frame of a strip the same size."""
    def __init__(s, width=1024):
        s.W = width; s.items = []

    def add(s, key, frames):
        h, w = frames[0].shape[:2]
        for f in frames:
            assert f.shape[:2] == (h, w), (key, f.shape, (h, w))
        s.items.append((key, frames))

    def pack(s):
        boxes = {}; x = y = row = 0
        order = sorted(range(len(s.items)), key=lambda i: -s.items[i][1][0].shape[0])
        for i in order:
            key, frames = s.items[i]
            h, w = frames[0].shape[:2]; tw = w * len(frames)
            if x + tw > s.W:
                x = 0; y += row + 1; row = 0
            boxes[key] = [x, y, tw, h]; x += tw + 1; row = max(row, h)
        H = y + row + 1
        img = np.zeros((H, s.W, 4), np.uint8)
        for key, frames in s.items:
            bx, by, tw, h = boxes[key]; w = frames[0].shape[1]
            for k, f in enumerate(frames):
                img[by:by + h, bx + k * w:bx + (k + 1) * w] = f
        used = np.nonzero(img[..., 3].any(0))[0]
        return img[:, :used.max() + 2] if len(used) else img, boxes


def held(old, name, frames=1):
    """A still for an old strip: the same length of time, in one picture (or `frames` copies of it)."""
    st = old.get("strips", {}).get(name, {"frames": 1, "fps": 0})
    n, fps = int(st.get("frames", 1)), float(st.get("fps", 0))
    if fps <= 0:
        return 0
    return round(fps * frames / n, 3)


def cut(img, box):
    x, y, w, h = box
    return img[y:y + h, x:x + w].copy()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--layout", default="", help="a layout.json already printed (otherwise layout.gd is run)")
    a = ap.parse_args()
    for p in reversed(CODE):
        sys.path.insert(0, p)
    import hl_king2 as K2, hl_king3 as K3, hl3, core

    # --- Rattlecrown and his throne ------------------------------------------------------------------------------
    rpath = os.path.join(GAME, "art/foes/rattlecrown")
    old = json.load(open(rpath + ".json")); old_img = np.array(Image.open(rpath + ".png").convert("RGBA"))
    sh = Sheet()
    king, kf = K3.scrap_king(False); crowned, cf = K3.scrap_king(True)
    seated, sf = K3.scrap_enthroned(); empty, ef = K3.scrap_throne_empty()
    enemies = {}; pic_of = {}                  # (every strip of a still shares its one picture)
    for key, im in (("king", king), ("crowned", crowned), ("seated", seated), ("empty", empty)):
        sh.add(key, [arr(im)])
    for name, im, ft, key, note in (("rattlecrown", king, kf, "king", "Rattlecrown on foot in scrap armour, the crown at his belt."),
                                    ("rattlecrown_crowned", crowned, cf, "crowned", "With the crown on (phase 3).")):
        o = old["enemies"][name]; strips = {}
        for s_name in o["strips"]:
            strips[s_name] = {"frames": 1, "fps": held(o, s_name)}; pic_of[(name, s_name)] = key
        enemies[name] = {"frame": [im.w, im.h], "origin_feet": list(ft), "strips": strips,
                         "note": note + " A still for every strip until Darren says the look is settled (\"Don't animate yet\")."}
    o = old["enemies"]["throne"]; strips = {}
    for s_name in o["strips"]:
        pic_of[("throne", s_name)] = "empty" if s_name == "wreck" else "seated"
        strips[s_name] = {"frames": 1, "fps": held(o, s_name)}
    enemies["throne"] = {"frame": [seated.w, seated.h], "origin_feet": list(sf), "solid": [104, 46], "strips": strips,
                         "note": "The scrap throne. Feet = the middle of the front of its lower step. 'idle', 'point' and 'kick' have him on it; "
                                 "'wreck' is the throne standing empty (a broken one waits for the Art builder). Solid as wide as its steps and "
                                 "back to the stand behind it."}
    for s_name, info in old["shots"].items():
        sh.add(("shot", s_name), [cut(old_img, info["box"])])
    img, boxes = sh.pack()
    for name, e in enemies.items():
        for s_name, st in e["strips"].items():
            st["box"] = boxes[pic_of[(name, s_name)]]
    shots = {}
    for s_name, info in old["shots"].items():
        shots[s_name] = dict(info); shots[s_name]["box"] = boxes[("shot", s_name)]
    out = {"note": "Rattlecrown, round 2 (the Art builder's hl_king3.py), baked by tools/rattlecrown_kit/bake.py. Everything faces right; "
                   "strips run left to right. Stills only (Darren, 23 Nov: \"Don't animate yet as I might change more\").",
           "enemies": enemies, "shots": shots}
    Image.fromarray(img).save(rpath + ".png"); json.dump(out, open(rpath + ".json", "w"), indent=1)
    print("rattlecrown", img.shape[1], img.shape[0])

    # --- The Scrapyard's sheet -----------------------------------------------------------------------------------
    ypath = os.path.join(GAME, "art/scrapyard/scrapyard")
    yold = json.load(open(ypath + ".json"))["sprites"]; yimg = np.array(Image.open(ypath + ".png").convert("RGBA"))
    sh = Sheet(); sprites = {}

    def put(name, frames, origin, fps=0, **extra):
        sh.add(name, frames)
        sprites[name] = dict({"frame": [frames[0].shape[1], frames[0].shape[0]], "origin": list(origin), "frames": len(frames)}, **extra)
        if fps:
            sprites[name]["fps"] = fps

    raw = lambda f, *args, **kw: _raw(K3, f, *args, **kw)
    # The gate: shut is the Art builder's; opening and open are the same gate with its two leaves swung in, narrowed
    # against their posts (a stand-in until an open gate is drawn).
    g, gf = K3.scrap_gate()
    put("gate_front_shut", [arr(g)], gf)
    def swung(f):
        gr = _raw_gate(K2, K3)
        leaves = gr[:, 8:46].copy(); gr[:, 8:46] = 0
        for a, b, left in ((0, 19, True), (19, 38, False)):
            src = leaves[:, a:b]; w = max(2, round((b - a) * f))
            cols = [int(i * (b - a) / w) for i in range(w)]
            leaf = src[:, cols].copy(); leaf[..., :3] = (leaf[..., :3] * (0.6 + 0.4 * f)).astype(np.uint8)
            x0 = 8 if left else 46 - w
            m = leaf[..., 3] > 0; gr[:, x0:x0 + w][m] = leaf[m]
        out = core.outline(_im(core, gr)); im = core.Im(56, 64); im.blit(out, 0, 0)
        return arr(im)
    put("gate_front_opening", [swung(f) for f in (0.75, 0.5, 0.3)], gf, fps=6)
    put("gate_front_open", [swung(0.16)], gf)
    # The scrap piles.
    for name, (w, h, seed) in PILES.items():
        p, pf = K3.scrap_pile(w, h, seed)
        put(name, [arr(p)], pf, solid=[int(w * 0.72), 8])
    # The braziers stay the cave's own, as the first draft had them.
    b = yold["brazier"]; put("brazier", [cut(yimg, [b["box"][0] + k * b["frame"][0], b["box"][1], b["frame"][0], b["frame"][1]]) for k in range(b["frames"])],
                             b["origin"], fps=b.get("fps", 5))
    # His hoard: the golden chest (its lid does not open yet: the same picture full and empty), and its portcullis.
    c, cfo = K3.gold_chest()
    put("hoard_chest", [arr(c)] * 5, cfo, foot=list(cfo), solid=[26, 6])
    put("hoard_chest_empty", [arr(c)], cfo, foot=list(cfo), solid=[26, 6])
    VW, VH = 52, 40
    full = raw(K3.vault_gate, VW, VH)
    bare = full.copy(); bare[9:, 10:VW - 10] = 0
    bars = full.copy(); bars[bare[..., 3] > 0] = 0; bars[:9] = 0
    vf = (VW // 2 + 1, VH + 1)
    frames = []
    for k in range(5):
        lift = round((VH - 12) * k / 4)
        layer = np.zeros_like(full)
        layer[:VH - lift] = bars[lift:]
        comp = layer.copy(); m = bare[..., 3] > 0; comp[m] = bare[m]
        frames.append(arr(core.outline(_im(core, comp))))
    put("hoard_gate_shut", [frames[0]], vf)
    put("hoard_gate_opening", frames[1:4], vf, fps=6)
    put("hoard_gate_open", [frames[4]], vf)
    # The spikes: nothing above the floor while a trap is down (its slab is painted into the floor), the tips while
    # it rattles, then up.
    blank = np.zeros((30, 18, 4), np.uint8)
    put("spike_trap_down", [blank], (9, 29))
    put("spike_trap_warn", [arr(K3.spikes(3, 1)[0]), arr(K3.spikes(3, 0)[0])], (9, 29), fps=12)
    put("spike_trap_rise", [arr(K3.spikes(h)[0]) for h in (4, 7, 10, 12)], (9, 29), fps=24)
    put("spike_trap_up", [arr(K3.spikes(12)[0])], (9, 29))
    # The stands and the crowd, fitted to the room (CrownPlan.throne_layout).
    lay = _layout(a)
    runs = [d for d in lay["scenery"] if str(d[0]).startswith("stand_front_")]
    room_w = lay["room"][0]
    for d in runs:
        k = int(str(d[0]).split("_")[-1]); x0 = int(d[1][0]) // T
        x1 = _run_end(lay, x0, room_w)
        fr, ff = K3.stand_front(x1 - x0 + 1, k + 1)
        put(str(d[0]), [arr(fr)], ff)
    rail, rf = K3.stand_rail(lay["room"][1], 1)
    put("stand_rail", [arr(rail)], rf)
    for i, pose in enumerate(POSES):
        for cap in (False, True):
            gb, gbf = K3.goblin(pose, cap, i * 2 + int(cap))
            put("goblin_%s%s" % (pose, "_cap" if cap else ""), [arr(gb)], gbf)
    img, boxes = sh.pack()
    for name in sprites:
        sprites[name]["box"] = boxes[name]
    out = {"note": "The Scrapyard's gate, Rattlecrown's hoard, the scrap piles, the spike traps' spikes, the stands and the watching goblins: "
                   "round 2 (the Art builder's hl_king3.py), baked by tools/rattlecrown_kit/bake.py. Stills; the open gate is the shut one "
                   "with its leaves swung in against its posts, until an open gate is drawn.", "sprites": sprites}
    Image.fromarray(img).save(ypath + ".png"); json.dump(out, open(ypath + ".json", "w"), indent=1)
    print("scrapyard", img.shape[1], img.shape[0])

    # --- The Throne Room's floor ---------------------------------------------------------------------------------
    lay = _layout(a, again=True)            # (the throne's size, and so where the braziers stand, came from the sheet just written)
    floor(lay, hl3, K3)


def _layout(a, again=False):
    if a.layout and not again:
        return json.load(open(a.layout))
    tmp = tempfile.mktemp(suffix=".json")
    subprocess.run([a.godot, "--headless", "--path", GAME, "-s", "tools/rattlecrown_kit/layout.gd", "--", "out=" + tmp], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    lay = json.load(open(tmp)); os.unlink(tmp)
    return lay


def _run_end(lay, x0, room_w):
    """The last column of the back stand's run starting at x0: up to the throne's gap, the alcove, or the wall."""
    mid = lay["door"]; al = lay["alcove"]
    for stop in (mid - 5, al[0] - 1, room_w - 1):
        if stop >= x0:
            return stop
    return room_w - 1


def _im(core, a):
    im = core.Im(a.shape[1], a.shape[0]); im.a = a.copy(); return im


def _raw(K3, f, *args, **kw):
    """What a drawing function draws before its outline goes round it."""
    keep = K3.outline
    K3.outline = lambda o: o
    try:
        im, _ = f(*args, **kw)
    finally:
        K3.outline = keep
    return np.array(im.a, dtype=np.uint8)


def _raw_gate(K2, K3):
    keep = K2.outline
    K2.outline = lambda o: o
    try:
        with K3.ramp(K3.IRON2):
            im, _ = K2.gate2()
    finally:
        K2.outline = keep
    return np.array(im.a, dtype=np.uint8)[:62, :54]


def floor(lay, hl3, K3):
    """Paints the room's floor as the Art builder's still does, on a map of the room's own shape, and keeps what differs
    from the plain dug floor: in the light (for the land's lit layer) and in shadow (for its shade layer)."""
    RW, RH = lay["room"]; S = lay["stands_deep"]; al = lay["alcove"]; mid = lay["door"]; M = 2
    gx0, gy0 = -S - M, al[1] - M                       # the map's top left, in the room's tiles
    GW, GH = RW + 2 * (S + M), RH + 2 + M - gy0        # (2: the wall below the room, with the door)
    def rows(planks):
        G = hl3.Grid(GW, GH); G.rect(0, 0, GW - 1, GH - 1, "#")
        def r(x, y, w, h, ch): G.rect(x - gx0, y - gy0, x - gx0 + w - 1, y - gy0 + h - 1, ch)
        for st in lay["stands"]: r(*st, "p" if planks else "o")
        r(0, 0, RW, RH, "o"); r(*al, "o"); r(mid - 1, RH, 3, 2, "o")
        return G.rows()
    A = hl3.World(rows(False), 23, long_grass=0.0)
    B = hl3.World(rows(True), 23, long_grass=0.0)
    ox, oy = -gx0 * T, -gy0 * T                        # the room's top left corner, in the map's pixels
    tile = lambda x0, y0, x1, y1: (x0 - gx0, y0 - gy0, x1 - gx0, y1 - gy0)
    K3.paving(B, [tile(x, y, x + w - 1, y + h - 1) for (x, y, w, h) in lay["paving"]], 5)
    patches = _patches([tuple(t) for t in lay["traps"]])
    K3.paving(B, [tile(x, y, x + w - 1, y + h - 1) for (x, y, w, h) in patches], 9, spread=(1, 1, 1, 0.6, 0.22, 0.05))
    for (x, y, w, h) in patches:
        K3.sunk_traps(B, x - gx0, y - gy0, w, h)
    for i, (bx, by) in enumerate(lay["braziers"]):
        K3.soot(B, int(bx) + ox, int(by) - 1 + oy, 11, 6, i)
    for i, (name, (hx, hy)) in enumerate(lay["heaps"]):
        K3.debris(B, int(hx) + ox, int(hy) - 2 + oy, PILES[name][0] * 0.62, 7, i)
    diff = (B.mat != A.mat) | (B.step != A.step)
    B.shadow[:] = False; lit = np.array(B.image().convert("RGB"))
    B.shadow[:] = True; dark = np.array(B.image().convert("RGB"))
    sh = Sheet(1024); pieces = []
    H, W = diff.shape
    for py in range(0, H, PIECE):
        for px in range(0, W, PIECE):
            m = diff[py:py + PIECE, px:px + PIECE]
            if not m.any():
                continue
            ys, xs = np.nonzero(m); y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            mm = m[y0:y1, x0:x1]
            def rgba(src):
                o = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
                o[..., :3] = src[py + y0:py + y1, px + x0:px + x1]; o[..., 3] = np.where(mm, 255, 0)
                return o
            k = len(pieces)
            sh.add(("lit", k), [rgba(lit)]); sh.add(("shade", k), [rgba(dark)])
            pieces.append([px + x0 - ox, py + y0 - oy])
    img, boxes = sh.pack()
    out = {"note": "The Throne Room's floor (version 50): the Art builder's paving, sunk trap slabs, soot, trodden scrap and the stands' planks "
                   "(hl_king3.py paving, sunk_traps, soot, debris; hl3.py planks), painted on the room's own shape and kept where they differ "
                   "from plain dug floor. 'at' is a piece's top left from the room's top left corner (art pixels); 'rect' its lit picture, "
                   "'shade' the same in shadow. Baked by tools/rattlecrown_kit/bake.py.",
           "pieces": [{"at": [int(p[0]), int(p[1])], "rect": boxes[("lit", k)], "shade": boxes[("shade", k)]} for k, p in enumerate(pieces)]}
    fpath = os.path.join(GAME, "art/scrapyard/throne_floor")
    Image.fromarray(img).save(fpath + ".png"); json.dump(out, open(fpath + ".json", "w"), indent=1)
    print("floor", img.shape[1], img.shape[0], len(pieces), "pieces")


def _patches(tiles):
    """The trap tiles as rectangles (each patch is one)."""
    left = set(tiles); out = []
    while left:
        x, y = min(left, key=lambda t: (t[1], t[0]))
        w = 1
        while (x + w, y) in left: w += 1
        h = 1
        while all((x + i, y + h) in left for i in range(w)): h += 1
        for j in range(h):
            for i in range(w): left.discard((x + i, y + j))
        out.append((x, y, w, h))
    return out


if __name__ == "__main__":
    main()
