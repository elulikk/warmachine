# Técnicas de rendimiento: qué tenemos y qué falta

Registro de la revisión del 2026-10-13. Compara las técnicas que se suelen usar en juegos de hordas (investigadas en
internet) con lo que **ya está implementado** en el código. Es un inventario de solo lectura: no se midió nada nuevo
ni se tocó código al escribirlo. Para medir, ver la skill `perf-benchmark` y `PROJECT_CONTEXT.md` secciones 15 y 16.

## El síntoma que motivó la revisión

Prueba en la Sala de Estrés (vsync apagado, un proceso): 20 granadas de hielo por segundo (`F9`/`F11`, tipo Hielo) y
enemigos en mezcla a 10 por segundo, tope 1000, sin fuego automático.

| Tiempo | FPS | Enemigos vivos | Nodos |
|---|---|---|---|
| 5 s | 231 | 72 | 3.881 |
| 15 s | 130 | 175 | 7.989 |
| 30 s | 51 | 326 | 13.911 |
| 50 s | 9 | 527 | 21.679 |

Lectura: la caída es continua y sigue a los enemigos vivos. Los nodos crecen ~400 por segundo, o sea unos **40 nodos
por enemigo**. El hielo ralentiza pero no mata, y sin disparos nadie los elimina, así que se acumulan.

## Resumen

| # | Técnica | Estado | Dónde |
|---|---|---|---|
| 1 | Menos nodos por enemigo / nodos de estado bajo demanda | **Parcial** | barra de vida de un nodo; cartel de estados sigue siempre |
| 2 | Dibujo masivo con MultiMesh / RenderingServer | **No** | sin `MultiMesh` ni dibujo por servidor |
| 2b | Sprite único horneado para lejanos (equivalente a animación horneada) | **Sí** | `entities/enemies/enemy_art.gd` (`enemy_lod`) |
| 3 | Física e IA más baratas por enemigo / lejos de cámara | **Parcial** | solo el arte duerme; la física no |
| 4 | Flow field (pathfinding compartido) | **No aplica hoy** | los enemigos persiguen por diferencia en X, sin pathfinding |
| 5 | Spatial hash / grilla para consultas | **No** | `Area2D` y grupos de Godot |
| 6 | Números de daño baratos | **Parcial** | tope de 40 vivos; no son partículas |
| 7 | Pooling y topes | **Parcial** | proyectiles y disparos sí; enemigos y granadas no |
| 8 | Apagar lo que está fuera de cámara | **Parcial** | `ViewCull` en arte y efectos; no en física/IA |

## Lo que ya está implementado

### Dormir lo invisible: `ViewCull`
- `core/view_cull.gd`: rectángulo visible de la cámara calculado una vez por cuadro y compartido (`near(node, margin)`).
- `entities/enemies/enemy_art.gd`: con `SLEEP_MARGIN = 220 px` fuera de cámara el arte no anima. El daño y la lógica siguen.
- `entities/player/character_rig.gd`: el rig de aliados/enemigos fuera de cámara no se actualiza.
- Charcos de ácido (`acid_pool.gd`), nubes de gas (`gas_cloud.gd`) y redes (`root_net.gd`) no redibujan fuera de cámara.

### LOD de enemigos lejanos (opción `enemy_lod`, activada por defecto)
- Más allá de `LOD_FAR_DISTANCE = 340 px` en horizontal el enemigo se dibuja como **un solo sprite** en vez del esqueleto
  o de las piezas partidas; vuelve a `LOD_NEAR_DISTANCE = 280 px` (histéresis, sin parpadeo).
- La imagen del esqueleto se **hornea una vez por cuerpo** desde un `SubViewport` y se comparte (`_snapshot_for`).
- Se revisa cada ~0.3 s con un desfase aleatorio, no cada cuadro. Lejos solo se mantiene el tinte (hielo, fuego, golpe).
- Es la versión 2D de "hornear la animación en una textura" que usó Deep Rock Galactic: Survivor.

### Pooling, topes y presupuestos
- `core/projectile_pool.gd`: pool de proyectiles con lista de libres.
- `combat/shot_fx.gd`: pool de fogonazos, humo y chispas (hasta 40 por tipo). Sin medir en F9.
- `core/effect_cap.gd`: tope por tipo de efecto persistente (gas, fuego, redes); al pasarse, el más viejo se desvanece.
- `combat/death_fx_queue.gd`: cola de muertes con presupuesto de 2,5 ms por cuadro. El gore viejo (más de 500 ms) se
  descarta; el botín nunca se pierde y se funde si se acumula.
- `core/loot/loot_combiner.gd`: funde botín quieto de a 10 (hasta nivel 3).
- `combat/blood_fx.gd`: `GIB_LIMIT = 40` y `STAIN_LIMIT = 60`. `combat/damage_fx.gd`: `MAX_MARKS = 8`.
- `combat/damage_number.gd`: `MAX_ALIVE = 40` (salvo daño al jugador).

