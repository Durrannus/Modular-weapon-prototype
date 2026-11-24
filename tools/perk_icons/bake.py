# The role trees' perk icons (version 56): python3 tools/perk_icons/bake.py art/roles/perk_icons.png
# Writes the sheet, its .json (the order) and a big tinted preview beside it (not kept in the game).
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glyphs import G
from PIL import Image
ORDER = ["challenge", "unmoved", "bodyguard", "payback", "tempered", "shoulder_charge", "plate", "unbroken",
 "punish", "close_call", "flank", "keep_the_chain", "sharp", "kill_rush", "expose", "execution",
 "kindle", "helping_hand", "banked_warmth", "hearth", "drift", "bolster", "flare", "rekindle",
 "ore_sense", "vein_breaker", "recall", "field_anvil", "laden", "second_look", "deep_pockets", "forge_prophet"]
bad = []
sheet = Image.new("RGBA", (16 * 8, 16 * 4), (0, 0, 0, 0))
for n, name in enumerate(ORDER):
    rows = [r for r in G[name].strip("\n").split("\n")]
    if len(rows) != 16 or any(len(r) != 16 for r in rows):
        bad.append((name, len(rows), [len(r) for r in rows]))
    for y, r in enumerate(rows[:16]):
        for x, ch in enumerate(r[:16]):
            if ch == "#":
                sheet.putpixel(((n % 8) * 16 + x, (n // 8) * 16 + y), (255, 255, 255, 255))
            elif ch == "+":
                sheet.putpixel(((n % 8) * 16 + x, (n // 8) * 16 + y), (150, 150, 150, 255))
print("bad:", bad)
out = sys.argv[1] if len(sys.argv) > 1 else "perk_icons.png"
sheet.save(out)
json.dump({"size": 16, "cols": 8, "order": ORDER}, open(out.replace(".png", ".json"), "w"), indent=1)
# A preview: tinted like the game, big, on the plate colour.
prev = Image.new("RGBA", (sheet.width * 6 + 7*6, sheet.height * 6 + 3*6), (25, 20, 42, 255))
big = sheet.resize((sheet.width * 6, sheet.height * 6), Image.NEAREST)
tint = Image.new("RGBA", big.size, (232, 228, 188, 255))
from PIL import ImageChops
col = ImageChops.multiply(big, tint)
for n in range(32):
    cx, cy = (n % 8), (n // 8)
    tile = col.crop((cx*96, cy*96, cx*96+96, cy*96+96))
    prev.alpha_composite(tile, (cx*102, cy*102))
prev.save(out.replace(".png", "_preview.png"))
