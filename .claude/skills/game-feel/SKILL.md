---
name: game-feel
description: Ajustar o agregar "game feel" (jugo) en WARMACHINE — peso de impactos, screen shake, hit stop, retroceso y animación del arma, sonidos, FX de disparo/muerte/daño, feedback de vida baja y telegrafiado de enemigos — respetando las opciones de accesibilidad y los topes de rendimiento. Usar cuando el usuario diga que algo "se siente flojo", "no tiene peso", "falta feedback", "pegá más fuerte", "más jugo", o pida mejorar la sensación de un arma, golpe, habilidad, enemigo o evento.
---

# Game feel

Leer `PROJECT_CONTEXT.md` secciones 4, 5, 14 y 15. La sensación **se ajusta jugando**: el usuario la valida con `run.bat`. Tu trabajo es dejar valores razonables, en constantes fáciles de tocar, y decirle exactamente cuáles mover.

## Paso 0: diagnosticar qué falta

Preguntarse (sin preguntarle al usuario si se puede deducir) qué canal del golpe está débil. Un impacto con peso suele tener **todos** estos; lo que falta es el que "se siente plano":

| Canal | Qué lo da | Dónde vive |
|---|---|---|
| **Cámara** | shake | `GameFeel.shake(ctx, fuerza, duración)` |
| **Tiempo** | hit stop | `GameFeel.hit_stop(ctx, duración)` |
| **Arma** | retroceso, subida del cañón, fogonazo, casquillos | `WeaponMotion` (`kick`), `ShotFx`, `WeaponData.recoil_force` |
| **Blanco** | parpadeo, retroceso, sangre/chispas, sangrado, trozos | `_play_hit_flash()` de cada enemigo, `DamageFx`, `BloodFx`, `HitPayload.knockback_force` |
| **Número** | color, tamaño, crítico "!" | `DamageNumber` |
| **Sonido** | golpe, impacto, muerte, ambiente | `Sfx` (`GameFeel.sfx`) |
| **Pantalla** | viñeta, borde rojo, destello | `PostFx`, `LowHealthFeedback` |
| **Aviso** | telegrafiado antes de un ataque o aparición | `SpawnTelegraph`, franja de la onda del jefe |

## API y constantes que ya existen

Todo entra por `GameFeel` (`core/game_feel.gd`, estático, recibe un nodo de contexto dentro del árbol):

| Llamada | Qué hace | Valores actuales |
|---|---|---|
| `GameFeel.shake(ctx, strength, duration=0.18)` | sacude la cámara (`CameraFollow.shake`); se conserva la más fuerte en curso; ya multiplica por la opción `screen_shake` | crítico 4.0/0.15 · golpe fuerte (≥ 40) 3.0/0.12 · melee que conecta 3.0/0.12 · muerte de enemigo 2.5/0.12 · tiro pesado `clamp(recoil/30, 2, 6)`/0.14 · martillo 9.0/0.3 · jefe 6–8/0.25–0.4 |
| `GameFeel.hit_stop(ctx, duration=0.03)` | `Engine.time_scale = 0.05` con timer que ignora la escala; respeta la opción `hit_stop`; cooldown 90 ms; no corre en pausa | crítico, melee que conecta (0.03), martillo 0.07 |
| `GameFeel.on_player_hit(ctx, is_crit, dmg)` | crítico → hit stop + shake; `dmg ≥ STRONG_HIT_DAMAGE (40)` → shake; lo llama `HealthComponent` si el origen es el `Player` | — |
| `GameFeel.on_weapon_fired(ctx, recoil)` | shake solo si `recoil ≥ HEAVY_RECOIL_THRESHOLD (90)` | — |
| `GameFeel.sfx(ctx, &"nombre", pos?, vol_db?, pitch?)` | sonido sintetizado por nombre; con `pos` se atenúa por distancia (pleno hasta 420 px, silencio a 1400) | — |
| `DeathFxQueue.burst/gore/loot/exp_orb(ctx, …)` | efectos de muerte con presupuesto por cuadro (2.5 ms) | — |
| `GameFeel.death_burst(ctx, pos, mechanical)` | muerte (vía `DeathFxQueue.burst`, no directo): mecánico = 18 chispas + 5 de destello + `enemy_death`; carne = solo `enemy_death_flesh` | — |
| `Settings.get_float("screen_shake")`, `get_bool("hit_stop")`, `reduce_flashes()`, `particle_scale()`, `get_bool("damage_numbers")` | opciones de accesibilidad y calidad | — |

Retroceso y animación del arma: `core/art/weapon_motion.gd` por id de arma.

