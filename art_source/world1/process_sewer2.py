"""Procesa las hojas nuevas de las alcantarillas (2026-10-19) y las deja en assets/art/.

Uso: python art_source/world1/process_sewer2.py
Entrada: art_source/world1/sewer2/ (hojas de Flow ya recortadas con flow_tools.py split --bg green [--holes] en _cut/).
Salida: assets/art/world1/sewer_*.png (plataformas, obstáculos y decoración), sewer_stone.png, edge_sewer.png,
sewer_water.png y assets/art/bg/city_sewer.jpg. Los PNG van al doble del tamaño de juego (art_scale 0.5).
"""
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(HERE, "sewer2")
CUT = os.path.join(SRC, "_cut")
OUT = os.path.join(ROOT, "assets", "art", "world1")
OUT_BG = os.path.join(ROOT, "assets", "art", "bg")

# nombre -> (recorte, "w" o "h", tamaño en px del PNG)
PIECES = {
    "sewer_plat_raft": ("a_1209_01", "w", 320), "sewer_plat_planks": ("a_1209_02", "w", 320),
    "sewer_plat_grate": ("a_1209_03", "w", 320), "sewer_plat_grate2": ("a_1209_04", "w", 320),
    "sewer_plat_pipe": ("a_1209_05", "w", 320), "sewer_plat_hanging": ("a_1209_06", "w", 320),
    "sewer_plat_slab": ("a_1209_07", "w", 320),
    "sewer_barrel": ("b_1217_01", "h", 160), "sewer_crates": ("b_1217_02", "h", 192),
    "sewer_pipe_fallen": ("b_1217_03", "w", 240), "sewer_bricks": ("b_1217_04", "h", 180),
    "sewer_sacks": ("b_1217_05", "h", 120), "sewer_gate": ("b_1217_06", "h", 160),
    "sewer_wall_grate": ("c_1219_01", "h", 120), "sewer_pipe_drip": ("c_1219_02", "h", 460),
    "sewer_ladder": ("c_1219_03", "h", 400), "sewer_railing": ("c_1219_04", "h", 120),
    "sewer_lamp": ("c_1219_05", "h", 132), "sewer_valve": ("c_1219_06", "h", 100),
}


def fit(img, axis, size):
    if axis == "w":
        return img.resize((size, max(1, round(img.height * size / img.width))), Image.LANCZOS)
    return img.resize((max(1, round(img.width * size / img.height)), size), Image.LANCZOS)


def main():
    for name, (cut, axis, size) in PIECES.items():
        img = Image.open(os.path.join(CUT, cut + ".png")).convert("RGBA")
        out = fit(img, axis, size)
        out.save(os.path.join(OUT, name + ".png"))
        print("ok", name, out.size)

    # Suelo repetible
    Image.open(os.path.join(SRC, "tile_cobble.jpg")).convert("RGB").resize((256, 256), Image.LANCZOS).save(
        os.path.join(OUT, "sewer_stone.png"))

    # Borde superior del piso: losa con limo de la tira (se recorta lo blanco de arriba y abajo)
    strip = Image.open(os.path.join(SRC, "edge_strip.jpg")).convert("RGB")
    top = strip.crop((0, 178, strip.width, 178 + 520))
    top.resize((512, round(520 * 512 / strip.width))).save(os.path.join(OUT, "edge_sewer.png"))

    # Agua: superficie con espuma (se repite en horizontal); debajo va un bloque liso del color del fondo de la franja
    water = Image.open(os.path.join(SRC, "water.jpg")).convert("RGB")
    surface = water.crop((0, 640, water.width, 1450))
    surface.resize((700, round(810 * 700 / water.width)), Image.LANCZOS).save(os.path.join(OUT, "sewer_water.png"))
    deep = np.array(water.crop((0, 1440, water.width, 1450))).reshape(-1, 3).mean(0) / 255.0
    print("color del fondo del agua:", [round(float(c), 3) for c in deep])

    # Fondo del túnel
    Image.open(os.path.join(SRC, "bg_tunnel.jpg")).convert("RGB").resize((1376, 768), Image.LANCZOS).save(
        os.path.join(OUT_BG, "city_sewer.jpg"), quality=90)
    print("ok fondo, suelo, borde y agua")


if __name__ == "__main__":
    main()
