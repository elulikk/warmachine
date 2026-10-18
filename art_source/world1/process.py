"""Procesa las imágenes de Google Flow del Mundo 1 (El Presente) y las deja listas para Godot.

Uso: python art_source/world1/process.py  (desde la raíz del proyecto o desde esta carpeta)
Entradas: los .jpg de esta carpeta. Salidas: assets/art/world1/, assets/art/bg/, assets/art/portraits/.
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import Delaunay

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_WORLD = os.path.join(ROOT, "assets", "art", "world4")
OUT_BG = os.path.join(ROOT, "assets", "art", "bg")
OUT_PORT = os.path.join(ROOT, "assets", "art", "portraits")
for d in (OUT_WORLD, OUT_BG, OUT_PORT):
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


def cut_dark(rgb, thresh=3.0):
    """Para figuras casi negras (trajes oscuros): máscara por umbral muy bajo, cerrada y rellena, y se queda con la pieza mayor."""
    m = ndimage.binary_closing(rgb.max(axis=2) > thresh, iterations=5)
    m = ndimage.binary_fill_holes(m)
    labels, n = ndimage.label(m)
    if n > 1:
        sizes = ndimage.sum(np.ones_like(labels), labels, range(1, n + 1))
        m = labels == (int(np.argmax(sizes)) + 1)
    alpha = ndimage.gaussian_filter(ndimage.binary_erosion(m, iterations=1).astype(np.float32), 0.8)
    return np.clip(np.dstack([rgb, alpha * 255.0]), 0, 255).astype(np.uint8)


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


def drop_halo(img, top=0.39, low=0.47):
    """Faroles: el halo marrón oscuro detrás de la lámpara es opaco en la hoja; lo vuelve transparente fuera de la silueta del farol.
    La silueta (`top`, fracción de la altura) sale de los píxeles no cálidos y claros de la parte alta. Debajo del farol
    (hasta `low`) solo se quitan los píxeles cálidos, así el poste azulado se conserva."""
    a = np.asarray(img).astype(np.float32)
    h, w = a.shape[:2]
    rgb = a[..., :3]
    mx = rgb.max(axis=2)
    warm = (rgb[..., 0] - rgb[..., 2] > 6) & (mx < 110)
    up = np.zeros((h, w), bool)
    up[: int(h * top)] = True
    cand = (~warm) & (mx >= 45) & (a[..., 3] > 200) & up
    ys, xs = np.where(cand)
    tri = Delaunay(np.stack([xs, ys], 1)[:: max(1, len(xs) // 4000)].astype(float))
    yy, xx = np.mgrid[0:h, 0:w]
    inside = tri.find_simplex(np.stack([xx.ravel(), yy.ravel()], 1)).reshape(h, w) >= 0
    inside = ndimage.binary_dilation(inside, iterations=2)
    low_band = np.zeros((h, w), bool)
    low_band[: int(h * low)] = True
    kill_mask = ((warm | ((mx < 60) & up)) & ~inside & low_band)
    kill = ndimage.gaussian_filter(kill_mask.astype(np.float32), 0.7)
    a[..., 3] *= 1.0 - np.clip(kill * 1.5, 0.0, 1.0)
    return Image.fromarray(a.astype(np.uint8))


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
for src, dst in (("bg_city_street", "city_street"), ("bg_alley", "city_alley"), ("bg_sewer", "city_sewer"), ("bg_houses", "city_houses"),
                 ("bg_dock", "city_dock"), ("bg_hotel", "city_hotel"), ("bg_club", "city_club"), ("bg_rooftop", "city_rooftop"),
                 ("bg_corridor", "box_corridor"), ("bg_jewelry_flashback", "jewelry_flashback")):
    Image.open(os.path.join(HERE, src + ".jpg")).convert("RGB").save(os.path.join(OUT_BG, dst + ".jpg"), quality=90)
    print("ok", dst)

# ---------------------------------------------------------------- texturas repetibles
for src, dst in (("tile_asphalt", "asphalt"), ("tile_brick", "city_brick"), ("tile_sewer", "sewer_stone"), ("tile_dock", "dock_planks"),
                 ("tile_marble", "marble"), ("tile_club", "club_floor"), ("tile_roof", "roof_gravel")):
    save(Image.fromarray(seamless(load(src + ".jpg"), 256)), OUT_WORLD, dst + ".png")

# ---------------------------------------------------------------- piezas aisladas
for src, dst, w, h in (("plat_fire_escape", "fire_escape", 360, 160), ("plat_awning", "awning", 300, 200), ("plat_container", "container", 400, 160),
                       ("helicopter", "helicopter", 640, 300), ("time_agent", "time_agent", 300, 400),
                       ("gunther_full", "gunther_full", 300, 400), ("gunther_young", "gunther_young", 300, 400)):
    rgba = cut_dark(load(src + ".jpg")) if src == "time_agent" else cut_out(load(src + ".jpg"), thresh=8.0)
    if src not in ("helicopter", "time_agent"):  # el helicóptero son varias piezas (aspas, cola, haz de luz)
        rgba = largest(rgba)
    img = crop_alpha(Image.fromarray(rgba))
    save(fit(img, w, h), OUT_WORLD, dst + ".png")

# ---------------------------------------------------------------- cuadrículas de objetos
def objects(rgb, cols, rows, thresh=22.0, pad=6):
    """Recorta cada objeto por su componente conexa, no por celda fija (la grilla cortaba a los que cruzan el límite).
    Asigna fila por altura y columna por orden horizontal. Devuelve [(fila, columna, recorte RGB)]."""
    h, w = rgb.shape[:2]
    labels, _ = ndimage.label(ndimage.binary_dilation(rgb.max(axis=2) > thresh, iterations=pad))
    per_row = [[] for _ in range(rows)]
    for sl in ndimage.find_objects(labels):
        ys, xs = sl
        if (ys.stop - ys.start) * (xs.stop - xs.start) < 2000:
            continue
        per_row[min(rows - 1, int((ys.start + ys.stop) / 2 * rows / h))].append(((xs.start + xs.stop) / 2, sl))
    out = []
    for r, items in enumerate(per_row):
        if len(items) != cols:
            raise ValueError("fila %d: %d objetos, se esperaban %d" % (r, len(items), cols))
        for c, (_, sl) in enumerate(sorted(items, key=lambda t: t[0])):
            out.append((r, c, rgb[sl]))
    return out


def grid(src, cols, rows, names, limit, margin=6, thresh=8.0, by_object=False):
    rgb = load(src + ".jpg")
    for r, c, cell in (objects(rgb, cols, rows) if by_object else cells(rgb, cols, rows, margin)):
        name = names[r][c]
        if name in ("e_hitman_elite", "e_hitman_smg", "e_bouncer"):  # trajes casi negros
            img = crop_alpha(Image.fromarray(cut_dark(cell)))
        elif name in ("fire_ladder", "iron_ladder"):  # piezas oscuras y finas: umbral bajo y sin descartar fragmentos
            img = crop_alpha(Image.fromarray(cut_out(cell, thresh=8.0)))
        else:
            img = crop_alpha(Image.fromarray(largest(cut_out(cell, thresh=thresh))))
        img = fit(img, *limit)
        if name in ("street_lamp", "dock_lamp"):  # el halo oscuro del farol no debe verse como un círculo negro
            img = drop_halo(img)
        save(img, OUT_WORLD, name + ".png")


grid("decor_street", 5, 2, [["street_lamp", "hydrant", "mailbox", "dumpster", "traffic_light"],
                            ["bus_stop", "phone_booth", "bench", "bar_sign", "trash_can"]], (220, 260), by_object=True)
grid("decor_alley_sewer", 5, 2, [["fire_ladder", "trash_bags", "wet_boxes", "steam_grate", "rust_pipe"],
                                 ["valve", "sewer_grate", "puddle", "barrel", "iron_ladder"]], (220, 260), by_object=True)
grid("decor_houses_dock", 5, 2, [["white_fence", "flower_pot", "bicycle", "house_mailbox", "bollard"],
                                 ["buoy", "crates", "oil_barrel", "rope_coil", "dock_lamp"]], (220, 260), by_object=True)
grid("decor_hotel_club", 5, 2, [["armchair", "big_plant", "luggage_cart", "reception_desk", "chandelier"],
                                ["speaker", "dj_console", "disco_ball", "bar_counter", "stage_light"]], (220, 260), by_object=True)
grid("decor_rooftop", 4, 2, [["water_tank", "ac_unit", "antenna", "vent_chimney"],
                             ["roof_sign", "safety_rail", "heli_spot", "vent_duct"]], (240, 280), by_object=True)
grid("cars", 2, 2, [["car_sedan", "car_taxi"], ["car_pickup", "car_police"]], (420, 200))
grid("the_box", 2, 1, [["box_closed", "box_open"]], (300, 300), by_object=True)
grid("enemies_street", 2, 2, [["e_rat", "e_thief"], ["e_brute", "e_gunman"]], (300, 400))
grid("enemies_syndicate", 3, 1, [["e_bouncer", "e_hitman_elite", "e_hitman_smg"]], (300, 420), by_object=True)

# ---------------------------------------------------------------- retratos (3 por hoja)
for src, names in (("portraits_1", ["gunther", "partner", "agent"]), ("portraits_2", ["syndicate_boss", "traveler", "stevedore"])):
    for r, c, cell in cells(load(src + ".jpg"), 3, 1, 4):
        img = Image.fromarray(cell.astype(np.uint8))
        img = img.resize((192, round(192 * img.height / img.width)), Image.LANCZOS)
        save(img, OUT_PORT, names[c] + ".png")

# ---------------------------------------------------------------- tiras de plataforma (delgadas, 9-patch)
cont = Image.open(os.path.join(OUT_WORLD, "container.png")).convert("RGBA")
rim = cont.crop((24, 0, cont.width - 24, 22))
save(rim, OUT_WORLD, "plat_metal.png")
dock = Image.open(os.path.join(OUT_WORLD, "dock_planks.png")).convert("RGB")
band = dock.crop((0, 40, 256, 62))
save(band, OUT_WORLD, "plat_wood.png")

# ---------------------------------------------------------------- enemigos (mirando a la derecha, 3x el tamaño en juego)
# nombre del mob -> (hoja, alto en juego en px). `MOBS` de core/art/armor_art.gd usa size = textura / 3.
MOB_SRC = {"rat": ("e_rat", 20), "thief": ("e_thief", 46), "thug": ("e_brute", 54), "gunman": ("e_gunman", 52),
           "bouncer": ("e_bouncer", 62), "hitman_elite": ("e_hitman_elite", 56), "hitman_smg": ("e_hitman_smg", 54),
           "time_agent": ("time_agent", 54)}
for mob, (src, game_h) in MOB_SRC.items():
    img = Image.open(os.path.join(OUT_WORLD, src + ".png")).convert("RGBA")
    img = img.transpose(Image.FLIP_LEFT_RIGHT)
    th = game_h * 3
    img = img.resize((max(1, round(img.width * th / img.height)), th), Image.LANCZOS)
    save(img, OUT_WORLD, "mob_" + mob + ".png")
    print('    "%s": {"file": "res://assets/art/world1/mob_%s.png", "size": Vector2(%.2f, %.2f), "foot": Vector2(%.2f, %.2f)},'
          % (mob, mob, img.width / 3.0, img.height / 3.0, img.width / 6.0, img.height / 3.0))

# ---------------------------------------------------------------- bordes superiores del suelo (tiras repetibles de 28 px)
# Un labio irregular (no una línea recta) con brillo arriba y degradé hacia el suelo. Una por tipo de suelo.
EDGE_STYLES = {
    "asphalt": ((74, 78, 98), (165, 185, 225)),    # cordón de cemento mojado
    "sewer": ((44, 70, 62), (110, 170, 120)),      # piedra con musgo
    "dock": ((96, 68, 48), (170, 135, 100)),       # tablón gastado
    "marble": ((58, 54, 82), (240, 200, 110)),     # mármol con filo dorado
    "club": ((26, 22, 44), (255, 70, 180)),        # neón rosa que vira a cian
    "roof": ((74, 76, 88), (150, 160, 185)),       # membrana y grava
}


def make_edge(base, hi, club=False, width=256, height=28, seed=0):
    rng = np.random.default_rng(seed)
    xs = np.arange(width)
    # Silueta del labio: ruido periódico (se repite sin costura)
    lip = np.zeros(width)
    for freq in (3, 5, 9, 17):
        lip += rng.uniform(1.0, 2.2) / (freq ** 0.35) * np.sin(2 * np.pi * freq * xs / width + rng.uniform(0, 6.28))
    top = 7.0 + lip
    img = np.zeros((height, width, 4), dtype=np.float32)
    grain = rng.normal(0, 1, (height, width))
    for x in range(width):
        t = top[x]
        for y in range(height):
            d = y - t
            if d < 0:
                continue
            if d < 2.5:  # filo brillante
                col = np.array(hi, dtype=np.float32)
                if club:
                    k = 0.5 + 0.5 * np.sin(2 * np.pi * 2 * x / width)
                    col = (1 - k) * np.array(hi, np.float32) + k * np.array((60, 220, 255), np.float32)
                a = 1.0
            elif d < 4.5:  # sombra bajo el filo
                col = np.array(base, dtype=np.float32) * 0.55
                a = 1.0
            else:
                shade = 1.0 - min(1.0, (d - 4.5) / 22.0) * 0.45
                col = np.array(base, dtype=np.float32) * shade + grain[y, x] * 6.0
                a = 1.0 - max(0.0, (d - 11.0) / 12.0)  # se funde con el suelo
            img[y, x, :3] = np.clip(col, 0, 255)
            img[y, x, 3] = np.clip(a, 0, 1) * 255.0
    # Antialias del borde superior
    img[..., 3] = ndimage.gaussian_filter(img[..., 3], (0.6, 0.0))
    return Image.fromarray(img.astype(np.uint8), "RGBA")


for i, (name, (base, hi)) in enumerate(EDGE_STYLES.items()):
    save(make_edge(base, hi, club=(name == "club"), seed=11 + i), OUT_WORLD, "edge_" + name + ".png")
