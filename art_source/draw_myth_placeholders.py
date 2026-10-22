"""Arte provisorio de las armas míticas (Poseidón, Zeus, Leviatán, Gungnir, Excalibur, Rey Mono) y sus proyectiles.
Las que tienen pariente en el juego se recolorean de un arma existente; el resto se dibuja.
Reemplazar por arte de Flow cuando esté (prompts en .claude/skills/add-level/politicas.md).

Uso: python art_source/draw_myth_placeholders.py  (desde la raíz del proyecto)
"""
import colorsys
import math

from PIL import Image, ImageDraw, ImageFilter

OUT = (20, 18, 16)
W = "assets/art/weapons/"
P = "assets/sprites/proyectiles/"


def recolor(src, dst, hue, sat_mult=1.0, val_mult=1.0, min_sat=0.0):
    """Lleva cada píxel al tono `hue` (0-1) conservando el brillo: un arma de otro color sin redibujarla."""
    im = Image.open(src).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            s = min(1.0, max(min_sat, s) * sat_mult)
            v = min(1.0, v * val_mult)
            r2, g2, b2 = colorsys.hsv_to_rgb(hue, s, v)
            px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    im.save(dst)
    print(dst, im.size)
    return im


def thumb(im, dst, width):
    h = max(4, int(im.height * width / im.width))
    t = im.resize((width, h), Image.LANCZOS)
    t.save(dst)
    print(dst, t.size)


def zeus_bolt():
    im = Image.new("RGBA", (256, 60), (0, 0, 0, 0))
    # Zigzag grueso: una banda que quiebra de arriba a abajo, más fina en las puntas
    xs = [4, 40, 70, 110, 140, 180, 212, 252]
    ys = [30, 14, 40, 12, 44, 16, 38, 30]
    top, bot = [], []
    for i, (x, y) in enumerate(zip(xs, ys)):
        w = 3 if i in (0, len(xs) - 1) else 9
        top.append((x, y - w))
        bot.append((x, y + w))
    pts = top + bot[::-1]
    glow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).polygon(pts, fill=(255, 240, 120, 200))
    glow = glow.filter(ImageFilter.GaussianBlur(5))
    im = Image.alpha_composite(glow, im)
    d = ImageDraw.Draw(im)
    d.polygon(pts, fill=(255, 232, 90), outline=(170, 120, 20))
    d.line(list(zip(xs, ys)), fill=(255, 255, 235), width=3)
    im.save(W + "zeus_bolt.png")
    print(W + "zeus_bolt.png", im.size)
    # proyectil: rayo corto
    small = Image.new("RGBA", (44, 14), (0, 0, 0, 0))
    ds = ImageDraw.Draw(small)
    ds.line([(0, 7), (10, 3), (18, 10), (28, 2), (36, 9), (44, 6)], fill=(255, 250, 200), width=3)
    ds.line([(0, 7), (10, 3), (18, 10), (28, 2), (36, 9), (44, 6)], fill=(255, 230, 80), width=1)
    small.save(P + "rayo_zeus.png")
    print(P + "rayo_zeus.png", small.size)


def monkey_staff():
    im = Image.new("RGBA", (256, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((2, 6, 254, 18), 5, fill=(170, 30, 26), outline=OUT, width=2)
    d.line((10, 9, 246, 9), fill=(220, 80, 60), width=2)
    for x0 in (2, 222):
        d.rectangle((x0, 3, x0 + 32, 21), fill=(230, 180, 50), outline=OUT, width=2)
        d.line((x0 + 6, 7, x0 + 26, 7), fill=(255, 230, 140), width=2)
    im.save(W + "monkey_staff.png")
    print(W + "monkey_staff.png", im.size)


def tidal_wave():
    im = Image.new("RGBA", (48, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i, (col, off) in enumerate((((40, 110, 200, 200), 0), ((70, 160, 230, 220), 6), ((200, 240, 255, 230), 12))):
        pts = [(4 + off, 64), (4 + off, 40), (14 + off, 18), (30, 6 + off), (44, 12 + off), (36, 22 + off),
               (30 + off // 2, 34), (34, 64)]
        d.polygon(pts, fill=col)
    im.save(P + "ola.png")
    print(P + "ola.png", im.size)


def light_slash():
    im = Image.new("RGBA", (40, 56), (0, 0, 0, 0))
    glow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).arc((-30, 2, 34, 54), -70, 70, fill=(255, 230, 140, 220), width=10)
    glow = glow.filter(ImageFilter.GaussianBlur(3))
    im = Image.alpha_composite(im, glow)
    ImageDraw.Draw(im).arc((-30, 2, 34, 54), -70, 70, fill=(255, 255, 235, 255), width=4)
    im.save(P + "tajo_luz.png")
    print(P + "tajo_luz.png", im.size)


if __name__ == "__main__":
    recolor(W + "hell_trident.png", W + "poseidon_trident.png", 0.52, 1.2, 1.15, 0.35)
    axe = recolor(W + "abyss_axe.png", W + "leviathan_axe.png", 0.56, 0.7, 1.25, 0.25)
    recolor(W + "frostmourne.png", W + "excalibur.png", 0.13, 0.75, 1.35, 0.25)
    spear = recolor(W + "javelin.png", W + "gungnir.png", 0.12, 1.3, 1.2, 0.45)
    thumb(axe, P + "hacha_leviatan.png", 40)
    s = spear.resize((72, 6), Image.LANCZOS)
    s.save(P + "lanza_gungnir.png")
    print(P + "lanza_gungnir.png", s.size)
    zeus_bolt()
    monkey_staff()
    tidal_wave()
    light_slash()
