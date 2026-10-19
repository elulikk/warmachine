"""Genera los sprites de daño de los obstáculos rompibles del Mundo 1.

Uso: python art_source/world1/bake_prop_damage.py [nombre ...]
Por cada obstáculo (assets/art/world1/<nombre>.png) escribe <nombre>_dmg1.png (golpeado) y <nombre>_dmg2.png
(a punto de romperse), que `entities/world/world_prop.gd` muestra al bajar la vida del 66% y del 33%.
Es determinista (semilla = nombre): correrlo de nuevo da los mismos dibujos. Si más adelante se prefiere arte de
Flow, alcanza con pisar esos PNG con el mismo nombre.
"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DIR = os.path.join(ROOT, "assets", "art", "world1")

# Debe coincidir con los obstáculos que marca bake_decor_props.py como rompibles.
BREAKABLE = ["barrel", "oil_barrel", "crates", "wet_boxes", "trash_can", "trash_bags", "mailbox"]


def alpha_of(img):
    return img.getchannel("A")


def solid_points(mask, rng, count, margin=0.08):
    """Puntos al azar dentro de lo dibujado (alfa alto)."""
    w, h = mask.size
    px = mask.load()
    pts = []
    tries = 0
    while len(pts) < count and tries < 4000:
        tries += 1
        x = rng.randint(int(w * margin), int(w * (1 - margin)))
        y = rng.randint(int(h * margin), int(h * (1 - margin)))
        if px[x, y] > 200:
            pts.append((x, y))
    return pts


def crack_lines(start, rng, length, branch=True):
    """Grieta quebrada que se abre en ramas cortas: lista de polilíneas."""
    x, y = start
    ang = rng.uniform(0, math.tau)
    pts = [(x, y)]
    steps = max(4, int(length / 9))
    for _ in range(steps):
        ang += rng.uniform(-0.7, 0.7)
        x += math.cos(ang) * length / steps
        y += math.sin(ang) * length / steps
        pts.append((x, y))
    lines = [pts]
    if branch:
        for i in range(2, len(pts) - 1, 2):
            if rng.random() < 0.55:
                lines += crack_lines(pts[i], rng, length * 0.45, branch=False)
    return lines


def chip(mask_img, rng, edge_pts, size):
    """Quita un trozo irregular del borde (agujero en el alfa)."""
    d = ImageDraw.Draw(mask_img)
    cx, cy = edge_pts
    n = rng.randint(5, 8)
    poly = []
    for i in range(n):
        a = math.tau * i / n + rng.uniform(-0.3, 0.3)
        r = size * rng.uniform(0.45, 1.0)
        poly.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    d.polygon(poly, fill=0)


def edge_points(mask, rng, count):
    """Puntos sobre el borde del dibujo (para arrancar trozos)."""
    edge = mask.filter(ImageFilter.FIND_EDGES).point(lambda v: 255 if v > 60 else 0)
    w, h = edge.size
    px = edge.load()
    pts = [(x, y) for y in range(0, h, 3) for x in range(0, w, 3) if px[x, y] > 0]
    rng.shuffle(pts)
    # Preferencia por la mitad de arriba: ahí es donde se rompe primero
    pts.sort(key=lambda p: p[1] + rng.uniform(0, h * 0.5))
    return pts[:count]


def soot(size, rng, mask, strength):
    """Manchas de hollín y golpes (oscurecen sin salirse del dibujo)."""
    layer = Image.new("L", size, 0)
    d = ImageDraw.Draw(layer)
    for p in solid_points(mask, rng, 7):
        r = rng.randint(size[0] // 14, size[0] // 6)
        d.ellipse((p[0] - r, p[1] - r * 0.8, p[0] + r, p[1] + r * 0.8), fill=rng.randint(60, 140))
    layer = layer.filter(ImageFilter.GaussianBlur(size[0] / 28))
    return layer.point(lambda v: int(v * strength))


def make_stage(src, name, stage):
    rng = random.Random("%s-%d" % (name, stage))
    w, h = src.size
    base = src.copy()
    mask = alpha_of(src)
    heavy = stage >= 2
    scale = w / 260.0

    # 1) Desgaste: menos color y más oscuro, más hollín
    rgb = base.convert("RGB")
    grey = rgb.convert("L").convert("RGB")
    rgb = Image.blend(rgb, grey, 0.22 if not heavy else 0.4)
    dark = Image.new("RGB", rgb.size, (22, 16, 12))
    rgb = Image.blend(rgb, dark, 0.14 if not heavy else 0.27)
    s = soot(base.size, rng, mask, 0.55 if not heavy else 0.9)
    rgb = Image.composite(Image.new("RGB", rgb.size, (10, 8, 6)), rgb, s)

    # 2) Grietas y rayones (oscuras, con un hilo claro al lado para que parezcan grietas)
    crack_layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    light_layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    cd = ImageDraw.Draw(crack_layer)
    ld = ImageDraw.Draw(light_layer)
    n_cracks = 3 if not heavy else 6
    for p in solid_points(mask, rng, n_cracks):
        length = rng.uniform(0.18, 0.34) * w * (1.0 if not heavy else 1.35)
        for pts in crack_lines(p, rng, length):
            ld.line([(x + 2, y + 2) for x, y in pts], fill=(255, 235, 200, 110), width=max(1, int(2 * scale)))
            cd.line(pts, fill=(14, 9, 6, 235), width=max(2, int(3 * scale)), joint="curve")
    crack_alpha = ImageChops.multiply(crack_layer.getchannel("A"), mask)
    light_alpha = ImageChops.multiply(light_layer.getchannel("A"), mask)
    rgb = Image.composite(Image.new("RGB", rgb.size, (255, 232, 196)), rgb, light_alpha.point(lambda v: v // 3))
    rgb = Image.composite(Image.new("RGB", rgb.size, (12, 8, 5)), rgb, crack_alpha)

    # 3) Agujeros de bala: círculo oscuro con borde claro
    holes = Image.new("L", base.size, 0)
    hd = ImageDraw.Draw(holes)
    for p in solid_points(mask, rng, 2 if not heavy else 4):
        r = rng.randint(max(3, int(5 * scale)), max(4, int(8 * scale)))
        hd.ellipse((p[0] - r - 2, p[1] - r - 2, p[0] + r + 2, p[1] + r + 2), fill=120)
        hd.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=255)
    holes = ImageChops.multiply(holes, mask)
    rgb = Image.composite(Image.new("RGB", rgb.size, (6, 4, 3)), rgb, holes)

    out = rgb.convert("RGBA")

    # 4) Trozos que faltan en el borde (el alfa se recorta): pocos al principio, muchos al final
    new_mask = mask.copy()
    chips = 2 if not heavy else 6
    for p in edge_points(mask, rng, chips):
        chip(new_mask, rng, p, rng.uniform(0.045, 0.085 if not heavy else 0.13) * w)
    out.putalpha(new_mask)
    return out


def bake(name):
    path = os.path.join(DIR, name + ".png")
    if not os.path.exists(path):
        print("falta", path)
        return
    src = Image.open(path).convert("RGBA")
    for stage in (1, 2):
        make_stage(src, name, stage).save(os.path.join(DIR, "%s_dmg%d.png" % (name, stage)))
    print("ok", name)


def main():
    names = sys.argv[1:] or BREAKABLE
    for name in names:
        bake(name)


if __name__ == "__main__":
    main()
