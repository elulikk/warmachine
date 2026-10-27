"""Procesa las imágenes de Google Flow del Mundo 3 (Abismo Ígneo) y las deja listas para Godot.

Uso: python art_source/world3/process.py  (desde la raíz del proyecto o desde esta carpeta)
Entradas: los .jpg de esta carpeta. Salidas: assets/art/world3/, assets/art/bg/, assets/art/weapons/, assets/art/icons/.
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_WORLD = os.path.join(ROOT, "assets", "art", "world3")
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


def cells(rgb, cols, rows, margin=4):
    """Corta la hoja en una grilla fija y devuelve [(fila, columna, recorte RGB)]."""
    h, w = rgb.shape[:2]
    out = []
    for r in range(rows):
        for c in range(cols):
            out.append((r, c, rgb[r * h // rows + margin:(r + 1) * h // rows - margin, c * w // cols + margin:(c + 1) * w // cols - margin]))
    return out


def components(rgb, thresh=22.0, dil=5, min_area=2000):
    """Piezas sueltas de una hoja sobre negro: [(centro y, centro x, máscara de la pieza)] (une halos y mangos finos)."""
    m = ndimage.binary_dilation(rgb.max(axis=2) > thresh, iterations=dil)
    labels, _ = ndimage.label(m)
    out = []
    for i, sl in enumerate(ndimage.find_objects(labels)):
        ys, xs = sl
        if (ys.stop - ys.start) * (xs.stop - xs.start) < min_area:
            continue
        out.append(((ys.start + ys.stop) / 2.0, (xs.start + xs.stop) / 2.0, labels == i + 1))
    return out


def piece(rgb, mask, glow=False, thresh=22.0, holes=False):
    """Recorta una pieza (máscara de `components`) con su fondo quitado (`holes`: también los huecos cerrados)."""
    only = rgb * mask[..., None]
    rgba = glow_cut(only) if glow else cut_out(only, thresh=thresh, holes=holes)
    return crop_alpha(Image.fromarray(rgba))


# ---------------------------------------------------------------- fondos
for src, dst in (("bg_plain.jpg", "hell_plain.jpg"), ("bg_cavern.jpg", "lava_cavern.jpg"), ("bg_citadel.jpg", "demon_citadel.jpg")):
    Image.open(os.path.join(HERE, src)).convert("RGB").save(os.path.join(OUT_BG, dst), quality=90)
    print("ok", dst)

# ---------------------------------------------------------------- texturas
save(Image.fromarray(seamless(load("rock.jpg"), 256)), OUT_WORLD, "volcanic_rock.png")
save(Image.fromarray(seamless(load("brick.jpg"), 256)), OUT_WORLD, "demon_brick.png")

# Borde superior: costra de roca con brasas, tira repetible de 44 px de alto (solo la franja de arriba)
crust = crop_alpha(Image.fromarray(largest(cut_out(load("ember_crust.jpg"), thresh=22.0))))
crust = crop_alpha(crust.crop((0, 0, crust.width, int(crust.height * 0.55))))
crust = crust.resize((round(crust.width * 44 / crust.height), 44), Image.LANCZOS)
save(tile_h(crust, 60), OUT_WORLD, "ember_crust.png")

# Plataforma de hueso y hierro: solo la franja de huesos y chapas (sin la roca de abajo), 30 px de alto
plat_rgb = load("platform.jpg")
_, _, plat_mask = max(components(plat_rgb, 22.0, 6), key=lambda c: c[2].sum())
plat = piece(plat_rgb, plat_mask)
top = crop_alpha(plat.crop((0, int(plat.height * 0.14), plat.width, int(plat.height * 0.6))))
save(top.resize((round(top.width * 30 / top.height), 30), Image.LANCZOS), OUT_WORLD, "bone_platform.png")

# ---------------------------------------------------------------- decorados grandes (2 x 2)
big_names = [["stalagmite", "dead_tree"], ["broken_column", "hanging_cage"]]
for r, c, cell in cells(load("big_decor.jpg"), 2, 2, 6):
    img = crop_alpha(Image.fromarray(largest(cut_out(cell, thresh=22.0))))
    save(fit(img, 400, 400), OUT_WORLD, big_names[r][c] + ".png")

# ---------------------------------------------------------------- decorados chicos (4 x 3)
small_names = [
    ["skull", "bone_pile", "chain", "brazier"],
    ["sulfur_crystal", "smoking_rock", "hell_mushroom", "stake"],
    ["tombstone", "demon_eye", "ember", "ash"],
]
for r, c, cell in cells(load("decor.jpg"), 4, 3, 4):
    name = small_names[r][c]
    if name == "ember":
        img = crop_alpha(Image.fromarray(glow_cut(cell)))
        save(fit(img, 24, 24), OUT_WORLD, name + ".png")
        continue
    img = crop_alpha(Image.fromarray(largest(cut_out(cell, thresh=22.0, holes=(name == "chain")))))
    limit = 24 if name == "ash" else 160
    save(fit(img, limit, limit), OUT_WORLD, name + ".png")

# ---------------------------------------------------------------- armas (2 columnas x 5 filas, apuntando a la derecha)
weapon_names = [
    ["scythe", "hell_crossbow"],
    ["hell_bolt", "hell_trident"],
    ["soul_staff", "soul_orb"],
    ["sulfur_scepter", "sulfur_ball"],
    ["demon_sword", "abyss_axe"],
]
PROJECTILES = {"hell_bolt": (52, 16), "soul_orb": (44, 28), "sulfur_ball": (48, 28)}
weap_rgb = load("weapons.jpg")
wh, ww = weap_rgb.shape[:2]
for cy, cx, mask in components(weap_rgb):
    name = weapon_names[min(int(cy / wh * 5), 4)][min(int(cx / ww * 2), 1)]
    if name in PROJECTILES:
        save(fit(piece(weap_rgb, mask, glow=True), *PROJECTILES[name]), OUT_WORLD, name + ".png")
        continue
    # La ballesta encierra fondo negro entre el arco y la cuerda
    img = piece(weap_rgb, mask, holes=(name == "hell_crossbow"))
    save(fit(img, 256, 256), OUT_WEAPONS, name + ".png")
    icon = img.rotate(45, expand=True, resample=Image.BICUBIC)
    save(fit(crop_alpha(icon), 64, 64), OUT_ICONS, name + ".png")
# El tridente en vuelo usa el mismo arte, chico
tri = Image.open(os.path.join(OUT_WEAPONS, "hell_trident.png"))
save(fit(tri, 64, 16), OUT_WORLD, "trident_projectile.png")
