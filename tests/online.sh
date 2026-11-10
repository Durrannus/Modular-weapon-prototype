#!/bin/bash
# Runs two copies of the game against each other on this computer and checks
# they stay identical all the way through the tutorial cave (or the arena).
#   tests/online.sh /path/to/godot [fast|real] [extra arguments for both copies...]
# "fast" (the default) runs as quickly as the computer can, which also stresses
# the waiting: each copy keeps getting ahead of the other. "real" runs at normal
# speed, like two people playing.
# Arguments starting host: or join: go to that copy only (host:slow=8).
GODOT="$1"; shift
SPEED="${1:-fast}"; shift
OUT="${OUT:-/tmp/online_test}"
PORT="${PORT:-24601}"
mkdir -p "$OUT"
FPS="--fixed-fps 60"
[ "$SPEED" = "real" ] && FPS=""
HOST_ARGS=(); JOIN_ARGS=()
for a in "$@"; do
  case "$a" in
    host:*) HOST_ARGS+=("${a#host:}");;
    join:*) JOIN_ARGS+=("${a#join:}");;
    *) HOST_ARGS+=("$a"); JOIN_ARGS+=("$a");;
  esac
done
cd "$(dirname "$0")/.."
timeout 900 "$GODOT" --headless --path . $FPS --script res://tests/online_cave.gd -- net=host port=$PORT dump="$OUT/host.txt" "${HOST_ARGS[@]}" > "$OUT/host.log" 2>&1 &
H=$!
timeout 900 "$GODOT" --headless --path . $FPS --script res://tests/online_cave.gd -- net=join port=$PORT dump="$OUT/join.txt" "${JOIN_ARGS[@]}" > "$OUT/join.log" 2>&1 &
J=$!
wait $H; HC=$?
wait $J; JC=$?
echo "--- host (exit $HC)"; grep -v "^Godot Engine\|^$\|ObjectDB\|stage:" "$OUT/host.log" | tail -12
echo "--- join (exit $JC)"; grep -v "^Godot Engine\|^$\|ObjectDB\|stage:" "$OUT/join.log" | tail -12
# The checksums of every tick both copies reached must be the same.
if python3 - "$OUT/host.txt" "$OUT/join.txt" <<'PY'
import sys
a = [l.split(" ", 2) for l in open(sys.argv[1])]
b = [l.split(" ", 2) for l in open(sys.argv[2])]
n = min(len(a), len(b))
bad = [i for i in range(n) if a[i][:2] != b[i][:2]]
print("--- %d checksums on the host, %d on the joiner" % (len(a), len(b)))
if bad:
    i = bad[0]
    print("FIRST DIFFERENCE at tick", a[i][0]); print(" host:", a[i][2][:600]); print(" join:", b[i][2][:600])
    sys.exit(1)
if n < 10:
    print("too few checksums to mean anything"); sys.exit(1)
print("all %d checksums match" % n)
PY
then SAME=0; else SAME=1; fi
[ $HC -eq 0 ] && [ $JC -eq 0 ] && [ $SAME -eq 0 ] && echo "ONLINE TEST PASSED" || { echo "ONLINE TEST FAILED"; exit 1; }
