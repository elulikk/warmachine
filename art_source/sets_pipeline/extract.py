"""Corta las hojas de sets en piezas RGBA (casco, torso, guantes, botas) por watershed con semillas."""
import glob, os, sys, json
import numpy as np, cv2
from PIL import Image
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(PROJ, "assets", "sprites", "sets  mobs")
WORK = os.path.join(HERE, "work")

SHEETS = [
    ("ahora,_armadura_de_adamantio", ["adamantine", "mithril", "olympus", "infernal"], 110),
    ("ahora,_negro_villero", ["cumbiero", "spy", "wick", "scrap"], 145),
    ("bueno_ahora_cambialos", ["iron_power", "advanced_power", "nano", "wizard"], 120),
    ("los_pantalones", ["iron", "leather", "bronze", "steel"], 115),
    ("samurai_set", ["samurai", "ninja", "predator", "magneto"], 140),
    ("set_de_oro", ["gold", "diamond", "obsidian", "fire"], 115),
]
# semillas extra por set (coordenadas relativas a cx se resuelven en seg; aqui absolutas en px de hoja)
EXTRA = {}
BOUNDS = [330, 950, 1525, 2135, 2752]
T = 30

def find_sheet(prefix):
    for p in glob.glob(os.path.join(SRC, "*.jpg")):
        if os.path.basename(p).startswith(prefix):
            return p
    raise FileNotFoundError(prefix)

def fg_mask(a):
    h, w, _ = a.shape
    border = np.concatenate([a[:6].reshape(-1,3), a[-6:].reshape(-1,3), a[:, :6].reshape(-1,3), a[:, -6:].reshape(-1,3)])
    bg = np.median(border, axis=0)
    d = np.abs(a.astype(np.int16) - bg).max(axis=2)
    lab, n = ndi.label(d <= T)
    bl = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:,0], lab[:,-1]]))) - {0}
    bgc = np.isin(lab, list(bl))
    # bolsillos de fondo encerrados por la silueta (entre brazo y torso, etc.): casi exactamente del color del fondo
    tol = 7 if bg.min() < 254 else 4
    tight = (d <= tol) & ~bgc
    plab, pn = ndi.label(tight)
    if pn:
        sizes = ndi.sum(tight, plab, range(1, pn + 1))
        big = [i + 1 for i, sz in enumerate(sizes) if sz >= 150]
        bgc = bgc | np.isin(plab, big)
    return ~bgc, d, bg

def seg(a, fg, d, cols_range, ymin, cx=None, extra=None):
    """Devuelve dict nombre -> mascara booleana para una columna."""
    h, w, _ = a.shape
    x0, x1 = cols_range
    col = np.zeros_like(fg)
    col[ymin:, x0:x1] = fg[ymin:, x0:x1]
    # texto de filas y titulos fuera
    # centro de columna: extremos en filas 880..1200
    ys, xs = np.nonzero(col[880:1205])
    cx0 = int((xs.min() + xs.max()) / 2) if cx is None else cx
    markers = np.zeros((h, w), np.int32)
    BG, HELM, BODY, GL, GR, BL, BR = 1, 2, 3, 4, 5, 6, 7
    markers[~fg] = BG
    markers[:, :x0] = BG
    markers[:, x1:] = BG
    markers[:ymin] = BG
    def line(label, p0, p1, th):
        cv2.line(markers, p0, p1, label, th)
    # semillas
    cv2.ellipse(markers, (cx0, 285), (46, 85), 0, 0, 360, HELM, -1)
    for ex in (extra or {}).get("helm", []):
        line(HELM, (cx0 + ex[0][0], ex[0][1]), (cx0 + ex[1][0], ex[1][1]), ex[2])
    for ex in (extra or {}).get("body", []):
        line(BODY, (cx0 + ex[0][0], ex[0][1]), (cx0 + ex[1][0], ex[1][1]), ex[2])
    line(BODY, (cx0 - 150, 540), (cx0 + 150, 540), 18)
    line(BODY, (cx0, 560), (cx0, 900), 50)
    line(BODY, (cx0 - 55, 1000), (cx0 - 55, 1150), 30)
    line(BODY, (cx0 + 55, 1000), (cx0 + 55, 1150), 30)
    line(BODY, (cx0 - 190, 640), (cx0 - 190, 800), 24)
    line(BODY, (cx0 + 190, 640), (cx0 + 190, 800), 24)
    line(GL, (cx0 - 225, 1010), (cx0 - 225, 1170), 34)
    line(GR, (cx0 + 225, 1010), (cx0 + 225, 1170), 34)
    # botas: componentes bajo la fila 1225
    low = np.zeros_like(fg)
    low[1228:, x0:x1] = fg[1228:, x0:x1]
    lab, n = ndi.label(ndi.binary_erosion(low, iterations=4))
    if n >= 2:
        areas = ndi.sum(low, lab, range(1, n + 1))
        order = np.argsort(areas)[::-1][:2]
        comps = []
        for o in order:
            ys2, xs2 = np.nonzero(lab == o + 1)
            comps.append((xs2.mean(), o + 1))
        comps.sort()
        markers[lab == comps[0][1]] = BL
        markers[lab == comps[1][1]] = BR
    # los pixeles fg sin semilla quedan 0 (desconocido)
    markers[(markers == 0) & ~fg] = BG
    out = cv2.watershed(a.copy(), markers.astype(np.int32))
    # fronteras (-1) -> vecino mas cercano
    bad = out == -1
    if bad.any():
        idx = ndi.distance_transform_edt(bad, return_distances=False, return_indices=True)
        out = out[tuple(idx)]
    names = {HELM: "helm", BODY: "body", GL: "glove_l", GR: "glove_r", BL: "boot_l", BR: "boot_r"}
    res = {}
    for lbl, nm in names.items():
        m = (out == lbl) & fg & (np.arange(w)[None, :] >= x0) & (np.arange(w)[None, :] < x1)
        m[:ymin] = False
        res[nm] = m
    return res, cx0

