"""Corta character.psd en piezas de rig. Ejecutar: python -I build_rig.py (desde art_source/character_rig)."""
import sys, json, os; sys.path.insert(0,'.')
from common import *
OUT="../../assets/PSD/out"; os.makedirs(OUT+"/pieces",exist_ok=True)
ld=lambda n: Image.open(n).convert("RGBA")
head=ld("_clean_CABEZA.png"); torso=ld("_torso_patched.png")
upper=ld("_clean_BRAZO.png"); ante=ld("_clean_ANTEBRAZO.png")
pierna=ld("_clean_PIERNA.png"); pies=ld("_clean_PIES.png")

# ---- pivotes (px del lienzo 2048x2048) ----
P={"neck":(1020,622),"shoulder":(1000,690),"elbow":(985,895),"wrist":(1060,1115),
   "hip":(1040,1240),"knee":(1040,1480),"ankle":(1025,1832),"grip":(1128,1212)}
a=np.array(pies)[...,3]
ys,xs=np.nonzero(a>128)
ground_y=int(ys.max()); 
foot_x=int((xs.min()+xs.max())/2)
P["ground"]=(1060,ground_y)

def seg_mask(p0,p1,s_min=None,s_max=None):
    """máscara por posición s a lo largo del eje p0->p1 (s=0 en p0, s=1 en p1, escala px)."""
    d=np.array(p1,float)-p0; L=np.hypot(*d); d/=L
    yy,xx=np.mgrid[0:CH,0:CW]
    s=(xx-p0[0])*d[0]+(yy-p0[1])*d[1]
    m=np.ones((CH,CW),bool)
    if s_min is not None: m&=s>=s_min
    if s_max is not None: m&=s<=s_max
    return m,L
def cut(im,m):
    o=np.array(im); o[~m]=0; return Image.fromarray(o,"RGBA")
OVA,OVL=16,30   # solape en px: brazo / pierna
# antebrazo / mano
m,L=seg_mask(P["elbow"],P["wrist"],s_max=None)
m_fore,L=seg_mask(P["elbow"],P["wrist"],s_max=L+OVA)
m_hand,_=seg_mask(P["elbow"],P["wrist"],s_min=L-OVA)
arm_up=upper; arm_lo=cut(ante,m_fore); hand=cut(ante,m_hand)
# pierna: muslo / espinilla (pantalón+venda) / pie
_,Lk=seg_mask(P["hip"],P["knee"])
m_th,_=seg_mask(P["hip"],P["knee"],s_max=Lk+OVL)
m_sh,_=seg_mask(P["hip"],P["knee"],s_min=Lk-OVL)
shin_full=pies.copy(); shin_full.alpha_composite(pierna)
thigh=cut(pierna,m_th)
_,La=seg_mask(P["knee"],P["ankle"])
m_sh2,_=seg_mask(P["knee"],P["ankle"],s_min=-OVL,s_max=La+OVL)
shin=cut(shin_full,m_sh&m_sh2)
m_ft,_=seg_mask(P["knee"],P["ankle"],s_min=La-OVL)
foot=cut(pies,m_ft)

def shade(im,k=0.6):
    o=np.array(im).astype(np.float32); g=o[...,:3].mean(-1,keepdims=True)
    o[...,:3]=(o[...,:3]*0.8+g*0.2)*k; return Image.fromarray(np.clip(o,0,255).astype(np.uint8),"RGBA")
def shift(im,dx,dy):
    c=Image.new("RGBA",im.size,(0,0,0,0)); c.paste(im,(dx,dy)); return c
OFF_ARM=(-34,-6); OFF_LEG=(46,0)
near={"head":head,"torso":torso,"arm_near_upper":arm_up,"arm_near_lower":arm_lo,"hand_near":hand,
      "leg_near_thigh":thigh,"leg_near_shin":shin,"foot_near":foot}
far={"arm_far_upper":(arm_up,OFF_ARM),"arm_far_lower":(arm_lo,OFF_ARM),"hand_far":(hand,OFF_ARM),
     "leg_far_thigh":(thigh,OFF_LEG),"leg_far_shin":(shin,OFF_LEG),"foot_far":(foot,OFF_LEG)}
pieces=dict(near)
for k,(im,o) in far.items(): pieces[k]=shift(shade(im),*o)
ORDER=["foot_far","leg_far_shin","leg_far_thigh","arm_far_upper","arm_far_lower","hand_far",
       "foot_near","leg_near_shin","leg_near_thigh","head","torso","arm_near_upper","arm_near_lower","hand_near"]

