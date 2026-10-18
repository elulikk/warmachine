"""Herramientas locales para el arte que baja de Google Flow (reemplazan pasos manuales del skill google-flow).

Subcomandos (python art_source/flow_tools.py <cmd> ...):

  ingest [--since MIN] [--dest DIR] [--prefix P] [--pattern GLOB]
      Copia a DIR (por defecto art_source/_inbox) las imágenes nuevas de Downloads (últimos MIN minutos,
      30 por defecto) con un nombre limpio y legible: <prefix><n>_<título>.jpg. No borra nada de Downloads.
      Imprime una línea por archivo: tamaño, fondo detectado (black/white) y destino.

  split SRC [--out DIR] [--name N] [--bg auto|black|white] [--min-area 0.002] [--gap 6] [--size H] [--line PX] [--holes] [--glow]
      Recorta el fondo liso de SRC y separa cada objeto de la hoja en un PNG con alfa (<name>_01.png ...),
      ordenados por filas y de izquierda a derecha. --size H escala cada pieza a alto H (Lanczos).
      --line PX quita las rayas separadoras de cuadrícula que Flow a veces dibuja entre celdas (4 por defecto).
      --holes quita tambien el fondo encerrado (huecos de una valla, entre ramas); sin esto solo sale el exterior.
      --glow usa la luminancia como opacidad (fuego/hielo/brillos sobre negro).

  place SRC --kind mob|item|weapon|prop --id ID [--world N] [--game-h H] [--flip] [--force] [--dry-run]
      Deja UN asset listo en su destino del juego (recorta fondo, queda con el objeto mas grande):
        mob    -> assets/art/world<N>/mob_<id>.png, alto = 3 x H (H = alto en juego en px, --game-h),
                  imprime la linea para MOBS de core/art/armor_art.gd. --flip lo voltea (si mira a la izquierda).
        item   -> assets/art/items/<id>.png, 32x32 con el objeto centrado.
        weapon -> assets/art/weapons/<id>.png, ancho 256 (--width) manteniendo proporcion.
        prop   -> assets/art/world<N>/<id>.png, alto --game-h (o --width) manteniendo proporcion.
      No pisa un archivo existente sin --force. --dry-run solo informa.

  contact FILE... [--out contact.png] [--cols 6] [--cell 160]
      Junta varios PNG/JPG en una sola hoja de contacto con etiqueta e índice sobre un damero, para
      revisarlos con UNA sola lectura de imagen.

El fondo se detecta solo mirando las esquinas (Flow a veces ignora "fondo negro" y usa blanco).
"""
import argparse
import glob
import json
import math
import os
import re
import shutil
import sys
import time

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
DOWNLOADS = os.path.join(os.path.expanduser("~"), "Downloads")
IMG_EXT = (".jpg", ".jpeg", ".png", ".webp")


LOG = os.path.join(HERE, "flow_log.jsonl")


def log(event, **data):
    """Una linea JSON por operacion (fecha, evento, datos): sirve para medir tandas reales, no para el juego."""
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(json.dumps({"t": time.strftime("%Y-%m-%d %H:%M:%S"), "event": event, **data}) + chr(10))
    except OSError:
        pass


def detect_bg(rgb):
    """'black' o 'white' según el promedio de las cuatro esquinas (parches de 8 px)."""
    h, w = rgb.shape[:2]
    k = 8
    patches = [rgb[:k, :k], rgb[:k, w - k:], rgb[h - k:, :k], rgb[h - k:, w - k:]]
    return "white" if float(np.mean([p.mean() for p in patches])) > 127 else "black"


def cut_out(rgb, bg="black", thresh=28.0, glow=False, holes=False):
    """RGBA uint8: fondo liso conectado al borde -> transparente. `glow`: luminancia = opacidad."""
    rgb = rgb.astype(np.float32)
    if glow:
        alpha = np.clip((rgb.max(axis=2) - 10.0) / 120.0, 0.0, 1.0)
        color = np.clip(rgb / np.maximum(alpha[..., None], 0.05), 0, 255)
        return np.dstack([color, alpha * 255.0]).astype(np.uint8)
    is_bg = rgb.max(axis=2) < thresh if bg == "black" else rgb.min(axis=2) > 255.0 - thresh
    labels, _ = ndimage.label(is_bg)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])))
    border.discard(0)
    background = is_bg if holes else np.isin(labels, list(border))
    alpha = ndimage.binary_erosion(~background, iterations=1).astype(np.float32)
    alpha = ndimage.gaussian_filter(alpha, 0.8)
    return np.clip(np.dstack([rgb, alpha * 255.0]), 0, 255).astype(np.uint8)


