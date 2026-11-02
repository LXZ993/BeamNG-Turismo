#!/bin/sh
# Rendert alle Turismo-Grafiken mit VectorCraft und kopiert die PNGs in den Mod.
# VC=/pfad/zu/vectorcraft-cli sh tools/art/build.sh
set -e
VC=${VC:-vectorcraft-cli}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=${OUT:-$ROOT/tools/art/out}
DEST=$ROOT/mod/ui/modules/apps/TurismoHub/art
python3 "$ROOT/tools/art/make_art.py" "$OUT"
mkdir -p "$DEST"
for s in "$OUT"/*_steps.json; do
  n=${s%_steps.json}
  "$VC" run --in "$n.svg" --commands "$s" --export "$n.png" --scale 2 > "$n.log"
  cp "$n.png" "$DEST/"
done
echo "fertig: $(ls "$DEST" | wc -l) Bilder in $DEST"
