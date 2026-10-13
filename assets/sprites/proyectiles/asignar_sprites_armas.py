"""Asigna el sprite de proyectil a cada arma (data/weapons/*.tres) que dispara la bala estándar.

Solo toca armas cuyo projectile_scene es res://combat/projectile.tscn. Idempotente: si ya tiene projectile_sprite, no hace nada.
Uso: python -I "C:/Users/Usuario/Documents/warmachine/assets/sprites/proyectiles/asignar_sprites_armas.py"
"""
import os
import re

RAIZ = "C:/Users/Usuario/Documents/warmachine"
ARMAS = {
    "pistol_9mm": "bala_pistola",
    "colt_44": "bala_pistola",
    "revolver": "bala_pistola",
    "rust_revolver": "bala_pistola",
    "desert_eagle": "bala_pistola",
    "smg": "bala_smg",
    "mp5": "bala_smg",
    "m4": "bala_rifle",
    "ak47": "bala_rifle",
    "scrap_carbine": "bala_rifle",
    "old_rifle": "bala_rifle",
    "shotgun": "perdigon",
    "heavy_sniper": "bala_francotirador",
}


def asignar(arma, sprite):
    ruta = os.path.join(RAIZ, "data", "weapons", arma + ".tres")
    with open(ruta, encoding="utf-8") as f:
        texto = f.read()
    if "projectile_sprite" in texto:
        return f"SKIP    {arma}: ya tiene projectile_sprite"
    if 'res://combat/projectile.tscn' not in texto:
        return f"SKIP    {arma}: no usa la bala estándar"

    recurso = f"res://assets/sprites/proyectiles/{sprite}.png"
    id_ext = "3_sprite"

    # Agregar el ext_resource después del último existente
    lineas_ext = list(re.finditer(r'^\[ext_resource[^\n]*\n', texto, re.MULTILINE))
    fin = lineas_ext[-1].end()
    texto = texto[:fin] + f'[ext_resource type="Texture2D" path="{recurso}" id="{id_ext}"]\n' + texto[fin:]

    # Subir load_steps en 1
    texto = re.sub(r"load_steps=(\d+)", lambda m: f"load_steps={int(m.group(1)) + 1}", texto, count=1)

    # Propiedad dentro de [resource]
    texto = texto.replace("[resource]\n", f'[resource]\nprojectile_sprite = ExtResource("{id_ext}")\n', 1)

    with open(ruta, "w", encoding="utf-8", newline="\n") as f:
        f.write(texto)
    return f"OK      {arma} -> {sprite}"


if __name__ == "__main__":
    for arma, sprite in ARMAS.items():
        print(asignar(arma, sprite))
