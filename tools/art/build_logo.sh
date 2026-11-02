#!/bin/sh
# Rendert das Beam-Turismo-Logo (Schrift Russo One, Runde 8) mit VectorCraft und legt die vier Bilder in den Mod.
# VC=/pfad/zu/vectorcraft-cli sh tools/art/build_logo.sh
# Unter Windows ohne sh: SVGs mit render.cmd im Ausgabeordner rendern, dann die Zeilen unten von Hand ausführen.
# Danach in einem Mod-Ordner, der noch die alten Texte hat: apply_logo_patch.py und apply_logo_russo.py.
set -e
VC=${VC:-vectorcraft-cli}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=${OUT:-$ROOT/tools/art/out/logo}
DEST=$ROOT/mod/ui/modules/apps/TurismoHub/art
python3 "$ROOT/tools/art/make_logo.py" "$OUT" runde8
for s in "$OUT"/*_steps.json; do
  n=${s%_steps.json}
  "$VC" run --in "$n.svg" --commands "$s" --export "$n.png" --scale 2 > "$n.log"
done
mkdir -p "$DEST"
python3 "$ROOT/tools/art/crop_png.py" "$OUT/komplett_frei_dunkel.png" "$DEST/logo_auf_dunkel.png" 16
python3 "$ROOT/tools/art/crop_png.py" "$OUT/komplett_frei_hell.png" "$DEST/logo_auf_hell.png" 16
python3 "$ROOT/tools/art/crop_png.py" "$OUT/leiste_frei_dunkel.png" "$DEST/logo_leiste.png" 12
python3 "$ROOT/tools/art/crop_png.py" "$OUT/menu_icon.png" "$DEST/menu_icon.png" 4
# auf Spielgröße verkleinern
python3 - "$DEST" <<'PY'
import sys
from PIL import Image
for f, h in (("menu_icon.png", 256), ("logo_leiste.png", 128), ("logo_auf_dunkel.png", 600), ("logo_auf_hell.png", 600)):
    p = sys.argv[1] + "/" + f; im = Image.open(p)
    im.resize((round(im.width * h / im.height), h), Image.LANCZOS).save(p, optimize=True)
PY
echo "Logo nach $DEST kopiert"
