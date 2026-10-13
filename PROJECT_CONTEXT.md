# PROJECT_CONTEXT — Mapa técnico de WARMACHINE

Shooter-RPG de plataformas 2D en Godot 4.7 (`gl_compatibility`), GDScript tipado. Este archivo es un **índice**: ubicá tu tarea en la tabla de la sección 2 y leé **solo** esa sección. Los valores de armas, enemigos e ítems no se repiten acá: viven en los `.tres` de `data/`. Lo que falta hacer está en `ROADMAP.md`.

---

## 1. Reglas del proyecto (valen siempre)

- **Tipado estricto:** toda variable, `@export`, argumento y retorno lleva tipo (`var x: int = 0`, `func f(a: float) -> void:`).
- **Verificación:** no se escriben suites de tests (`test_*.gd`). La jugabilidad la valida el usuario con F5 / `run.bat`. Para confirmar que compila: lanzar una escena real con `--quit-after` y filtrar `SCRIPT ERROR`; para probar lógica, una escena descartable que se borra después (`tests/test_phase*.gd` son históricos).
- **Scripts nuevos y `class_name`:** `run.bat` no regenera `.godot/global_script_class_cache.cfg` (solo el editor). Un script nuevo referenciado desde otro archivo se carga con `const X = preload("res://...")`, no por su `class_name`: si no, falla el parseo en cascada.
- **Nombres:** no llamar a un enum con el nombre de un `class_name` existente (`State`, etc.). En scripts que carga la clase base, no usar `is ClaseHija` (ciclo de referencias): comparar con `get_global_name()`.
- **Pipeline de combate:** todo daño es un `HitPayload` → resuelto por `HealthComponent` → proyectiles balísticos por `ProjectilePool`.
- **Cambios de escena:** siempre `GameManager.change_scene()` / `reload_scene()` (pantalla de carga), nunca `change_scene_to_file`.
- **Arte nuevo:** cargar con `Art.tex(path)` (`core/art/art.gd`), no con `load()`: `run.bat` no importa por el editor.
- **Sin `print()` por enemigo, moneda o impacto:** cada línea va al log en disco y cuesta ms en masacres.
- **Cada sistema nuevo debe poder usarse desde el editor** (`@export`, escena, marcador). Los sistemas pesados se prueban en la Sala de Estrés.
- **Alcance quirúrgico:** tocar solo los archivos de la tarea; no refactorizar lo que funciona.
- **Git:** rama `main`, sin remoto. `.godot/`, `build/` y `ost.zip` ignorados; `.import` y `.uid` versionados.

---

## 2. Router: qué querés tocar → dónde ir

| Quiero tocar… | Sección | Archivos de entrada |
|---|---|---|
| Movimiento, salto, dash, agacharse, habilidades de movilidad | 3 | `entities/player/player.gd`, `states/` |
| Vida, daño, armadura, estados (fuego, hielo, arraigo), proyectiles, melee, FX de daño | 4 | `combat/hit_payload.gd`, `core/health_component.gd` |
| Armas, recarga, runas, escudos, mano 2 | 5 | `core/weapon_manager.gd`, `core/weapon_data.gd` |
| Enemigos, jefe, oleadas, arenas | 6 | `entities/enemies/`, `core/wave_manager.gd` |
| Aliados, esqueletos, invocaciones, drones | 7 | `entities/allies/ally_base.gd` |
| Ítems, equipo, mochila, baúl, botín, orbes, pickups | 8 | `entities/player/equipment_manager.gd`, `core/loot/` |
| Tienda, consumibles, herrero | 9 | `core/trade/`, `core/consumables/` |
| Niveles, sectores, campamento, menú de mapas | 10 | `levels/level_base.gd`, `core/managers/level_registry.gd` |
| Guardado, flujo de partida, derrota/victoria | 11 | `core/managers/save_manager.gd`, `game_manager.gd` |
| HUD, ventanas, inventario, tooltips, arrastre de ítems | 12 | `ui/`, `ui/components/` |
| Arte, rig del personaje, íconos, fondos | 13 | `entities/player/character_rig.gd`, `core/art/` |
| Sonido y música | 14 | `core/sfx.gd`, `core/music.gd` |
| Opciones, accesibilidad, posprocesado, logs, rendimiento | 15 | `core/settings.gd`, `core/debug/perf_monitor.gd` |
| Banco de Pruebas, Sala de Estrés, marcadores del editor | 16 | `core/test_level.gd`, `scenes/hub/stress_room.gd` |

