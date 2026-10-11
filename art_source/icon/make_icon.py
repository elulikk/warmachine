"""Genera el ícono del .exe (icon.ico en la raíz) desde la cabeza del héroe.

Uso (desde la raíz del proyecto):  python -I art_source/icon/make_icon.py
Fondo: placa redondeada oscura con borde de cobre, estilo de la interfaz. Tamaños 16 a 256.
"""
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HEAD = os.path.join(ROOT, "assets", "PSD", "out", "pieces", "head.png")
OUT_ICO = os.path.join(ROOT, "icon.ico")
OUT_PNG = os.path.join(ROOT, "art_source", "icon", "icon_256.png")
S = 256


def plate() -> Image.Image:
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle((6, 6, S - 7, S - 7), radius=44, fill=255)
    # Degradado vertical oscuro
    grad = Image.new("RGBA", (S, S))
    gd = ImageDraw.Draw(grad)
    for y in range(S):
        f = y / (S - 1)
        gd.line([(0, y), (S, y)], fill=(int(38 - 18 * f), int(34 - 16 * f), int(40 - 16 * f), 255))
    img.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((6, 6, S - 7, S - 7), radius=44, outline=(190, 118, 52, 255), width=10)
    d.rounded_rectangle((16, 16, S - 17, S - 17), radius=36, outline=(92, 58, 30, 255), width=3)
    # Remaches en las esquinas
    for cx, cy in ((34, 34), (S - 35, 34), (34, S - 35), (S - 35, S - 35)):
        d.ellipse((cx - 7, cy - 7, cx + 7, cy + 7), fill=(150, 96, 44, 255), outline=(60, 36, 18, 255), width=2)
    return img


def main() -> None:
    base = plate()
    head = Image.open(HEAD).convert("RGBA")
    scale = 196 / head.height
    head = head.resize((int(head.width * scale), int(head.height * scale)), Image.LANCZOS)
    # Sombra suave detrás de la cabeza
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    alpha = head.split()[3].point(lambda a: int(a * 0.6))
    sx = (S - head.width) // 2 + 6
    sy = (S - head.height) // 2 + 14
    shadow.paste((0, 0, 0, 255), (sx, sy), alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(6))
    base = Image.alpha_composite(base, shadow)
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    layer.paste(head, ((S - head.width) // 2, (S - head.height) // 2 + 6), head)
    base = Image.alpha_composite(base, layer)
    base.save(OUT_PNG)
    base.save(OUT_ICO, sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print("ok", OUT_ICO)


if __name__ == "__main__":
    main()
