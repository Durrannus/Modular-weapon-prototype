"""The shake and the fall of every tree that is felled like a pine (pine_0 to pine_5 and rowan_0 to rowan_2), made from the
game's own baked pictures by the Art builder's dig_fx.pine_frames (/mnt/project-files/art/dig-fx-v1/code/dig_fx.py: "a pure
function: a baker can call it on any pine picture"). Written into art/dig_fx/ beside the cracks and bursts already there,
which are kept as they are. Run it after bake.py whenever the trees change:

    python3 tools/highlands_kit/fell.py [repo]

Needs numpy and Pillow. Nothing here runs in the game."""
import json, os, re, sys
import numpy as np
from PIL import Image

sys.dont_write_bytecode = True
sys.path.insert(0, "/mnt/project-files/art/dig-fx-v1/code")
import dig_fx

TREE = re.compile(r"^(pine|rowan)_\d+$")


def main(repo):
    kit = json.load(open(os.path.join(repo, "art/highlands/kit.json")))["things"]
    things = np.array(Image.open(os.path.join(repo, "art/highlands/things.png")).convert("RGBA"))
    doc = json.load(open(os.path.join(repo, "art/dig_fx/dig_fx.json")))
    sheet = np.array(Image.open(os.path.join(repo, "art/dig_fx/dig_fx.png")).convert("RGBA"))
    items = []
    for name, info in doc["sprites"].items():          # the cracks and bursts, as they are
        if TREE.match(name.split("_shake")[0].split("_fall")[0]):
            continue
        x, y, w, h = info["box"]
        items.append((name, sheet[y:y + h, x:x + w].copy(), {k: v for k, v in info.items() if k != "box"}))
    trees = sorted(n for n in kit if TREE.match(n) and "rect" in kit[n])
    for name in trees:
        r = kit[name]["rect"]
        pic = things[r[1]:r[1] + r[3], r[0]:r[0] + r[2]].copy()
        for fn, (im, ft) in dig_fx.pine_frames(pic, tuple(kit[name]["foot"])).items():
            items.append(("%s_%s" % (name, fn), im, {"foot": [int(ft[0]), int(ft[1])]}))
    # shelves, in the order made (as dig_fx.build packs them)
    wd = 1024; x = y = 1; shelf = 0; table = {}; put = []
    for name, im, extra in items:
        h, w = im.shape[:2]
        if x + w + 1 > wd:
            x = 1; y += shelf + 1; shelf = 0
        put.append((x, y, im)); table[name] = {"box": [x, y, w, h], **extra}; x += w + 1; shelf = max(shelf, h)
    out = np.zeros((y + shelf + 1, wd, 4), np.uint8)
    for x, y, im in put:
        out[y:y + im.shape[0], x:x + im.shape[1]] = im
    Image.fromarray(out).save(os.path.join(repo, "art/dig_fx/dig_fx.png"))
    doc["sprites"] = table
    json.dump(doc, open(os.path.join(repo, "art/dig_fx/dig_fx.json"), "w"), indent=1)
    print("trees", len(trees), "sprites", len(table), "sheet", out.shape[1], "x", out.shape[0])


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
