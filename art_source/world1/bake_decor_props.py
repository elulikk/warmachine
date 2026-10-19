"""Hornea los obstáculos de la decoración del Mundo 1 en los niveles del capítulo 1.

Uso: python art_source/world1/bake_decor_props.py
Pasos: 1) Godot headless calcula la lista de obstáculos por sector (bake_decor_props.gd) y la guarda en
decor_props.json; 2) este script reemplaza el nodo `Props` de cada levels/chapter_1/level_1_0X.tscn con esos
obstáculos, como nodos `WorldProp` (entities/world/world_prop.gd) con su arte de assets/art/world1/.

Orden al cambiar la geometría de un nivel: correr build_levels.py y después este script.
Los obstáculos ya no se generan en el juego: lo que se edita en el editor es lo que queda en el .tscn.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
GODOT = r"C:\GODOT\Godot_v4.7.2-stable_win64_console.exe"
JSON_PATH = os.path.join(ROOT, "art_source", "world1", "decor_props.json")
SCRIPT = "res://art_source/world1/bake_decor_props.gd"
WORLD_PROP_EXT = '[ext_resource type="Script" path="res://entities/world/world_prop.gd" id="world_prop"]'
# Obstáculos rompibles y su vida (los sprites de daño salen de bake_prop_damage.py)
BREAKABLE_HEALTH = {"barrel": 60, "oil_barrel": 70, "crates": 90, "wet_boxes": 70, "trash_can": 45,
                    "trash_bags": 40, "mailbox": 55}
PROPS_BLOCK = re.compile(r'\[node name="Props".*?(?=\[node name="SpawnPoint")', re.S)


def build_props_block(plan):
    lines = ['[node name="Props" type="Node2D" parent="."]', ""]
    for i, p in enumerate(plan, start=1):
        lines += [
            '[node name="Deco%02d" type="StaticBody2D" parent="Props" groups=["world", "decor_prop"]]' % i,
            "position = Vector2(%.1f, %.1f)" % (p["x"], p["y"]),
            "collision_mask = 0",
            'script = ExtResource("world_prop")',
            "size = Vector2(%.1f, %.1f)" % (p["w"], p["h"]),
            'art_path = "res://assets/art/world1/%s.png"' % p["name"],
            "stretch_art = true",
            "flip_art = %s" % ("true" if p["flip"] else "false"),
        ]
        if p["name"] in BREAKABLE_HEALTH:
            lines += ["destructible = true", "max_health = %.1f" % BREAKABLE_HEALTH[p["name"]]]
        lines.append("")
    return "\n".join(lines) + "\n"


def bake_level(path, plan):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    if WORLD_PROP_EXT not in text:
        ext_lines = [m for m in re.finditer(r"^\[ext_resource[^\n]*\n", text, re.M)]
        last = ext_lines[-1]
        text = text[:last.end()] + WORLD_PROP_EXT + "\n" + text[last.end():]
    block = build_props_block(plan)
    if PROPS_BLOCK.search(text):
        text = PROPS_BLOCK.sub(lambda _m: block, text, count=1)
    else:
        text = text.replace('[node name="SpawnPoint"', block + '[node name="SpawnPoint"', 1)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def patch_destructibles(path):
    """Marca como rompibles los obstáculos ya horneados sin tocar posiciones ni tamaños (idempotente)."""
    with open(path, encoding="utf-8", newline="") as f:
        text = f.read()
    crlf = "\r\n" in text
    text = text.replace("\r\n", "\n")
    pattern = re.compile(r'(art_path = "res://assets/art/world1/(\w+)\.png"\n(?:stretch_art = \w+\n)?(?:flip_art = \w+\n)?)(?!destructible)')

    def add(m):
        name = m.group(2)
        if name not in BREAKABLE_HEALTH:
            return m.group(0)
        return m.group(1) + "destructible = true\nmax_health = %.1f\n" % BREAKABLE_HEALTH[name]

    text = pattern.sub(add, text)
    if crlf:
        text = text.replace("\n", "\r\n")
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    return text.count("destructible = true")


def main():
    if "--patch-only" in sys.argv:
        for name in sorted(os.listdir(os.path.join(ROOT, "levels", "chapter_1"))):
            if name.endswith(".tscn"):
                full = os.path.join(ROOT, "levels", "chapter_1", name)
                print(name, patch_destructibles(full), "rompibles")
        return
    subprocess.run([GODOT, "--headless", "--path", ROOT, "-s", SCRIPT], check=True)
    with open(JSON_PATH, encoding="utf-8") as f:
        data = json.load(f)
    for res_path, plan in data.items():
        path = os.path.join(ROOT, res_path.replace("res://", "").replace("/", os.sep))
        bake_level(path, plan)
        print("ok", res_path, len(plan), "obstáculos")


if __name__ == "__main__":
    main()
