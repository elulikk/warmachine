"""Piso de la ciudad (sector 1_01) desde art_source/world1/city_floor_src.jpg (Google Flow, 2K).
Salidas en assets/art/world1/: city_floor_strip.png (acera + bordillo + calle, repite en horizontal)
y city_floor_fill.png (asfalto liso que repite en ambos ejes, para el relleno bajo la franja)."""
import numpy as np
from PIL import Image

SRC = "art_source/world1/city_floor_src.jpg"
OUT = "assets/art/world1/"
SCALE = 0.27       # píxeles de juego por píxel de la fuente (ancho)
SCALE_Y = 0.17     # alto: más bajo que el ancho para que la acera ocupe poco y la calle se vea sobre la barra de ítems
OVERLAP = 220      # ancho del cruce de fundido para que repita sin costura (px de fuente)

im = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float32)
h, w, _ = im.shape
# Primera fila con arte (el borde superior de la acera): lo de arriba es negro liso del lienzo
rowmean = im.mean(axis=(1, 2))
top = int(np.argmax(rowmean > 25.0))
top = max(0, top - 0)
body = im[top:]
bh = body.shape[0]
# Repetición horizontal: la cola se funde con la cabeza
out_w = w - OVERLAP
strip = body[:, :out_w].copy()
t = (np.arange(OVERLAP, dtype=np.float32) / OVERLAP)[None, :, None]
tail = body[:, out_w:]
head = body[:, :OVERLAP]
strip[:, :OVERLAP] = tail * (1.0 - t) + head * t
img = Image.fromarray(strip.clip(0, 255).astype(np.uint8))
img = img.resize((round(out_w * SCALE), round(bh * SCALE_Y)), Image.LANCZOS)
img.save(OUT + "city_floor_strip.png")
print("strip", img.size, "top row", top)

# Relleno: asfalto de la parte baja de la franja, repetible en ambos ejes
tile = body[bh - 400:bh - 20, 300:1300].copy()   # 380 x 1000, debajo de la raya amarilla
th, tw, _ = tile.shape
def wrap2d(a):
    ph, pw = a.shape[:2]
    wy = np.minimum(np.arange(ph), ph - 1 - np.arange(ph)) / (ph / 2.0)
    wx = np.minimum(np.arange(pw), pw - 1 - np.arange(pw)) / (pw / 2.0)
    m = (wy[:, None] * wx[None, :])[:, :, None] ** 0.5
    rolled = np.roll(np.roll(a, ph // 2, axis=0), pw // 2, axis=1)
    return a * m + rolled * (1 - m)
tile = wrap2d(tile)
fill = Image.fromarray(tile.clip(0, 255).astype(np.uint8)).resize((400, 152), Image.LANCZOS)
fill.save(OUT + "city_floor_fill.png")
print("fill", fill.size)