- `kick = {back, climb_deg, time, body}`: cuánto se echa atrás el arma (px), cuánto sube el cañón (°), duración (s) y cuánto reacciona el cuerpo (multiplicador).
- `PATTERNS` / `SUSTAINED_CLIMB` en `weapon_manager.gd`: subida acumulada de las automáticas (`climb_step`, `max_climb`, `sway`, `recover`).
- `hold`, `swings` (melee), `impact` (martillo): ver cabecera del archivo.
- Retroceso físico del jugador: `WeaponData.recoil_force`; empuje al blanco: `knockback_force`.

## Recetas

### "El arma no tiene peso"
1. Subir `kick.back` y `kick.climb_deg` en su perfil de `weapon_motion.gd`; `time` más corto = más seco.
2. Subir `recoil_force` del `.tres` por encima de 90 si debe sacudir la cámara (escopeta, francotirador, pesada).
3. Revisar el sonido: `family` decide `shot_*` (`Sfx.weapon_fire_profile`). Si falta carácter, `fire_stream` real o una receta nueva en `Sfx._build()`.
4. `knockback_force` mayor para que el blanco reaccione.

### "El golpe melee no se siente"
- `swings` con `length`/`hit_delay` ajustados y `body` (lean, x) para que el cuerpo acompañe; un impacto de 3 cuadros de anticipación y golpe corto vende más que uno largo.
- El hit stop y el shake ya se disparan en `MeleeHitbox` al conectar: no duplicarlos. Para armas pesadas, usar `impact` + onda y subir `hit_stop` a 0.05–0.07.

### "El enemigo no reacciona"
- `_play_hit_flash()` ya existe en cada enemigo: ajustar color/duración ahí, no crear otro sistema.
- `DamageFx` (`combat/damage_fx.gd`) hace sangre/chispas (mecánicos: `MECHANICAL_SCRIPTS`), trozos a 2/3 y 1/3 y **sangrado**: un `CPUParticles2D` por enemigo herido (cuadraditos rojos repartidos por el cuerpo) desde `BLEED_START` (0.8 de vida), con más cantidad y tamaño al bajar la vida (`_update_bleed`: 1.5–6 px → 6–11 px). Se apaga lejos de cámara y con `particle_scale() < 0.5`. Usa un cuadrado blanco de 4 px: sin textura la escala no se respeta.
- Salpicaduras (`blood_fx.gd`, `spray` / `spray_sprite`): sprite de salpicadura **chico**, gotas que salen volando **grandes** (4–8 px), pedido del usuario. Las "marcas pintadas" en el cuerpo se descartaron (se veían enormes).
- Muerte: la carne hace un golpe sordo (`enemy_death_flesh`) sin chispas; solo las máquinas conservan estallido (`GameFeel.death_burst(ctx, pos, mechanical)`; `health_component.gd` decide por `MECHANICAL_SCRIPTS` o el grupo `mechanical`). Un enemigo mecánico nuevo debe entrar a esa lista o grupo.
- Fuego: una llamita por stack sobre el cuerpo, hasta 6 (`StatusReceiverComponent`: `MAX_VISIBLE_FLAMES`, `FLAME_SLOTS`); el cartel "xN" quedó oculto. Hielo conserva su cartel.
- Retroceso por `HitPayload.knockback_force`; los enemigos con `knockback_immune` o jefes no se mueven (esperado).

### "Quiero un efecto nuevo" (explosión, habilidad, aura)
1. Pasarlo por el patrón del repo: **procedural** (polígonos, `CPUParticles2D`, `draw_*`), compatible con `gl_compatibility`; texturas por `Art.tex()`.
2. Escalar la cantidad con `Settings.particle_scale()`; el destello blanco se omite con `Settings.reduce_flashes()`.
3. Si se crea muchas veces por segundo: **reserva de nodos** (`ShotFx._take/_recycle`, `POOL_MAX`), no `instantiate()` y `queue_free()` cada vez.
4. Si persiste (charcos, nubes, redes): registrarlo en `EffectCap.register(key, node, max_alive)` con un método `expire()` (hoy hay topes para `fuel_pool`, `gas_cloud` y `root_net`; se carga por `preload("res://core/effect_cap.gd")`).
5. Si nace de una muerte: pasarlo por `DeathFxQueue`.
6. Sin `print()` por impacto.

### "Falta feedback del jugador"
- Daño recibido: `Player.take_damage` ya hace `hurt` + parpadeo + número rojo (tamaño 26) + shake 3.0 (`DamageNumber.PLAYER_HIT_*`). Ajustar constantes, no sumar otra capa.
- Vida baja: `LowHealthFeedback` (borde rojo desde 60 % de vida, latido bajo 30 % con escudo vacío; sin pulso con `reduce_flashes`).
- Habilidades equipadas (láser, capa): sonido propio (`laser_beam`, `cloak_on/off`) y tinte; cualquier cambio de estado visible para el jugador debe tener sonido **y** una señal en pantalla.

