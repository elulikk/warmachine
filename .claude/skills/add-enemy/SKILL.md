---
name: add-enemy
description: Agregar un enemigo nuevo a WARMACHINE (variante de corredor, bruto, centinela o armado a distancia, o con comportamiento propio), con su arte generado en Google Flow, botín, registro en los generadores de niveles y prueba. Usar cuando el usuario pida un enemigo, mob, jefe, élite o variante nueva para un sector o mundo.
---

# Agregar un enemigo

Leer antes `PROJECT_CONTEXT.md` sección 6 (enemigos, oleadas, arenas). Valores de vida, daño y velocidad viven en las escenas `.tscn` y en `data/loot/*.tres`, no en el código.

## Paso 0: decidir el molde

| Quiero… | Molde | Ejemplo en el repo |
|---|---|---|
| Un corredor cuerpo a cuerpo con otros stats/arte | instanciar `basic_runner.tscn` y sobrescribir | `entities/enemies/city_thief.tscn`, `city_rat.tscn` |
| Un bruto con armadura | instanciar `armored_brute.tscn` (`brute_name/health/armor/speed`) | `city_bouncer.tscn`, `city_thug.tscn` |
| Un humano armado que mantiene distancia | instanciar `basic_runner.tscn` + `script = armed_enemy.gd` (`gun`: pistol/shotgun/smg) | `city_gunman.tscn`, `city_hitman_smg.tscn` |
| Un centinela con escudo / torreta | instanciar `shielded_sentinel.tscn` / `sniper_turret.tscn` | — |
| Un jefe | instanciar `brute_boss.tscn` (grupo `boss`, onda de choque, furia al 50 %) | `levels/chapter_4/level_4_10.tscn` |
| Un comportamiento nuevo (vuela, salta, invoca…) | script nuevo que hereda de `basic_runner.gd` **por ruta** | `armed_enemy.gd`, `ghost.gd` |

Empezar siempre por una variante de escena (cero código). Script nuevo solo si el comportamiento no se puede lograr con exports.

## Paso 1: la escena

Crear `entities/enemies/<mundo>_<nombre>.tscn` con `instance=` de la base (ver `city_thief.tscn` como patrón mínimo):

```
[node name="CityThief" instance=ExtResource("1_runner")]
loot_table = ExtResource("2_loot")      # data/loot/*.tres
entity_name = "Ladrón"
move_speed = 110.0
aggro_range = 320.0
art_kind = "thief"                      # clave de ArmorArt.MOBS (paso 2)
contact_damage = 10.0

[node name="CollisionShape2D" parent="." index="0"]      # cápsula del cuerpo, pies en y=0
[node name="HealthComponent" parent="." index="2"]       # max_health
[node name="StatusDisplayComponent" parent="." index="4"] # barra de vida, un poco sobre la cabeza
[node name="CollisionShape2D" parent="Hurtbox" index="0"]
```

Reglas:

- **Las escenas guardan 1x**: `MOB_SCALE = 1.5` (`mob_scale.gd`) se aplica solo al final del `_ready`. La colisión contra el mundo tiene tope de 72 px de alto.
- La vida se escala sola con la dificultad al aparecer (`Settings.enemy_health_mult()`); no la multipliques a mano.
- Los índices de nodo (`index="0"`, `"2"`, `"4"`) son los de la escena base; si cambia la base, revisarlos.

## Paso 2: arte (Google Flow → `MOBS`)

**Primero ver si sirve un `art_kind` existente** (`runner`, `brute`, `sentinel`, `thief`, `thug`, `gunman`, `bouncer`, `hitman_*`, `time_agent`): una variante de stats no necesita arte nuevo. Generar arte solo si el usuario lo pidió o el enemigo es visualmente distinto. En ese caso usar el skill **`google-flow`** (que a su vez usa `asset-browser`). Receta:

1. Prompt: personaje de cuerpo entero, de lado, mirando a la derecha, fondo negro liso, estilo 2D de videojuego, sin sombra de suelo. Una hoja con varios enemigos del mismo mundo mantiene la coherencia.
2. Descargar 1K a `art_source/worldN/` (p. ej. `e_<nombre>.jpg`).
3. Agregarlo a `MOB_SRC` en `art_source/worldN/process.py` (`"<id>": ("<hoja>", <alto_en_juego_px>)`) y correr `python art_source/worldN/process.py`: recorta el fondo, voltea, escala a **3x** del alto en juego y escribe `assets/art/worldN/mob_<id>.png`. **Imprime la línea `MOBS`**.
4. Pegar esa línea en `MOBS` de `core/art/armor_art.gd` (`size` = textura / 3, `foot` = punto de apoyo).
5. Agregar `"<id>"` a `MOB_SPLIT` en `entities/enemies/enemy_art.gd`: `waist` (altura de la cintura, 0.60 corredor / 0.63 bruto), `overlap` 9, `scale`, `attack` (duración de la embestida), `lunge` (px), `lean` (rad), `step`. Copiar el de un enemigo parecido.
6. `Godot --headless --path . --import` una vez.

Si Flow no está disponible: reusar el `art_kind` de otro enemigo (`runner`, `brute`, `sentinel`, `thief`…) y dejar anotado en el ROADMAP "arte pendiente". No inventar sprites.

## Paso 3: botín

- Reusar una tabla de `data/loot/` (`city_loot`, `city_elite_loot`, `armored_brute_loot`…) o crear una `.tres` de `LootTable` con `LootEntry` (`COIN`, `AMMO`, `HEALTH`, `CRYSTAL`). `DROP_AMOUNT_MULT` = 0.5 ya se aplica.
- Equipo: `gear_chance` / `gear_pool` / `early_gear_pool` dependen de `LevelBase.gear_loot_tier` del nivel.

## Paso 4: comportamiento nuevo (solo si hace falta)

```gdscript
extends "res://entities/enemies/basic_runner.gd"
```

- **Cargar por ruta**, no por `class_name`; sin `class_name` si otro archivo lo referencia por tipo (`run.bat` no regenera la caché de clases).
- Respetar la **capa de invisibilidad**: `if target_player.is_invisible: is_aggroed = false` (como `armed_enemy.gd`). Todo script de IA nuevo y el `TargetScannerComponent` ya lo leen.
- Daño siempre por `HitPayload` → `HealthComponent`; proyectiles hostiles por el pool, no `Projectile.new()`.
- Sin `print()` por enemigo.
- En scripts que `EnemyBase` carga (GameFeel, MusicDirector) no usar `is TuClase`: `get_global_name()` o grupos.
- Si muere dejando algo (invocaciones, charcos), pasar por `DeathFxQueue` (`GameFeel.death_burst`), no crearlo directo.

## Paso 5: registrarlo en los niveles

- Generadores: en `art_source/worldN/build_levels.py` agregar la clave al diccionario `RES` (`"<clave>": ("PackedScene", "res://entities/enemies/<escena>.tscn")`) y usarla con `L.enemies("<clave>", [x...])` o en `L.arena(x, "<clave>", [rondas], elite, [n_elite], título)`. Regenerar con `python art_source/worldN/build_levels.py`. Ver skill `add-level`.
- Capítulo 4: se edita el `.tscn` a mano (instancia + `position`).
- Los que bloquean la salida llevan `groups=["arena_enemies"]` (`guard=True` en el generador).
- Opcional: sumarlo a `scenes/hub/stress_room.gd` (`TYPE_NAMES`, `_scene_for`) y a `core/test_level.gd` para probarlo en masa.

## Reglas de diseño (preferencias del usuario)

- **Ciclo de progresión:** primero crece la cantidad de un tipo (`round_sizes`) y solo cuando ya son muchos entra uno nuevo, **de a uno por sector y en cantidad baja**. Después el ciclo se repite.
- **Nunca aparecen de la nada:** en arenas `ArenaEncounter` activa `WaveManager.spawn_offscreen`; nacen fuera de cámara y se acercan. Las paredes de arena están en la capa 6 (valor 32): los enemigos no la tienen en la máscara y la atraviesan. No cambiar la máscara de colisión del enemigo.
- Tipos nuevos: dejar los stats "mínimamente coherentes" y listarlos en el ROADMAP como "sin validar"; el usuario los afina jugando.

## Paso 6: verificar

1. `bash .claude/skills/smoke-test/scripts/smoke.sh res://levels/chapter_N/level_N_NN.tscn 120` con el enemigo colocado en el sector.
2. Para matar por código: vida justa (`current_health + 1.0`), nunca 99999.
3. Reportar qué quedó sin validar (balance, arte). No hacer commit ni tocar el ROADMAP salvo que se pida, y entonces una sola vez por tanda.