---

## 3. Jugador y movimiento

- **Archivos:** `entities/player/player.gd` (controlador, daño, respawn), `entities/player/states/` (`idle`, `move`, `jump`, `fall` sobre `core/state_machine/`), `data/player_movement_data.gd` (parámetros físicos: velocidad, salto, gravedad, coyote time, jump buffer).
- **Habilidades por flags:** `EquipmentManager` prende `can_wall_jump`, `has_jetpack`, `has_wings`, `has_magic_flight`, `can_dash`, `has_eye_laser`, `has_cloak` en el `Player` según el ítem equipado. Los estados las leen (`player.is_dashing()` en `PlayerState`); no hay estado nuevo por habilidad.
- **Agacharse:** siempre disponible; cápsula y hurtbox pasan a 40 px y se sale solo si hay espacio (`test_move`). Constantes `CROUCH_*` en `player.gd` y `character_rig.gd`.
- **Dash:** constantes `DASH_*` en `player.gd`; acción `dash` (Shift / B).
- **Capa de invisibilidad:** `cloak_controller.gd` (+ `Player.is_invisible`, que leen los enemigos y `TargetScannerComponent`). **Casco láser:** `eye_laser.gd`. **Aura de nivel:** `level_up_aura.gd`. **Borde rojo y latido con vida baja:** `low_health_feedback.gd`.
- **Estadísticas:** `stats_manager.gd`, fórmula `(Base + Plano) * (1 + Porcentaje)`; nivel máximo 10; vida y daño por nivel derivados de `level` (persisten solos). La mitigación por armadura del jugador existe pero hoy vale 0 (las armaduras se eliminaron).
- **Trampa de tamaño:** el jugador está al 2x (`Visuals.scale = 2`, cápsula 18×64). Si cambia, revisar `ReloadIndicator.BAR_OFFSET`, las partículas de jetpack y los `Vector2(0, -32)` de `LootDrop`, `SniperTurret`, `ThrowableManager` y `GrapplingHook`.
- **`knockback_immune`:** si es true, el retroceso de armas y empujones no lo mueve (lo usa la Sala de Estrés).

---

## 4. Combate: daño, estados y efectos

- **Archivos:** `combat/hit_payload.gd` (daño, retroceso, emisor, estados, DoT, `armor_penetration`), `core/health_component.gd`, `core/projectile_pool.gd`, `combat/projectile.gd`, `combat/melee_hitbox.gd`, `core/status_receiver_component.gd`.
- **Vida (3 capas):** escudo de energía → armadura (`100 / (100 + armor × (1 − penetración))`) → vida. Crítico x1.5. Emite `hit_resolved` por impacto y `died`. En enemigos escala la vida con la dificultad al aparecer; el daño al jugador se escala en `Player.take_damage()`.
- **Proyectil:** velocidad, vida útil, rebotes, perforación, bifurcación, `deflect` (parry) y `reflect(normal)` (escudo espejo y superficies reflejantes; cada rebote deja 50 % del daño). Rebotes innatos del arma en `WeaponData.innate_bounces`; `WeaponData.impact_scene` aparece donde termina el proyectil (p. ej. un `AreaBurst`). Un script de proyectil que no es `projectile.tscn` no pasa por el pool.
- **Melee:** barrido angular por Tween; ventana de parry balístico de 0.06 s.
- **Estados:** fuego (hasta 10 stacks, DoT), hielo (ralentiza), aturdimiento, **arraigo** (`apply_root()`: velocidad 0, conserva agro y ataques). Por payload llegan como efecto + duración (`"ROOT"` usa `ice_duration`). Tinte y llama (`fire_vfx.gd`) automáticos.
- **FX de daño:** `combat/damage_fx.gd` y `blood_fx.gd` (sangre, manchas, heridas, trozos con `gib.gd`; arte opcional en `assets/art/fx/`), `shot_fx.gd` (fogonazo, humo, chispas), `damage_number.gd` (tope de 40 vivos), `reload_debris.gd`, `spawn_telegraph.gd`.
- **Cola de muertes:** `combat/death_fx_queue.gd` reparte gore y botín de muertes masivas con presupuesto por cuadro. Todo lo que crea una muerte pasa por ahí (`burst`, `gore`, `loot`, `exp_orb`).
- **Arrojadizos:** `combat/throwables/` (base `RigidBody2D` con arco y fusible; granadas, charcos, nubes, red arraigadora, boomerang) y `combat/tools/` (gancho, baliza). Gestor: `entities/player/throwable_manager.gd` (acción `throw_tactical`, [G]).
- **Lanzallamas de combustible:** `combat/fuel_droplet.gd` → `throwables/fuel_pool.gd` (charco que quema).