def drop_lines(rgba, width):
    """Quita rayas finas (separadores de cuadrícula que Flow dibuja entre celdas) de hasta ~2*width px."""
    if width <= 0:
        return rgba
    solid = rgba[..., 3] > 30
    core = ndimage.binary_opening(solid, iterations=width)
    keep = ndimage.binary_dilation(core, iterations=width + 1) & solid
    out = rgba.copy()
    out[..., 3] = (out[..., 3] * keep).astype(np.uint8)
    return out


def split_objects(rgba, min_area=0.002, gap=12):
    """Cajas (x0, y0, x1, y1) de cada objeto: componentes del alfa unidos si están a menos de `gap` px."""
    solid = rgba[..., 3] > 30
    merged = ndimage.binary_dilation(solid, iterations=gap)
    labels, n = ndimage.label(merged)
    total = solid.size
    boxes = []
    for i, sl in enumerate(ndimage.find_objects(labels), start=1):
        if sl is None:
            continue
        area = int(np.count_nonzero(solid[sl] & (labels[sl] == i)))
        if area < min_area * total:
            continue
        ys, xs = sl
        boxes.append((xs.start, ys.start, xs.stop, ys.stop))
    # Orden de lectura: filas (por centro vertical, tolerancia = mitad del alto medio) y luego izquierda->derecha
    if not boxes:
        return boxes
    mean_h = float(np.mean([b[3] - b[1] for b in boxes]))
    boxes.sort(key=lambda b: (round(((b[1] + b[3]) / 2) / max(mean_h * 0.75, 1.0)), b[0]))
    return boxes


def tight_crop(img):
    a = np.asarray(img)[..., 3]
    ys, xs = np.where(a > 12)
    if len(xs) == 0:
        return img
    return img.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def clean_title(name):
    base = os.path.splitext(os.path.basename(name))[0]
    base = re.sub(r"_?\d{12,14}$", "", base)  # sufijo de fecha AAAAMMDDHHMMSS
    base = re.sub(r"_?(1K|2K|4K)(_\w+)?$", "", base, flags=re.I)
    base = re.sub(r"[^A-Za-z0-9]+", "_", base).strip("_")
    return base[:48] or "img"


def cmd_ingest(a):
    dest = a.dest or os.path.join(HERE, "_inbox")
    os.makedirs(dest, exist_ok=True)
    cutoff = time.time() - a.since * 60
    files = [p for p in glob.glob(os.path.join(DOWNLOADS, a.pattern))
             if p.lower().endswith(IMG_EXT) and os.path.getmtime(p) >= cutoff]
    files.sort(key=os.path.getmtime)
    if not files:
        print("Sin imágenes nuevas en", DOWNLOADS, "en los últimos", a.since, "min")
        return 1
    log("ingest", found=len(files), since_min=a.since, dest=os.path.relpath(dest, os.path.dirname(HERE)))
    for n, src in enumerate(files, start=1):
        ext = os.path.splitext(src)[1].lower()
        dst = os.path.join(dest, "%s%02d_%s%s" % (a.prefix, n, clean_title(src), ext))
        shutil.copy2(src, dst)
        im = Image.open(dst).convert("RGB")
        print("%-60s %dx%d fondo=%s" % (os.path.relpath(dst, os.path.dirname(HERE)), im.width, im.height,
                                         detect_bg(np.asarray(im))))
    return 0


