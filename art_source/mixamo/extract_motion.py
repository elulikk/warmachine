"""Lee un FBX de Mixamo con Blender y vuelca los angulos de perfil por fotograma a JSON.

Uso: blender.exe -b --python extract_motion.py -- <entrada.fbx> <salida.json>

Todos los angulos son del plano sagital de la pelvis (de perfil), en grados:
  0 = segmento colgando recto hacia abajo, + = hacia adelante (adonde mira el personaje).
  trunk / head: inclinacion desde la vertical (+ = hacia adelante).
  hips_h: altura de la cadera respecto del primer fotograma (m de Blender).
"""
import sys
import json
import math
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)

arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
act = arm.animation_data.action
f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
scene = bpy.context.scene
bones = arm.pose.bones


def bone_name(b):
    for pre in ("mixamorig:", "mixamorig1:", "mixamorig9:"):
        if pre + b in bones:
            return pre + b
    for k in bones.keys():
        if k.endswith(b):
            return k
    raise KeyError(b)


NAMES = ["Hips", "Neck", "Head", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "RightUpLeg", "RightLeg",
         "RightFoot", "RightToeBase", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand"]
N = {k: bone_name(k) for k in NAMES}


def head(b):
    return arm.matrix_world @ bones[N[b]].head


def tail(b):
    return arm.matrix_world @ bones[N[b]].tail


UP = Vector((0, 0, 1))


def lateral():
    v = head("LeftUpLeg") - head("RightUpLeg")
    v.z = 0
    return v.normalized()


def forward_of(lat):
    return lat.cross(UP).normalized()


def go(f):
    scene.frame_set(f)
    bpy.context.view_layer.update()


# Sentido de "adelante": en todo el clip las rodillas quedan, en promedio, delante de la linea cadera-tobillo.
vote = 0.0
for f in range(f0, f1 + 1):
    go(f)
    fw = forward_of(lateral())
    for side in ("Left", "Right"):
        hip, knee, ank = head(side + "UpLeg"), head(side + "Leg"), head(side + "Foot")
        vote += (knee - (hip + ank) * 0.5).dot(fw)
SIGN = 1.0 if vote >= 0 else -1.0


def ang(a, b, fwd):
    """Angulo del segmento a->b respecto de 'hacia abajo', + hacia adelante."""
    d = b - a
    return math.degrees(math.atan2(d.dot(fwd), -d.z))


frames = []
rest_h = None
for f in range(f0, f1 + 1):
    go(f)
    fwd = forward_of(lateral()) * SIGN
    hips = head("Hips")
    if rest_h is None:
        rest_h = hips.z
    neck = head("Neck")
    tr = neck - hips
    hd = tail("Head") - head("Head")
    fr = {
        "f": f - f0,
        "hips_h": round(hips.z - rest_h, 4),
        "trunk": round(math.degrees(math.atan2(tr.dot(fwd), tr.z)), 2),
        "head": round(math.degrees(math.atan2(hd.dot(fwd), hd.z)), 2),
    }
    for side in ("Left", "Right"):
        k = side[0].lower()
        hip, knee, ank, toe = head(side + "UpLeg"), head(side + "Leg"), head(side + "Foot"), head(side + "ToeBase")
        fr[k + "_thigh"] = round(ang(hip, knee, fwd), 2)
        fr[k + "_shin"] = round(ang(knee, ank, fwd), 2)
        fr[k + "_foot_h"] = round(ank.z - rest_h, 4)
        sh, el, wr = head(side + "Arm"), head(side + "ForeArm"), head(side + "Hand")
        fr[k + "_uarm"] = round(ang(sh, el, fwd), 2)
        fr[k + "_farm"] = round(ang(el, wr, fwd), 2)
    frames.append(fr)

out = {"source": src, "fps": scene.render.fps, "frames": frames, "hips_rest_h": round(rest_h or 0.0, 4)}
with open(dst, "w") as fh:
    json.dump(out, fh)
print("MIXAMO_OK frames=%d fps=%s rest_h=%.3f sign=%s" % (len(frames), scene.render.fps, rest_h or 0.0, SIGN))
