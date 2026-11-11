# Music

Looping background music, made from scratch in Python (numpy only, no samples).
Played by `scripts/music.gd`; the cave switches tracks in `scripts/cave/cave.gd`.

| File | Where | Made by |
|---|---|---|
| `cave_calm.ogg` | tutorial cave, from the end of the cutscene, and again after the guardian falls | `python3 cave_music.py M out/` (128 s loop, D minor) |
| `cave_boss.ogg` | the forge guardian fight | `python3 boss_music.py out/` (60 s loop, 128 BPM, D minor) |

The scripts write WAV files. Turn them into Ogg with
`ffmpeg -i in.wav -c:a libvorbis -q:a 6 out.ogg`. Every loop is built on a circular
timeline (notes and reverb wrap round), so the files repeat with no seam.
`cave_music.py A` and `B` are the two earlier drafts the calm track was mixed from.