def cmd_split(a):
    src = a.src
    rgb = np.asarray(Image.open(src).convert("RGB"))
    bg = detect_bg(rgb) if a.bg == "auto" else a.bg
    rgba = drop_lines(cut_out(rgb, bg=bg, glow=a.glow, holes=a.holes), a.line)
    boxes = split_objects(rgba, a.min_area, a.gap)
    out = a.out or os.path.join(os.path.dirname(os.path.abspath(src)), "_cut")
    os.makedirs(out, exist_ok=True)
    name = a.name or os.path.splitext(os.path.basename(src))[0]
    print("fondo=%s objetos=%d" % (bg, len(boxes)))
    log("split", src=os.path.basename(src), bg=bg, objects=len(boxes), holes=a.holes, glow=a.glow, line=a.line, gap=a.gap)
    for i, (x0, y0, x1, y1) in enumerate(boxes, start=1):
        # Solo el objeto de la caja: el alfa de los vecinos que caigan dentro se descarta
        piece = rgba[y0:y1, x0:x1].copy()
        solid = piece[..., 3] > 30
        lab, n = ndimage.label(ndimage.binary_dilation(solid, iterations=a.gap))
        if n > 1:
            sizes = ndimage.sum(solid, lab, range(1, n + 1))
            piece[..., 3] = (piece[..., 3] * (lab == int(np.argmax(sizes)) + 1)).astype(np.uint8)
        img = tight_crop(Image.fromarray(piece))
        if a.size:
            s = a.size / img.height
            img = img.resize((max(1, round(img.width * s)), a.size), Image.LANCZOS)
        dst = os.path.join(out, "%s_%02d.png" % (name, i))
        img.save(dst)
        print("%02d  %4dx%-4d  %s" % (i, img.width, img.height, os.path.relpath(dst, os.getcwd())))
    return 0


def largest_piece(rgba, gap):
    """Deja solo el objeto mas grande del alfa (descarta restos y vecinos)."""
    solid = rgba[..., 3] > 30
    lab, n = ndimage.label(ndimage.binary_dilation(solid, iterations=gap))
    if n > 1:
        sizes = ndimage.sum(solid, lab, range(1, n + 1))
        rgba = rgba.copy()
        rgba[..., 3] = (rgba[..., 3] * (lab == int(np.argmax(sizes)) + 1)).astype(np.uint8)
    return rgba


