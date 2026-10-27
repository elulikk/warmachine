"""Arte provisorio de la tanda noir del mundo 1 (armas en mano e íconos de ítems), dibujado por script.
Reemplazar por el arte de Flow cuando esté (prompts en .claude/skills/add-level/politicas.md).

Uso: python art_source/draw_noir_placeholders.py  (desde la raíz del proyecto)
Armas: assets/art/weapons/<id>.png, 256 px de ancho, apuntando a la derecha. Los puntos de agarre que imprime
van a core/art/weapon_art.gd (grip sobre el eje del cañón, hand en la empuñadura, support en la mano de apoyo).
Ítems: assets/art/items/<id>.png, 64x64.
"""
import math
from PIL import Image, ImageDraw

OUT = (20, 18, 16)
STEEL = (70, 72, 80)
STEEL_HI = (120, 124, 134)
WOOD = (112, 64, 32)
WOOD_DK = (70, 38, 18)


def new(w, h):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def save(im, path, info):
    im.save(path)
    print(path, im.size, info)


def thompson():
    im, d = new(256, 110)
    # culata de madera
    d.polygon([(2, 28), (74, 22), (74, 48), (2, 66)], fill=WOOD, outline=OUT)
    d.line((10, 40, 68, 32), fill=WOOD_DK, width=2)
    # cañón con aletas de enfriamiento
    d.rectangle((168, 28, 250, 40), fill=STEEL, outline=OUT, width=2)
    for x in range(176, 236, 7):
        d.line((x, 26, x, 42), fill=STEEL_HI, width=2)
    d.rectangle((242, 22, 248, 28), fill=STEEL, outline=OUT)
    # cajón de mecanismos
    d.rounded_rectangle((70, 20, 172, 48), 4, fill=STEEL, outline=OUT, width=2)
    d.line((80, 26, 160, 26), fill=STEEL_HI, width=2)
    # empuñadura y empuñadura delantera
    d.polygon([(92, 46), (114, 46), (106, 92), (84, 92)], fill=WOOD, outline=OUT)
    d.polygon([(180, 40), (196, 40), (194, 82), (182, 82)], fill=WOOD, outline=OUT)
    # tambor
    d.ellipse((114, 40, 166, 92), fill=STEEL, outline=OUT, width=3)
    d.ellipse((132, 58, 148, 74), fill=STEEL_HI, outline=OUT, width=2)
    # guardamonte
    d.arc((108, 40, 132, 66), 20, 160, fill=OUT, width=3)
    save(im, "assets/art/weapons/thompson.png", "grip (100, 34) hand (98, 70) support (188, 62) tip 252")


def sawed_off():
    im, d = new(256, 110)
    # dos cañones cortos
    d.rectangle((100, 24, 252, 36), fill=STEEL, outline=OUT, width=2)
    d.rectangle((100, 36, 252, 48), fill=STEEL, outline=OUT, width=2)
    d.line((110, 28, 246, 28), fill=STEEL_HI, width=2)
    # báscula
    d.rounded_rectangle((70, 20, 112, 54), 4, fill=STEEL_HI, outline=OUT, width=2)
    d.polygon([(76, 18), (86, 8), (92, 10), (86, 22)], fill=STEEL, outline=OUT)  # martillo
    # guardamano de madera
    d.rounded_rectangle((112, 46, 190, 58), 4, fill=WOOD, outline=OUT, width=2)
    # empuñadura recortada (culata serruchada)
    d.polygon([(72, 50), (30, 62), (14, 100), (46, 104), (64, 70), (88, 56)], fill=WOOD, outline=OUT)
    d.line((22, 96, 44, 98), fill=WOOD_DK, width=4)
    d.arc((68, 46, 98, 74), 0, 180, fill=OUT, width=3)
    save(im, "assets/art/weapons/sawed_off.png", "grip (70, 36) hand (52, 76) tip 252")