---

## 5. Armas, runas y escudos

- **Archivos:** `core/weapon_manager.gd` (arsenal, disparo, tajos, recarga, mano 2, dibujo del arma), `core/weapon_data.gd` (recurso), `core/runes/rune_data.gd`, `data/weapons/*.tres`, `data/runes/*.tres`.
- **Tipos:** `WeaponData.family` (pistola, revólver, carabina, subfusil, escopeta, fusil, rifle de precisión, energía, lanzallamas, melee corto, espada, pesada) y `grip` (una mano, dos manos, escudo). `FAMILY_RULES` fija por familia el techo de perforación, el piso de penetración y qué suelta al recargar. El sonido de disparo sale de la familia.
- **Mano 2:** segundo `WeaponManager` hijo (`offhand`), acción `attack_secondary` (clic derecho). Un arma a dos manos la bloquea. Prioridad: la función secundaria del arma principal (`has_secondary_function()`, hoy ninguna) gana sobre la mano 2.
- **Escudos:** `grip = SHIELD`, se levantan con clic derecho mantenido y solo bloquean levantados (`SHIELD_BLOCK_MULT` en `player.gd`). El espejo (`reflects_projectiles`) usa `entities/shield/mirror_reflector.gd`. `energy_shield.gd` es la esfera de escudo de energía de jugador y centinela.
- **Armas de movimiento/animación:** `core/art/weapon_motion.gd` (agarre, tajos, recarga, ráfaga por id de arma), `core/art/weapon_art.gd` (arte en mano; generado), `ui/components/item_icons.gd` (`WEAPON_POSES`). Un arma nueva con arte propio necesita entrada en esos tres.
- **Runas:** hasta 3 sockets por arma; se engarzan solo en el herrero. Efectos: rebote, perforación, bifurcación, daño plano, infusión elemental.
- **Frostmourne:** hielo en cada golpe (`ice_duration` / `ice_speed_multiplier` del arma) e invocación al matar (sección 7).
- **Datos que el arma entrega al payload:** penetración, hielo, `knockback_force`, `melee_hitbox_scale`; audio real opcional con `fire_stream` / `hit_stream`.

---

## 6. Enemigos, oleadas y arenas

- **Base:** `entities/enemies/enemy_base.gd` (golpes, retroceso, estados, barra de vida, botín). `basic_runner.gd` es el corredor; zombi y fantasma lo heredan; bruto (`armored_brute`), centinela con escudo (`shielded_sentinel`), torreta francotiradora y muñeco/torreta de práctica completan el elenco. Jefe del 1-10: `brute_boss.gd` (hereda del bruto; grupo `boss`; onda de choque con aviso; furia al 50 %).
- **Escala:** `mob_scale.gd` (`MOB_SCALE = 1.5`) se aplica al final del `_ready` de cada enemigo; las escenas guardan 1x. La colisión contra el mundo tiene tope de 72 px de alto para pasar bajo plataformas bajas.
- **Arte:** `entities/enemies/enemy_art.gd` (`attach(host, tipo)`); los `ColorRect` originales quedan transparentes porque los scripts leen su `color`.
- **Oleadas:** `core/wave_manager.gd`. Modo continuo (`max_alive`, `respawn_delay`) o por rondas (`round_sizes`, `rest_between_rounds`, `elite_scene` + `elite_per_round`). Los puntos de aparición son marcadores hijos (`entities/markers/enemy_spawn_marker.gd`).
- **Arenas:** `core/arena_encounter.gd` cierra barreras al entrar y las abre al despejar; se reinicia si el jugador muere. Pieza lista: `entities/world/arena.tscn`.
- **Dificultad:** `Settings.enemy_damage_mult()` y `enemy_health_mult()` (sección 15).
- **Regla de diseño de oleadas:** crecen las de un enemigo; cuando ya son grandes entra uno nuevo, de a uno por sector.

---

## 7. Aliados e invocaciones

