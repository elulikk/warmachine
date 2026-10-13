---
name: add-level
description: Agregar o rehacer un sector (nivel) de WARMACHINE con el generador de niveles del mundo (art_source/worldN/build_levels.py), incluyendo geometría, enemigos, arenas, checkpoints, armas del sector, vestido (LevelSkin), decoración, música, registro y prueba. Usar cuando el usuario pida un nivel, sector o capítulo nuevo, o cambios de estructura en uno existente.
---

# Agregar un sector

Leer `PROJECT_CONTEXT.md` secciones 6 y 10. Los niveles de los mundos 2, 3 y 4 **no se editan a mano**: los genera `art_source/world{2,3,4}/build_levels.py` (clase `Level`). El capítulo 1 sí son `.tscn` a mano. El capítulo 5 son 10 esqueletos vacíos (`levels/chapter_5/`): para armarlo, copiar el generador del mundo 4.

## Paso 0: tema y diseño

- Leer la descripción del sector en `PROJECT_CONTEXT.md` / `ROADMAP.md` / `story.md`. Si no tiene temática clara, **preguntar** antes de generar.
- Elegir qué se introduce: un arma (pedestal), un enemigo nuevo (de a uno por sector, ver `add-enemy`), una mecánica (pozos, plataformas, cinemática).
- Largo típico: 6400 a 9000 px. Estructura típica: tutorial/rampa → checkpoint → arena → checkpoint → guardias → salida.

## Paso 1: editar el generador

En `art_source/worldN/build_levels.py` agregar una función `level_K()` (o editar la existente) y sumarla a la tupla `for fn in (level_1, …)` del `if __name__ == "__main__":` del final. `cine()` y `box()` solo existen en el mundo 4; los mundos 2 y 3 comparten el resto de la API (mirar el archivo del mundo antes de usar un método). API de `Level`:

| Método | Qué hace |
|---|---|
| `Level(num, "Nombre", largo, backdrop="")` | crea el sector (`backdrop` = `backdrop_file` que pisa el fondo del capítulo) |
| `L.bedrock(); L.walls()` | lecho de roca (omitirlo = pozos reales: agua en el 4, lava en el 3) y paredes laterales |
| `L.floor(x0, x1)` | tramo de suelo; los huecos entre tramos son pozos |
| `L.block(x, w, h)` / `L.plat(x, y, w)` | bloque macizo en el suelo / plataforma delgada (`y` = cara superior) |
| `L.weapon(x, "w_clave", "texto")` | pedestal con arma (la clave va en `RES`) |
| `L.enemies("clave", [x...], guard=False)` | enemigos sueltos (`guard=True`: grupo `arena_enemies`, bloquean la salida) |
| `L.arena(x, "clave", [rondas], elite, [n_elite], "TÍTULO")` | arena de oleadas centrada en `x` |
| `L.checkpoint(x)` | terminal de puesto de control (id `checkpoint_N_NN_a/b/…`) |
| `L.label(x, y, texto)` / `L.title(...)` | carteles |
| `L.cine(id, x, zone=…, after_arena=…)` | disparador de cinemática (mundo 4) |
| `L.guaranteed = ["res://data/weapons/….tres"]` | arma garantizada una sola vez por personaje |
| `L.music`, `L.event` | pista base y evento de Agentes (mundo 4) |
| `L.gate_reward = "Nombre"` | texto del arma que entrega la salida |
| `L.arena(x, "runner", [2], "boss", [1])` | arena de jefe (mundo 3: `boss` = `brute_boss`) |
| `L.write(next_of(K))` | escribe el `.tscn` (siempre LF) |

Constantes: **suelo en y=556** (cara superior), **enemigos en y=555**, **armas sobre pedestal en y=512**, spawn del jugador en `(160, 545)`. La salida (`ExitGate`) queda a `largo - 250`.

Reglas de diseño:

- **Arenas:** el suelo debe ser **continuo en `[x-540, x+540]`** (barreras a ±530). Los enemigos nacen fuera de cámara (`spawn_offscreen`) y caminan hacia el jugador; no los hagas aparecer en pantalla.
- **Progresión de oleadas:** crecer las cantidades del tipo actual antes de sumar un enemigo nuevo; uno nuevo por sector y poca cantidad. La tabla vigente de cantidades del mundo 1 está en el ROADMAP (sección 2.2e).
- **Pozos:** quien cae vuelve al último checkpoint (el mundo 3 además daña con lava). Poner una plataforma de aterrizaje cerca (`L.plat`) para que el salto sea justo.
- Sin `print()` ni nodos por enemigo extra.

Regenerar y revisar el `git diff` del `.tscn` (los otros sectores del mismo script se reescriben iguales; si cambian sin querer, algo tocó una función compartida):

```bash
python art_source/worldN/build_levels.py
```

## Paso 2: registrarlo

- `core/managers/level_registry.gd`: agregar la ruta a `IMPLEMENTED_LEVELS`; si el capítulo no tiene 10 sectores, `LEVEL_COUNTS`; `CHAPTER_EXIT` para el último sector (hoy todos vuelven a la Caja `HUB_PATH`); nombres de sectores en `JANO_SECTOR_NAMES` (capítulo 4).
- Encadenado: `next_level_path` lo pone `next_of(K)` del generador.
- Mundo nuevo: entrada nueva en `CHAPTER_NAMES` / `CHAPTER_COLORS` y en `LevelSkin.CHAPTER_THEMES`.

## Paso 3: vestido, decoración, música

- **Texturas y fondo:** `levels/level_skin.gd` → `CHAPTER_THEMES[N]["sectors"]["N_NN"]` pisa `edge`, `ground`, `stone`, `platform`, tonos y `backdrop`. Sin colisiones.
- **Fondo con paralaje:** usar el skill **`parallax-level-background`** (usa `google-flow` con Claude in Chrome en el Edge del usuario).
- **Decoración:** `levels/city_decor.gd` (`SECTORS`), `meadow_decor.gd`, `hell_decor.gd`; un mundo nuevo = un `*_decor.gd` nuevo registrado en el tema.
- **Música:** `base_music = &"nombre"` (pista `ost/<nombre>.ogg` agregada a `Music.TRACKS`; si falta, suena la de exploración y se anota en el ROADMAP).
- **Props nuevos o arte propio del sector:** `google-flow` → `art_source/worldN/` → `process.py` → `assets/art/worldN/`, `Godot --headless --path . --import`, y cargar con `Art.tex()`.

## Paso 4: verificar

1. `bash .claude/skills/smoke-test/scripts/smoke.sh res://levels/chapter_N/level_N_NN.tscn 150` (respalda y restaura saves).
2. Mirar un cuadro con `--write-movie` (ver `smoke-test`): que el suelo, las arenas y el fondo se lean.
3. Si hay pozos: confirmar a ojo el salto; no se puede validar sin jugar.
4. Reportar qué no se validó (balance, recorrido completo, jefe). Anotar el sector en la lista "hecho, sin verificar" del ROADMAP **una sola vez por tanda**. Sin commit salvo que se pida.

## Trampas

- No editar a mano un `.tscn` generado: el siguiente `build_levels.py` lo pisa.
- Un script nuevo (decoración, trigger) se carga por `preload`, no por `class_name`.
- `LevelBase.gear_loot_tier` fija qué equipo cae en el sector (0 = nada).
- Cambios de escena siempre con `GameManager.change_scene()`.
- El sector 4-9/4-10 y el capítulo 5 son esqueletos: `is_implemented()` los marca pendientes en el selector hasta registrarlos.