def flare_gun():
    im, d = new(256, 150)
    ORANGE = (226, 104, 28)
    ORANGE_DK = (150, 58, 16)
    # caño grueso
    d.rounded_rectangle((96, 18, 236, 62), 8, fill=ORANGE, outline=OUT, width=3)
    d.line((106, 28, 226, 28), fill=(250, 170, 90), width=3)
    d.rectangle((228, 12, 252, 68), fill=ORANGE_DK, outline=OUT, width=3)
    # armazón
    d.rounded_rectangle((40, 16, 104, 64), 6, fill=ORANGE, outline=OUT, width=3)
    d.polygon([(42, 18), (52, 4), (60, 6), (56, 20)], fill=STEEL, outline=OUT)  # martillo
    # empuñadura
    d.polygon([(48, 60), (102, 60), (92, 142), (40, 140)], fill=ORANGE_DK, outline=OUT)
    for y in range(76, 136, 10):
        d.line((52, y, 92, y), fill=ORANGE, width=3)
    d.arc((96, 50, 140, 100), 90, 200, fill=OUT, width=4)  # guardamonte
    save(im, "assets/art/weapons/flare_gun.png", "grip (70, 40) hand (72, 100) tip 252")


def nail_bat():
    im, d = new(256, 64)
    cy = 32
    # cuerpo que se ensancha del mango a la punta
    pts_top, pts_bot = [], []
    for x in range(8, 248, 4):
        t = max(0.0, (x - 80) / 168.0)
        r = 5 + 10 * (t ** 0.8)
        pts_top.append((x, cy - r))
        pts_bot.append((x, cy + r))
    d.polygon(pts_top + pts_bot[::-1], fill=(170, 120, 70), outline=OUT)
    d.ellipse((234, cy - 15, 254, cy + 15), fill=(170, 120, 70), outline=OUT, width=2)
    d.ellipse((0, cy - 8, 14, cy + 8), fill=(150, 104, 60), outline=OUT, width=2)  # pomo
    # cinta del mango
    for x in range(14, 74, 8):
        d.line((x, cy - 6, x + 5, cy + 6), fill=(40, 40, 46), width=4)
    # clavos
    for i, x in enumerate(range(150, 240, 13)):
        t = (x - 80) / 168.0
        r = 5 + 10 * (t ** 0.8)
        sgn = -1 if i % 2 == 0 else 1
        y0 = cy + sgn * (r - 3)
        y1 = cy + sgn * (r + 9)
        d.line((x, y0, x + 3, y1), fill=(196, 198, 206), width=3)
        d.line((x - 2, y1, x + 6, y1), fill=(196, 198, 206), width=2)
    save(im, "assets/art/weapons/nail_bat.png", "grip/hand (40, 32) tip 254")


def item_icons():
    S = 128

    def finish(im, path):
        im = im.resize((64, 64), Image.LANCZOS)
        im.save(path)
        print(path, im.size)

    # Gabardina
    im, d = new(S, S)
    TAN = (176, 140, 92)
    d.polygon([(40, 14), (88, 14), (110, 40), (104, 118), (24, 118), (18, 40)], fill=TAN, outline=OUT)
    d.polygon([(44, 14), (64, 52), (84, 14)], fill=(120, 92, 58), outline=OUT)  # cuello
    d.polygon([(64, 52), (52, 118), (76, 118)], fill=(150, 118, 76), outline=OUT)
    d.rectangle((22, 70, 106, 80), fill=(96, 70, 40), outline=OUT)  # cinturón
    d.rectangle((58, 68, 70, 82), outline=(220, 200, 120), width=3)
    finish(im, "assets/art/items/trench_coat.png")

    # Sombrero de ala
    im, d = new(S, S)
    HAT = (64, 62, 70)
    d.ellipse((8, 70, 120, 104), fill=HAT, outline=OUT, width=3)
    d.polygon([(30, 86), (36, 34), (64, 26), (92, 34), (98, 86)], fill=HAT, outline=OUT)
    d.line((50, 30, 64, 44), fill=OUT, width=3)
    d.line((64, 44, 78, 30), fill=OUT, width=3)
    d.rectangle((32, 68, 96, 80), fill=(150, 40, 36), outline=OUT)  # cinta
    finish(im, "assets/art/items/fedora.png")

    # Puño americano
    im, d = new(S, S)
    BRASS = (214, 176, 70)
    for i in range(4):
        x = 12 + i * 26
        d.ellipse((x, 30, x + 30, 66), fill=BRASS, outline=OUT, width=3)
        d.ellipse((x + 8, 39, x + 22, 57), fill=(0, 0, 0, 0), outline=OUT, width=3)
    d.rounded_rectangle((20, 62, 110, 98), 16, fill=BRASS, outline=OUT, width=3)
    d.line((32, 72, 98, 72), fill=(250, 226, 140), width=4)
    finish(im, "assets/art/items/brass_knuckles.png")

    # Molotov
    im, d = new(S, S)
    GLASS = (70, 130, 60)
    d.rounded_rectangle((36, 52, 92, 122), 14, fill=GLASS, outline=OUT, width=3)
    d.rectangle((54, 26, 74, 54), fill=GLASS, outline=OUT, width=3)
    d.rectangle((44, 74, 84, 100), fill=(220, 200, 150), outline=OUT, width=2)  # etiqueta
    d.polygon([(56, 28), (50, 14), (60, 18), (64, 4), (70, 18), (80, 12), (72, 28)], fill=(240, 120, 30), outline=OUT)
    d.polygon([(60, 26), (62, 16), (66, 22), (68, 26)], fill=(255, 220, 90))
    finish(im, "assets/art/items/molotov.png")


