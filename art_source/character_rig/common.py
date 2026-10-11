import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as nd
CW=CH=2048
NAMES=["CABEZA","PECHO","BRAZO","ANTEBRAZO","PIERNA","PIES"]
BBOX={"PIES":(938,1551),"PIERNA":(906,1181),"CABEZA":(857,220),"PECHO":(791,551),"BRAZO":(865,581),"ANTEBRAZO":(906,850)}

def defringe(im):
    a=np.array(im).astype(np.float32)
    al=a[...,3]
    solid=nd.binary_erosion(al>=250,iterations=1)
    idx=nd.distance_transform_edt(~solid,return_distances=False,return_indices=True)
    rgb=a[...,:3][idx[0],idx[1]]
    out=np.zeros_like(a)
    out[...,:3]=rgb
    na=np.clip((al-40)/(250-40),0,1)
    out[...,3]=np.where(solid,255,na*255)
    out[...,3][al<40]=0
    out[...,:3][out[...,3]==0]=0
    return Image.fromarray(out.round().astype(np.uint8),"RGBA")

def load_layers(clean=True):
    d={}
    for n in NAMES:
        im=Image.open(f"_src_{n}.png").convert("RGBA")
        if clean: im=defringe(im)
        c=Image.new("RGBA",(CW,CH),(0,0,0,0)); c.paste(im,BBOX[n]); d[n]=c
    return d