# ---- pivotes por pieza + JSON ----
pivot_json={"canvas":[CW,CH],"units":"px","facing":"right","scale_note":"escala original del PSD (2048x2048)",
 "overlap_px":{"arm":OVA,"leg":OVL},"far_offsets":{"arm":OFF_ARM,"leg":OFF_LEG},
 "draw_order_back_to_front":ORDER,"pivots":{},"pieces":{}}
for k,v in P.items(): pivot_json["pivots"][k+"_near"]=list(v) if k in("neck","shoulder","elbow","wrist","hip","knee","ankle") else list(v)
for k in ("shoulder","elbow","wrist","hip","knee","ankle"):
    o=OFF_ARM if k in("shoulder","elbow","wrist") else OFF_LEG
    pivot_json["pivots"][k+"_far"]=[P[k][0]+o[0],P[k][1]+o[1]]
pivot_json["pivots"]["neck"]=list(P["neck"]); del pivot_json["pivots"]["neck_near"]
pivot_json["pivots"]["grip"]=list(P["grip"]); del pivot_json["pivots"]["grip_near"]
pivot_json["pivots"]["ground"]=list(P["ground"]); del pivot_json["pivots"]["ground_near"]
for k in ("shoulder","elbow","wrist","hip","knee","ankle"):
    pivot_json["pivots"][k+"_near"]=list(P[k]); 
pivot_json["pivots"]["origin"]=list(P["ground"])
JOINT={"head":"neck","torso":None,"arm_near_upper":"shoulder_near","arm_near_lower":"elbow_near","hand_near":"wrist_near",
 "leg_near_thigh":"hip_near","leg_near_shin":"knee_near","foot_near":"ankle_near",
 "arm_far_upper":"shoulder_far","arm_far_lower":"elbow_far","hand_far":"wrist_far",
 "leg_far_thigh":"hip_far","leg_far_shin":"knee_far","foot_far":"ankle_far"}
for k,im in pieces.items():
    bb=im.getbbox(); crop=im.crop(bb); crop.save(f"{OUT}/pieces/{k}.png")
    j=JOINT[k]; pv=pivot_json["pivots"].get(j) if j else None
    pivot_json["pieces"][k]={"file":f"pieces/{k}.png","offset":[bb[0],bb[1]],"size":list(crop.size),
        "pivot_canvas":pv,"pivot_local":[pv[0]-bb[0],pv[1]-bb[1]] if pv else None}
json.dump(pivot_json,open(f"{OUT}/character_rig.json","w"),indent=1)
import pickle; pickle.dump({"pieces":{k:np.array(v) for k,v in pieces.items()},"order":ORDER,"P":pivot_json["pivots"]},open("_state.pkl","wb"))

# ---- imagen de revisión de pivotes ----
base=Image.new("RGBA",(CW,CH),(0,0,0,0))
for k in ORDER: base.alpha_composite(pieces[k])
box=(640,180,1420,1960)
rev=Image.new("RGBA",(box[2]-box[0],box[3]-box[1]),(150,150,190,255)); rev.alpha_composite(base.crop(box))
d=ImageDraw.Draw(rev)
col={"neck":(255,255,0),"shoulder":(255,0,0),"elbow":(255,128,0),"wrist":(0,255,255),"hip":(255,0,255),"knee":(0,255,0),"ankle":(0,128,255),"grip":(255,255,255),"origin":(0,0,0)}
for k,v in pivot_json["pivots"].items():
    if k=="ground": continue
    b=k.replace("_near","").replace("_far","")
    x,y=v[0]-box[0],v[1]-box[1]; r=9 if "far" not in k else 6
    d.ellipse([x-r,y-r,x+r,y+r],outline=col[b]+(255,),width=3)
    d.line([x-r-5,y,x+r+5,y],fill=col[b]+(255,)); d.line([x,y-r-5,x,y+r+5],fill=col[b]+(255,))
    d.text((x+r+6,y-6),k,fill=(0,0,0,255))
gy=P["ground"][1]-box[1]; d.line([0,gy,rev.width,gy],fill=(255,0,0,255),width=2)
rev.convert("RGB").save(f"{OUT}/review_pivots.png")
print("ground",P["ground"],"foot_x_center",foot_x)