def cmd_place(a):
    root = os.path.dirname(HERE)
    rgb = np.asarray(Image.open(a.src).convert("RGB"))
    bg = detect_bg(rgb) if a.bg == "auto" else a.bg
    rgba = largest_piece(drop_lines(cut_out(rgb, bg=bg, glow=a.glow, holes=a.holes), a.line), a.gap)
    img = tight_crop(Image.fromarray(rgba))
    if a.flip:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    world = os.path.join(root, "assets", "art", "world%d" % a.world)
    line = None
    if a.kind == "mob":
        if not a.game_h:
            raise SystemExit("mob necesita --game-h (alto en juego en px)")
        th = a.game_h * 3
        img = img.resize((max(1, round(img.width * th / img.height)), th), Image.LANCZOS)
        dst = os.path.join(world, "mob_%s.png" % a.id)
        line = ('    "%s": {"file": "res://assets/art/world%d/mob_%s.png", "size": Vector2(%.2f, %.2f), "foot": Vector2(%.2f, %.2f)},'
                % (a.id, a.world, a.id, img.width / 3.0, img.height / 3.0, img.width / 6.0, img.height / 3.0))
    elif a.kind == "item":
        s = min(28.0 / img.width, 28.0 / img.height)
        small = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        img.paste(small, ((32 - small.width) // 2, (32 - small.height) // 2), small)
        dst = os.path.join(root, "assets", "art", "items", "%s.png" % a.id)
    elif a.kind == "weapon":
        w = a.width or 256
        img = img.resize((w, max(1, round(img.height * w / img.width))), Image.LANCZOS)
        dst = os.path.join(root, "assets", "art", "weapons", "%s.png" % a.id)
    else:  # prop
        if a.game_h:
            img = img.resize((max(1, round(img.width * a.game_h / img.height)), a.game_h), Image.LANCZOS)
        elif a.width:
            img = img.resize((a.width, max(1, round(img.height * a.width / img.width))), Image.LANCZOS)
        dst = os.path.join(world, "%s.png" % a.id)
    rel = os.path.relpath(dst, root)
    if os.path.exists(dst) and not a.force:
        print("EXISTE %s (usar --force para pisarlo)" % rel)
        return 1
    if a.dry_run:
        print("DRY-RUN %s %dx%d fondo=%s" % (rel, img.width, img.height, bg))
    else:
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        img.save(dst)
        print("OK %s %dx%d fondo=%s" % (rel, img.width, img.height, bg))
        log("place", kind=a.kind, id=a.id, dst=rel, w=img.width, h=img.height, bg=bg)
    if line:
        print(line)
    return 0


def cmd_contact(a):
    cols = max(1, a.cols)
    cell = a.cell
    files = []
    for pat in a.files:
        files.extend(sorted(glob.glob(pat)) or [pat])
    rows = math.ceil(len(files) / cols)
    pad = 18
    sheet = Image.new("RGB", (cols * cell, rows * (cell + pad)), (40, 40, 44))
    # Damero para que se vea la transparencia
    tile = Image.new("RGB", (cell, cell), (70, 70, 74))
    d = ImageDraw.Draw(tile)
    for y in range(0, cell, 16):
        for x in range(0, cell, 16):
            if (x // 16 + y // 16) % 2:
                d.rectangle([x, y, x + 15, y + 15], fill=(95, 95, 100))
    draw = ImageDraw.Draw(sheet)
    for i, path in enumerate(files):
        cx, cy = (i % cols) * cell, (i // cols) * (cell + pad)
        sheet.paste(tile, (cx, cy + pad))
        try:
            im = Image.open(path).convert("RGBA")
        except Exception as e:  # archivo roto: se marca y se sigue
            draw.text((cx + 4, cy + 2), "%d ERR %s" % (i + 1, e), fill=(255, 90, 90))
            continue
        s = min((cell - 8) / im.width, (cell - 8) / im.height)
        im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
        sheet.paste(im, (cx + (cell - im.width) // 2, cy + pad + (cell - im.height) // 2), im)
        label = "%d %s" % (i + 1, os.path.splitext(os.path.basename(path))[0])
        draw.text((cx + 4, cy + 3), label[:26], fill=(235, 235, 235))
    out = a.out
    sheet.save(out)
    print("OK", out, "%dx%d" % sheet.size, "%d imagenes" % len(files))
    log("contact", images=len(files))
    return 0


def main():
    p = argparse.ArgumentParser(description="Herramientas para arte de Google Flow")
    sub = p.add_subparsers(dest="cmd", required=True)

    i = sub.add_parser("ingest")
    i.add_argument("--since", type=float, default=30)
    i.add_argument("--dest")
    i.add_argument("--prefix", default="")
    i.add_argument("--pattern", default="*")
    i.set_defaults(fn=cmd_ingest)

    s = sub.add_parser("split")
    s.add_argument("src")
    s.add_argument("--out")
    s.add_argument("--name")
    s.add_argument("--bg", default="auto", choices=["auto", "black", "white"])
    s.add_argument("--min-area", type=float, default=0.002)
    s.add_argument("--gap", type=int, default=6)
    s.add_argument("--size", type=int, default=0)
    s.add_argument("--line", type=int, default=4, help="grosor (px) de rayas separadoras a eliminar; 0 = no")
    s.add_argument("--holes", action="store_true", help="tambien quita el fondo encerrado dentro del objeto (huecos)")
    s.add_argument("--glow", action="store_true")
    s.set_defaults(fn=cmd_split)

    pl = sub.add_parser("place")
    pl.add_argument("src")
    pl.add_argument("--kind", required=True, choices=["mob", "item", "weapon", "prop"])
    pl.add_argument("--id", required=True)
    pl.add_argument("--world", type=int, default=4)
    pl.add_argument("--game-h", dest="game_h", type=int, default=0)
    pl.add_argument("--width", type=int, default=0)
    pl.add_argument("--flip", action="store_true")
    pl.add_argument("--bg", default="auto", choices=["auto", "black", "white"])
    pl.add_argument("--line", type=int, default=4)
    pl.add_argument("--gap", type=int, default=6)
    pl.add_argument("--holes", action="store_true")
    pl.add_argument("--glow", action="store_true")
    pl.add_argument("--force", action="store_true")
    pl.add_argument("--dry-run", dest="dry_run", action="store_true")
    pl.set_defaults(fn=cmd_place)

    c = sub.add_parser("contact")
    c.add_argument("files", nargs="+")
    c.add_argument("--out", default="contact.png")
    c.add_argument("--cols", type=int, default=6)
    c.add_argument("--cell", type=int, default=160)
    c.set_defaults(fn=cmd_contact)

    a = p.parse_args()
    sys.exit(a.fn(a))


if __name__ == "__main__":
    main()
