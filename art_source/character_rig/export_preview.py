import sys, pickle, math, json; sys.path.insert(0,'.')
from common import *
from psd_tools import PSDImage
from psd_tools.api.layers import PixelLayer
OUT="../../assets/PSD/out"
st=pickle.load(open("_state.pkl","rb")); pcs={k:Image.fromarray(v,"RGBA") for k,v in st["pieces"].items()}
ORDER=st["order"]; P=st["P"]
# --- PSD ---
psd=PSDImage.new("RGB",(CW,CH),color=(0,0,0))
for k in ORDER:  # abajo -> arriba
    PixelLayer.frompil(pcs[k],psd,k,top=0,left=0)
psd.save(f"{OUT}/character_rig.psd")
chk=PSDImage.open(f"{OUT}/character_rig.psd"); print([l.name for l in chk])

# --- FK preview ---
def rp(p,c,a):
    a=math.radians(a); dx,dy=p[0]-c[0],p[1]-c[1]
    return (c[0]+dx*math.cos(a)-dy*math.sin(a), c[1]+dx*math.sin(a)+dy*math.cos(a))
def rot(im,c,a): return im.rotate(-a,resample=Image.BICUBIC,center=c)
def pose(sh,el,hipa,kn,an,side="near"):
    """devuelve dict pieza->imagen rotada. sh/el: ángulos (° horario) hombro/codo; hipa/kn/an cadera/rodilla/tobillo."""
    r={}
    s=P["shoulder_"+side]; e=P["elbow_"+side]; w=P["wrist_"+side]
    r["arm_%s_upper"%side]=rot(pcs["arm_%s_upper"%side],s,sh)
    e2=rp(e,s,sh); a1=sh+el
    r["arm_%s_lower"%side]=rot(rot(pcs["arm_%s_lower"%side],e,el) if False else pcs["arm_%s_lower"%side],e,0)  # placeholder
    lo=rot(pcs["arm_%s_lower"%side],s,sh); lo=rot(lo,e2,el); r["arm_%s_lower"%side]=lo
    w2=rp(rp(w,s,sh),e2,el)
    h=rot(pcs["hand_%s"%side],s,sh); h=rot(h,e2,el); r["hand_%s"%side]=h
    # leg
    hp=P["hip_"+side]; k=P["knee_"+side]; a=P["ankle_"+side]
    r["leg_%s_thigh"%side]=rot(pcs["leg_%s_thigh"%side],hp,hipa)
    k2=rp(k,hp,hipa)
    sh_=rot(pcs["leg_%s_shin"%side],hp,hipa); sh_=rot(sh_,k2,kn); r["leg_%s_shin"%side]=sh_
    a2=rp(rp(a,hp,hipa),k2,kn)
    f=rot(pcs["foot_%s"%side],hp,hipa); f=rot(f,k2,kn); f=rot(f,a2,an); r["foot_%s"%side]=f
    return r
def render(near,far):
    imgs=dict(pcs); imgs.update(near); imgs.update(far)
    c=Image.new("RGBA",(CW,CH),(0,0,0,0))
    for k in ORDER: c.alpha_composite(imgs[k])
    return c
def panel(c,title,box=(560,180,1500,1960)):
    bg=Image.new("RGBA",(box[2]-box[0],box[3]-box[1]),(150,150,190,255)); bg.alpha_composite(c.crop(box))
    ImageDraw.Draw(bg).text((8,8),title,fill=(0,0,0,255)); return bg
poses=[("neutra",(0,0,0,0,0),(0,0,0,0,0)),
       ("adelante: hombro -30, codo -30, cadera -30, rodilla +30",(-30,-30,-30,30,0),(30,15,30,-30,0)),
       ("atras: hombro +30, codo -10, cadera +30, rodilla +10",(30,-10,30,10,0),(-30,-30,-30,30,0))]
pans=[]
for t,n,f in poses:
    c=render(pose(*n,side="near"),pose(*f,side="far")); pans.append(panel(c,t))
    if t=="neutra": c.save(f"{OUT}/preview_assembled_neutral_full.png")
W=sum(p.width for p in pans); sheet=Image.new("RGBA",(W,pans[0].height))
x=0
for p in pans: sheet.paste(p,(x,0)); x+=p.width
sheet.convert("RGB").save(f"{OUT}/preview_neutral_and_rotated.png")
pans[0].convert("RGB").save(f"{OUT}/preview_neutral.png")
pans[1].convert("RGB").save(f"{OUT}/preview_rotated_30.png")
