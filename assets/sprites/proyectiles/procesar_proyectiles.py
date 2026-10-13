"""Procesa los JPG descargados de Google Flow: quita el fondo negro, recorta y guarda PNG transparentes.

Uso: python -I "C:/Users/Usuario/Documents/warmachine/assets/sprites/proyectiles/procesar_proyectiles.py"
"""
import os
import re
from PIL import Image

DESCARGAS = "C:/Users/Usuario/Downloads"
DESTINO = "C:/Users/Usuario/Documents/warmachine/assets/sprites/proyectiles"
LADO_MAX = 24  # px; la bala base del juego es 16x16, así que no conviene que sea mucho más grande
# Los objetos finos (francotirador, flecha, láser) pierden todo el detalle si se achican a 24 px de largo
LADO_MAX_POR_ID = {"bala_francotirador": 40, "flecha": 36, "laser": 36}

# id de la hoja -> prefijo del nombre de archivo que dio Flow
MAPA = {
    "bala_pistola": "Gold_bullet_pixel_art",
    "bala_smg": "Brass_submachine_gun_bullet",
    "bala_rifle": "Pixel_rifle_bullet_sprite",
    "perdigon": "Metallic_lead_pellet_pixel_art",
    "bala_francotirador": "Pixel_art_sniper_bullet",
    "flecha": "Pixel_art_wooden_arrow",
    "dardo": "Metallic_dart_with_purple_fin",
    "granada": "Olive_green_hand_grenade_sprite",
    "cohete": "Red_rocket_with_flame",
    "bola_plasma": "Cyan_energy_sphere_sprite",
    "laser": "Red_laser_flash_sprite",
    "bumeran": "Curved_wooden_boomerang_with_metal",
}


def buscar_original(prefijo):
    """Devuelve la descarga más reciente que empieza con el prefijo de Flow."""
    candidatos = [
        f for f in os.listdir(DESCARGAS)
        if f.startswith(prefijo) and re.search(r"_\d{14}\.jpg$", f)
    ]
    if not candidatos:
        return None
    return os.path.join(DESCARGAS, max(candidatos, key=lambda f: os.path.getmtime(os.path.join(DESCARGAS, f))))


def quitar_fondo(img):
    """Convierte el fondo negro en transparente: el alfa sale del brillo, así el resplandor se conserva."""
    img = img.convert("RGBA")
    pixeles = img.load()
    ancho, alto = img.size
    umbral = 14
    for y in range(alto):
        for x in range(ancho):
            r, g, b, _ = pixeles[x, y]
            brillo = max(r, g, b)
            if brillo <= umbral:
                pixeles[x, y] = (0, 0, 0, 0)
            else:
                alfa = min(255, int((brillo - umbral) * 255 / (255 - umbral)))
                pixeles[x, y] = (r, g, b, alfa)
    return img


def procesar(id_hoja, prefijo):
    origen = buscar_original(prefijo)
    if origen is None:
        return f"FALTA   {id_hoja}: no hay descarga para '{prefijo}'"

    img = Image.open(origen)
    img = quitar_fondo(img)
    recorte = img.getbbox()
    if recorte is not None:
        img = img.crop(recorte)
    lado = LADO_MAX_POR_ID.get(id_hoja, LADO_MAX)
    img.thumbnail((lado, lado), Image.LANCZOS)
    salida = os.path.join(DESTINO, f"{id_hoja}.png")
    img.save(salida)
    return f"OK      {id_hoja}.png  {img.size[0]}x{img.size[1]}  <- {os.path.basename(origen)}"


if __name__ == "__main__":
    for id_hoja, prefijo in MAPA.items():
        print(procesar(id_hoja, prefijo))
