#!/usr/bin/env python3
"""Schneidet transparente PNGs auf den sichtbaren Inhalt zu (plus Rand). Aufruf: crop_png.py IN OUT [RAND]"""
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGBA")
pad = int(sys.argv[3]) if len(sys.argv) > 3 else 12
x0, y0, x1, y1 = im.getchannel("A").getbbox()
im.crop((max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad))).save(sys.argv[2], optimize=True)
