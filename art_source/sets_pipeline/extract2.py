import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import json, os, numpy as np, cv2
from PIL import Image
from scipy import ndimage as ndi
import extract as E
from extract import find_sheet, fg_mask, to_rgba, WORK

def skins():
    path = find_sheet("ahora_quiero_el_personaje")
    a = np.asarray(Image.open(path).convert("RGB"))
    fg, d, bg = fg_mask(a)
    h, w, _ = a.shape
    bounds = [330, 940, 1545, 2115, 2752]
    ids = ["no_armor", "zombie", "skeleton", "ghost"]
    ymin = 150
    meta = {}
    dbg = np.zeros(a.shape, np.uint8) + 255
    colors = {"head": (255, 0, 0), "body": (0, 160, 0), "hand_l": (0, 0, 255), "hand_r": (255, 150, 0), "foot_l": (160, 0, 160), "foot_r": (0, 200, 200)}
    for ci, sid in enumerate(ids):
        x0, x1 = bounds[ci], bounds[ci + 1]
        col = np.zeros_like(fg)
        col[ymin:, x0:x1] = fg[ymin:, x0:x1]
        ys, xs = np.nonzero(col[900:1205])
        cx0 = int((xs.min() + xs.max()) / 2)
        BG, HEAD, BODY, HL, HR, FL, FR = 1, 2, 3, 4, 5, 6, 7
        mk = np.zeros((h, w), np.int32)
        mk[~fg] = BG
        mk[:, :x0] = BG; mk[:, x1:] = BG; mk[:ymin] = BG
        ycut = {"no_armor": 443, "zombie": 454, "skeleton": 461, "ghost": 445}[sid]
        mk[ymin:ycut, x0:x1][fg[ymin:ycut, x0:x1]] = HEAD
        cv2.line(mk, (cx0 - 150, ycut + 90), (cx0 + 150, ycut + 90), BODY, 18)
        cv2.line(mk, (cx0, ycut + 110), (cx0, 900), BODY, 50)
        if sid != "ghost":
            cv2.line(mk, (cx0 - 55, 1000), (cx0 - 55, 1450), BODY, 40)
            cv2.line(mk, (cx0 + 55, 1000), (cx0 + 55, 1450), BODY, 40)
        else:
            cv2.line(mk, (cx0, 900), (cx0, 1450), BODY, 60)
            cv2.line(mk, (cx0 - 120, 1250), (cx0 - 120, 1450), BODY, 40)
            cv2.line(mk, (cx0 + 120, 1250), (cx0 + 120, 1450), BODY, 40)
        cv2.line(mk, (cx0 - 190, 640), (cx0 - 190, 800), BODY, 24)
        cv2.line(mk, (cx0 + 190, 640), (cx0 + 190, 800), BODY, 24)
        cv2.line(mk, (cx0 - 230, 1010), (cx0 - 230, 1170), HL, 34)
        cv2.line(mk, (cx0 + 230, 1010), (cx0 + 230, 1170), HR, 34)
        mk[(mk == 0) & ~fg] = BG
        out = cv2.watershed(a.copy(), mk.astype(np.int32))
        bad = out == -1
        idx = ndi.distance_transform_edt(bad, return_distances=False, return_indices=True)
        out = out[tuple(idx)]
        rows_ = np.arange(h)[:, None]
        out[(rows_ >= ycut) & (out == HEAD)] = BODY
        out[(rows_ < ycut) & fg & (out != BG)] = HEAD
        xs_ = np.arange(w)[None, :]
        names = {HEAD: "head", BODY: "body", HL: "hand_l", HR: "hand_r", FL: "foot_l", FR: "foot_r"}
        meta[sid] = {"cx": cx0, "pieces": {}}
        for lbl, nm in names.items():
            m = (out == lbl) & fg & (xs_ >= x0) & (xs_ < x1)
            m[:ymin] = False
            r = to_rgba(a, m, d, bg)
            if r is None:
                print("FALTA", sid, nm); continue
            im, box = r
            im.save(os.path.join(WORK, "pieces", f"{sid}__{nm}.png"))
            meta[sid]["pieces"][nm] = {"box": box, "size": im.size}
            dbg[m] = colors[nm]
    Image.fromarray(dbg).resize((1376, 768)).save(os.path.join(WORK, "dbg_skins.png"))
    return meta

def mobs():
    path = find_sheet("Corredor_Bruto")
    a = np.asarray(Image.open(path).convert("RGB"))
    fg, d, bg = fg_mask(a)
    fg2 = ndi.binary_opening(fg, iterations=1)
    lab, n = ndi.label(fg2)
    objs = ndi.find_objects(lab)
    want = {
        "runner": (399, 147, 887, 711), "brute": (968, 132, 1490, 729), "sentinel": (1600, 121, 2107, 731),
        "sniper_gun": (2161, 716, 2715, 904), "sniper_base": (2240, 911, 2692, 1527),
        "runner_blade_a": (396, 696, 619, 808), "runner_blade_b": (430, 764, 645, 866), "runner_crossbow": (663, 701, 914, 856),
        "brute_hammer": (963, 718, 1498, 879), "sentinel_spear": (1537, 764, 2138, 816),
    }
    meta = {}
    for name, box in want.items():
        bx0, by0, bx1, by1 = box
        # componente cuya caja coincide mejor
        best, bscore = None, 1e9
        for i, sl in enumerate(objs):
            if sl is None: continue
            y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
            sc = abs(x0 - bx0) + abs(y0 - by0) + abs(x1 - bx1) + abs(y1 - by1)
            if sc < bscore:
                best, bscore = i + 1, sc
        m = lab == best
        r = to_rgba(a, m, d, bg)
        im, bb = r
        im.save(os.path.join(WORK, "pieces", f"mob__{name}.png"))
        meta[name] = {"box": bb, "size": im.size, "score": int(bscore)}
        print(name, im.size, bscore)
    path = find_sheet("Mu")
    return meta, a

def props():
    import glob
    p = [x for x in glob.glob(os.path.join(E.SRC, "*.jpg")) if "Mu" in os.path.basename(x) and "pr" in os.path.basename(x)][0]
    a = np.asarray(Image.open(p).convert("RGB"))
    fg, d, bg = fg_mask(a)
    fg2 = ndi.binary_opening(fg, iterations=1)
    lab, n = ndi.label(fg2)
    objs = ndi.find_objects(lab)
    areas = ndi.sum(fg2, lab, range(1, n + 1))
    big = sorted([(areas[i], i + 1) for i in range(n) if areas[i] > 100000], reverse=True)
    res = {}
    comps = []
    for ar, l in big:
        sl = objs[l - 1]
        comps.append((sl[1].start, l))
    comps.sort()
    names = ["practice_dummy", "training_turret"]
    for (x, l), nm in zip(comps, names):
        im, bb = to_rgba(a, lab == l, d, bg)
        im.save(os.path.join(WORK, "pieces", f"mob__{nm}.png"))
        res[nm] = {"box": bb, "size": im.size}
        print(nm, im.size)
    return res

if __name__ == "__main__":
    meta = json.load(open(os.path.join(WORK, "meta.json")))
    meta.update(skins())
    m2, _ = mobs()
    m3 = props()
    meta["_mobs"] = {**m2, **m3}
    json.dump(meta, open(os.path.join(WORK, "meta.json"), "w"), indent=1)
