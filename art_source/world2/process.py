"""Procesa las imágenes de Google Flow del Mundo 2 (Valle Esmeralda) y las deja listas para Godot.

Uso: python art_source/world2/process.py  (desde la raíz del proyecto o desde esta carpeta)
Entradas: los .jpg de esta carpeta. Salidas: assets/art/world2/, assets/art/bg/, assets/art/weapons/, assets/art/icons/.
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_WORLD = os.path.join(ROOT, "assets", "art", "world2")
OUT_BG = os.path.join(ROOT, "assets", "art", "bg")
OUT_WEAPONS = os.path.join(ROOT, "assets", "art", "weapons")
OUT_ICONS = os.path.join(ROOT, "assets", "art", "icons")
for d in (OUT_WORLD, OUT_BG, OUT_WEAPONS, OUT_ICONS):
    os.makedirs(d, exist_ok=True)


def load(name):
    return np.asarray(Image.open(os.path.join(HERE, name)).convert("RGB")).astype(np.float32)


def cut_out(rgb, bg="black", thresh=28.0, holes=False):
    """Quita el fondo liso conectado al borde (o todo el color de fondo si `holes`). Devuelve RGBA (uint8)."""
    if bg == "black":
        is_bg = rgb.max(axis=2) < thresh
    else:  # blanco
        is_bg = rgb.min(axis=2) > 255.0 - thresh
    labels, _ = ndimage.label(is_bg)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])))
    border.discard(0)
    background = is_bg if holes else np.isin(labels, list(border))
    alpha = (~background).astype(np.float32)
    # Borde suave
    alpha = ndimage.binary_erosion(alpha > 0.5, iterations=1).astype(np.float32)
    alpha = ndimage.gaussian_filter(alpha, 0.8)
    rgba = np.dstack([rgb, alpha * 255.0])
    return np.clip(rgba, 0, 255).astype(np.uint8)


def glow_cut(rgb):
    """Para fuego/hielo: la luminancia es la opacidad (brillo sobre negro)."""
    m = rgb.max(axis=2)
    alpha = np.clip((m - 10.0) / 120.0, 0.0, 1.0)
    color = np.clip(rgb / np.maximum(alpha[..., None], 0.05), 0, 255)
    return np.dstack([color, alpha * 255.0]).astype(np.uint8)


def largest(rgba):
    """Deja solo la pieza más grande (descarta restos de la fila vecina)."""
    labels, n = ndimage.label(rgba[..., 3] > 30)
    if n <= 1:
        return rgba
    sizes = ndimage.sum(np.ones_like(labels), labels, range(1, n + 1))
    keep = ndimage.binary_dilation(labels == (int(np.argmax(sizes)) + 1), iterations=3)
    out = rgba.copy()
    out[..., 3] = (out[..., 3] * keep).astype(np.uint8)
    return out


def crop_alpha(img):
    a = np.asarray(img)[..., 3]
    ys, xs = np.where(a > 12)
    if len(xs) == 0:
        return img
    return img.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def fit(img, max_w, max_h):
    w, h = img.size
    s = min(max_w / w, max_h / h)
    return img.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)


def seamless(rgb, size):
    """Textura repetible: mezcla la imagen con su versión desplazada media vuelta."""
    img = np.asarray(Image.fromarray(rgb.astype(np.uint8)).resize((size, size), Image.LANCZOS)).astype(np.float32)
    shifted = np.roll(np.roll(img, size // 2, axis=0), size // 2, axis=1)
    t = np.linspace(-1.0, 1.0, size)
    w1 = np.clip(1.6 - 1.6 * np.abs(t), 0.0, 1.0)
    w = np.outer(w1, w1)[..., None]
    return (img * w + shifted * (1.0 - w)).astype(np.uint8)


def tile_h(img, blend=40):
    """Hace repetible en horizontal una tira RGBA mezclando los extremos."""
    a = np.asarray(img).astype(np.float32)
    w = a.shape[1]
    out = a[:, : w - blend].copy()
    ramp = np.linspace(0.0, 1.0, blend)[None, :, None]
    out[:, :blend] = a[:, :blend] * ramp + a[:, w - blend:] * (1.0 - ramp)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def save(img, folder, name):
    img.save(os.path.join(folder, name))
    print("ok", name, img.size)


def grid_cells(rgba, cols, rows):
    """Recorta por componentes conexas y las ordena en la grilla (fila, columna)."""
    a = rgba[..., 3] > 30
    a = ndimage.binary_dilation(a, iterations=6)
    labels, n = ndimage.label(a)
    objs = ndimage.find_objects(labels)
    h, w = a.shape
    items = []
    for i, sl in enumerate(objs):
        ys, xs = sl
        area = (ys.stop - ys.start) * (xs.stop - xs.start)
        if area < 400:
            continue
        cy = (ys.start + ys.stop) / 2 / h
        cx = (xs.start + xs.stop) / 2 / w
        items.append((int(cy * rows), int(cx * cols), sl, i + 1))
    return items


# ---------------------------------------------------------------- fondos
for src, dst in (("bg_meadow.jpg", "meadow.jpg"), ("bg_forest.jpg", "forest_green.jpg"), ("bg_castle.jpg", "castle_sunset.jpg")):
    Image.open(os.path.join(HERE, src)).convert("RGB").save(os.path.join(OUT_BG, dst), quality=90)
    print("ok", dst)

# ---------------------------------------------------------------- texturas
save(Image.fromarray(seamless(load("dirt.jpg"), 256)), OUT_WORLD, "dirt.png")
save(Image.fromarray(seamless(load("stone.jpg"), 256)), OUT_WORLD, "stone.png")

# Borde de césped: tira repetible de 48 px de alto
grass = crop_alpha(Image.fromarray(cut_out(load("grass_edge.jpg"))))
grass = grass.resize((round(grass.width * 48 / grass.height), 48), Image.LANCZOS)
save(tile_h(grass, 60), OUT_WORLD, "grass_edge.png")

# Plataforma: solo el tablón superior (sin patas), 26 px de alto
plat = crop_alpha(Image.fromarray(cut_out(load("platform.jpg"))))
plank = plat.crop((0, 0, plat.width, int(plat.height * 0.42)))
plank = crop_alpha(plank)
save(plank.resize((round(plank.width * 26 / plank.height), 26), Image.LANCZOS), OUT_WORLD, "platform_wood.png")

# ---------------------------------------------------------------- árboles (fondo blanco con grilla negra)
trees_rgb = load("trees.jpg")
th, tw = trees_rgb.shape[:2]
names = [["tree_oak", "tree_pine"], ["tree_birch", "tree_apple"]]
for r in range(2):
    for c in range(2):
        cell = trees_rgb[r * th // 2 + 6:(r + 1) * th // 2 - 6, c * tw // 2 + 6:(c + 1) * tw // 2 - 6]
        img = crop_alpha(Image.fromarray(cut_out(cell, bg="white", thresh=14.0, holes=True)))
        save(fit(img, 400, 400), OUT_WORLD, names[r][c] + ".png")

# ---------------------------------------------------------------- decoración (4 x 3)
decor_names = [
    ["flower_red", "flower_yellow", "flower_blue", "bush"],
    ["rock", "mushroom", "fence", "sign"],
    ["grass_tuft", "log", "leaf_green", "leaf_orange"],
]
decor = cut_out(load("decor.jpg"), holes=True)
for row, col, sl, _ in grid_cells(decor, 4, 3):
    name = decor_names[min(row, 2)][min(col, 3)]
    img = crop_alpha(Image.fromarray(decor[sl]))
    limit = 40 if name.startswith("leaf") else 160
    save(fit(img, limit, limit), OUT_WORLD, name + ".png")

# ---------------------------------------------------------------- armas (filas)
weap_rgb = load("weapons.jpg")
# Filas medidas sobre el perfil vertical de la hoja (las de abajo se tocan: se cortan en los valles)
bands = [slice(10, 160), slice(164, 240), slice(246, 308), slice(310, 404), slice(404, 490), slice(490, 648), slice(648, 762)]
weapon_names = ["bow", "arrow", "javelin", "fire_staff", "ice_staff", "fireball", "iceball"]
for name, band in zip(weapon_names, bands):
    strip = weap_rgb[band.start:band.stop]
    if name in ("fireball", "iceball"):
        img = crop_alpha(Image.fromarray(glow_cut(strip)))
        save(fit(img, 52, 20), OUT_WORLD, name + ".png")
        continue
    img = crop_alpha(Image.fromarray(largest(cut_out(strip, holes=(name == "bow")))))
    if name == "arrow":
        save(fit(img, 44, 10), OUT_WORLD, "arrow.png")
        continue
    if name == "bow":
        # En mano el arco va parado: cuerda hacia el jugador, curva hacia adelante
        img = img.rotate(-90, expand=True)
        save(fit(img, 256, 256), OUT_WEAPONS, "longbow.png")
        icon = img.rotate(-45, expand=True, resample=Image.BICUBIC)
        save(fit(crop_alpha(icon), 64, 64), OUT_ICONS, "longbow.png")
        continue
    save(fit(img, 256, 256), OUT_WEAPONS, name + ".png")
    icon = img.rotate(45, expand=True, resample=Image.BICUBIC)
    save(fit(crop_alpha(icon), 64, 64), OUT_ICONS, name + ".png")
# La jabalina en vuelo usa el mismo arte, chico
jav = Image.open(os.path.join(OUT_WEAPONS, "javelin.png"))
save(fit(jav, 64, 12), OUT_WORLD, "javelin_projectile.png")
