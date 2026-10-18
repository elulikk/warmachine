"""Coloca edificios (sprites sin colisión) a lo largo del piso de los niveles del Mundo 1.

Uso: python art_source/world1/bake_buildings.py [level_1_01 level_1_02 ...]   (sin argumentos: level_1_01)
Escribe en cada levels/chapter_1/level_1_0X.tscn un nodo `Buildings` (Node2D, z_index -2: detrás del jugador,
de los obstáculos y de la decoración, delante del fondo con paralaje) con un Sprite2D por edificio:
  - la `position` es el CENTRO DE LA BASE del edificio; se entierra SINK px bajo la cara superior del piso, así
    cualquier desfase de la base queda detrás del suelo y no se ve;
  - son solo dibujo: sin colisión, se pueden mover, escalar y espejar en el editor.
La colocación es determinista (semilla = nombre del nivel). Para cambiar la escala o la densidad, tocar las
constantes de abajo y volver a correr (pisa el nodo `Buildings`).

Orden al cambiar la geometría de un nivel: build_levels.py -> bake_decor_props.py -> este script.
Arte: assets/art/world1/buildings/bld_0N.png (ver process_buildings.py).
"""
import glob
import os
import random
import re
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
LEVELS = os.path.join(ROOT, "levels", "chapter_1")
ART_DIR = os.path.join(ROOT, "assets", "art", "world1", "buildings")

SCALE = 1.0              # los recortes van al doble de alto (576 px) para verse nítidos a escala 1; antes era 2.0 con 288 px
SINK = 10.0              # px que se entierra la base bajo la cara superior del piso
GAP = (0.0, 36.0)        # separación normal entre edificios vecinos
ALLEY_CHANCE = 0.15      # probabilidad de dejar un hueco (callejón) donde se ve el fondo
ALLEY = (120.0, 260.0)
TINT = "Color(0.74, 0.8, 0.92, 1)"   # leve oscurecimiento frío: el jugador y los enemigos se leen delante
Z_INDEX = -2

NODE_RE = re.compile(r'\[node name="(Floor\d+)" type="StaticBody2D" parent="Environment"[^\n]*\]\n'
                     r'position = Vector2\(([-\d.]+), ([-\d.]+)\)\n.*?'
                     r'\[node name="CollisionShape2D" type="CollisionShape2D" parent="Environment/\1"\]\nshape = SubResource\("Rect_(\d+)x(\d+)"\)', re.S)


def floors(text):
    """Pisos del nivel: (x0, x1, y_superior) de cada StaticBody `Floor*` del entorno."""
    out = []
    for m in NODE_RE.finditer(text):
        cx, cy, w, h = float(m.group(2)), float(m.group(3)), float(m.group(4)), float(m.group(5))
        out.append((cx - w / 2.0, cx + w / 2.0, cy - h / 2.0))
    return sorted(out)


def sizes():
    out = {}
    for path in sorted(glob.glob(os.path.join(ART_DIR, "bld_0*.png"))):
        name = os.path.splitext(os.path.basename(path))[0]
        out[name] = Image.open(path).size
    if not out:
        raise SystemExit("No hay edificios en %s: correr process_buildings.py primero." % ART_DIR)
    return out


def plan(level_name, segments, art):
    rng = random.Random(level_name)
    names = sorted(art)
    placed = []
    last = None
    for x0, x1, top in segments:
        x = x0 + rng.uniform(*GAP)
        while True:
            choices = [n for n in names if n != last] or names
            name = rng.choice(choices)
            w = art[name][0] * SCALE
            if x + w > x1:
                break
            placed.append({"name": name, "x": x + w / 2.0, "y": top + SINK, "flip": False})  # sin espejar: los carteles quedarían al revés
            last = name
            x += w + (rng.uniform(*ALLEY) if rng.random() < ALLEY_CHANCE else rng.uniform(*GAP))
    return placed


def block(placed, art):
    lines = ['[node name="Buildings" type="Node2D" parent="."]', "z_index = %d" % Z_INDEX, ""]
    for i, p in enumerate(placed, start=1):
        w, h = art[p["name"]]
        sx = -SCALE if p["flip"] else SCALE
        lines += [
            '[node name="Bld%02d" type="Sprite2D" parent="Buildings"]' % i,
            "modulate = %s" % TINT,
            "position = Vector2(%.1f, %.1f)" % (p["x"], p["y"]),
            "scale = Vector2(%.2f, %.2f)" % (sx, SCALE),
            'texture = ExtResource("%s")' % p["name"],
            "centered = false",
            "offset = Vector2(%.1f, %.1f)" % (-w / 2.0, -h),
            "",
        ]
    return "\n".join(lines) + "\n"


def bake(path, level_name, art):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    segs = [s for s in floors(text) if s[1] - s[0] >= 110.0]
    if not segs:
        raise SystemExit("%s: no se encontraron pisos (Floor*)" % level_name)
    placed = plan(level_name, segs, art)
    # Textura(s) usadas como ext_resource (se reemplazan las de una corrida anterior)
    text = re.sub(r'\[ext_resource type="Texture2D" path="res://assets/art/world1/buildings/[^\n]*\n', "", text)
    used = sorted({p["name"] for p in placed})
    ext = "".join('[ext_resource type="Texture2D" path="res://assets/art/world1/buildings/%s.png" id="%s"]\n' % (n, n)
                  for n in used)
    last = list(re.finditer(r"^\[ext_resource[^\n]*\n", text, re.M))[-1]
    text = text[:last.end()] + ext + text[last.end():]
    new = block(placed, art)
    pattern = re.compile(r'\[node name="Buildings".*?(?=\[node name="(?:Props|SpawnPoint)")', re.S)
    if pattern.search(text):
        text = pattern.sub(lambda _m: new, text, count=1)
    else:
        anchor = '[node name="Props"' if '[node name="Props"' in text else '[node name="SpawnPoint"'
        text = text.replace(anchor, new + anchor, 1)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("ok", level_name, len(placed), "edificios,", len(segs), "tramo(s) de piso")


def main():
    art = sizes()
    targets = sys.argv[1:] or ["level_1_01"]
    for name in targets:
        path = os.path.join(LEVELS, name + ".tscn")
        bake(path, name, art)


if __name__ == "__main__":
    main()
