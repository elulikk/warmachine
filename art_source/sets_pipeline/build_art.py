"""Genera las piezas del rig, los iconos y los mobs en el proyecto y core/art/armor_art.gd."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import json
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.abspath(os.path.join(HERE, "..", ".."))
W = os.path.join(HERE, "work")
RIG_DIR = os.path.join(PROJ, "assets", "art", "rig")
ITEMS_DIR = os.path.join(PROJ, "assets", "art", "items")
MOBS_DIR = os.path.join(PROJ, "assets", "art", "mobs")
for d in (RIG_DIR, ITEMS_DIR, MOBS_DIR):
    os.makedirs(d, exist_ok=True)

G = 0.061          # px de juego por px de hoja
TEXS = 3.0         # px de textura por px de juego (CharacterRig.TEX_SCALE = 1/3)
ANKLE = 16.0       # altura del borde inferior del pantalon sobre el suelo (armaduras)
SETS = []  # los sets de armadura se eliminaron del juego; volver a listarlos aquí para regenerarlos
SKINS = ["no_armor", "zombie", "skeleton", "ghost"]
meta = json.load(open(os.path.join(W, "meta.json")))


def load_piece(sid, name):
    im = Image.open(os.path.join(W, "pieces", f"{sid}__{name}.png")).convert("RGBA")
    box = meta[sid]["pieces"][name]["box"]
    return im, box


def trim(im):
    a = np.asarray(im)[..., 3]
    ys, xs = np.nonzero(a > 6)
    if len(ys) == 0:
        return None
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    return im.crop((int(x0), int(y0), int(x1), int(y1))), int(x0), int(y0)


def export(im, name, game_scale=G):
    """Guarda `im` (px de hoja) reducida a TEXS px por px de juego. Devuelve (ancho, alto) en px de juego."""
    w = max(1, round(im.width * game_scale * TEXS))
    h = max(1, round(im.height * game_scale * TEXS))
    out = im.resize((w, h), Image.LANCZOS)
    out.save(os.path.join(RIG_DIR, name + ".png"), optimize=True)
    return (w / TEXS, h / TEXS)


def fmt(v):
    return "%.2f" % v


def boot_height(sid):
    im, _ = load_piece(sid, "boot_r")
    t = trim(im)
    return t[0].height * G


def clean_body(A):
    """Quita hebras finas (pelo, cables) que quedaron pegadas arriba del cuerpo."""
    from scipy import ndimage as ndi
    opened = ndi.binary_opening(A, structure=np.ones((3, 3), bool), iterations=4)
    lab, n = ndi.label(opened)
    if n == 0:
        return A
    sizes = ndi.sum(opened, lab, range(1, n + 1))
    core = lab == (int(np.argmax(sizes)) + 1)
    recon = core.copy()
    for _ in range(10):
        recon = ndi.binary_dilation(recon, iterations=2) & A
    thin = A & ~recon
    rows = np.nonzero(A.sum(axis=1) >= 0.45 * A.shape[1])[0]
    y_s = int(rows.min()) if len(rows) else 0
    ys = np.arange(A.shape[0])[:, None]
    drop = thin & (ys < y_s + 0.02 * A.shape[0])
    return A & ~drop


def arm_component(region, neck_l, body_h):
    """Parte de `region` que forma el brazo: arranca en el hombro y corta en el primer hueco (manga corta)."""
    from scipy import ndimage as ndi
    counts = region.sum(axis=1)
    rows = np.nonzero(counts > 0)[0]
    if len(rows) == 0:
        return region
    y0 = int(rows.min())
    limit = max(10.0, 0.035 * region.shape[1])
    cut_y = region.shape[0]
    run = 0
    for y in range(y0 + int(0.06 * body_h), region.shape[0]):
        if counts[y] <= limit:
            run += 1
            if run >= 4:
                cut_y = y - 3
                break
        else:
            run = 0
    r2 = region.copy()
    r2[cut_y:] = False
    lab, n = ndi.label(r2, structure=np.ones((3, 3), bool))
    if n == 0:
        return r2
    sizes = ndi.sum(r2, lab, range(1, n + 1))
    objs = ndi.find_objects(lab)
    keep = np.zeros_like(r2)
    for i in range(n):
        if objs[i][0].start <= neck_l + 0.30 * body_h and sizes[i] >= 0.05 * sizes.max():
            keep |= lab == (i + 1)
    return keep if keep.any() else r2


def build_body(sid, is_skin, glove_name):
    body, bbox = load_piece(sid, "body")
    arr = np.asarray(body)
    A = arr[..., 3] > 6
    H, Wd = A.shape
    A = clean_body(A)
    cx_sheet = meta[sid]["cx"]
    x0s, y0s = bbox[0], bbox[1]
    cxl = cx_sheet - x0s
    has_legs = sid != "ghost"
    lo = max(0, int(cxl - 0.22 * Wd))
    hi = int(cxl + 0.22 * Wd)
    rows = np.nonzero(A[:, lo:hi].any(axis=1))[0]
    ankle_l = int(rows.max())
    nlo = max(0, int(cxl - 0.10 * Wd))
    nhi = int(cxl + 0.10 * Wd)
    neck_rows = np.nonzero(A[:, nlo:nhi].any(axis=1))[0]
    neck_l = int(neck_rows.min())
    body_h = ankle_l - neck_l
    k = 0.255 * Wd
    ov = 0.045 * Wd
    glove_y0 = meta[sid]["pieces"][glove_name + "_l"]["box"][1]
    y_arm_end = (glove_y0 - 30) - y0s
    y_arm_end = float(np.clip(y_arm_end, neck_l + 0.45 * body_h, neck_l + 0.80 * body_h))
    y_hip = neck_l + 0.50 * body_h
    ys, xs = np.mgrid[0:H, 0:Wd]
    left_strict = (xs < cxl - k) & (ys < y_arm_end)
    right_strict = (xs > cxl + k) & (ys < y_arm_end)
    arm_l_m = arm_component(A & (xs < cxl - k + ov) & (ys < y_arm_end), neck_l, body_h)
    arm_r_m = arm_component(A & (xs > cxl + k - ov) & (ys < y_arm_end), neck_l, body_h)
    # el brazo estricto es solo lo que quedo en el componente del hombro (los muslos anchos no cuentan)
    left_strict = left_strict & arm_l_m
    right_strict = right_strict & arm_r_m
    torso_m = A & ~(left_strict | right_strict)
    if has_legs:
        torso_m &= ys < (y_hip + 0.035 * body_h)
        legs_m = A & ~(left_strict | right_strict) & (ys >= y_hip)
        leg_l_m = legs_m & (xs < cxl + 2)
        leg_r_m = legs_m & (xs >= cxl - 2)
    base_y = 0.0 if is_skin else -(boot_height(sid) - 2.0)

    def rigx(xl):
        return (xl - cxl) * G

    def rigy(yl):
        return base_y - (ankle_l - yl) * G

    out = {"neck": (0.0, rigy(neck_l)), "ankle": base_y, "has_legs": has_legs, "sid": sid}

    def cut(mask, name):
        ys_, xs_ = np.nonzero(mask)
        if len(ys_) == 0:
            return None
        bx0, bx1, by0, by1 = int(xs_.min()), int(xs_.max()) + 1, int(ys_.min()), int(ys_.max()) + 1
        crop = body.crop((bx0, by0, bx1, by1))
        a = np.asarray(crop).copy()
        a[..., 3] = np.where(mask[by0:by1, bx0:bx1], a[..., 3], 0)
        crop = Image.fromarray(a)
        size = export(crop, f"{sid}_{name}")
        return {"file": f"res://assets/art/rig/{sid}_{name}.png", "size": size,
                "pos": (rigx(bx0), rigy(by0)), "_box": (bx0, by0, bx1, by1)}

    out["torso"] = cut(torso_m, "torso")
    out["arm_l"] = cut(arm_l_m, "arm_l")
    out["arm_r"] = cut(arm_r_m, "arm_r")
    for key, m in (("arm_l", arm_l_m), ("arm_r", arm_r_m)):
        b = out[key]["_box"]
        sub = m[b[1]:b[3], b[0]:b[2]]
        h_ = sub.shape[0]
        sx = (cxl - (k - 0.02 * Wd)) if key == "arm_l" else (cxl + (k - 0.02 * Wd))
        sy = b[1] + 0.07 * body_h
        out[key]["shoulder"] = (rigx(sx), rigy(sy))
        tail = sub[max(0, h_ - max(4, int(0.07 * h_))):]
        txs = np.nonzero(tail)[1]
        wx = b[0] + (txs.mean() if len(txs) else sub.shape[1] / 2)
        out[key]["wrist"] = (rigx(wx), rigy(b[3]))
    if has_legs:
        out["leg_l"] = cut(leg_l_m, "leg_l")
        out["leg_r"] = cut(leg_r_m, "leg_r")
        hip_y = rigy(y_hip + 0.03 * body_h)
        out["leg_l"]["pivot"] = (-0.6, hip_y)
        out["leg_r"]["pivot"] = (0.6, hip_y)
        for key, mm in (("leg_l", leg_l_m), ("leg_r", leg_r_m)):
            b = out[key]["_box"]
            sub = mm[b[1]:b[3], b[0]:b[2]]
            tail = sub[max(0, sub.shape[0] - max(4, int(0.12 * sub.shape[0]))):]
            txs = np.nonzero(tail)[1]
            fx = b[0] + (txs.mean() if len(txs) else sub.shape[1] / 2)
            out[key]["foot_x"] = rigx(fx)
    out["_neck_l"] = (cxl, neck_l, x0s, y0s)
    return out


def build_hand(sid, name, kind):
    """Guante o mano: ancla horizontal (centro del borde superior) y centro de la mano, en px de juego."""
    im, box = load_piece(sid, name)
    im2, _, _ = trim(im)
    arr = np.asarray(im2)[..., 3] > 6
    h = arr.shape[0]
    top = arr[: max(3, int(0.18 * h))]
    txs = np.nonzero(top)[1]
    ax = txs.mean() if len(txs) else arr.shape[1] / 2
    fname = f"{sid}_{kind}_{name[-1]}"
    size = export(im2, fname)
    bot = arr[int(0.55 * h):]
    bx = np.nonzero(bot)[1]
    hx = bx.mean() if len(bx) else arr.shape[1] / 2
    return {"file": f"res://assets/art/rig/{fname}.png", "size": size, "anchor_x": ax * G,
            "hand": (hx * G, size[1] * 0.80)}


def build_boot(sid):
    im, box = load_piece(sid, "boot_r")
    im2, _, _ = trim(im)
    arr = np.asarray(im2)[..., 3] > 6
    h = arr.shape[0]
    top = arr[: int(0.30 * h)]
    txs = np.nonzero(top)[1]
    ax = txs.mean() if len(txs) else arr.shape[1] / 2
    size = export(im2, f"{sid}_boot")
    return {"file": f"res://assets/art/rig/{sid}_boot.png", "size": size, "pos_rel": (-(ax * G), -size[1])}


def build_headgear(sid, own_body, name):
    im, box = load_piece(sid, name)
    im2, tx0, ty0 = trim(im)
    hx0 = box[0] + tx0
    hy0 = box[1] + ty0
    cxl, neck_l, x0s, y0s = own_body["_neck_l"]
    neck_sheet = (x0s + cxl, y0s + neck_l)
    size = export(im2, f"{sid}_{name}")
    return {"file": f"res://assets/art/rig/{sid}_{name}.png", "size": size,
            "pos_rel": ((hx0 - neck_sheet[0]) * G, (hy0 - neck_sheet[1]) * G)}


def build_foot(sid):
    """Pie descalzo: parte baja de la pierna derecha del cuerpo base."""
    body, bbox = load_piece(sid, "body")
    A = np.asarray(body)[..., 3] > 6
    cxl = meta[sid]["cx"] - bbox[0]
    rows = np.nonzero(A.any(axis=1))[0]
    bot = int(rows.max())
    h_foot = int(0.17 * (bot - rows.min()))
    xoff = int(cxl)
    crop = body.crop((xoff, bot - h_foot, body.width, bot + 1))
    im2, _, _ = trim(crop)
    a2 = np.asarray(im2)[..., 3] > 6
    top = a2[: max(3, int(0.3 * a2.shape[0]))]
    txs = np.nonzero(top)[1]
    ax = txs.mean() if len(txs) else a2.shape[1] / 2
    size = export(im2, f"{sid}_foot")
    return {"file": f"res://assets/art/rig/{sid}_foot.png", "size": size, "pos_rel": (-(ax * G), -size[1])}


def vec(v):
    return "Vector2(%s, %s)" % (fmt(v[0]), fmt(v[1]))


def piece(p, extra=()):
    items = [f'"file": "{p["file"]}"', f'"size": {vec(p["size"])}']
    if "pos" in p:
        items.append(f'"pos": {vec(p["pos"])}')
    if "pos_rel" in p:
        items.append(f'"pos_rel": {vec(p["pos_rel"])}')
    if "anchor_x" in p:
        items.append(f'"anchor_x": {fmt(p["anchor_x"])}')
    for k in extra:
        if k in p:
            v = p[k]
            items.append(f'"{k}": {vec(v)}' if isinstance(v, tuple) else f'"{k}": {fmt(v)}')
    return "{" + ", ".join(items) + "}"


def emit_body(b):
    parts = [f'"neck": {vec(b["neck"])}', f'"ankle": {fmt(b["ankle"])}',
             f'"has_legs": {"true" if b["has_legs"] else "false"}',
             f'"torso": {piece(b["torso"])}',
             f'"arm_l": {piece(b["arm_l"], ("shoulder", "wrist"))}',
             f'"arm_r": {piece(b["arm_r"], ("shoulder", "wrist"))}']
    if b["has_legs"]:
        parts.append(f'"leg_l": {piece(b["leg_l"], ("pivot", "foot_x"))}')
        parts.append(f'"leg_r": {piece(b["leg_r"], ("pivot", "foot_x"))}')
    return parts


ICON = 96


def fit_icon(images, out_path, pad=6, gap=24):
    ims = [trim(i)[0] for i in images]
    h = max(i.height for i in ims)
    w = sum(i.width for i in ims) + gap * (len(ims) - 1)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = 0
    for i in ims:
        canvas.alpha_composite(i, (x, (h - i.height) // 2))
        x += i.width + gap
    scale = (ICON - 2 * pad) / max(canvas.width, canvas.height)
    nw, nh = max(1, round(canvas.width * scale)), max(1, round(canvas.height * scale))
    small = canvas.resize((nw, nh), Image.LANCZOS)
    out = Image.new("RGBA", (ICON, ICON), (0, 0, 0, 0))
    out.alpha_composite(small, ((ICON - nw) // 2, (ICON - nh) // 2))
    out.save(out_path, optimize=True)


def make_icons(sid):
    helm, _ = load_piece(sid, "helm")
    body, _ = load_piece(sid, "body")
    gl, _ = load_piece(sid, "glove_l")
    gr, _ = load_piece(sid, "glove_r")
    bl, _ = load_piece(sid, "boot_l")
    br, _ = load_piece(sid, "boot_r")
    fit_icon([helm], os.path.join(ITEMS_DIR, f"{sid}_helm.png"))
    fit_icon([body], os.path.join(ITEMS_DIR, f"{sid}_chest.png"))
    fit_icon([gl, gr], os.path.join(ITEMS_DIR, f"{sid}_gloves.png"))
    fit_icon([bl, br], os.path.join(ITEMS_DIR, f"{sid}_boots.png"))


MOB_SCALE = {"runner": 0.088, "brute": 0.098, "sentinel": 0.096, "sniper_base": 0.058, "sniper_gun": 0.075,
             "practice_dummy": 0.0385, "training_turret": 0.036,
             "runner_blade_a": 0.07, "runner_crossbow": 0.07, "brute_hammer": 0.085, "sentinel_spear": 0.1}


def build_mobs():
    ents = []
    for name, sc in MOB_SCALE.items():
        im = Image.open(os.path.join(W, "pieces", f"mob__{name}.png")).convert("RGBA")
        im2 = trim(im)[0]
        if name == "sniper_gun":
            im2 = im2.transpose(Image.FLIP_LEFT_RIGHT)  # la boca queda a la derecha
        arr = np.asarray(im2)[..., 3] > 6
        w = max(1, round(im2.width * sc * TEXS))
        h = max(1, round(im2.height * sc * TEXS))
        im2.resize((w, h), Image.LANCZOS).save(os.path.join(MOBS_DIR, f"{name}.png"), optimize=True)
        size = (w / TEXS, h / TEXS)
        tail = arr[int(0.85 * arr.shape[0]):]
        txs = np.nonzero(tail)[1]
        fx = (txs.mean() if len(txs) else arr.shape[1] / 2) * sc
        ents.append(f'\t"{name}": {{"file": "res://assets/art/mobs/{name}.png", "size": {vec(size)}, "foot": {vec((fx, size[1]))}}}')
    return "const MOBS: Dictionary = {\n" + ",\n".join(ents) + "\n}"


def main():
    lines = ["extends RefCounted",
             "## GENERADO a partir de las hojas de sets (assets/sprites/sets  mobs). No editar a mano.",
             "## Piezas del esqueleto del jugador y de los humanoides: SETS (armaduras de 4 piezas), SKINS (cuerpos base) y MOBS.",
             "## Unidades en px de juego; el origen del esqueleto es el suelo entre los pies. Las texturas son 3x (CharacterRig.TEX_SCALE).",
             "## `pos` es la esquina superior izquierda en coordenadas del esqueleto; `pos_rel`, relativa al cuello (casco/cabeza),",
             "## a la muneca (guantes/manos) o al punto de apoyo del pie (botas/pies).",
             "",
             "const SETS: Dictionary = {"]
    ents = []
    for sid in SETS:
        body = build_body(sid, False, "glove")
        helm = build_headgear(sid, body, "helm")
        gl = build_hand(sid, "glove_l", "glove")
        gr = build_hand(sid, "glove_r", "glove")
        boot = build_boot(sid)
        parts = emit_body(body)
        parts += [f'"helm": {piece(helm)}', f'"glove_l": {piece(gl, ("hand",))}',
                  f'"glove_r": {piece(gr, ("hand",))}', f'"boot": {piece(boot)}']
        ents.append(f'\t"{sid}": {{' + ", ".join(parts) + "}")
        make_icons(sid)
    lines.append(",\n".join(ents))
    lines += ["}", "", "const SKINS: Dictionary = {"]
    ents = []
    for sid in SKINS:
        body = build_body(sid, True, "hand")
        head = build_headgear(sid, body, "head")
        hl = build_hand(sid, "hand_l", "hand")
        hr = build_hand(sid, "hand_r", "hand")
        parts = emit_body(body)
        parts += [f'"head": {piece(head)}', f'"hand_l": {piece(hl, ("hand",))}', f'"hand_r": {piece(hr, ("hand",))}']
        if sid != "ghost":
            parts.append(f'"foot": {piece(build_foot(sid))}')
        ents.append(f'\t"{sid}": {{' + ", ".join(parts) + "}")
    lines.append(",\n".join(ents))
    lines += ["}", "", build_mobs()]
    open(os.path.join(PROJ, "core", "art", "armor_art.gd"), "w", encoding="utf-8").write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
    print("ok")
