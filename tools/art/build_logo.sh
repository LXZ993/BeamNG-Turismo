#!/bin/sh
# Rendert Logo und Hauptmenü-Icon mit VectorCraft und legt die gewählte Variante in den Mod.
# VC=/pfad/zu/vectorcraft-cli LOGO=a sh tools/art/build_logo.sh     (LOGO = a | b | c)
# Unter Windows ohne sh: die SVGs mit render.cmd im Ausgabeordner rendern, dann die zwei Zeilen
# mit crop_png.py unten von Hand ausführen.
set -e
VC=${VC:-vectorcraft-cli}
LOGO=${LOGO:-a}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=${OUT:-$ROOT/tools/art/out/logo}
DEST=$ROOT/mod/ui/modules/apps/TurismoHub/art
python3 "$ROOT/tools/art/make_logo.py" "$OUT"
for s in "$OUT"/*_steps.json; do
  n=${s%_steps.json}
  "$VC" run --in "$n.svg" --commands "$s" --export "$n.png" --scale 2 > "$n.log"
done
mkdir -p "$DEST"
python3 "$ROOT/tools/art/crop_png.py" "$OUT/logo_${LOGO}_auf_dunkel.png" "$DEST/logo_auf_dunkel.png" 16
python3 "$ROOT/tools/art/crop_png.py" "$OUT/logo_${LOGO}_auf_hell.png" "$DEST/logo_auf_hell.png" 16
python3 "$ROOT/tools/art/crop_png.py" "$OUT/icon_${LOGO}.png" "$DEST/menu_icon.png" 6
echo "Logo-Variante $LOGO nach $DEST kopiert"
