"""Genera core/art/locomotion_data.gd a partir de los JSON que saca extract_motion.py (clips de Mixamo).

Uso: python build_locomotion.py [carpeta_con_jsons]   (por defecto C:/Users/Usuario/Downloads/mixamo)

Ciclos: se descarta el ultimo fotograma (repite al primero) y se remuestrean a CYCLE_N fotogramas.
Poses: un fotograma fijo del clip.
"""
import json
import os
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else "C:/Users/Usuario/Downloads/mixamo"
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "core", "art", "locomotion_data.gd")
CYCLE_N = 24

CYCLES = {"walk": "rifle_walk", "run": "rifle_run", "crouch": "rifle_crouch_walk"}
# nombre -> (clip, fotograma)
POSES = {"air_up": ("rifle_jump", 32), "air_down": ("rifle_jump", 38), "land": ("rifle_jump", 46),
         "fire": ("firing_rifle", 4)}
FIELDS = ["l_thigh", "r_thigh", "l_shin", "r_shin", "hips_h", "trunk"]
KEYS = {"l_thigh": "thigh_l", "r_thigh": "thigh_r", "l_shin": "shin_l", "r_shin": "shin_r", "hips_h": "hips", "trunk": "trunk"}


def load(name):
    with open(os.path.join(SRC, name + ".json")) as fh:
        return json.load(fh)["frames"]


def resample(vals, n):
    m = len(vals)
    out = []
    for i in range(n):
        t = i / n * m
        a = int(t) % m
        b = (a + 1) % m
        f = t - int(t)
        out.append(vals[a] * (1 - f) + vals[b] * f)
    return out


def arr(vals, prec=1):
    return "[" + ", ".join(("%." + str(prec) + "f") % v for v in vals) + "]"


lines = []
lines.append("extends RefCounted")
lines.append("## GENERADO por art_source/mixamo/build_locomotion.py a partir de clips de Mixamo (extract_motion.py). No editar a mano.")
lines.append("## Angulos de perfil en grados (0 = segmento colgando, + = hacia adelante); `hips` en metros respecto del reposo.")
lines.append("## Sin class_name: se carga por preload desde CharacterRig.")
lines.append("")
lines.append("const CYCLE_N: int = %d" % CYCLE_N)
lines.append("")
lines.append("const CYCLES: Dictionary = {")
items = []
for cname, clip in CYCLES.items():
    fr = load(clip)[:-1]
    body = []
    for fld in FIELDS:
        v = [f[fld] for f in fr]
        body.append('\t\t"%s": %s' % (KEYS[fld], arr(resample(v, CYCLE_N), 3 if fld == "hips_h" else 1)))
    items.append('\t"%s": {\n%s\n\t}' % (cname, ",\n".join(body)))
lines.append(",\n".join(items))
lines.append("}")
lines.append("")
lines.append("const POSES: Dictionary = {")
items = []
for pname, (clip, idx) in POSES.items():
    f = load(clip)[idx]
    body = ", ".join(('"%s": %.3f' if k == "hips_h" else '"%s": %.1f') % (KEYS[k], f[k]) for k in FIELDS)
    items.append('\t"%s": {%s}' % (pname, body))
lines.append(",\n".join(items))
lines.append("}")
lines.append("")
lines.append("")
lines.append("## Fotograma interpolado del ciclo `id` en u (0..1, envuelve). Vacio si el ciclo no existe.")
lines.append("static func sample(id: String, u: float) -> Dictionary:")
lines.append("\tvar cycle: Dictionary = CYCLES.get(id, {}) as Dictionary")
lines.append("\tif cycle.is_empty():")
lines.append("\t\treturn {}")
lines.append("\tvar t: float = fposmod(u, 1.0) * float(CYCLE_N)")
lines.append("\tvar a: int = int(t) % CYCLE_N")
lines.append("\tvar b: int = (a + 1) % CYCLE_N")
lines.append("\tvar f: float = t - floorf(t)")
lines.append("\tvar out: Dictionary = {}")
lines.append("\tfor k: Variant in cycle.keys():")
lines.append("\t\tvar arr: Array = cycle[k] as Array")
lines.append("\t\tout[k] = lerpf(float(arr[a]), float(arr[b]), f)")
lines.append("\treturn out")
lines.append("")
lines.append("")
lines.append("## Promedio de un campo del ciclo (para quitarle la postura media y quedarse con la oscilacion).")
lines.append("static func mean(id: String, field: String) -> float:")
lines.append("\tvar cycle: Dictionary = CYCLES.get(id, {}) as Dictionary")
lines.append("\tif cycle.is_empty() or not cycle.has(field):")
lines.append("\t\treturn 0.0")
lines.append("\tvar arr: Array = cycle[field] as Array")
lines.append("\tvar sum: float = 0.0")
lines.append("\tfor v: Variant in arr:")
lines.append("\t\tsum += float(v)")
lines.append("\treturn sum / float(arr.size())")
lines.append("")

with open(OUT, "w", newline="\n", encoding="utf-8") as fh:
    fh.write("\n".join(lines))
print("ok", os.path.abspath(OUT))
