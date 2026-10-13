---
name: perf-benchmark
description: Medir rendimiento (FPS, tiempo por cuadro) de WARMACHINE en la Sala de Estrés sin engañarse con vsync ni con corridas atípicas, y encontrar el cuello de botella por bisección con variables de entorno. Usar cuando el usuario reporte caídas de FPS, lag con muchos enemigos, FX o lluvia, o pida optimizar o comparar el costo de una pieza.
---

# Benchmark de rendimiento

Leer `PROJECT_CONTEXT.md` secciones 15 y 16 (`perf_monitor.gd`, Sala de Estrés). Técnicas ya aplicadas: botín fundido, objetos quietos sin física, cola de muertes, tope de números de daño.

## Reglas para no engañarse

1. **Vsync apagado y `Engine.max_fps = 0`**: con vsync todo da 60 fps y no se ve el margen real.
2. **Un proceso por combinación.** Reinstanciar la sala en el mismo proceso rompe el pool de proyectiles (retiene al jugador liberado).
3. **Repetir 2-3 veces.** Hay corridas atípicas (una variante dio 59 fps y no se repitió).
4. **No adivinar el cuello de botella: apagar una pieza por vez y medir.** La hipótesis "charcos × enemigos" estaba mal; el costo eran los `draw_circle` de las gotas.
5. Sin cambios de código entre corridas que no sean el interruptor que se mide.
6. Respaldar los saves (el script `smoke.sh` lo hace; la Sala de Estrés no guarda, pero el campamento sí).

## Procedimiento

1. Copiar `.claude/skills/perf-benchmark/templates/bench.gd` a la raíz como `_x.gd` y crear `_x.tscn` (un `Node` con ese script). Es descartable: borrar los dos y sus `.uid` al terminar.
2. Elegir qué se mide con variables de entorno (una por proceso):

   | Variable | Qué hace | Por defecto |
   |---|---|---|
   | `BENCH_TYPE` | tipo de enemigo (0 corredor, 1 zombi, 2 fantasma, 3 bruto, 4 centinela, 5 mezcla) | 5 |
   | `BENCH_CAP` | enemigos vivos a la vez | 100 |
   | `BENCH_RATE` | aparecen por segundo | 20 |
   | `BENCH_FIRE` | disparos por segundo del jugador (fuego automático) | 15 |
   | `BENCH_SECONDS` | duración de la medición (tras 2 s de calentamiento) | 10 |

3. Correr un proceso por combinación (cada línea `XT` imprime FPS promedio, mínimo y p1):

```bash
for cap in 50 100 200; do
  for run in 1 2 3; do
    BENCH_CAP=$cap "/c/GODOT/Godot_v4.7.2-stable_win64_console.exe" --path . res://_x.tscn --quit-after 100000 2>&1 | grep "^XT"
  done
done
```

El script se cierra solo con `get_tree().quit()` al terminar los segundos; `--quit-after` grande es solo un tope. Usar `timeout 120` delante si se prefiere.

## Bisección con variables de entorno

Para encontrar qué pieza cuesta: en el código sospechoso, agregar **temporalmente** un interruptor y medir con y sin él.

```gdscript
if OS.has_environment("BENCH_NO_DROPLETS"):
	return
```

Apagar de a una pieza (gotas, charcos, sangre, números de daño, partículas, IA, física) y comparar el FPS. La que más sube al apagarse es el cuello.

**Al terminar, sacar todos los interruptores:** `grep -rn has_environment --include=*.gd .` (excluyendo `_x.gd`, que se borra) no debe devolver nada.

## Después de medir

- Comparar con una referencia: la misma combinación antes y después del cambio, en el mismo equipo y con el mismo número de corridas.
- Para FPS en una partida real: **F9** abre `perf_monitor.gd` en cualquier escena (CSV y TXT en `user://logs/rendimiento/`).
- Optimizaciones frecuentes en este proyecto: `draw_*` por gota/partícula → agrupar en un solo `_draw` o usar `MultiMesh`/`CPUParticles2D`; evitar `queue_redraw()` por objeto cada cuadro; objetos quietos sin física (`set_physics_process(false)`); repartir trabajo con presupuesto por cuadro (`DeathFxQueue`); topes de FX (`effect_cap.gd`); LOD de enemigos lejanos (`set_enemy_lod`).
- Los `.gd` del proyecto pueden ser CRLF: parchear con un script Python que normalice saltos (`newline=''`), no con heredocs con tildes. Para ediciones grandes, crear el `.py` con la herramienta Write y correrlo.

## Reportar

Tabla corta: combinación, FPS promedio / mínimo (2-3 corridas), hipótesis y qué cambió al apagar la pieza. Aclarar que se midió con vsync apagado y que la validación en máquina real la hace el usuario con F9.
