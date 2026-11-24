#!/usr/bin/env python3
"""Bakes Rattlecrown's fight for the game out of the Art builder's own drawing code (version 50).

The look is the Art builder's round 2, which Darren shaped on 23 November ("He needs more spikes like actual scrap
armour", "Change the throne to match the scrap look too", "Make the chest golden and the gate better", "it has to look
part of the world and not just a thing placed onto", "put scrap piles around the arena") and asked for in the game on 24
November ("Add the new art for scrap boss fight", then "Get art thread to animate"). It lives in hl_rc_anim.py (the
animation), hl_king3.py and hl_king2.py, in /mnt/project-files/art/highlands-rattlecrown-v2/code/ (the rough stills'
code in highlands-rattlecrown-v2-rough/code/ is the fallback), with the cave's kit (core.py, knight.py, props.py) and
the Highlands land (hl3.py). The king, his throne, the gate, the hoard, the spikes and the crowd are animated; the
scrap piles, the stands and the floor are stills.

What it writes (and what reads it):
  art/foes/rattlecrown.png, .json      the king on foot, crowned, and on his throne (scripts/foes/rattlecrown.gd, crown.gd)
  art/scrapyard/scrapyard.png, .json   the gate, the hoard's chest and portcullis, the scrap piles, the spikes, the
                                       stands and the watching goblins (crown.gd, crown_plan.gd)
  art/scrapyard/throne_floor.png, .json  the Throne Room's floor: paving, the traps' sunk slabs, soot, trodden scrap and
                                       the stands' planks, in pieces the land painter paints into the dug floor
                                       (land_painter.gd, CrownPlan.stamp)
  art/scrapyard/rooms_floor.png, .json   the other rooms' floors (version 52): soot under their braziers, scrap trodden
                                       in round their piles, the Gatehouse's paved way (the same readers)

    python3 tools/rattlecrown_kit/bake.py --godot /path/to/godot

Where things stand in the rooms comes from the game (CrownPlan.throne_layout and CrownPlan.room_dress_layout, printed
by layout.gd), so the floors are painted to fit. Needs numpy and Pillow. Nothing here runs in the game.
"""
import argparse, json, os, subprocess, sys, tempfile
import numpy as np
from PIL import Image

ART = "/mnt/project-files/art/"
CODE = [ART + "highlands-rattlecrown-v2/code", ART + "highlands-rattlecrown-v2-rough/code", ART + "highlands-concept/v3/code", ART + "concept-art-3/code",
        ART + "highlands-scrapyard-v1/code", ART + "highlands-enemies-v1/code"]