def nail_gun():
    im, d = new(256, 130)
    YEL = (222, 176, 40)
    YEL_DK = (150, 112, 20)
    # nariz y guía de clavos
    d.rectangle((168, 30, 250, 50), fill=STEEL, outline=OUT, width=2)
    d.rectangle((236, 24, 252, 56), fill=STEEL_HI, outline=OUT, width=2)
    d.polygon([(150, 50), (240, 50), (232, 74), (150, 74)], fill=(54, 56, 62), outline=OUT)  # tira de clavos
    for x in range(156, 232, 8):
        d.line((x, 52, x, 72), fill=STEEL_HI, width=2)
    # cuerpo
    d.rounded_rectangle((40, 18, 176, 58), 10, fill=YEL, outline=OUT, width=3)
    d.line((52, 28, 164, 28), fill=(250, 214, 110), width=3)
    d.rectangle((40, 30, 60, 46), fill=YEL_DK, outline=OUT, width=2)
    # empuñadura y gatillo
    d.polygon([(70, 56), (108, 56), (98, 122), (60, 122)], fill=(40, 40, 46), outline=OUT)
    d.polygon([(108, 58), (122, 58), (118, 76), (108, 76)], fill=STEEL, outline=OUT)
    # racor de la manguera
    d.rectangle((50, 116, 76, 128), fill=STEEL, outline=OUT, width=2)
    save(im, "assets/art/weapons/nail_gun.png", "grip (84, 40) hand (82, 96) tip 252")

    # clavo (proyectil)
    im, d = new(24, 6)
    d.rectangle((2, 2, 21, 3), fill=(190, 192, 200))
    d.rectangle((0, 0, 2, 5), fill=(150, 152, 160))
    d.polygon([(21, 1), (24, 3), (21, 4)], fill=(220, 222, 230))
    save(im, "assets/sprites/proyectiles/clavo.png", "")


def pipe_wrench():
    im, d = new(256, 90)
    RED = (170, 40, 34)
    # mango
    d.rounded_rectangle((4, 38, 200, 56), 6, fill=RED, outline=OUT, width=3)
    d.line((14, 44, 190, 44), fill=(214, 88, 70), width=3)
    d.ellipse((0, 36, 18, 58), fill=RED, outline=OUT, width=2)
    # cabeza: mandíbula fija, tuerca moleteada y mandíbula móvil
    d.rectangle((190, 26, 222, 64), fill=STEEL, outline=OUT, width=3)
    d.polygon([(214, 8), (252, 8), (252, 28), (222, 30)], fill=STEEL_HI, outline=OUT)
    d.polygon([(222, 60), (252, 58), (252, 80), (214, 82)], fill=STEEL_HI, outline=OUT)
    for x in range(226, 252, 5):
        d.line((x, 26, x, 30), fill=OUT, width=1)
        d.line((x, 58, x, 62), fill=OUT, width=1)
    d.ellipse((196, 36, 216, 56), fill=STEEL_HI, outline=OUT, width=2)
    for y in range(38, 56, 4):
        d.line((198, y, 214, y), fill=OUT, width=1)
    save(im, "assets/art/weapons/pipe_wrench.png", "grip/hand (36, 47) tip 252")


