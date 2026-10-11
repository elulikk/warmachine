import sys; sys.path.insert(0,'.')
from common import *
from scipy.ndimage import gaussian_filter
im=np.array(Image.open("_clean_PECHO.png")).astype(np.float32)
H,W=im.shape[:2]
yy,xx=np.mgrid[0:H,0:W]
CX,CY,RX,RY=987,736,99,127
ell=((xx-CX)/RX)**2+((yy-CY)/RY)**2<=1.0
ell=nd.binary_dilation(ell,iterations=2)
al=im[...,3]
# known vest pixels: opaque, near ellipse, not dark outline pixels
lum=im[...,:3]@np.array([.3,.59,.11],np.float32)
band=nd.binary_dilation(ell,iterations=45)&~nd.binary_dilation(ell,iterations=3)&(al>250)&(lum>38)
# normalized convolution (diffuse fill)
w=band.astype(np.float32)
sig=28
num=np.stack([gaussian_filter(im[...,c]*w,sig) for c in range(3)],-1)
den=gaussian_filter(w,sig)[...,None]
base=num/np.maximum(den,1e-4)
# widen for pixels with tiny support
for s in (60,120):
    n2=np.stack([gaussian_filter(im[...,c]*w,s) for c in range(3)],-1); d2=gaussian_filter(w,s)[...,None]
    base=np.where(den<0.02,n2/np.maximum(d2,1e-4),base)
# detail from a vest region below the hole (mirror tiled)
src=im[870:992,905:1075,:3]
hp=src-np.stack([gaussian_filter(src[...,c],7) for c in range(3)],-1)
sh,sw=hp.shape[:2]
ys=np.arange(H)[:,None]; xs=np.arange(W)[None,:]
def refl(v,n):
    v=np.mod(v,2*n); return np.where(v>=n,2*n-1-v,v)
Y=refl(ys-600,sh); X=refl(xs-880,sw)
detail=hp[Y,X]
fill=np.clip(base+detail*0.35,0,255)
# soft mask, alpha-limited
m=gaussian_filter(ell.astype(np.float32),1.5)[...,None]
m=np.where((al>0)[...,None],m,0)
out=im.copy()
out[...,:3]=im[...,:3]*(1-m)+fill*m
Image.fromarray(out.round().astype(np.uint8),"RGBA").save("_torso_patched.png")
c=Image.fromarray(out.round().astype(np.uint8),"RGBA").crop((780,540,1280,1320))
bg=Image.new("RGBA",c.size,(150,150,190,255)); bg.alpha_composite(c); bg.convert("RGB").save("_g_torso_patched.png")