- **Base:** `entities/allies/ally_base.gd` (vida, inmunidad a fuego amigo, escáner de blancos, rescate por distancia). Mercenario contratable (`mercenary_skeleton`) y dron orbital (`support_drone`).
- **Invocaciones:** `is_summon = true` antes de `super._ready()` las mete en el grupo `summons`; usar `rest_goal_x(delta)` para el casillero de descanso y `apply_separation(delta)` antes de `move_and_slide()`.
- **Frostmourne:** `frostmourne_summoner.gd` (hijo del jugador; se engancha a `hit_resolved`, tope 5, −5 % de vida máxima por esqueleto) + `frostmourne_skeleton.gd/.tscn`.

---

## 8. Ítems, equipo, inventario y botín

- **Equipo:** `entities/player/equipment_manager.gd` (ranuras `HEAD`, `CHEST`, `GLOVES`, `BOOTS`, `BACK`, `ACCESSORY_1/2`, `TACTICAL`; aplica pasivas y flags). Datos: `core/item_data.gd` + `data/items/*.tres`.
- **Mochila:** `inventory_manager.gd` (20 casilleros). **Baúl:** `ui/stash_window.gd`, `StashChest` (ilimitado, por personaje, armas con sus runas).
- **Pickups:** `entities/items/` (`pickup_item`, `weapon_pickup`, `rune_pickup`, `loot_drop`, `exp_orb`, `pickup_aura`). `allow_duplicates = false` hace desaparecer el pedestal si ya se posee; los drops de enemigos usan `true`.
- **Armas garantizadas por nivel:** `LevelBase.guaranteed_weapon_paths`, entregadas una sola vez por personaje (flag `weapon_granted:<ruta>` en el slot).
- **Botín:** `core/loot/loot_table.gd` (monedas, munición, vida, equipo por tier de nivel, `early_gear_pool` + `jackpot_chance` en tiers bajos), `gear_loot.gd` (tirada de equipo; filtra lo ya poseído o peor), `loot_combiner.gd` (funde botín quieto de a 10, hasta nivel 3). Tablas en `data/loot/`. Tier del nivel: `LevelBase.gear_loot_tier` (0 = sin equipo).
- **Armaduras:** se eliminaron (no hay piezas ni sets).

---

## 9. Comercio, consumibles y herrero

- **Comercio:** `core/trade/trader_data.gd` (recurso por comerciante: stock, precios, categorías, recompra), `trade_session.gd` (toda la lógica, sin interfaz; devuelve `TradeResult`, `NEEDS_CONFIRM` si requiere confirmación), `ui/trade_window.gd` (solo muestra y dispara), `entities/interactables/trader_npc.gd` (+ `merchant_npc`). Estado persistido en `SaveManager.trade_state`. `sell_everything` en `data/traders/merchant.tres` ofrece todo `.tres` sin límite (modo prueba).
- **Consumibles:** `core/consumables/consumable_manager.gd` (hijo del jugador; tope 5 por tipo, uso por barra rápida o M4/M5), `data/consumables/*.tres`.
- **Herrero:** `ui/blacksmith_window.gd` (yunque + 3 sockets), `entities/interactables/blacksmith_npc.gd`.

---

## 10. Niveles y campaña