GAME = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
T = 16
PIECE = 128                 # the floor is cut into pieces no bigger than this (a chunk of land is 256)
PILES = {                   # the Throne Room's scrap piles, as the Art builder's still has them: (wide, deep, seed)
    "scrap_pile_big": (64, 38, 2), "scrap_pile_mid": (46, 28, 4), "scrap_pile_side": (44, 26, 6), "scrap_pile_small": (32, 18, 8),
    "scrap_heap_large": (48, 30, 11), "scrap_heap_small": (32, 20, 12),     # the other rooms' (same names as before)
}


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
    import hl_king2 as K2, hl_king3 as K3, hl3, core, hl_rc_anim as A

    # --- Rattlecrown and his throne: animated (Darren, 24 Nov: "Get art thread to animate") -------------------------
    rpath = os.path.join(GAME, "art/foes/rattlecrown")
    old = json.load(open(rpath + ".json")); old_img = np.array(Image.open(rpath + ".png").convert("RGBA"))
    sh = Sheet(1200); enemies = {}
    fps_of = A.king_strips()
    for name, crowned, note in (("rattlecrown", False, "Rattlecrown on foot in scrap armour with his cog club, the crown at his belt (phase 2)."),
                                ("rattlecrown_crowned", True, "With the crown on (phase 3): the same strips, no crown_on.")):
        strips = {}; frame = feet = None
        for s_name in A.KING_ORDER:
            if crowned and s_name == "crown_on":
                continue
            fr = A.king_frames(s_name, crowned)
            sh.add((name, s_name), [arr(im) for im, _ in fr])
            frame = [fr[0][0].w, fr[0][0].h]; feet = list(fr[0][1])
            strips[s_name] = {"frames": len(fr), "fps": fps_of[s_name][0]}
        # Where the art puts things, in art pixels in front of his feet and up (the Art builder's README): the club's head
        # on slam frame 1, the lump leaving his hand on toss frame 0, the levelled club in the charge.
        enemies[name] = {"frame": frame, "origin_feet": feet, "strips": strips,
                         "reach": {"slam": [81, 11], "hand": [23, 49], "charge": [89, 26]},
                         "note": note + " Faces right, the club in his right hand on the right of the frame; mirror for left."}
    strips = {}; frame = feet = None
    for s_name in ("idle", "point", "kick", "wreck"):
        fr = A.throne_frames(s_name)
        sh.add(("throne", s_name), [arr(im) for im, _ in fr])
        frame = [fr[0][0].w, fr[0][0].h]; feet = list(fr[0][1])
        strips[s_name] = {"frames": len(fr), "fps": A.THRONE_STRIPS[s_name]}
    enemies["throne"] = {"frame": frame, "origin_feet": feet, "solid": [104, 46], "strips": strips,
                         "note": "The scrap throne. Feet = the middle of the front of its lower step. idle and point have him on it; kick: he "
                                 "stands 6 px below its feet, kicks back, it flies apart, the heap; then wreck, with him on foot 6 px below its feet."}
    sc = A.scrap_shot()
    sh.add(("shot", "scrap"), [arr(im) for im, _ in sc])
    for s_name in ("slam_mark", "scrap_mark"):                # the floor marks are round 1's, unchanged
        info = old["shots"][s_name]; x, y, w, h = info["box"]; fw = info["frame"][0]
        sh.add(("shot", s_name), [old_img[y:y + h, x + k * fw:x + (k + 1) * fw].copy() for k in range(info["frames"])])
    img, boxes = sh.pack()
    for name, e in enemies.items():
        for s_name, st in e["strips"].items():
            st["box"] = boxes[(name, s_name)]
    shots = {"scrap": {"frame": [sc[0][0].w, sc[0][0].h], "origin": list(sc[0][1]), "frames": len(sc), "fps": 10, "box": boxes[("shot", "scrap")],
                       "note": "The lump he throws, tumbling."}}
    for s_name in ("slam_mark", "scrap_mark"):
        shots[s_name] = dict(old["shots"][s_name]); shots[s_name]["box"] = boxes[("shot", s_name)]
    out = {"note": "Rattlecrown, round 2, animated (the Art builder's hl_rc_anim.py), baked by tools/rattlecrown_kit/bake.py. Everything "
                   "faces right; strips run left to right.", "enemies": enemies, "shots": shots}
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

    # The gate: shut, its two leaves swinging back against the posts, open (the Art builder's animation).
    for st, fps in (("shut", 0), ("opening", 8), ("open", 0)):
        fr = A.gate_frames(st)
        put("gate_front_" + st, [arr(im) for im, _ in fr], fr[0][1], fps=fps if len(fr) > 1 else 0)
    # The scrap piles.
    for name, (w, h, seed) in PILES.items():
        p, pf = K3.scrap_pile(w, h, seed)
        put(name, [arr(p)], pf, solid=[int(w * 0.72), 8])
    # The braziers stay the cave's own, as the first draft had them.
    b = yold["brazier"]; put("brazier", [cut(yimg, [b["box"][0] + k * b["frame"][0], b["box"][1], b["frame"][0], b["frame"][1]]) for k in range(b["frames"])],
                             b["origin"], fps=b.get("fps", 5))
    # His hoard: the golden chest whose lid swings back over the coins, and its portcullis rising into the lintel.
    fr = A.hoard_chest_frames()
    put("hoard_chest", [arr(im) for im, _ in fr], fr[0][1], foot=list(fr[0][1]), solid=[26, 8])
    fr = A.hoard_chest_frames(True)
    put("hoard_chest_empty", [arr(im) for im, _ in fr], fr[0][1], foot=list(fr[0][1]), solid=[26, 8])
    for st, fps in (("shut", 0), ("opening", 8), ("open", 0)):
        fr = A.hoard_gate_frames(st)
        put("hoard_gate_" + st, [arr(im) for im, _ in fr], fr[0][1], fps=fps if len(fr) > 1 else 0)
    # The spikes (their slabs, collars and kerbs are painted into the floor): down, rattling, rising, up.
    for st in ("down", "warn", "rise", "up"):
        fr = A.spike_frames(st)
        put("spike_trap_" + st, [arr(im) for im, _ in fr], fr[0][1], fps=A.SPIKE_FPS[st] if len(fr) > 1 else 0)
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
    for i, pose in enumerate(("cheer", "lean", "fist", "drum")):     # (the Art builder's seeds for each pose)
        for cap in (False, True):
            fr = A.goblin_frames(pose, cap, i)
            put("goblin_%s%s" % (pose, "_cap" if cap else ""), [arr(im) for im, _ in fr], fr[0][1], fps=4)
    img, boxes = sh.pack()
    for name in sprites:
        sprites[name]["box"] = boxes[name]
    out = {"note": "The Scrapyard's gate, Rattlecrown's hoard, the scrap piles, the spike traps' spikes, the stands and the watching goblins: "
                   "round 2 (the Art builder's hl_king3.py and hl_rc_anim.py), baked by tools/rattlecrown_kit/bake.py. The gate, the hoard, "
                   "the spikes and the crowd move; the piles and the stands are stills.", "sprites": sprites}
    Image.fromarray(img).save(ypath + ".png"); json.dump(out, open(ypath + ".json", "w"), indent=1)
    print("scrapyard", img.shape[1], img.shape[0])

    # --- The Throne Room's floor ---------------------------------------------------------------------------------
    lay = _layout(a, again=True)            # (the throne's size, and so where the braziers stand, came from the sheet just written)
    floor(lay, hl3, K3)
    rooms_floor(lay["rooms"], hl3, K3)


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
    sh = Sheet(1024); pieces = []
    _cut_pieces(A, B, ox, oy, sh, pieces, "throne")
    img, boxes = sh.pack()
    out = {"note": "The Throne Room's floor (version 50): the Art builder's paving, sunk trap slabs, soot, trodden scrap and the stands' planks "
                   "(hl_king3.py paving, sunk_traps, soot, debris; hl3.py planks), painted on the room's own shape and kept where they differ "
                   "from plain dug floor. 'at' is a piece's top left from the room's top left corner (art pixels); 'rect' its lit picture, "
                   "'shade' the same in shadow. Baked by tools/rattlecrown_kit/bake.py.",
           "pieces": [{"at": [int(p[0]), int(p[1])], "rect": boxes[("lit", k)], "shade": boxes[("shade", k)]} for k, p in enumerate(pieces)]}
    fpath = os.path.join(GAME, "art/scrapyard/throne_floor")
    Image.fromarray(img).save(fpath + ".png"); json.dump(out, open(fpath + ".json", "w"), indent=1)
    print("floor", img.shape[1], img.shape[0], len(pieces), "pieces")


