#!/bin/bash
# Runs the checks quietly: one line for each suite, and under it only what failed.
# The whole output of every suite is kept in a log folder, for when it is needed.
#
#   tests/run.sh [--full] [--jobs N] [area or suite ...]
#
# Areas (more than one may be named; nothing named means "all"):
#   highlands  the Highlands: land, map, snow, enemies, loot, Rattlecrown, Pip, gear, tools, levels, saving
#   weapons    the weapons, their runes and threads, the forge's numbers, the lab, combat rules
#   cave       the tutorial cave played through, the forge guardian, the title, the arena's switches
#   all        all three (about five minutes)
# A suite can be named on its own too: tests/run.sh lab highlands_map
#
#   --full     print each suite's whole output after its line, not only the failures
#   --jobs N   how many suites run at once (3 by default)
#
# Godot: $GODOT, else `godot` on the PATH. The logs go to $CHECKS_LOG (default /tmp/checks):
# one file per suite, named after it. Exits 1 if any suite failed.
# Not in here: the online check (tests/online.sh, two copies of the game) and the version stamp
# check (tests/version_check.gd), which are run on their own before a version is pushed.

cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-$(command -v godot)}"
if [ -z "$GODOT" ] || [ ! -x "$GODOT" ]; then
  echo "No Godot: set GODOT=/path/to/godot" >&2
  exit 2
fi
LOG="${CHECKS_LOG:-/tmp/checks}"
FULL=0
JOBS=3

HIGHLANDS="highlands highlands_map highlands_snow highlands_foes highlands_creatures highlands_loot highlands_crown highlands_folk highlands_gear highlands_tools highlands_levels saving"
WEAPONS="test_swing_build blade_shapes bow bow_runes hammer hammer_runes staff staff_runes active_runes combat_rules feel_check spirit check_parts lab"
CAVE="cave_playthrough cave_words smoke_forge title_screen arena_switches"

suites=()
while [ $# -gt 0 ]; do
  case "$1" in
    --full) FULL=1;;
    --jobs) shift; JOBS="$1";;
    highlands) suites+=($HIGHLANDS);;
    weapons) suites+=($WEAPONS);;
    cave) suites+=($CAVE);;
    all) suites+=($HIGHLANDS $WEAPONS $CAVE);;
    *) if [ -f "tests/$1.gd" ]; then suites+=("$1"); else echo "No area or suite called $1" >&2; exit 2; fi;;
  esac
  shift
done
[ ${#suites[@]} -eq 0 ] && suites=($HIGHLANDS $WEAPONS $CAVE)

mkdir -p "$LOG"
rm -f "$LOG"/*.txt "$LOG"/*.line

# The lines worth reading in a suite's output: its failures and script errors (not the engine's own chatter).
failures() {
  grep -E '^(FAIL|SCRIPT ERROR|ERROR: [^C]|Parse Error|   at: .*\.gd)' "$1" | grep -v 'ERROR: Condition "status < 0"' | head -n 25
}

one() {
  local t=$1 start=$(date +%s)
  timeout 900 "$GODOT" --headless --path . --fixed-fps 60 -s "tests/$t.gd" > "$LOG/$t.txt" 2>&1
  local code=$? secs=$(( $(date +%s) - start ))
  local fails=$(grep -c '^FAIL' "$LOG/$t.txt")
  if [ $code -eq 0 ] && [ "$fails" -eq 0 ]; then
    echo "PASS  $t  (${secs} s)" > "$LOG/$t.line"
  else
    {
      echo "FAIL  $t  (exit $code, $fails failed, ${secs} s; whole output: $LOG/$t.txt)"
      failures "$LOG/$t.txt" | sed 's/^/      /'
    } > "$LOG/$t.line"
  fi
}

for t in "${suites[@]}"; do
  one "$t" &
  while [ "$(jobs -r | wc -l)" -ge "$JOBS" ]; do wait -n; done
done
wait

bad=0
for t in "${suites[@]}"; do
  cat "$LOG/$t.line"
  grep -q '^FAIL' "$LOG/$t.line" && bad=$((bad + 1))
  if [ $FULL -eq 1 ]; then
    sed 's/^/      | /' "$LOG/$t.txt"
  fi
done
echo "$(( ${#suites[@]} - bad )) of ${#suites[@]} suites passed"
[ $bad -eq 0 ]
