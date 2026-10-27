"""Edificios 2D del Mundo 1 (dos hojas de Flow con croma verde) -> assets/art/world1/buildings/bld_01..08.png
y sus salidas para enemigos en levels/building_exits.gd.

Uso: python -I art_source/world1/process_buildings_2d.py
Entrada: art_source/world1/buildings_2d_a.jpg (altos) y buildings_2d_b.jpg (bajos), 2752x1536, 4 edificios cada una.
Después: Godot --headless --path . --import  y  python art_source/world1/bake_buildings.py

Las salidas se marcan a mano en coordenadas de la hoja (px de la imagen original) y se pasan a px del PNG final:
  doors  puertas, persianas y portones por donde salen los humanos
  rats   la abertura baja (reja de sótano, caño, agujero) por donde salen las ratas
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))
from flow_tools import cut_out, split_objects  # noqa: E402

DST = os.path.join(ROOT, "assets", "art", "world1", "buildings")
OUT_GD = os.path.join(ROOT, "levels", "building_exits.gd")
# Escala hoja -> juego: puertas a ~1.3 veces el alto de Gunther
K = 0.51
# La hoja b trae una línea de piso negra que une los edificios: se corta por encima
CROP_BOTTOM = {"b": 1338}
# Las coordenadas de abajo se tomaron sobre la hoja vista a 2000 px de ancho (x 1.376 = px originales)
VIEW = 2752.0 / 2000.0

# (hoja, salidas): rectángulos (x0, y0, x1, y1) en la vista de 2000 px, de izquierda a derecha
SHEETS = [
    ("a", [
        {"doors": [(100, 945, 165, 1070), (195, 950, 390, 1070)], "rats": [(205, 1010, 290, 1070)]},
        {"doors": [], "rats": [(690, 1005, 785, 1060)]},
        {"doors": [(1200, 945, 1290, 1068)], "rats": [(1340, 1035, 1392, 1070)]},
        {"doors": [(1715, 945, 1780, 1065), (1595, 945, 1685, 1068)], "rats": [(1820, 1038, 1875, 1068)]},
    ]),
    ("b", [
        {"doors": [(100, 765, 345, 972), (448, 820, 528, 972)], "rats": [(355, 870, 430, 972)]},
        {"doors": [(697, 805, 778, 972)], "rats": [(850, 932, 940, 972)]},
        {"doors": [(1130, 785, 1330, 972), (1365, 775, 1450, 972)], "rats": [(1100, 900, 1180, 972)]},
        {"doors": [(1820, 785, 1915, 972)], "rats": [(1645, 935, 1735, 972)]},
    ]),
]


def despill(rgba):
    a = rgba.astype(np.float32)
    m = np.maximum(a[..., 0], a[..., 2])
    g = a[..., 1] > m * 1.12 + 6
    a[..., 1] = np.where(g, m * 1.05, a[..., 1])
    return a.clip(0, 255).astype(np.uint8)


def main():
    lines = []
    index = 0
    for sheet, exits in SHEETS:
        im = Image.open(os.path.join(HERE, "buildings_2d_%s.jpg" % sheet)).convert("RGB")
        if sheet in CROP_BOTTOM:
            im = im.crop((0, 0, im.width, CROP_BOTTOM[sheet]))
        rgba = cut_out(np.asarray(im), bg="green")
        boxes = sorted(split_objects(rgba, 0.002, 10), key=lambda b: b[0])
        assert len(boxes) == len(exits), "hoja %s: %d edificios, se esperaban %d" % (sheet, len(boxes), len(exits))
        for (x0, y0, x1, y1), ex in zip(boxes, exits):
            index += 1
            piece = rgba[y0:y1, x0:x1].copy()
            piece[..., 3] = np.where(piece[..., 3] >= 128, 255, 0)
            ys, xs = np.where(piece[..., 3] > 0)
            left, top, right, bottom = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
            piece = piece[top:bottom, left:right]
            ox, oy = x0 + left, y0 + top
            out = Image.fromarray(despill(piece)).resize((round(piece.shape[1] * K), round(piece.shape[0] * K)), Image.LANCZOS)
            arr = np.asarray(out).copy()
            arr[..., 3] = np.where(arr[..., 3] >= 128, 255, 0)
            name = "bld_%02d" % index
            Image.fromarray(arr).save(os.path.join(DST, name + ".png"))

            def to_px(r):
                rx0, ry0, rx1, ry1 = [v * VIEW for v in r]
                px0 = max((rx0 - ox) * K, 0.0)
                py0 = max((ry0 - oy) * K, 0.0)
                px1 = min((rx1 - ox) * K, out.width)
                py1 = min((ry1 - oy) * K, out.height)
                return "Rect2(%.0f, %.0f, %.0f, %.0f)" % (px0, py0, px1 - px0, py1 - py0)

            doors = ", ".join(to_px(r) for r in ex["doors"])
            rats = ", ".join(to_px(r) for r in ex["rats"])
            lines.append('\t"%s": {"doors": [%s], "rats": [%s]},' % (name, doors, rats))
            print(name, out.size)

    with open(OUT_GD, "w", encoding="utf-8", newline="\n") as f:
        f.write("extends RefCounted\n")
        f.write("## Salidas de enemigos de cada edificio del Mundo 1, en px de su PNG (`assets/art/world1/buildings/`).\n")
        f.write("## Generado por art_source/world1/process_buildings_2d.py: no editar a mano, cambiar las coordenadas allá.\n")
        f.write("##   doors  puertas, persianas y portones (humanos)\n")
        f.write("##   rats   abertura baja dibujada en la base (ratas)\n")
        f.write("## Sin class_name: lo usa `ambush_director.gd` por `preload`.\n\n")
        f.write("const EXITS: Dictionary = {\n")
        f.write("\n".join(lines) + "\n}\n")
    print("ok", os.path.relpath(OUT_GD, ROOT))


if __name__ == "__main__":
    main()
