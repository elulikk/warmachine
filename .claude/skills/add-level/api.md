# Generador de niveles: API y reglas

Se lee antes de editar `build_levels.py` (Paso 1 de `SKILL.md`).

En `art_source/worldN/build_levels.py` agregar una función `level_K()` (o editar la existente) y sumarla a la tupla `for fn in (level_1, …)` del `if __name__ == "__main__":` del final. `cine()` y `box()` solo existen en el mundo 1; los mundos 2 y 3 comparten el resto de la API (mirar el archivo del mundo antes de usar un método). API de `Level`:

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
| `L.cine(id, x, zone=…, after_arena=…)` | disparador de cinemática (mundo 1) |
| `L.guaranteed = ["res://data/weapons/….tres"]` | arma garantizada una sola vez por personaje |
| `L.music`, `L.event` | pista base y evento de Agentes (mundo 1) |
| `L.gate_reward = "Nombre"` | texto del arma que entrega la salida |
| `L.arena(x, "runner", [2], "boss", [1])` | arena de jefe (mundo 3: `boss` = `brute_boss`) |
| `L.write(next_of(K))` | escribe el `.tscn` (siempre LF) |

Constantes: **suelo en y=556** (cara superior), **enemigos en y=555**, **armas sobre pedestal en y=512**, spawn del jugador en `(160, 545)`. La salida (`ExitGate`) queda a `largo - 250`.

Reglas de diseño:

- **Arenas:** el suelo debe ser **continuo en `[x-540, x+540]`** (barreras a ±530). Los enemigos nacen fuera de cámara (`spawn_offscreen`) y caminan hacia el jugador; no los hagas aparecer en pantalla.
- **Progresión de oleadas:** crecer las cantidades del tipo actual antes de sumar un enemigo nuevo; uno nuevo por sector y poca cantidad. La tabla vigente de cantidades del mundo 4 está en el ROADMAP (sección 2.2e).
- **Pozos:** quien cae vuelve al último checkpoint (el mundo 3 además daña con lava). Poner una plataforma de aterrizaje cerca (`L.plat`) para que el salto sea justo.
- Sin `print()` ni nodos por enemigo extra.

Regenerar y revisar el `git diff` del `.tscn` (los otros sectores del mismo script se reescriben iguales; si cambian sin querer, algo tocó una función compartida):

```bash
python art_source/worldN/build_levels.py
```
