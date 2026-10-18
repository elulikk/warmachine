"""Convierte las monedas de Google Flow (JPG, fondo negro) en sprites PNG 38x38 con transparencia.

Uso: python process_coins.py
Lee silver_1k.jpg, gold_1k.jpg, platinum_1k.jpg de esta carpeta y escribe
assets/art/props/coin_silver.png, coin_gold.png, coin_platinum.png.
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "art", "props"))
SIZE = 38
# Brillo por debajo de este valor se considera fondo negro; por encima, se va haciendo opaco.
BG_LOW = 18
BG_HIGH = 60

JOBS = {
    "silver_1k.jpg": "coin_silver.png",
    "gold_1k.jpg": "coin_gold.png",
    "platinum_1k.jpg": "coin_platinum.png",
}


def cut_out(src: str, dst: str) -> None:
    img = Image.open(src).convert("RGB")
    # Alpha por brillo: el fondo negro sale transparente, el metal (que es brillante) queda opaco
    gray = img.convert("L")
    alpha = gray.point(lambda v: max(0, min(255, int((v - BG_LOW) * 255 / (BG_HIGH - BG_LOW)))))
    rgba = img.copy()
    rgba.putalpha(alpha)
    # Recorte al círculo: la moneda ocupa casi todo el cuadro, así que se achica al bbox del alfa
    box = rgba.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    if box is None:
        raise SystemExit("No se encontró la moneda en " + src)
    side = max(box[2] - box[0], box[3] - box[1])
    cx, cy = (box[0] + box[2]) // 2, (box[1] + box[3]) // 2
    square = rgba.crop((cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side))
    small = square.resize((SIZE, SIZE), Image.LANCZOS)
    small.save(dst)
    print("OK", os.path.basename(dst), small.size, "bbox", box)


if __name__ == "__main__":
    for src_name, dst_name in JOBS.items():
        cut_out(os.path.join(HERE, src_name), os.path.join(OUT_DIR, dst_name))
