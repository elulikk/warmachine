"""Arma figuras de reposo con los datos generados (replica de CharacterRig) para revisar el arte."""
import re, sys, os
from PIL import Image

PROJ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "work")
src = open(os.path.join(PROJ, "core", "art", "armor_art.gd"), encoding="utf-8").read()


def grab(name):
    m = re.search(r"const %s: Dictionary = \{(.*?)\n\}\n" % name, src, re.S)
    body = "{" + m.group(1) + "}"
    body = body.replace("Vector2(", "(").replace("true", "True").replace("false", "False")
    return eval(body)


SETS = grab("SETS")
SKINS = grab("SKINS")
S = 3.0  # px de salida por px de juego (igual a la textura)


def tex(p):
    return Image.open(os.path.join(PROJ, p["file"].replace("res://", "").replace("/", os.sep))).convert("RGBA")


def put(canvas, p, x, y, flip=False):
    im = tex(p)
    canvas.alpha_composite(im, (round(x * S + canvas.width / 2), round(y * S + canvas.height - 12)))


def figure(skin, helm=None, body=None, gloves=None, boots=None, size=(260, 270)):
    canvas = Image.new("RGBA", (int(size[0] * S / 1.5), int(size[1] * S / 1.5)), (60, 62, 72, 255))
    sk = SKINS[skin]
    b = SETS[body] if body else sk
    # brazo de atras
    def arm(side, back):
        a = b["arm_" + side]
        put(canvas, a, a["pos"][0], a["pos"][1])
        g = None
        if gloves:
            g = SETS[gloves]["glove_" + side]
        else:
            g = sk["hand_" + side]
        wx, wy = a["wrist"]
        sx, sy = a["shoulder"]
        put(canvas, g, wx - g["anchor_x"], sy + 29.0 - g["hand"][1])
    arm("l", True)
    if b.get("has_legs", True):
        for side in ("l", "r"):
            leg = b["leg_" + side]
            put(canvas, leg, leg["pos"][0], leg["pos"][1])
            if boots:
                bt = SETS[boots]["boot"]
                put(canvas, bt, leg["foot_x"] + bt["pos_rel"][0], 0 + bt["pos_rel"][1])
            elif body and "foot" in sk:
                ft = sk["foot"]
                put(canvas, ft, leg["foot_x"] + ft["pos_rel"][0], 0 + ft["pos_rel"][1])
    put(canvas, b["torso"], b["torso"]["pos"][0], b["torso"]["pos"][1])
    nx, ny = b["neck"]
    h = sk["head"]
    put(canvas, h, nx + h["pos_rel"][0], ny + h["pos_rel"][1])
    if helm:
        hm = SETS[helm]["helm"]
        put(canvas, hm, nx + hm["pos_rel"][0], ny + hm["pos_rel"][1])
    arm("r", False)
    return canvas


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "sets"
    if which == "sets":
        ids = list(SETS)
        cols = 6
        figs = [figure("no_armor", s, s, s, s) for s in ids]
        w, h = figs[0].size
        sheet = Image.new("RGBA", (w * cols, h * ((len(figs) + cols - 1) // cols)), (60, 62, 72, 255))
        for i, f in enumerate(figs):
            sheet.alpha_composite(f, ((i % cols) * w, (i // cols) * h))
        sheet.convert("RGB").save(os.path.join(OUT, "preview_sets.png"))
        print(sheet.size)
    elif which == "skins":
        figs = [figure(s) for s in SKINS]
        w, h = figs[0].size
        sheet = Image.new("RGBA", (w * 4, h), (60, 62, 72, 255))
        for i, f in enumerate(figs):
            sheet.alpha_composite(f, (i * w, 0))
        sheet.convert("RGB").save(os.path.join(OUT, "preview_skins.png"))
