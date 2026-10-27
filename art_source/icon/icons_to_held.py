"""Arma en mano = ícono de inventario.

Para cada arma de core/art/weapon_art.gd que tenga ícono (assets/art/icons/<id>.png) arma una textura
"en mano" con el dibujo del ícono pero en el MISMO marco que el arte grande: el ícono se gira/espeja
hasta que coincide con la silueta del arte grande (cañón a la derecha) y se estira a su caja. Así el
agarre, la boca del cañón, las manos y el `impact` del martillo siguen valiendo, multiplicados por
`ratio` (lado de la textura nueva / lado del arte grande).

Salida: assets/art/weapons_held/<id>.png y core/art/weapon_held_art.gd (tabla id -> file, ratio).
Uso: python art_source/icon/icons_to_held.py
"""
import math
import os
import re

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ICONS = os.path.join(ROOT, "assets", "art", "icons")
OUT_DIR = os.path.join(ROOT, "assets", "art", "weapons_held")
TABLE = os.path.join(ROOT, "core", "art", "weapon_held_art.gd")
## Orientación forzada (giro, espejo) cuando la comparación de siluetas se equivoca.
OVERRIDES = {"mp5": (0, False)}
UPSCALE = 4  # píxeles de textura por píxel del ícono (al girar 45° el pixel art queda en bloques)


def res_to_path(res):
    return os.path.join(ROOT, res.replace("res://", "").replace("/", os.sep))


def weapons():
    src = open(os.path.join(ROOT, "core", "art", "weapon_art.gd"), encoding="utf-8").read()
    for m in re.finditer(r'^\t"(\w+)": \{"file": "([^"]+)"', src, re.MULTILINE):
        yield m.group(1), m.group(2)


def alpha_mask(img, size):
    a = img.getchannel("A").resize(size, Image.BILINEAR)
    return [1 if v > 96 else 0 for v in a.getdata()]


def transformed(icon, angle, flip):
    big = icon.resize((icon.width * UPSCALE, icon.height * UPSCALE), Image.NEAREST)
    if flip:
        big = big.transpose(Image.FLIP_LEFT_RIGHT)
    if angle:
        big = big.rotate(angle, resample=Image.NEAREST, expand=True)
    box = big.getbbox()
    return big.crop(box) if box else None


def best_fit(icon, hd_crop):
    probe = (48, max(4, round(48 * hd_crop.height / hd_crop.width))) if hd_crop.width >= hd_crop.height \
        else (max(4, round(48 * hd_crop.width / hd_crop.height)), 48)
    ref = alpha_mask(hd_crop, probe)
    hd_aspect = hd_crop.width / hd_crop.height
    best = None
    for angle in range(0, 360, 45):
        for flip in (False, True):
            crop = transformed(icon, angle, flip)
            if crop is None:
                continue
            cand = alpha_mask(crop, probe)
            inter = sum(1 for a, b in zip(ref, cand) if a and b)
            union = sum(1 for a, b in zip(ref, cand) if a or b) or 1
            stretch = abs(math.log((crop.width / crop.height) / hd_aspect))
            score = inter / union - 0.35 * stretch
            if best is None or score > best[0]:
                best = (score, angle, flip, crop)
    return best


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    rows = []
    for wid, res in weapons():
        icon_path = os.path.join(ICONS, wid + ".png")
        hd_path = res_to_path(res)
        if not os.path.exists(icon_path) or not os.path.exists(hd_path):
            print("SKIP   %-20s sin ícono o sin arte grande" % wid)
            continue
        icon = Image.open(icon_path).convert("RGBA")
        hd = Image.open(hd_path).convert("RGBA")
        hd_box = hd.getbbox()
        hd_crop = hd.crop(hd_box)
        score, angle, flip, crop = best_fit(icon, hd_crop)
        if wid in OVERRIDES:
            angle, flip = OVERRIDES[wid]
            crop = transformed(icon, angle, flip)
        # Lado largo del ícono transformado = lado largo de la caja del arte grande, por `ratio`
        long_hd = max(hd_crop.width, hd_crop.height)
        ratio = max(crop.width, crop.height) / long_hd
        size = (max(1, round(hd.width * ratio)), max(1, round(hd.height * ratio)))
        box = [round(v * ratio) for v in hd_box]
        fitted = crop.resize((max(1, box[2] - box[0]), max(1, box[3] - box[1])), Image.NEAREST)
        out = Image.new("RGBA", size, (0, 0, 0, 0))
        out.paste(fitted, (box[0], box[1]), fitted)
        out.save(os.path.join(OUT_DIR, wid + ".png"))
        rows.append((wid, ratio))
        print("OK     %-20s giro %3d espejo %-5s ajuste %.2f ratio %.4f" % (wid, angle, flip, score, ratio))

    lines = [
        "extends RefCounted",
        "## GENERADO por art_source/icon/icons_to_held.py. Arma en mano dibujada con su ícono de inventario.",
        "## Sin class_name: se carga por preload desde ItemIcons / WeaponManager.",
        "##",
        "## La textura está en el mismo marco que el arte grande (weapon_art.gd) a escala `ratio`: los puntos de",
        "## la pose (grip, hand, support, tip_x, impact) se multiplican por `ratio` y la escala se divide por él.",
        "",
        "const WEAPONS: Dictionary = {",
    ]
    for i, (wid, ratio) in enumerate(rows):
        sep = "," if i < len(rows) - 1 else ""
        lines.append('\t"%s": {"file": "res://assets/art/weapons_held/%s.png", "ratio": %.5f}%s' % (wid, wid, ratio, sep))
    lines.append("}")
    open(TABLE, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    print("Tabla:", TABLE, len(rows), "armas")


if __name__ == "__main__":
    main()
