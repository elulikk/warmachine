"""Cuadros de animación de un enemigo: recorta las hojas de Flow y deja PNG del mismo lienzo, con los pies en el
mismo punto, en assets/art/world<N>/<kind>/ (walk_N, attack_N, hit_N, death_N). Imprime la línea de MOB_FRAMES
(entities/enemies/enemy_art.gd).

Hojas esperadas (croma verde, una fila de cuadros cada una) en art_source/world<N>/<kind>/:
  walk.jpg, attack.jpg, hitdeath.jpg  (los primeros --hit cuadros de hitdeath son golpe, el resto muerte)

Uso: python art_source/process_anim.py <kind> --world 1 --ref-h 60 [--ref-w ANCHO] [--hit 2]
  --ref-h / --ref-w: alto o ancho (px de textura, 3x el juego) del primer cuadro de caminar; fija la escala de todos.
Después: Godot --headless --path . --import (opcional: Art.tex lee del disco si no está importado)."""
import argparse, glob, os, subprocess, sys
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("kind"); ap.add_argument("--world", type=int, default=1)
ap.add_argument("--ref-h", type=float, default=0.0); ap.add_argument("--ref-w", type=float, default=0.0)
ap.add_argument("--hit", type=int, default=2)
a = ap.parse_args()
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(HERE, "world%d" % a.world, a.kind)
CUT = os.path.join(SRC, "_cut")
OUT = os.path.join(ROOT, "assets", "art", "world%d" % a.world, a.kind)
if not (a.ref_h or a.ref_w):
    sys.exit("falta --ref-h o --ref-w")

import shutil
shutil.rmtree(CUT, ignore_errors=True)  # recortes viejos de otra corrida
for sheet in ("walk", "attack", "hitdeath"):
    jpg = os.path.join(SRC, sheet + ".jpg")
    if os.path.exists(jpg):
        subprocess.run([sys.executable, os.path.join(HERE, "flow_tools.py"), "split", jpg, "--out", CUT, "--name", sheet,
                        "--bg", "green", "--holes", "--gap", "2", "--min-area", "0.004"], check=True, stdout=subprocess.DEVNULL)

def cuts(name):
    return [Image.open(f).convert("RGBA") for f in sorted(glob.glob(os.path.join(CUT, name + "_*.png")))]

frames = {}
for i, im in enumerate(cuts("walk")): frames["walk_%d" % i] = im
for i, im in enumerate(cuts("attack")): frames["attack_%d" % i] = im
for i, im in enumerate(cuts("hitdeath")):
    frames[("hit_%d" % i) if i < a.hit else ("death_%d" % (i - a.hit))] = im
if "walk_0" not in frames:
    sys.exit("no hay cuadros de caminar")

ref = frames["walk_0"]
k = a.ref_w / ref.width if a.ref_w else a.ref_h / ref.height
scaled = {n: im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS) for n, im in frames.items()}

def cx(im):  # centro de masa horizontal (la cola o el arma fina casi no pesan)
    m = np.asarray(im)[:, :, 3].astype(np.float64).sum(axis=0)
    return float((m * np.arange(len(m))).sum() / max(m.sum(), 1.0))

left = max(cx(im) for im in scaled.values())
right = max(im.width - cx(im) for im in scaled.values())
W, H = int(np.ceil(left + right)) + 4, int(max(im.height for im in scaled.values())) + 4
os.makedirs(OUT, exist_ok=True)
for f in glob.glob(os.path.join(OUT, "*.png")): os.remove(f)
for n, im in scaled.items():
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.paste(im, (int(round(left - cx(im))) + 2, H - 2 - im.height), im)
    canvas.save(os.path.join(OUT, n + ".png"))
cnt = lambda p: sum(1 for n in scaled if n.startswith(p + "_"))
print('Pegar en MOB_FRAMES de enemy_art.gd:')
print('\t"%s": {"dir": "res://assets/art/world%d/%s/", "foot": Vector2(%.1f, %d), "walk": %d, "attack": %d, "hit": %d, "death": %d},'
      % (a.kind, a.world, a.kind, left + 2, H - 2, cnt("walk"), cnt("attack"), cnt("hit"), cnt("death")))