- **Registro:** `core/managers/level_registry.gd` (`IMPLEMENTED_LEVELS`, `is_implemented()`, nombres de capítulo). `entities/interactables/map_selector.gd` bloquea lo no desbloqueado y lo no implementado. Hoy: capítulo 1, sectores 1-1 a 1-10 (`levels/chapter_1/`), capítulo 2 **Valle Esmeralda** (medieval, verde), sectores 2-1 a 2-10 (`levels/chapter_2/`), y capítulo 3 **Abismo Ígneo** (infierno), sectores 3-1 a 3-10 (`levels/chapter_3/`). La victoria del 2-10 lleva al 3-1. El capítulo 4 es **El Presente** (ver abajo); el 5 es un esqueleto vacío.
- **Capítulo 2:** los `.tscn` los genera `art_source/world2/build_levels.py` (editar ahí y regenerar). Armas por sector: cuchillo 2-1, arco 2-2, jabalina 2-4, báculo de fuego 2-6, báculo de hielo 2-8, espada de hierro 2-9, martillo tras el jefe (Rey Caído = `brute_boss`) del 2-10. `level_base.backdrop_file` pisa el fondo del capítulo (bosque en 2-6/2-8, castillo en 2-9/2-10). `levels/meadow_decor.gd` (lo llama LevelSkin en el capítulo 2) siembra árboles, flores y pasto que se mecen (shader) y hojas que caen (CPUParticles2D), con semilla fija por nivel.
- **Capítulo 3:** los `.tscn` los genera `art_source/world3/build_levels.py` (misma clase `Level` que el mundo 2). Armas por sector: Guadaña 3-1, Ballesta Infernal 3-2, Tridente Infernal 3-4 (atraviesa), Báculo de Almas 3-6 (`innate_bounces`), Cetro de Azufre 3-8 (`impact_scene` = `combat/throwables/sulfur_burst.tscn`), Espada Demoníaca 3-9, Hacha del Abismo (legendaria, onda de choque) tras el jefe (Señor del Abismo = `brute_boss`) del 3-10. Pozos de lava reales (sin `bedrock()`) en 3-3, 3-5 y 3-7. Fondos: llanura (`hell_plain.jpg`), caverna (3-5 a 3-7) y ciudadela (3-9/3-10). `levels/hell_decor.gd` siembra estalagmitas, árboles calcinados, columnas, calaveras y huesos, braseros que titilan, cadenas y jaulas que se balancean, brasas y ceniza que suben (CPUParticles2D), lava animada (shader) en los huecos entre suelos sin nada debajo y hace latir las grietas del suelo.
- **Capítulo 4 — El Presente (mundo moderno, primer mundo del juego):** 8 sectores (`levels/chapter_4/level_4_01..08.tscn`, el 4-9/4-10 son esqueletos sin usar), generados por `art_source/world4/build_levels.py` (misma clase `Level`, con `cine()` y `box()`). `LevelRegistry.LEVEL_COUNTS` = `{4: 8}` y `CHAPTER_EXIT` = el P-8 termina en `level_1_01` (la Caja lleva a la Periferia Subterránea). Partida nueva: `main_menu.gd` entra directo al P-1 y `unlocked_levels` arranca en `level_4_01` (los saves viejos conservan lo suyo); `pistol_9mm` llega por `guaranteed_weapon_paths` del 4-1. Arte: `art_source/world4/*.jpg` (Google Flow) → `process.py` → `assets/art/world4/` (props, texturas, `mob_*.png`), `assets/art/bg/` (`city_*.jpg`, `box_corridor.jpg`, `jewelry_flashback.jpg`) y `assets/art/portraits/`. `LevelSkin.CHAPTER_THEMES[4]` trae `sectors[level_id]` que pisa suelo, muros, plataforma y fondo por sector (alcantarilla, muelle, mármol, discoteca, azotea). `levels/city_decor.gd` pone mobiliario urbano por sector (tabla `SECTORS`), lluvia (una `CPUParticles2D` en un `CanvasLayer`) y relámpagos en exteriores, autos que cruzan por una capa de fondo, agua en los huecos (4-3, 4-5), luces de colores y bola de espejos en la discoteca. `LevelBase.base_music` (`club` en el 4-7: falta `ost/club.ogg`; mientras tanto suena la exploración).
- **Enemigos del presente:** `city_rat`, `city_thief` (corredor, `art_kind`), `city_thug` y `city_bouncer` (bruto con `art_kind`, `brute_name/health/armor/speed`), `city_gunman`, `city_hitman_smg`, `city_hitman_elite` y `time_agent` (`entities/enemies/armed_enemy.gd`: mantiene distancia y dispara proyectiles hostiles; `gun` pistol/shotgun/smg). El arte sale de `ArmorArt.MOBS` (`size` = textura/3) y `enemy_art.gd` (`MOB_SPLIT`). Botín: `data/loot/city_loot.tres`, `city_elite_loot.tres`, `time_agent_loot.tres` (suelta `CRYSTAL`).
- **Cristales de tiempo:** `StatsManager.time_crystals` (`add_crystals`, señal `crystals_changed`), `LootEntry`/`LootDrop` tipo `CRYSTAL` (moneda teñida de cian), guardado en `stats.time_crystals`, segunda línea del cartel de monedas del inventario (`ui/inventory_window.gd`). Todavía no se gastan.
- **Evento de Agentes:** `LevelBase.agent_events_enabled` / `agent_event_chance` / `agent_event_style` crean `levels/agent_event.gd` (helicóptero o destello; 2-3 Agentes). El del 4-5 es guionado (cinemática `p5_helicopter`); 4-6 y 4-7 lo tienen con 25 % en estilo `portal`.
- **Cinemáticas:** `core/cinematics/cinematic_player.gd` (motor: pasos `wait/say/title/fade/flash/bg/show/spawn/move/focus/release/shake/sfx/box/call/goto/par`; pausa el juego, barras negras, subtítulos con retrato, Enter avanza y Esc salta), `cinematic_library.gd` (textos de `story.md` por id) y `cinematic_trigger.gd` (nodo del nivel: al empezar, por franja, tras una arena o al tener un cristal; flag `cine:<id>` del slot para no repetir). La Caja es `levels/the_box.gd` (grupo `the_box`).
- **Nivel:** `levels/level_base.gd` (spawn, carga del slot, caída al abismo, armas garantizadas, equipo de prueba para F6). Cada nivel es una `.tscn` armada con piezas: `platform.tscn`, `arena.tscn`, `checkpoint_terminal`, `throwable_pedestal`, `exit_gate`, marcadores.
- **Vestido:** `levels/level_skin.gd` cubre los `StaticBody2D` de `Environment` con texturas y `levels/backdrop.gd` pone el fondo del capítulo; no tocan colisiones. `CHAPTER_THEMES` define por capítulo la carpeta de arte, texturas, tonos, borde superior, plataforma, oscurecimiento del fondo (por archivo) y el script de decoración; un capítulo sin entrada usa el revestimiento industrial del 1. Un mundo nuevo = una entrada nueva + su `*_decor.gd`. El lecho de roca no lleva borde superior (`_has_solid_on_top`).- **Salida:** `exit_gate.gd` se abre cuando no quedan enemigos del grupo `arena_enemies`; pasa `next_level_path` y la victoria ofrece SIGUIENTE SECTOR.
- **Campamento:** `scenes/hub/base_camp.gd` (baúl, herrero, mercader, selector, puerta a la Sala de Estrés).
- **`levels/level_01.tscn` / `.gd`:** sector antiguo, sin conectar al registro.

