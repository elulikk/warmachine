"""Lleva un edificio embellecido en Flow (fondo blanco o negro, un solo edificio) al juego, con la misma altura
que el recorte anterior para que la colocación de bake_buildings.py no cambie.

Uso: python -I art_source/world1/process_building_embellished.py <entrada.jpg> <bld_0N> [alto_px]
Salida: assets/art/world1/buildings/<bld_0N>.png (alfa binario, base recta, alto por defecto 576: el doble del recorte anterior, porque el juego lo dibuja a escala 1)."""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from process_buildings import clean  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DST = os.path.join(ROOT, "assets", "art", "world1", "buildings")
# Color de fondo: se quita lo que esté conectado al borde y sea casi uniforme (blanco o negro)
BG_TOL = 40


def remove_bg(img):
    a = np.asarray(img.convert("RGB")).astype(np.int16)
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg_colors = border[border.min(axis=1) > 200] if border.mean() > 128 else border[border.max(axis=1) < 60]
    if bg_colors.size == 0:
        bg_colors = border
    ref = np.median(bg_colors, axis=0)
    near = np.abs(a - ref).max(axis=2) <= BG_TOL
    labels, _ = ndimage.label(near)
    edge_labels = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
    mask = np.isin(labels, list(edge_labels))
    out = np.zeros((a.shape[0], a.shape[1], 4), dtype=np.uint8)
    out[..., :3] = a.clip(0, 255).astype(np.uint8)
    out[..., 3] = np.where(mask, 0, 255).astype(np.uint8)
    return Image.fromarray(out)


def main():
    src, name = sys.argv[1], sys.argv[2]
    height = int(sys.argv[3]) if len(sys.argv) > 3 else 576
    img = remove_bg(Image.open(src))
    cut = clean(img)
    w = round(cut.width * height / cut.height)
    cut = cut.resize((w, height), Image.LANCZOS)
    out = os.path.join(DST, name + ".png")
    cut.save(out)
    print("ok", out, cut.size)


if __name__ == "__main__":
    main()