def _cut_pieces(A, B, ox, oy, sh, pieces, room):
    """Keeps what B paints that plain dug floor (A) does not, cut into pieces no bigger than PIECE, lit and in shadow;
    each piece's top left goes in `pieces` as [x, y, room] from the room's top left corner (art pixels)."""
    diff = (B.mat != A.mat) | (B.step != A.step)
    B.shadow[:] = False; lit = np.array(B.image().convert("RGB"))
    B.shadow[:] = True; dark = np.array(B.image().convert("RGB"))
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
            pieces.append([px + x0 - ox, py + y0 - oy, room])


HEAP_WIDE = {"scrap_heap_large": 50, "scrap_heap_small": 34}    # the other rooms' piles (the Scrapyard sheet's frames)


def rooms_floor(rooms, hl3, K3):
    """The Scrapyard's other rooms (version 52): soot under each brazier, scrap trodden in round each pile and the
    Gatehouse's paved way, painted as the Throne Room's floor is, on a map of each room's own shape."""
    sh = Sheet(1024); pieces = []
    for n, (name, r) in enumerate(sorted(rooms.items())):
        RW, RH = int(r["size"][0]), int(r["size"][1]); M = 2
        GW, GH = RW + 2 * M, RH + 2 * M
        def grid():
            G = hl3.Grid(GW, GH); G.rect(0, 0, GW - 1, GH - 1, "#"); G.rect(M, M, M + RW - 1, M + RH - 1, "o")
            return G.rows()
        A = hl3.World(grid(), 23 + n, long_grass=0.0)
        B = hl3.World(grid(), 23 + n, long_grass=0.0)
        ox = oy = M * T
        if r["paving"]:
            K3.paving(B, [(x + M, y + M, x + M + w - 1, y + M + h - 1) for (x, y, w, h) in r["paving"]], 7 + n)
        sx, sy = int(r["soot"][0]), int(r["soot"][1])
        for i, ((bx, by), _flip) in enumerate(r["braziers"]):
            K3.soot(B, int(bx) + ox, int(by) - 1 + oy, sx, sy, i + 10 * n)
        for i, (pic, (hx, hy), _flip, _cover) in enumerate(r["heaps"]):
            K3.debris(B, int(hx) + ox, int(hy) - 2 + oy, HEAP_WIDE.get(pic, 40) * float(r["litter"]), 7, i + 10 * n)
        _cut_pieces(A, B, ox, oy, sh, pieces, name)
    img, boxes = sh.pack()
    out = {"note": "The Scrapyard's other rooms' floors (version 52): the Art builder's soot under each brazier, scrap trodden in round "
                   "each pile and the Gatehouse's paved way (hl_king3.py soot, debris, paving), painted on each room's own shape and kept "
                   "where they differ from plain dug floor. Per room, 'at' is a piece's top left from the room's top left corner (art "
                   "pixels); 'rect' its lit picture, 'shade' the same in shadow. Where they lie comes from CrownPlan.room_dress_layout. "
                   "Baked by tools/rattlecrown_kit/bake.py.", "rooms": {}}
    for k, p in enumerate(pieces):
        out["rooms"].setdefault(p[2], []).append({"at": [int(p[0]), int(p[1])], "rect": boxes[("lit", k)], "shade": boxes[("shade", k)]})
    fpath = os.path.join(GAME, "art/scrapyard/rooms_floor")
    Image.fromarray(img).save(fpath + ".png"); json.dump(out, open(fpath + ".json", "w"), indent=1)
    print("rooms floor", img.shape[1], img.shape[0], len(pieces), "pieces")


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