---

## 11. Guardado y flujo de partida

- **Guardado:** `core/managers/save_manager.gd`, 3 slots JSON en `user://saves/slot_{id}.json` (perfil, estadísticas, armas con runas, arma activa, equipo, mochila, baúl, barra rápida, consumibles, flags de mundo, `trade_state`, checkpoints). Autoguardado al cambiar inventario y al cerrar. `saving_suspended` lo apaga (Sala de Estrés).
- **Flujo:** `core/managers/game_manager.gd` (autoload único): estados `PLAYING`/`GAME_OVER`/`VICTORY`, pausa, respawn por checkpoint (R), pantalla de carga, atajos globales (ESC, F2, F9). `is_sandbox()` cubre el Banco de Pruebas y la Sala de Estrés.
- **Métricas:** `core/managers/metrics_manager.gd` (bajas, monedas, muertes, tiempo).
- **Contratos de zona:** `zone_modifier_manager.gd` + `contract_terminal`; solo en el sandbox.
- **Menú:** `scenes/main_menu.gd` (3 perfiles).

---

## 12. UI y ventanas

- **HUD:** `ui/hud.gd` (CanvasLayer capa 2; la 1 es el posprocesado), `ui/hotbar.gd` (9 casilleros: armas del arsenal y consumibles; las armas sueltas entran solas a los casilleros 1-3 libres), `ui/reload_indicator.gd`, `core/combat_hud.gd`.
- **Ventanas:** todas heredan de `ui/components/draggable_window.gd`: inventario con paper doll (`inventory_window.gd`), baúl, herrero, comercio, estadísticas (C), opciones (`settings_window.gd`).
- **Ítem en mano:** `ui/components/item_drag_controller.gd` (arrastrar o clic-clic, ESC o clic derecho cancela) con protocolo de duck typing; `item_slot.gd` es origen y destino (`accept_filter` para reglas por ventana). Un Control nuevo puede participar sin tocar el controlador.
- **Estilo:** `ui/components/steam_skin.gd` (`skin_tree()` restiliza una ventana sin tocar su `.tscn`). **Íconos:** `item_icons.gd` prefiere `assets/art/items|consumables|runes/<id>.png` y cae a pixel art 16x16. **Tooltip:** `item_tooltip.gd`.