def to_rgba(a, mask, d, bg):
    """Recorta, aplica alfa suave y quita el halo del fondo claro."""
    ys, xs = np.nonzero(mask)
    if len(ys) == 0:
        return None
    pad = 4
    y0, y1 = max(ys.min() - pad, 0), min(ys.max() + pad + 1, a.shape[0])
    x0, x1 = max(xs.min() - pad, 0), min(xs.max() + pad + 1, a.shape[1])
    m = mask[y0:y1, x0:x1].astype(np.float32)
    rgb = a[y0:y1, x0:x1].astype(np.float32)
    dd = d[y0:y1, x0:x1].astype(np.float32)
    # quedarse con el componente principal y los que pesen (sin motas)
    lab, n = ndi.label(m > 0)
    if n > 1:
        areas = ndi.sum(m, lab, range(1, n + 1))
        keep = [i + 1 for i, ar in enumerate(areas) if ar > max(60, 0.002 * areas.max())]
        m = np.isin(lab, keep).astype(np.float32)
    m = ndi.binary_closing(m > 0, iterations=1).astype(np.float32)
    # borde suave: erosion de 1 px + blur
    core = ndi.binary_erosion(m > 0, iterations=1).astype(np.float32)
    alpha = ndi.gaussian_filter(core, 0.9)
    alpha = np.clip(alpha * 1.15, 0, 1)
    alpha[m == 0] = 0
    # des-halo: mezcla con el fondo en el borde -> oscurecer hacia el vecino interior
    edge = (alpha > 0) & (alpha < 1)
    if edge.any():
        inner = ndi.grey_erosion(rgb, size=(3, 3, 1))
        rgb = np.where(edge[..., None], np.minimum(rgb, inner + 20), rgb)
    out = np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype(np.uint8)
    return Image.fromarray(out), (int(x0), int(y0), int(x1), int(y1))

def main():
    os.makedirs(os.path.join(WORK, "pieces"), exist_ok=True)
    meta = {}
    for prefix, ids, ymin in SHEETS:
        path = find_sheet(prefix)
        a = np.asarray(Image.open(path).convert("RGB"))
        fg, d, bg = fg_mask(a)
        dbg = np.zeros(a.shape, np.uint8) + 255
        colors = {"helm": (255, 0, 0), "body": (0, 160, 0), "glove_l": (0, 0, 255), "glove_r": (255, 150, 0), "boot_l": (160, 0, 160), "boot_r": (0, 200, 200)}
        for ci, sid in enumerate(ids):
            x0, x1 = BOUNDS[ci], BOUNDS[ci + 1]
            ym = ymin
            if prefix.startswith("ahora,_negro") and ci == 1:
                ym = 145
            if prefix.startswith("bueno") and ci == 1:
                ym = 148
            res, cx = seg(a, fg, d, (x0, x1), ym, extra=EXTRA.get(sid))
            meta[sid] = {"cx": int(cx), "pieces": {}}
            for nm, m in res.items():
                r = to_rgba(a, m, d, bg)
                if r is None:
                    print("FALTA", sid, nm)
                    continue
                im, box = r
                im.save(os.path.join(WORK, "pieces", f"{sid}__{nm}.png"))
                meta[sid]["pieces"][nm] = {"box": box, "size": im.size}
                dbg[m] = colors[nm]
        Image.fromarray(dbg).resize((1376, 768)).save(os.path.join(WORK, f"dbg_{ids[0]}.png"))
    json.dump(meta, open(os.path.join(WORK, "meta.json"), "w"), indent=1)

if __name__ == "__main__":
    main()