def extinguisher():
    im, d = new(256, 120)
    RED = (196, 34, 30)
    RED_DK = (120, 18, 16)
    # tubo
    d.rounded_rectangle((8, 20, 164, 84), 26, fill=RED, outline=OUT, width=3)
    d.line((26, 32, 150, 32), fill=(240, 110, 96), width=4)
    d.rectangle((60, 46, 112, 70), fill=(236, 230, 210), outline=OUT, width=2)  # etiqueta
    d.line((66, 54, 106, 54), fill=RED_DK, width=3)
    d.line((66, 62, 98, 62), fill=RED_DK, width=2)
    # válvula y palanca
    d.rectangle((160, 34, 186, 68), fill=STEEL_HI, outline=OUT, width=3)
    d.polygon([(166, 68), (206, 74), (204, 82), (164, 78)], fill=STEEL, outline=OUT)
    # tobera de CO2 (bocina negra)
    d.polygon([(186, 44), (252, 30), (252, 70), (186, 56)], fill=(36, 36, 40), outline=OUT)
    d.line((196, 48, 246, 38), fill=(80, 80, 88), width=2)
    # manija de abajo
    d.rectangle((60, 82, 84, 112), fill=(40, 40, 46), outline=OUT, width=2)
    save(im, "assets/art/weapons/extinguisher.png", "grip (70, 50) hand (72, 100) support (186, 76) tip 252")

    # bocanada de CO2 (proyectil): nube blanca suave
    S = 22
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = im.load()
    for y in range(S):
        for x in range(S):
            r = math.hypot(x - S / 2 + 0.5, y - S / 2 + 0.5) / (S / 2)
            if r < 1.0:
                a = int(200 * (1.0 - r) ** 1.3)
                px[x, y] = (236, 246, 255, a)
    save(im, "assets/sprites/proyectiles/espuma_co2.png", "")


def bazookas():
    for wid, body, accent in (("bazooka", (86, 98, 64), (60, 70, 44)), ("bazooka_guided", (60, 66, 74), (40, 44, 50))):
        im, d = new(256, 100)
        # tubo
        d.rectangle((6, 22, 250, 50), fill=body, outline=OUT, width=3)
        d.line((14, 30, 244, 30), fill=tuple(min(255, c + 50) for c in body), width=3)
        d.rectangle((0, 18, 14, 54), fill=accent, outline=OUT, width=2)    # boca trasera
        d.rectangle((238, 16, 254, 56), fill=accent, outline=OUT, width=2)  # boca delantera
        d.rectangle((120, 20, 128, 52), fill=accent)                        # abrazadera
        # empuñaduras
        d.polygon([(96, 48), (116, 48), (110, 88), (90, 88)], fill=(40, 40, 46), outline=OUT)
        d.polygon([(150, 48), (166, 48), (162, 80), (148, 80)], fill=(40, 40, 46), outline=OUT)
        # mira
        d.rectangle((70, 6, 100, 22), fill=(30, 30, 34), outline=OUT, width=2)
        if wid == "bazooka_guided":
            d.rectangle((168, 2, 214, 22), fill=(30, 30, 34), outline=OUT, width=2)  # caja de guía
            d.ellipse((204, 8, 212, 16), fill=(255, 40, 30))                         # láser
            d.line((176, 12, 200, 12), fill=(120, 200, 255), width=2)
        else:
            d.rectangle((40, 24, 60, 48), fill=(200, 170, 60), outline=OUT, width=2)  # franja de advertencia
        save(im, f"assets/art/weapons/{wid}.png", "grip (104, 36) hand (102, 80) support (156, 72) tip 254")


