"""The Highlands look of version 65: the Art builder's concept v4 and v4.1 (25 Nov 2026), baked for the game.

Darren said go on it on 25 November 2026 (22:46Z). The look lives in the Art builder's own code, in
/mnt/project-files/art/highlands-light-concept-v4/code/:

    hl_detail.py    the detail pass: chiselled, mossy rock with rubble at its foot, textured ground, turf by the damp
                    rule, sprig heather, the Scots pine, the rowan, the juniper and gorse
    hl_grow.py      rule 26 (everything grown into the land, Darren 23 and 25 Nov): small plants drawn into the ground
                    with no outline, damp beds, roots, canopy shadows and litter, scrap half buried
    hl_foliage.py   the foliage ramps and plants hl_grow uses
    hl_light_concept2.py   the bold palette (BOLD): only its colour tables are read here, by name

This file loads them beside hl3.py and friends (the land kit's own code), swaps the bold palette in, and holds the
helpers bake.py uses to stand one thing on a small patch of plain land, let the Art builder's code seat it (hl_grow:
tree, seat, bury, bush, plant), and cut out what that leaves: the thing's picture with its foot and anything drawn in
front of it, and the MARK it leaves in the ground (damp bed, canopy shadow, litter, roots, rust, blades). The game
lays each mark into the ground under the thing (scripts/highlands/land_grow.gd), relative to whatever ground is there.

Needs numpy and Pillow. Nothing here runs in the game.
"""
import ast, os, sys, types
import numpy as np

ART = "/mnt/project-files/art/"
LOOK_CODE = ART + "highlands-light-concept-v4/code"
# hl_grow.heap borrows plate drawing from the Scrapyard code (hl_king3), which needs these two folders too
EXTRA_CODE = [ART + "highlands-rattlecrown-v2/code", ART + "concept-art-3/code"]
# materials whose mark is relative to the ground under it (a step lighter or darker than whatever lies there)
RELATIVE = ("grass", "turf", "mixg", "earth", "mixe", "rustsoil", "snow", "floor")
GREENS = ("grass", "turf", "mixg")


def load(art_code, look_code=LOOK_CODE):
    """Imports the look's modules (art_code holds hl3.py) and swaps the bold palette in. Returns them in a namespace."""
    sys.dont_write_bytecode = True
    for p in reversed([look_code, art_code] + EXTRA_CODE):     # (the look first, hl3's own core before concept-art-3's)
        if p not in sys.path:
            sys.path.insert(0, p)
    from core import hx
    # hl_light_concept2 draws whole concept boards and needs the Art builder's own machine to import; hl_grow only
    # wants its palette, so only its colour tables are read (by name, from its source).
    if "hl_light_concept2" not in sys.modules:
        mod = types.ModuleType("hl_light_concept2"); ns = mod.__dict__
        ns["hx"] = hx; ns["np"] = np; ns["H_"] = lambda s: [hx(c) for c in s.split()]
        for node in ast.parse(open(os.path.join(look_code, "hl_light_concept2.py")).read()).body:
            if isinstance(node, ast.Assign) and any(getattr(t, "id", "") in ("BOLD", "TURF", "EARTH", "GORSE") for t in node.targets):
                exec(compile(ast.Module([node], []), "hl_light_concept2", "exec"), ns)
        sys.modules["hl_light_concept2"] = mod
    import hl3, hl3_props as PR, hl3_snow as SN, hl_detail as D, hl_foliage as FO, hl_grow as GR
    V2 = sys.modules["hl_light_concept2"]
    hl3.PAL.update(V2.BOLD); SN._register()                   # the bold moor (V1.Palette(BOLD) in the concept)
    return types.SimpleNamespace(hl3=hl3, PR=PR, SN=SN, D=D, FO=FO, GR=GR, BOLD=V2.BOLD)


class Patch:
    """A small piece of plain land (size x size tiles) to stand one thing on. ground: what it is (grass, earth or snow)."""
    def __init__(s, L, size=10, ground="grass", seed=0):
        hl3, GR = L.hl3, L.GR
        s.L = L
        rows = ["." * size] * size
        W = (L.SN.SnowWorld if ground == "snow" else hl3.World)(rows, seed=seed + 1, tone=False)
        s.base = {"grass": 3, "earth": 2, "snow": 4}[ground]
        W.mat[:] = hl3.MID[ground]; W.step[:] = s.base
        for k in ("shadow", "cover", "rock", "water", "floor", "path", "road", "face", "capm", "vein"):
            if hasattr(W, k): setattr(W, k, np.zeros((W.h, W.w), bool))
        W.plain = np.ones((W.h, W.w), bool)
        W.sprites = []
        W._g0 = W.step.copy(); W._m0 = W.mat.copy()
        s.W = W; s.mat0 = W.mat.copy(); s.step0 = W.step.copy()
        s.x, s.y = W.w // 2, W.h * 2 // 3                         # where the thing's foot goes (room above it for a crown)

    def picture(s):
        """Every picture now standing on the patch, laid as the concept lays them (by depth, sinking ones cut at the
        ground), as one image with the first thing's foot. None when nothing stands there."""
        W = s.W
        if not W.sprites: return None
        placed = []
        for sp in sorted(W.sprites, key=lambda q: (q["z"], q["y"])):
            im, (fx, fy) = sp["im"], sp["ft"]; a = im.a
            if sp["sink"]:
                a = a.copy(); a[max(0, fy - sp["sink"]):] = 0
            placed.append((a, sp["x"] - fx, sp["y"] - fy + sp["sink"]))
        x0 = min(p[1] for p in placed); y0 = min(p[2] for p in placed)
        x1 = max(p[1] + p[0].shape[1] for p in placed); y1 = max(p[2] + p[0].shape[0] for p in placed)
        out = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
        for a, ox, oy in placed:
            sub = out[oy - y0:oy - y0 + a.shape[0], ox - x0:ox - x0 + a.shape[1]]
            m = a[..., 3] > 0; sub[m] = a[m]
        al = out[..., 3] > 0
        if not al.any(): return None
        ys, xs = np.nonzero(al)
        cx0, cy0 = xs.min(), ys.min()
        out = out[cy0:ys.max() + 1, cx0:xs.max() + 1]
        main = W.sprites[0]
        return out, [int(main["x"] - x0 - cx0), int(main["y"] - y0 - cy0)]

    def mark(s):
        """What standing the thing there did to the ground, as a picture the game reads: per pixel R = the material
        (its place in hl3.MATS), G = the step (B = 2) or 128 + how many steps up or down from the ground there (B = 1).
        Returns (image, [dx, dy] from the foot to its top left) or None."""
        hl3 = s.L.hl3; W = s.W
        ch = (W.mat != s.mat0) | (W.step != s.step0)
        if not ch.any(): return None
        ys, xs = np.nonzero(ch); x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        out = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
        rel_ids = [hl3.MID[n] for n in RELATIVE if n in hl3.MID]
        for y, x in zip(ys, xs):
            m = int(W.mat[y, x]); st = int(W.step[y, x])
            if m in rel_ids: out[y - y0, x - x0] = (m, 128 + st - int(s.step0[y, x]), 1, 255)
            else: out[y - y0, x - x0] = (m, st, 2, 255)
        return out, [int(x0 - s.x), int(y0 - s.y)]


def sprite_shadow(a, foot, slen=20.0):
    """The shadow a standing picture throws, as the land kit's things always have (down and to the right, and hugging
    the base): a white mask and where its top left lies from the foot. hl3.World.image draws the same."""
    solidm = a[..., 3] > 0
    if not solidm.any(): return None
    fx, fy = foot
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
    return M, [int(mx), int(my)]