---

## 13. Arte y rig

- **Personaje:** `entities/player/character_rig.gd` (esqueleto modular, marcha, salto, brazos con IK al arma). Cuerpo `hero` articulado en `core/art/hero_art.gd` (generado desde `assets/PSD/out/` por `art_source/character_rig/export_game.py`). Cuerpos de zombi/esqueleto/fantasma en `core/art/armor_art.gd` (generado). Mochilas y alas en `rig_art.gd`.
- **Carpetas:** `assets/art/` (arte HD vigente), `assets/sprites/` (respaldo antiguo), `art_source/` (fuentes, ignorado por Godot). Fondos y plataformas en `assets/art/world|bg|props` (mundo 2: `assets/art/world2/`, mundo 3: `assets/art/world3/`; fuentes de Google Flow y script en `art_source/worldN/process.py`, importar después con `Godot --headless --path . --import`); FX en `assets/art/fx`; armas en mano en `assets/art/weapons`.
- **Props:** `entities/props/prop_skin.gd` (herrero, mercader, terminales, compuerta).
- **Ícono del `.exe`:** `icon.ico` generado por `art_source/icon/make_icon.py`.

---

## 14. Sonido y música

- **Efectos:** `core/sfx.gd` sintetiza WAV por código (estilo 8-bit, provisorio) y los cachea; para uno nuevo, agregar un caso en `_build()`. Se piden por la fachada `GameFeel.sfx(ctx, &"nombre", pos?)` (`core/game_feel.gd`, que también da `shake`, `hit_stop`, `death_burst`). Audio real: `fire_stream` / `hit_stream` en el arma o `Sfx.register_override()`.
- **Música:** `core/music.gd` (fundido entre pistas `ost/*.ogg`; prioridad anulaciones > situación > base) y `core/music_director.gd` (elige combate / élite / jefe según enemigos cercanos y el grupo `boss`). Para una pista nueva: convertir a `.ogg` y agregarla a `Music.TRACKS`.

---

## 15. Opciones, posprocesado, logs y rendimiento

- **Opciones:** `core/settings.gd` (estático, lo inicia `GameManager`), `core/settings_host.gd`, `ui/settings_window.gd`; se guarda en `user://settings.cfg`. Los sistemas leen `get_float/get_bool/get_int`, `particle_scale()`, `reduce_flashes()`, `ui_scale()`, `enemy_damage_mult()`, `enemy_health_mult()`. Reasignación de teclas con detección de conflictos (`REMAPPABLE`); las acciones se inyectan por código en `core/input_manager.gd`. Una acción nueva que el jugador deba poder reasignar va a `REMAPPABLE`.
- **Posprocesado:** `core/post_fx.gd` (viñeta, grano, bloom, peligro rojo; daltonismo en la capa 250). El MSAA 2D no aplica en `gl_compatibility`.
- **Logs:** `core/error_logger.gd` escribe `user://logs/errors_<fecha>.log` solo si hubo errores.
- **Rendimiento:** `core/debug/perf_monitor.gd` (F9 en cualquier escena; CSV y TXT en `user://logs/rendimiento/`). Técnicas ya aplicadas: botín fundido, objetos quietos sin física, cola de muertes, tope de números de daño.
- **Distribución:** `build_exe.bat` + `export_presets.cfg` (versión en `application/config/version`).

---

## 16. Banco de Pruebas, Sala de Estrés y herramientas de editor

- **Banco de Pruebas:** `core/test_level.gd/.tscn`, sandbox con pista, dummies, torretas, pedestales de todo lo nuevo y oleadas continuas. Atajos: N, B, M, Z, V (enemigos), K (limpiar), L (curar), U (subir nivel). No es parte de la campaña.
- **Sala de Estrés:** `scenes/hub/stress_room.gd` (puerta a la derecha del campamento). Panel F4: generador de enemigos, fuego automático, congelar, matar, inmortal. No guarda nada.
- **Marcadores:** `entities/markers/enemy_spawn_marker.gd` (enemigos), `item_floor_marker.gd` (arma, runa o ítem en el piso; escena de prueba `levels/test_markers.tscn`).
- **Equipo de prueba en F6:** grupo "Equipo de prueba" de `LevelBase` (`test_loadout_enabled`, `test_weapon_paths`, `test_coins`, `test_consumables`). Si después se guarda la partida, queda guardado.
