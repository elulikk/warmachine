"""Exporta las piezas aprobadas (assets/PSD/out) al juego: PNG a assets/art/rig/hero_*.png y core/art/hero_art.gd.
Ejecutar: python -I -W ignore export_game.py (desde art_source/character_rig)."""
import json, os
import numpy as np
from PIL import Image
HERE=os.path.dirname(os.path.abspath(__file__))
PROJ=os.path.abspath(os.path.join(HERE,"..",".."))
SRC=os.path.join(PROJ,"assets","PSD","out")
RIG=os.path.join(PROJ,"assets","art","rig")
G=0.049      # px de juego por px del lienzo (personaje ~83 px de alto, como el cuerpo anterior)
TEXS=3.0     # px de textura por px de juego (CharacterRig.TEX_SCALE = 1/3)
J=json.load(open(os.path.join(SRC,"character_rig.json")))
PV=J["pivots"]; OX,OY=PV["origin"]
def gp(p): return ((p[0]-OX)*G,(p[1]-OY)*G)
def v(p): return "Vector2(%.2f, %.2f)"%p
def resize(im,f):
    a=np.asarray(im).astype(np.float32); al=a[...,3:4]/255.0
    pm=Image.fromarray(np.dstack([a[...,:3]*al,a[...,3:4]]).astype(np.uint8),"RGBA") if False else None
    w,h=max(1,round(im.width*f)),max(1,round(im.height*f))
    chans=[Image.fromarray((a[...,i]*al[...,0]).astype(np.float32),"F").resize((w,h),Image.LANCZOS) for i in range(3)]
    ach=Image.fromarray(a[...,3].astype(np.float32),"F").resize((w,h),Image.LANCZOS)
    A=np.clip(np.asarray(ach),0,255)
    rgb=np.stack([np.asarray(c) for c in chans],-1)/np.maximum(A[...,None]/255.0,1e-3)
    out=np.dstack([np.clip(rgb,0,255),A]).round().astype(np.uint8)
    out[...,:3][out[...,3]==0]=0
    return Image.fromarray(out,"RGBA")
info={}
for k,pc in J["pieces"].items():
    im=Image.open(os.path.join(SRC,pc["file"])).convert("RGBA")
    t=resize(im,G*TEXS); name=f"hero_{k}.png"; t.save(os.path.join(RIG,name))
    pos=gp(pc["offset"]); size=(t.width/TEXS,t.height/TEXS)
    info[k]={"file":f"res://assets/art/rig/{name}","size":size,"pos":pos}
def piece(k):
    d=info[k]; return '{"file": "%s", "size": %s, "pos": %s}'%(d["file"],v(d["size"]),v(d["pos"]))
def arm(s):
    return ('{"shoulder": %s, "elbow": %s, "grip": %s, "upper": %s, "lower": %s, "hand": %s}'%
      (v(gp(PV["shoulder_"+s])),v(gp(PV["elbow_"+s])),v(gp([PV["grip"][0]+(PV["shoulder_far"][0]-PV["shoulder_near"][0] if s=="far" else 0),PV["grip"][1]+(PV["shoulder_far"][1]-PV["shoulder_near"][1] if s=="far" else 0)])),
       piece(f"arm_{s}_upper"),piece(f"arm_{s}_lower"),piece(f"hand_{s}")))
def leg(s):
    return ('{"hip": %s, "knee": %s, "ankle": %s, "thigh": %s, "shin": %s, "foot": %s}'%
      (v(gp(PV["hip_"+s])),v(gp(PV["knee_"+s])),v(gp(PV["ankle_"+s])),piece(f"leg_{s}_thigh"),piece(f"leg_{s}_shin"),piece(f"foot_{s}")))
neck=gp(PV["neck"]); hd=info["head"]
head='{"file": "%s", "size": %s, "pos_rel": %s}'%(hd["file"],v(hd["size"]),v((hd["pos"][0]-neck[0],hd["pos"][1]-neck[1])))
tr=info["torso"]
torso='{"file": "%s", "size": %s, "pos": %s}'%(tr["file"],v(tr["size"]),v(tr["pos"]))
body=('{"articulated": true, "neck": %s, "ankle": 0.00, "has_legs": true, "back_shift": %.2f, "belt_pos": Vector2(5.00, -40.00), '
      '"torso": %s, "head": %s, "arm_far": %s, "arm_near": %s, "leg_far": %s, "leg_near": %s}')%(
      v(neck),tr["pos"][0]+3.0,torso,head,arm("far"),arm("near"),leg("far"),leg("near"))
src=f'''extends RefCounted
## GENERADO por art_source/character_rig/export_game.py desde assets/PSD/out/character_rig.json. No editar a mano.
## Cuerpo base de perfil (mirando a la derecha) con miembros articulados: SKINS["hero"].
## Unidades en px de juego; el origen del esqueleto es el suelo entre los pies. Texturas al triple (CharacterRig.TEX_SCALE).
## Cada miembro lleva sus articulaciones (hombro/codo/agarre, cadera/rodilla/tobillo) y sus piezas con `pos` = esquina
## superior izquierda de la textura en coordenadas del esqueleto.

const SKINS: Dictionary = {{
	"hero": {body}
}}
'''
open(os.path.join(PROJ,"core","art","hero_art.gd"),"w",encoding="utf-8").write(src)
print("ok",len(info),"piezas; altura juego ~%.1f"%((OY-220)*G))
