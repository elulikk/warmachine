"""Convierte las capas de paralaje de un fondo en WebP listos para Godot.

Uso (desde la raíz del proyecto):
    python .claude/skills/parallax-level-background/scripts/build_layers.py <prefijo> \
        --sky <cielo.jpg> --far <lejos.jpg> --mid <medio.jpg> --street <calle.jpg> \
        [--base <base.jpg> --base-out assets/art/bg/<nombre>_base.jpg]

- `sky` es opaco (es el fondo completo, sin transparencia).
- `far`, `mid` y `street` vienen con fondo negro: el negro pasa a transparencia según la luminosidad.
- Salida: assets/art/bg/parallax/<prefijo>_parallax_<capa>.webp
"""
import argparse
import os
import shutil

from PIL import Image

LOW, HIGH = 10, 30  # luminosidad por debajo de LOW = transparente, por encima de HIGH = opaco


def to_alpha_layer(src: str, dst: str) -> None:
    rgb = Image.open(src).convert("RGB")
    alpha = Image.new("L", rgb.size)
    alpha.putdata([
        int(255 * min(1.0, max(0.0, (max(px) - LOW) / (HIGH - LOW))))
        for px in rgb.getdata()
    ])
    rgba = rgb.copy()
    rgba.putalpha(alpha)
    rgba.save(dst, "WEBP", quality=88, method=6)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("prefix", help="prefijo de los archivos, p. ej. city")
    parser.add_argument("--sky", required=True)
    parser.add_argument("--far", required=True)
    parser.add_argument("--mid", required=True)
    parser.add_argument("--street", required=True)
    parser.add_argument("--base", help="imagen fija (la base de Flow)")
    parser.add_argument("--base-out", help="dónde copiar la imagen fija dentro del proyecto")
    args = parser.parse_args()

    out_dir = os.path.join("assets", "art", "bg", "parallax")
    os.makedirs(out_dir, exist_ok=True)

    # Cielo: fondo completo, opaco
    Image.open(args.sky).convert("RGB").save(
        os.path.join(out_dir, f"{args.prefix}_parallax_sky.webp"), "WEBP", quality=88, method=6)
    for layer, src in (("far", args.far), ("mid", args.mid), ("street", args.street)):
        to_alpha_layer(src, os.path.join(out_dir, f"{args.prefix}_parallax_{layer}.webp"))

    if args.base and args.base_out:
        Image.open(args.base).convert("RGB").save(args.base_out, "JPEG", quality=92)
        print("imagen fija:", args.base_out)

    for name in sorted(os.listdir(out_dir)):
        if name.startswith(args.prefix + "_parallax_"):
            size_kb = os.path.getsize(os.path.join(out_dir, name)) // 1024
            print(name, size_kb, "KB")


if __name__ == "__main__":
    main()
