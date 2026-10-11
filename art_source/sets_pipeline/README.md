# Pipeline de las hojas de sets y mobs

Convierte las 9 hojas de `assets/sprites/sets  mobs/` (cuerpos base y mobs; los 24 sets de armadura se extraen pero ya no se usan: `SETS = []` en `build_art.py`) en las
piezas que usa el juego. Corre con Python 3 (`numpy`, `Pillow`, `scipy`, `opencv-python`). Esta carpeta la
ignora Godot (`art_source/.gdignore`). Ejecutar siempre con `python -I` y desde esta carpeta, en este orden:

| Paso | Script | Qué hace |
|---|---|---|
| 1 | `extract.py` | Quita el fondo y separa casco, cuerpo, guantes y botas de cada set (watershed con semillas). Escribe `work/pieces/` y `work/meta.json`. |
| 2 | `extract2.py` | Lo mismo para los cuerpos base (`no_armor`, `zombie`, `skeleton`, `ghost`) y los mobs. |
| 3 | `build_art.py` | Corta el cuerpo en torso, brazos y piernas, exporta los PNG a `assets/art/rig/`, `assets/art/items/` (íconos) y `assets/art/mobs/`, y genera `core/art/armor_art.gd`. |
| - | `preview.py` | Arma figuras de reposo con `armor_art.gd` para revisar el arte (`work/preview_sets.png`). |

## Si cambian las imágenes
- `extract.py` ubica cada hoja por el **comienzo del nombre del archivo** (`SHEETS`) y asume 4 columnas por hoja
  (`BOUNDS`) con filas casco / cuerpo / guantes / botas. Si se reemplaza una hoja, ajustar esos prefijos.
- Las constantes de escala están en `build_art.py` (`G`, `TEXS`, `MOB_SCALE`).
  `data/items/sets/*.tres` si ya se ajustaron a mano: en ese caso no volver a correr el paso 4).
