"""Lleva los edificios recortados de la hoja de Flow (art_source/world1/_cut/bld_0N.png) al juego.

Uso: python art_source/world1/process_buildings.py
Entrada: art_source/world1/_cut/bld_01.png ... (salida de `flow_tools.py split` sobre la hoja de edificios).
Salida: assets/art/world1/buildings/bld_01.png ... (mismo tamaño, alfa limpio: las filas de la base con alfa
parcial se recortan para que la base sea una línea recta).
Después: Godot --headless --path . --import  y  python art_source/world1/bake_buildings.py
"""
import glob
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SRC = os.path.join(ROOT, "art_source", "world1", "_cut")
DST = os.path.join(ROOT, "assets", "art", "world1", "buildings")
# Una fila de la base se considera "de edificio" si al menos esta fracción de su ancho es opaca
BASE_ROW_MIN = 0.6


def clean(img):
    a = np.array(img.convert("RGBA"))
    alpha = a[:, :, 3]
    # Alfa binario: sin bordes semitransparentes que dejen un halo oscuro contra el cielo
    a[:, :, 3] = np.where(alpha >= 128, 255, 0).astype(np.uint8)
    h, w = a.shape[:2]
    cols = np.where((a[:, :, 3] > 0).any(axis=0))[0]
    left, right = cols.min(), cols.max() + 1
    # Recorta filas de la base casi vacías (sobras de la línea de piso de la hoja)
    bottom = h
    while bottom > 1 and (a[bottom - 1, left:right, 3] > 0).mean() < BASE_ROW_MIN:
        bottom -= 1
    rows = np.where((a[:bottom, left:right, 3] > 0).any(axis=1))[0]
    top = rows.min()
    return Image.fromarray(a[top:bottom, left:right])


def main():
    os.makedirs(DST, exist_ok=True)
    files = sorted(glob.glob(os.path.join(SRC, "bld_0*.png")))
    if not files:
        raise SystemExit("No hay recortes en %s: correr flow_tools.py split primero." % SRC)
    for path in files:
        out = clean(Image.open(path))
        name = os.path.basename(path)
        out.save(os.path.join(DST, name))
        print("ok", name, "%dx%d" % out.size)


if __name__ == "__main__":
    main()