### "Un sonido nuevo"
- Agregar un caso en `Sfx._build()` (`return _render(duración, [capas…], …)` con `_n` ruido filtrado, `_s` senoidal con caída de tono, `_l`/`_arp` sintetizados). Pedirlo con `GameFeel.sfx`.
- Si suena en ráfaga, darle una separación mínima en `MIN_INTERVAL_MSEC` (hoy 35 ms por defecto; el láser 80, la muerte de enemigo 60, el latido 200).
- Si es de uso común al cargar el nivel, sumarlo a `PREWARM_SOUNDS` (se generan de a uno por cuadro, evita el tirón del primer disparo).
- Audio real (grabado o generado en ElevenLabs) en vez del sintetizado: skill **`generate-audio`** (parte B), solo si el usuario lo pide. Para "más grave / más corto / más seco" alcanza con tocar la receta en `_build()`: sin navegador ni créditos.

### "Telegrafiar un ataque o aparición"
- Aparición: `SpawnTelegraph.play(container, pos, duración)` (anillo que se cierra + portal); en arenas los enemigos nacen fuera de cámara (ver `arena-enemies-spawn-offscreen`).
- Ataque fuerte (jefe): franja roja visible y con tiempo de reacción **antes** del daño; el shake llega en el golpe, no en el aviso.

## Principios (y tus límites)

- **Primero feedback, después números:** que el golpe se *vea y suene* antes de subir daño.
- **Proporcional al evento:** un disparo de pistola no sacude; una escopeta sí; un crítico es el más notable de los chicos. Jerarquía: tiro común < crítico < golpe pesado < muerte de jefe.
- **Nada que dure de más:** shakes ≤ 0.4 s, hit stop ≤ 0.07 s (con 0.05 de escala de tiempo); el combate masivo no debe sentirse a cámara lenta ni marear.
- **Accesibilidad no negociable:** todo shake pasa por `GameFeel.shake` (respeta `screen_shake`), todo hit stop por `GameFeel.hit_stop` (respeta `hit_stop`), todo destello por `reduce_flashes()`, todo conteo de partículas por `particle_scale()`. No llamar a `camera.offset` ni tocar `Engine.time_scale` directo.
- **Presupuesto:** los FX se miden en la Sala de Estrés. Topes existentes: números de daño 40 vivos, 40 nodos por pool de `ShotFx`, 2.5 ms por cuadro de `DeathFxQueue`, `EffectCap` por tipo. Un efecto nuevo que se crea por disparo o por muerte se prueba con 100+ enemigos y fuego automático (`perf-benchmark`).
- **Tamaño del jugador:** está al 2x (`Visuals.scale = 2`); los offsets de FX (`Vector2(0, -32)`, `BAR_OFFSET`) dependen de eso.
- **Sin `class_name` nuevos** en los scripts de FX (se cargan por `preload`; ver `smoke-test`).

## Verificar

1. Compilación: `bash .claude/skills/smoke-test/scripts/smoke.sh res://core/test_level.tscn 120` (el Banco de Pruebas tiene dummies, torretas y pedestales).
2. Ver el efecto: `--write-movie <scratchpad>/f.png --fixed-fps 30 --quit-after 150` y mirar cuadros del momento del impacto (la captura estática no muestra shake ni hit stop: describir qué se espera ver).
3. Costo: solo si el efecto se crea por disparo, por impacto o por muerte, o persiste en el mundo: Sala de Estrés con `perf-benchmark` (`BENCH_FIRE` alto). Un ajuste de constantes (shake, kick, hit stop) no necesita benchmark.
4. Entregar la lista de **perillas**: archivo + constante + valor actual + qué hace subirla, para que el usuario afine jugando. Anotar en el ROADMAP, una sola vez por tanda, "game feel de X: sin validar". No commit salvo que se pida.

## Trampas

- **Hit stop acumulado:** varios golpes simultáneos (escopeta con perdigones, explosión) llaman a `hit_stop` muchas veces; el cooldown de 90 ms y `_hit_stop_active` lo protegen. Si agregás un hit stop nuevo, usá `GameFeel.hit_stop`, no un timer propio.
- **Shake aditivo:** `CameraFollow.shake` mantiene el más fuerte, no suma; llamar con mayor fuerza para pisar uno en curso.
- **Matar por código con la vida justa** al probar muertes (un daño de 99999 infla los FX de sangre y la escena crece a ~17 GB).
- **Sonido en cada cuadro:** un `GameFeel.sfx` en `_physics_process` sin `MIN_INTERVAL_MSEC` satura las 20 voces.
- Un efecto "bonito" que cuesta 3 ms por muerte es peor que ninguno: medir antes de entregar.
