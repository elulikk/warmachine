"""Arte provisorio del mangual (mango + cadena + bola con pinchos), 256x100, apuntando a la derecha.
Reemplazar por el arte de Flow cuando esté (ver politicas.md)."""
import math
from PIL import Image, ImageDraw

W, H = 256, 100
im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
cy = 50
# Mango de madera con pomo y empuñadura de cuero
d.rounded_rectangle((8, cy - 6, 92, cy + 6), 4, fill=(96, 62, 34), outline=(40, 24, 12), width=2)
for x in range(18, 56, 7):
    d.line((x, cy - 6, x + 4, cy + 6), fill=(58, 36, 20), width=3)
d.ellipse((2, cy - 9, 18, cy + 9), fill=(130, 130, 138), outline=(40, 40, 46), width=2)
d.rectangle((88, cy - 9, 98, cy + 9), fill=(140, 140, 150), outline=(40, 40, 46), width=2)
# Cadena: eslabones alternados
x = 100
i = 0
while x < 168:
    if i % 2 == 0:
        d.ellipse((x, cy - 5, x + 14, cy + 5), outline=(150, 150, 160), width=3)
    else:
        d.rounded_rectangle((x, cy - 2, x + 14, cy + 2), 2, fill=(110, 110, 120))
    x += 11
    i += 1
# Bola con pinchos
bx, by, r = 205, cy, 30
for k in range(12):
    a = k * math.tau / 12
    tip = (bx + math.cos(a) * (r + 16), by + math.sin(a) * (r + 16))
    b1 = (bx + math.cos(a - 0.22) * r, by + math.sin(a - 0.22) * r)
    b2 = (bx + math.cos(a + 0.22) * r, by + math.sin(a + 0.22) * r)
    d.polygon([b1, tip, b2], fill=(185, 185, 195), outline=(50, 50, 58))
d.ellipse((bx - r, by - r, bx + r, by + r), fill=(88, 88, 98), outline=(30, 30, 36), width=3)
d.ellipse((bx - r + 8, by - r + 6, bx - 4, by - 6), fill=(130, 130, 142))
im = im.crop(im.getbbox())
print(im.size)
im.save("assets/art/weapons/mangual.png")
