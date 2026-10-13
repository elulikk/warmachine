---
name: smoke-test
description: Verificar que WARMACHINE compila y arranca una escena sin errores de script, sin romper los guardados del usuario. Lanza la escena con --quit-after, respalda y restaura saves y settings, filtra SCRIPT ERROR / ERROR y avisa de procesos colgados. Usar antes de dar por terminado cualquier cambio de código, escena, nivel, enemigo o ítem, o cuando el usuario diga "probalo", "revisá que compile" o "revisá el log".
---

# Chequeo de compilación en runtime

El proyecto **no tiene tests** (regla del `PROJECT_CONTEXT.md`: no se escriben `test_*.gd`). La única verificación automática es lanzar una escena real unos cuadros y leer los errores. La jugabilidad la valida el usuario con `run.bat`.

## Uso rápido

```bash
bash .claude/skills/smoke-test/scripts/smoke.sh <escena> [cuadros=90] [timeout_s=100]
```

Ejemplos:

```bash
bash .claude/skills/smoke-test/scripts/smoke.sh res://levels/chapter_4/level_4_02.tscn
bash .claude/skills/smoke-test/scripts/smoke.sh res://scenes/hub/base_camp.tscn 120
bash .claude/skills/smoke-test/scripts/smoke.sh res://core/test_level.tscn
```

El script, en este orden:

1. **Respalda** `saves/` y `settings.cfg` en una carpeta temporal **nueva** (nunca reutiliza un respaldo viejo: el usuario juega entre medio y se le pisaría el progreso).
2. Corre Godot con `timeout` (`C:\GODOT\Godot_v4.7.2-stable_win64_console.exe --path . <escena> --quit-after N`).
3. **Restaura** saves y settings, pase lo que pase (trap).
4. Imprime solo `SCRIPT ERROR`, `ERROR:`, `Parse Error`, `Could not resolve class` (sin el ruido conocido) y termina con `RESULTADO: OK` o `RESULTADO: FALLÓ`.
5. Avisa si quedó algún Godot abierto.

Qué escena elegir:

| Cambiaste… | Lanzá… |
|---|---|
| Un sector o un enemigo de campaña | el `.tscn` del sector (`levels/chapter_N/level_N_NN.tscn`) |
| Un ítem, arma, consumible o UI | `res://scenes/hub/base_camp.tscn` o `res://core/test_level.tscn` |
| Rendimiento, FX masivos | `res://scenes/hub/stress_room.tscn` (ver skill `perf-benchmark`) |
| Algo del jugador o `GameManager` | cualquier nivel + el campamento |

## Ver el resultado (cuadros)

```bash
"/c/GODOT/Godot_v4.7.2-stable_win64_console.exe" --path . <escena> --write-movie "<scratchpad>/f.png" --fixed-fps 30 --quit-after 150
```

Mirar un cuadro (p. ej. `f00000120.png`) con Read. Respaldar los saves antes, igual que arriba.

## Probar lógica o UI (escena descartable)

`--script` **no sirve**: los autoloads (`MetricsManager`, etc.) no compilan ahí. Hacer así:

1. Crear `_x.tscn` (nodo `Node` con `_x.gd`) en la **raíz** del proyecto; `_x.gd` instancia la escena real (p. ej. `base_camp.tscn`), espera ~1 s y ejecuta la prueba.
2. Imprimir con prefijo `XT` y filtrar con `grep XT` sobre el log de la corrida.
3. Correr: `smoke.sh res://_x.tscn 200`.
4. **Borrar `_x.tscn`, `_x.gd` y sus `.uid` al terminar.**

Trucos de input real:

- Cursor: `get_viewport().warp_mouse(pos)`. Un `InputEventMouseMotion` sintético NO actualiza `get_mouse_position()`.
- Clic: `Input.parse_input_event(InputEventMouseButton)` con posición `get_window().get_final_transform() * pos`. Llega a `_unhandled_input` y a `Input.is_action_pressed`; sirve para el clic derecho (mano 2).
- Esperar ~0.2 s tras soltar antes de mirar (animaciones del ítem en mano).
- Captura: `get_viewport().get_texture().get_image().save_png(<scratchpad>/x.png)` y leerla.

## Trampas conocidas

- **Matar por código con la vida justa:** `health_component.apply_damage(current_health + 1.0, ...)`. Un daño de 99999 infla los FX de sangre y la escena crece a ~17 GB de RAM. Siempre `timeout`.
- **`class_name` nuevo no se registra con `run.bat`:** cargar scripts nuevos con `const X = preload("res://...")`. Si el log dice "Could not resolve class" o "Identifier not declared", empezar por acá.
- **Ciclos de clase:** en scripts que `EnemyBase`/`Player` cargan (GameFeel, MusicDirector, UI global) no usar `is ClaseHija`; comparar `get_global_name()` o grupos.
- **Enums con nombre de clase global** (`State`, etc.) rompen el parseo en cascada. Buscar `class_name <Nombre>` antes.
- `--check-only --script` da falsos positivos con autoloads: no usarlo salvo en scripts sin dependencias.
- "2 resources still in use at exit" al salir de un nivel es previo (cachés estáticos de `Sfx`): no es un error nuevo.
- Assets nuevos (webp/png/jpg) necesitan importarse una vez: `Godot --headless --path . --import`. En runtime cargarlos con `Art.tex(path)`.
- **Los logs rotan:** cada lanzamiento pisa `logs/godot.log` (Godot guarda 5). Si el usuario pidió "revisá el log", leelo **antes** de correr nada. Ubicación: `C:\Users\Usuario\AppData\Roaming\Godot\app_userdata\WARMACHINE\logs\godot.log`; el run anterior es `godot<fecha>T<hora>.log`.

## Al terminar

- Reportar fielmente: errores con su línea, o "compila sin errores nuevos". Decir qué escena se probó y que la jugabilidad no se validó.
- No hacer commit ni tocar el ROADMAP por esto.