def dart_pistols():
    for wid, tint in (("dart_venom", (70, 170, 60)), ("dart_charm", (220, 90, 200))):
        im, d = new(256, 140)
        # caño largo y fino
        d.rectangle((110, 34, 250, 48), fill=STEEL, outline=OUT, width=2)
        d.line((118, 38, 244, 38), fill=STEEL_HI, width=2)
        # tanque de CO2 bajo el caño
        d.rounded_rectangle((120, 50, 200, 66), 7, fill=tint, outline=OUT, width=2)
        # armazón y empuñadura
        d.rounded_rectangle((44, 24, 120, 58), 8, fill=(54, 56, 62), outline=OUT, width=3)
        d.polygon([(54, 56), (96, 56), (86, 132), (44, 130)], fill=(40, 40, 46), outline=OUT)
        d.arc((90, 46, 130, 90), 90, 200, fill=OUT, width=4)
        # dardo asomando con pluma del color
        d.line((240, 41, 254, 41), fill=(220, 220, 230), width=2)
        d.polygon([(30, 30), (46, 34), (46, 48), (30, 52)], fill=tint, outline=OUT)
        save(im, f"assets/art/weapons/{wid}.png", "grip (70, 41) hand (70, 96) tip 252")


def taser():
    im, d = new(256, 150)
    YEL = (238, 206, 40)
    # cuerpo de plástico amarillo y negro
    d.rounded_rectangle((40, 22, 228, 70), 12, fill=YEL, outline=OUT, width=3)
    d.rectangle((150, 22, 228, 70), fill=(30, 30, 34), outline=OUT, width=3)   # cartucho
    d.rectangle((222, 30, 252, 62), fill=(46, 46, 52), outline=OUT, width=3)
    d.ellipse((236, 36, 246, 46), fill=(255, 240, 120))
    d.ellipse((236, 48, 246, 58), fill=(255, 240, 120))
    d.line((50, 32, 140, 32), fill=(255, 238, 140), width=3)
    # empuñadura
    d.polygon([(58, 68), (110, 68), (98, 144), (50, 142)], fill=(30, 30, 34), outline=OUT)
    for y in range(84, 136, 10):
        d.line((60, y, 98, y), fill=(60, 60, 66), width=3)
    d.arc((102, 56, 146, 104), 90, 200, fill=OUT, width=4)
    save(im, "assets/art/weapons/taser.png", "grip (80, 46) hand (80, 106) tip 252")


def throwable_icons():
    S = 128

    def finish(im, path):
        im = im.resize((64, 64), Image.LANCZOS)
        im.save(path)
        print(path, im.size)

    # Bomba racimo: granada grande con bombitas alrededor
    im, d = new(S, S)
    d.ellipse((30, 34, 98, 110), fill=(76, 86, 60), outline=OUT, width=4)
    d.rectangle((54, 18, 74, 38), fill=(150, 150, 160), outline=OUT, width=3)
    for cx, cy in ((18, 30), (110, 40), (14, 96), (112, 100), (64, 120)):
        d.ellipse((cx - 10, cy - 10, cx + 10, cy + 10), fill=(218, 178, 50), outline=OUT, width=3)
    finish(im, "assets/art/items/cluster_bomb.png")

    # C4: ladrillo con cinta, detonador y LED rojo
    im, d = new(S, S)
    d.rectangle((14, 44, 114, 100), fill=(200, 180, 130), outline=OUT, width=4)
    d.rectangle((54, 40, 74, 104), fill=(60, 60, 66), outline=OUT, width=3)
    d.rectangle((80, 22, 110, 44), fill=(40, 40, 46), outline=OUT, width=3)
    d.ellipse((90, 26, 102, 38), fill=(255, 40, 30))
    d.line((94, 44, 96, 60), fill=(220, 40, 40), width=3)
    d.line((100, 44, 104, 60), fill=(60, 120, 220), width=3)
    finish(im, "assets/art/items/c4.png")


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:  # solo las piezas pedidas: python draw_noir_placeholders.py nail_gun pipe_wrench
        for name in sys.argv[1:]:
            globals()[name]()
        sys.exit(0)
    thompson()
    sawed_off()
    flare_gun()
    nail_bat()
    item_icons()
    nail_gun()
    pipe_wrench()
    extinguisher()
    bazookas()
    dart_pistols()
    taser()
    throwable_icons()