### Física y procesos
- `core/status_receiver_component.gd`: sale temprano de `_physics_process` si no hay ningún estado activo.
- `ui/status_display_component.gd` y objetos quietos (`loot_drop`, `exp_orb`): `set_process(false)` / `set_physics_process(false)`.
- Recolección de botín por distancia, no por `Area2D` (menos pares de colisión con enemigos).
- Enemigos muertos: `set_physics_process(false)` y colisiones apagadas antes de liberarse.
- `entities/ui/overhead_health_bar.gd`: barra de vida de **un solo nodo** que se dibuja con `_draw` y estilos compartidos.

### FX compartidos
- `combat/fx_shaders.gd`: shaders de fuego y ácido con **un material por tipo** (no rompen el lote de dibujo; la variación
  sale de la posición). Opción `fire_style`: sprites, partículas o shaders.
- Medido: los shaders rinden igual o un poco mejor que los sprites; las partículas cuestan 10-25 % más.

### Herramientas de medición
- `core/debug/perf_monitor.gd` (F9 en cualquier escena): CSV y TXT en `user://logs/rendimiento/`, censo de nodos, tabla
  de FPS según enemigos vivos.
- Sala de Estrés (`scenes/hub/stress_room.gd`): generador continuo, lluvia del cielo con granadas, fuego automático,
  congelar enemigos (separa costo de dibujo del de IA/física).
- Skill `perf-benchmark` con plantilla `bench.gd` y variables de entorno.

## Lo que falta (en orden de lo que más ayudaría al síntoma)

### 1. Nodos por enemigo (la raíz probable)
- Un corredor tiene ~9 nodos en su `.tscn`, pero con el arte en tiempo de ejecución, el cartel de estados, la barra y los
  componentes el censo da ~40 por enemigo.
- `StatusDisplayComponent` se instancia **siempre** (con su `HBoxContainer`, insignias y etiquetas) aunque el enemigo
  nunca se queme ni se congele. Ya figura como pendiente en el ROADMAP: crearlo al primer estado.
- Cada enemigo tiene un `Hurtbox` (`Area2D`) además del cuerpo; el ROADMAP ya lo señala (~4 `Area2D` por enemigo antes).
- Auditar cuántos de esos nodos existen "por si acaso" y cuáles pueden crearse bajo demanda.

### 2. Física e IA de enemigos lejanos
- `basic_runner.gd` corre `_physics_process` completo (gravedad, persecución, `move_and_slide`, salto de obstáculos,
  contacto) para **todos** los vivos, estén cerca o no. El dormir por `ViewCull` solo alcanza al arte.
- Ideas: física a menor frecuencia lejos (cada N cuadros con delta acumulado), o enemigos lejanos que solo avanzan
  en X sin `move_and_slide`. Figura como "física de enemigos lejanos más barata" en el ROADMAP.

### 3. Pool de enemigos y de granadas
- El instanciado cuesta 2-4 ms por enemigo al aparecer (ROADMAP). No hay pool de enemigos.
- Las granadas se instancian por tirada y no hay pool (`pool de granadas` pendiente en el ROADMAP).

### 4. Dibujo masivo (MultiMesh)
- No existe. Solo valdría la pena si, después de recortar nodos y física, el dibujo sigue siendo el cuello. Una prueba
  del foro de Godot midió que pasar de nodos a `RenderingServer` ganó apenas 5-8 %.

### 5. Consultas espaciales
- Las explosiones (`area_burst.gd`) usan un `Area2D` con círculo y esperan dos cuadros de física para ver las
  superposiciones. No hay spatial hash propio. Solo se justifica si el perfil muestra las consultas como cuello.

### 6. Números de daño como partículas
- Hoy son nodos con tope de 40. En Deep Rock Survivor los números eran un cuello y los pasaron a partículas con una
  hoja de dígitos. Baja prioridad aquí porque ya hay tope.

### 7. Flow field
- No aplica por ahora: los enemigos terrestres persiguen por diferencia en X y saltan obstáculos con `obstacle_hop.gd`.
  No hay `NavigationAgent` ni A* en el proyecto. Reconsiderar solo si se agrega pathfinding de verdad.

## Fuentes consultadas

- [Using MultiMesh (docs de Godot)](https://docs.godotengine.org/en/4.7/tutorials/performance/using_multimesh.html)
- [2D Rendering Performance (foro de Godot)](https://forum.godotengine.org/t/2d-rendering-performance/45719)
- [Optimizing a huge number of enemies (foro de Godot)](https://forum.godotengine.org/t/how-to-optimize-multiple-pathfinding-optimizing-a-huge-number-of-enemies/50709)
- [Many KinematicBody2D (foro de Godot)](https://forum.godotengine.org/t/how-to-optimize-performance-with-many-kinematicbody2d/26872)
- [DevLog #9: optimizar un juego de Godot](https://radiantslothgames.itch.io/destroy-the-monoliths/devlog/499567/devlog-9-how-to-optimize-your-game-made-with-godot-22)
- [Optimizing Deep Rock Galactic Survivor](https://unity.com/blog/optimizing-deep-rock-galactic-survivor-for-mobile)
- [swarmr (spatial hash, 2.000+ enemigos)](https://github.com/brac/swarmr)
