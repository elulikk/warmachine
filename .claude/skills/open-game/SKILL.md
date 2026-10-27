---
name: open-game
description: Abrir WARMACHINE directamente en un sector, el campamento, la sala de pruebas o la sala de estrés, sin pasar por el menú. Usar cuando el usuario diga "abrime el juego en…", "llevame al sector 1-03", "abrí el campamento", "quiero probar el nivel X" o similar.
---

# Abrir el juego en un lugar

Lanza Godot con la escena pedida, en una ventana aparte que queda abierta. Todo está en `open_game.py`, así que no hace falta armar comandos.

## Cómo se usa

```bash
python -I .claude/skills/open-game/open_game.py <destino>
```

| Pedido del usuario | Destino |
|---|---|
| "el sector 1-03", "nivel 3 del mundo 1" | `1_03` |
| "el mundo 4, sector 2" | `4_02` |
| "el campamento", "la base" | `base` |
| "la sala de pruebas" | `test` |
| "la sala de estrés" | `stress` |
| "el banco de cinemáticas", "probar las cinemáticas" | `cine` |
| "el menú" | `menu` |
| otra escena | `res://ruta/escena.tscn` |

Opciones:
- `--import`: reimporta el arte antes de abrir. Usarla si se agregó arte nuevo (PNG, WebP) desde la última vez; tarda más.
- `--dry-run`: solo muestra qué escena abriría. Útil para comprobar un destino sin abrir la ventana.

## Qué hacer después

- Decirle al usuario en qué escena quedó abierto, con el comando que corriste.
- Si el script avisa que ya hay una ventana de Godot abierta, la nueva se abre igual: decírselo y no cerrar la anterior.
- No cerrar Godot ni tocar los saves: el usuario juega en esa ventana. Para cerrar pruebas automáticas, usar el skill `smoke-test`.

## Límites

- **No entra a una posición dentro del sector** (por ejemplo, a la mitad o cerca de un enemigo). El juego no tiene un argumento para eso. Si el usuario lo pide, hay que agregar un argumento de línea de comandos en el código del juego (`OS.get_cmdline_user_args()`, como hace `core/test_level.gd` con `--test-aura`).
- El script usa la ruta fija `C:\GODOT\Godot_v4.7.2-stable_win64.exe`. Si Godot cambia de versión o de carpeta, actualizar la constante `GODOT` en `open_game.py`.
- Si el sector no existe, el script avisa con el número de mundo buscado. Revisar `levels/chapter_N/`.
