#!/bin/sh
# Rendert alle Turismo-Grafiken mit VectorCraft und kopiert die PNGs in den Mod.
# VC=/pfad/zu/vectorcraft-cli sh tools/art/build.sh
set -e
VC=${VC:-vectorcraft-cli}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=${OUT:-$ROOT/tools/art/out}
DEST=$ROOT/mod/ui/modules/apps/TurismoHub/art
python3 "$ROOT/tools/art/make_art.py" "$OUT"
python3 "$ROOT/tools/art/make_map.py" "$OUT"
mkdir -p "$DEST"
for s in "$OUT"/*_steps.json; do
  n=${s%_steps.json}
  case "$n" in */map_*) sc=1 ;; *) sc=2 ;; esac   # Stadtkarte ist schon 1920x1080
  "$VC" run --in "$n.svg" --commands "$s" --export "$n.png" --scale $sc > "$n.log"
  cp "$n.png" "$DEST/"
done
echo "fertig: $(ls "$DEST" | wc -l) Bilder in $DEST"
