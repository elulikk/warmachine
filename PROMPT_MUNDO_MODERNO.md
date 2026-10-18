# PROMPT — Mundo del Presente (ciudad moderna, de noche, con lluvia)

Prompt para una sesión nueva de Claude Code. Es grande: **hacerlo por fases, una fase por sesión**, en el orden de abajo. Al empezar cada sesión, pegar: *"Leé `PROMPT_MUNDO_MODERNO.md` y hacé la Fase N"*.

---

## Contexto (leer antes de cualquier fase)

- Leé `story.md` (secciones 1 a 5: Gunther, el Sindicato, los 8 sectores, diálogos), `lore.md` (la Caja, cristales, Agentes, enemigos del presente) y `ROADMAP.md` sección 3.
- El **mundo del presente es el primero del juego**. La Periferia Subterránea (steampunk, Capítulo 4 actual) **no se toca**: queda tal cual, con sus voces y su jefe, y pasa a ser el primer destino de la Caja.
- Mirá cómo se armaron el Valle Esmeralda y el Abismo Ígneo y repetí el mismo pipeline:
  - `art_source/world2/` y `art_source/world3/`: los `.jpg` de Google Flow, `process.py` (recorta y exporta) y `build_levels.py` (arma los `.tscn`).
  - `assets/art/world2/`, `assets/art/world3/`, `assets/art/bg/`.
  - `levels/level_skin.gd` (`CHAPTER_THEMES`, `CHAPTER_BACKDROPS`) y los decoradores `levels/meadow_decor.gd` / `levels/hell_decor.gd`.
  - `core/managers/level_registry.gd` (capítulos y niveles).
- Arte en mano: `core/art/weapon_art.gd`. Enemigos: `entities/enemies/enemy_art.gd` (incluye `_build_person(loadout)` para enemigos humanos con arma). Héroe por piezas: `art_source/character_rig/` (CABEZA, PECHO, BRAZO, ANTEBRAZO, PIERNA, PIES).
- Reglas del proyecto: scripts nuevos referenciados desde otros archivos van con `preload` (no confiar en `class_name` nuevos); no llamar `State` ni nombres de clases globales a los enums; probar con la escena lanzada con `--quit-after` y respaldar los saves antes; **no hacer commit sin que el usuario lo pida**.
- Skill de Google Flow: `.claude/skills/google-flow` (modo Agente, varias imágenes por mensaje, primero generar todo y después descargar todo).

## Decisiones ya tomadas

- **8 sectores** (los mundos no tienen por qué tener 10):
  P-1 La calle · P-2 Callejones · P-3 Alcantarillas · P-4 Barrio de casitas · P-5 Muelle · P-6 Hotel · P-7 Discoteca electrónica · P-8 Azotea (final).
- **Ambiente:** siempre de noche. En exteriores, lluvia, faroles, veredas mojadas con reflejos y autos que pasan en el fondo. Interiores (alcantarilla, hotel, discoteca) sin lluvia.
- **Enemigos:** ratas callejeras, ladrones, matones, asaltantes (con arma de fuego), patovicas, sicarios del Sindicato (élite) y Agentes del Tiempo (evento).
- **Armas:** las modernas que ya existen en `data/weapons/`. **Gunther empieza con la `pistol_9mm` equipada.** Cuchillo (`combat_knife`) temprano; después revólver, escopeta, SMG/MP5, Desert Eagle como recompensas. No crear armas nuevas.
- **Final (P-8):** sin jefe único. **Oleadas** cada vez más duras de lo peor del Sindicato protegiendo la Caja. Al vaciar la última oleada: cinemática de la Caja.
- **La Caja:** cubo negro liso (estilo *Dark Matter*, 2024). Adentro, un pasillo negro infinito con puertas. Por ahora, al terminar el P-8 se encadena al `level_4_01` (Periferia Subterránea), que es "la primera puerta". El menú del pasillo **no** es parte de este trabajo.

---

## Fase 1 — Arte con Google Flow

Usar la skill `google-flow`. Crear un proyecto nuevo en Flow llamado **"Warmachine - Mundo Presente"**. Modo Agente, confirmación "Nunca", x1. Mandar los 4 pedidos de abajo **uno tras otro** y descargar todo al final, en 1K, a `art_source/world1/` (renombrar cada archivo con el nombre indicado).

Estilo común para todo: **ilustración 2D de videojuego, no pixel art**, noir moderno, paleta fría (azules, violetas, ámbar de faroles, toques de neón rosa y cian), bordes nítidos.

### Pedido 1 — Fondos (10 imágenes, 16:9, sin fondo negro)

```
Genera 10 imágenes separadas, todas en 16:9, fondos de videojuego 2D de plataformas con vista lateral, ilustración 2D (no pixel art), estilo noir moderno, de noche, sin personajes, sin texto, sin logos. Deben poder usarse como fondo lejano con parallax: horizonte bajo, sin piso en primer plano.
1) "bg_city_street": ciudad moderna de noche con lluvia, edificios altos con ventanas encendidas, faroles ámbar, carteles de neón difusos, asfalto mojado que refleja las luces.
2) "bg_alley": callejón estrecho entre edificios de ladrillo, escaleras de incendio, cables, vapor saliendo de rejillas, lluvia, un farol solitario.
3) "bg_sewer": interior de alcantarilla abovedada de ladrillo, agua oscura en canal, tuberías, luz verdosa que entra por rejillas del techo.
4) "bg_houses": barrio de casitas pintorescas de dos pisos con techos inclinados, ventanas cálidas, cercas, árboles, lluvia suave, faroles.
5) "bg_dock": puerto de noche, grúas de carga, contenedores apilados, agua negra con reflejos, un barco carguero, faro a lo lejos, lluvia.
6) "bg_hotel": interior de lobby de hotel de lujo moderno, mármol, columnas, arañas de cristal, ascensores dorados, iluminación cálida y tenue.
7) "bg_club": interior de discoteca de música electrónica, cabina de DJ al fondo, láseres, humo, luces de colores rosa, cian y violeta, pantallas LED.
8) "bg_rooftop": azotea de rascacielos de noche con lluvia, skyline de la ciudad iluminada detrás, tanques de agua, antenas, helipuerto, nubes de tormenta.
9) "bg_corridor": pasillo negro infinito con perspectiva central, puertas idénticas a ambos lados que se pierden en la distancia, una sola puerta al fondo con luz blanca en el marco, atmósfera misteriosa y minimalista.
10) "bg_jewelry_flashback": joyería de noche con la vidriera rota, vitrinas, luces rojas y azules de un patrullero reflejadas, lluvia afuera, tono desaturado de recuerdo.
```

### Pedido 2 — Texturas de piso y plataformas (10 imágenes, 1:1)

```
Genera 10 imágenes separadas, todas en 1:1, texturas para un videojuego 2D de plataformas, ilustración 2D (no pixel art), de noche, iluminación fría. Las texturas 1 a 7 deben ser texturas planas que se puedan repetir en mosaico sin costuras, vistas de frente, sin objetos sueltos. Las 8 a 10 son piezas aisladas sobre fondo negro liso, vista lateral.
1) "tile_asphalt": asfalto mojado con reflejos, con una franja de vereda de cemento con cordón arriba.
2) "tile_brick": pared de ladrillo urbano oscuro, algo sucia, con manchas de humedad.
3) "tile_sewer": piedra y ladrillo de alcantarilla húmeda, con musgo y verdín.
4) "tile_dock": tablones de madera de muelle, gastados y mojados, con clavos.
5) "tile_marble": piso de mármol oscuro de hotel de lujo, con vetas doradas.
6) "tile_club": piso de discoteca negro brillante con líneas de luz LED de colores.
7) "tile_roof": techo de azotea de grava y membrana asfáltica, con charcos.
8) "plat_fire_escape": plataforma de escalera de incendio de metal negro con barandas, aislada sobre fondo negro liso.
9) "plat_awning": toldo de tela a rayas de un comercio, visto de costado, aislado sobre fondo negro liso.
10) "plat_container": techo de contenedor de carga metálico corrugado, visto de costado, aislado sobre fondo negro liso.
```

### Pedido 3 — Decorado, autos, la Caja y el helicóptero (8 imágenes)

```
Genera 8 imágenes separadas, hojas de sprites para un videojuego 2D de plataformas, ilustración 2D (no pixel art), vista lateral, estilo noir moderno de noche. En cada hoja, objetos distintos separados entre sí, a la misma escala, aislados sobre fondo negro liso, sin texto, sin sombra de suelo.
1) "decor_street" (16:9): cuadrícula de 10 objetos: farol de calle encendido, hidrante, buzón, contenedor de basura, semáforo, parada de colectivo, cabina telefónica, banco, cartel de neón "BAR" sin letras legibles, tacho de basura.
2) "decor_alley_sewer" (16:9): cuadrícula de 10 objetos: escalera de incendio vertical, pila de bolsas de basura, cajas de cartón mojadas, rejilla con vapor, caño oxidado, válvula, reja de alcantarilla, charco, barril, escalera de mano metálica.
3) "decor_houses_dock" (16:9): cuadrícula de 10 objetos: cerca de madera blanca, maceta con flores, bicicleta apoyada, buzón de casa, bita de amarre con soga, boya, pila de cajones de madera, barril de aceite, rollo de soga, poste de luz de muelle.
4) "decor_hotel_club" (16:9): cuadrícula de 10 objetos: sillón de cuero, planta en maceta grande, carrito de equipaje dorado, mostrador de recepción, araña de cristal, parlante grande de discoteca, consola de DJ, bola de espejos, barra de tragos con banquetas, luz robótica de escenario.
5) "decor_rooftop" (16:9): cuadrícula de 8 objetos: tanque de agua sobre patas, equipo de aire acondicionado, antena, chimenea de ventilación, cartel luminoso de azotea, baranda de seguridad, foco de helipuerto, conducto de ventilación.
6) "cars" (16:9): cuadrícula de 4 autos modernos vistos de costado, con faros encendidos: sedán, taxi amarillo, camioneta, patrullero de policía.
7) "the_box" (1:1): dos versiones de la misma caja: un cubo negro liso, metálico, mate, sin marcas ni botones, como en la serie Dark Matter. Izquierda: cerrada. Derecha: con la puerta abierta, mostrando un interior negro con un hilo de luz blanca. Fondo negro liso con un contorno sutil cian para que se distinga del fondo.
8) "helicopter" (16:9): helicóptero negro táctico sin insignias, visto de costado, con un reflector encendido apuntando hacia abajo.
```

### Pedido 4 — Personajes, enemigos y retratos (8 imágenes)

```
Genera 8 imágenes separadas para un videojuego 2D de plataformas, ilustración 2D (no pixel art), estilo noir moderno, aisladas sobre fondo negro liso, sin texto, sin sombra de suelo.
1) "gunther_parts" (16:9): hoja de piezas separadas para armar un personaje 2D por partes (rig), vista lateral mirando a la derecha: cabeza, torso, brazo superior, antebrazo con mano, pierna, pie. El personaje es Gunther, detective de unos 45 años, piloto largo color beige, camisa arremangada, corbata floja, barba de días, pelo corto canoso. Las piezas separadas entre sí, a la misma escala, con las articulaciones redondeadas.
2) "gunther_full" (1:1): el mismo Gunther de cuerpo entero, vista lateral, sosteniendo una pistola de 9 mm, como referencia de estilo.
3) "enemies_street" (16:9): cuadrícula de 4 enemigos de cuerpo entero, vista lateral mirando a la izquierda, a la misma escala: una rata de alcantarilla grande y agresiva (más chica que los humanos), un ladrón flaco con capucha y pasamontañas, un matón grandote con campera de cuero y bate, un asaltante con gorra sosteniendo una pistola.
4) "enemies_syndicate" (16:9): cuadrícula de 3 enemigos de cuerpo entero, vista lateral mirando a la izquierda, a la misma escala: un patovica de discoteca enorme con traje negro y auricular, un sicario de élite con traje oscuro, chaleco y escopeta, un sicario con abrigo largo y subfusil.
5) "time_agent" (1:1): agente del tiempo de cuerpo entero, vista lateral mirando a la izquierda: traje táctico negro sin insignias, visor opaco que cubre la cara con un brillo blanco tenue, arma de diseño extraño que no es de ninguna época.
6) "portraits_1" (16:9): cuadrícula de 3 retratos de busto para diálogos, de frente a tres cuartos, fondo negro: Gunther (detective descrito arriba, expresión cansada y seca); su compañero policía de uniforme, 30 años, sonrisa confiada; el agente del tiempo con el visor.
7) "portraits_2" (16:9): cuadrícula de 3 retratos de busto para diálogos, fondo negro: jefe del Sindicato, 60 años, traje blanco, anillos, mirada fría; un viajero de otro mundo con ropa extraña de época indefinida, asustado; un estibador de puerto con casco y chaleco reflectante, herido.
8) "gunther_young" (1:1): Gunther 12 años más joven, de uniforme de policía, cuerpo entero, vista lateral, para el flashback.
```

Después de descargar: copiar los `.jpg` a `art_source/world1/` con los nombres de arriba y escribir `art_source/world1/process.py` copiando el de `world3` (recorte de fondo negro con `cut_out`, cortes de las cuadrículas, salida a `assets/art/world1/`, fondos a `assets/art/bg/`, retratos a `assets/art/portraits/`). Si alguna imagen salió con fondo blanco, recortar igual por color de fondo.

---

## Fase 2 — Mundo en el registro y arranque de partida

- Usar el hueco vacío del **capítulo 1** (`levels/chapter_1/`) para el presente, para no renumerar los capítulos 1 a 3 ni romper los saves. Nombre en `CHAPTER_NAMES`: **"EL PRESENTE"**, color frío.
- `level_registry.gd` asume 10 niveles por capítulo (`LEVELS_PER_CHAPTER`). Agregar una cantidad por capítulo (por ejemplo, un diccionario con 8 para el presente) y que el último de cada capítulo sea el jefe/final. Cambio mínimo, sin reescribir el registro.
- **Partida nueva:** que empiece en el P-1 (`save_manager.gd`: `unlocked_levels` por defecto y el reinicio). Los saves viejos conservan lo que ya tenían desbloqueado.
- El final del P-8 encadena a `level_4_01` (Periferia Subterránea).
- **Equipo inicial:** `pistol_9mm` equipada desde el principio.

## Fase 3 — Look del mundo

- Tema en `level_skin.gd` para el capítulo 1 con las texturas de la Fase 1 (asfalto, ladrillo, alcantarilla, muelle, mármol, discoteca, azotea según el sector) y fondos por sector.
- Decorador nuevo `levels/city_decor.gd` (como `hell_decor.gd`): faroles, hidrantes, contenedores, etc., según el sector.
- **Lluvia:** partículas baratas (una sola `GPUParticles2D` o `CPUParticles2D` pegada a la cámara), salpicaduras chicas al tocar el piso solo si no cuesta FPS. Destellos de relámpago ocasionales en exteriores.
- **Autos que pasan:** sprites de `cars` cruzando en una capa del fondo con los faros encendidos, cada tantos segundos, sin colisión.
- **Discoteca:** luces que cambian de color al ritmo de un temporizador y bola de espejos girando. Reservar el tema musical del sector con `core/music.gd` (`set_base`); la música la pone el usuario después.
- Interiores sin lluvia.

## Fase 4 — Enemigos, Agentes y cristales

- **Reusar los scripts existentes con arte nuevo** antes de crear uno nuevo:
  - Ladrón → corredor rápido (`basic_runner`), con su arte.
  - Matón y patovica → bruto (`armored_brute`), con su arte y la vida ajustada.
  - Asaltante y sicarios → enemigo humano armado (`enemy_art._build_person(loadout)`); revisar cómo disparan hoy los enemigos con arma.
  - **Rata:** nueva, chica, rápida, poca vida, en grupos. Si alcanza con `basic_runner` escalado y con otros valores, hacerlo así.
- **Agente del Tiempo:** enemigo nuevo; humano armado, más duro que un sicario, **suelta cristales de tiempo en vez de monedas**.
- **Cristales de tiempo:** moneda nueva (contador en el inventario y el guardado, y en el HUD junto a las monedas). Todavía no se gastan en nada.
- **Evento del helicóptero:** el `helicopter` cruza con el reflector, se detiene y bajan 2 o 3 Agentes. Guionado en el P-5; a partir del P-5, con una probabilidad baja por nivel. Que se pueda apagar por nivel.
- Seguir el ciclo de progresión: crecer las oleadas de un tipo antes de introducir otro, y repetir.

## Fase 5 — Los 8 sectores

Armar los niveles con un `build_levels.py` en `art_source/world1/`, como en los mundos 2 y 3.

| Sector | Lugar | Enemigos | Notas |
|---|---|---|---|
| P-1 | La calle | Ratas, ladrones | Tutorial suave. Cuchillo en el piso. |
| P-2 | Callejones | Ratas, ladrones, primeros matones | Más vertical: escaleras de incendio y toldos. |
| P-3 | Alcantarillas | Ratas en masa, ladrones | Interior. Canales de agua; un objeto de filtración (decorado). |
| P-4 | Barrio de casitas | Ladrones, matones, primeros asaltantes | Techos y cercas como plataformas. Recompensa: revólver. |
| P-5 | Muelle | Asaltantes, matones, **Agentes (helicóptero guionado)** | Contenedores apilados. Primeros cristales. Recompensa: escopeta. |
| P-6 | Hotel | Patovicas, asaltantes, matones | Interior. Pisos conectados por escaleras. Recompensa: SMG o MP5. |
| P-7 | Discoteca | Patovicas, asaltantes, mezcla | Interior. Luces y música. Recompensa: Desert Eagle. |
| P-8 | Azotea | **Oleadas** de sicarios y lo peor del Sindicato | Arena final con `arena.tscn`: 5 o 6 rondas en escalada, élites al final. La Caja en el centro. |

## Fase 6 — Motor de cinemáticas, diálogos y escenas

- Motor mínimo (ver `ROADMAP.md` 3.6): una cinemática es un recurso con una lista de pasos. Pasos: `esperar`, `decir` (quién habla, texto, retrato, duración), `mover` actor a una posición, `enfocar` cámara en un nodo con zoom, `fundido` de entrada y de salida, `sacudir`, `sonido`/`música`, y un grupo `en paralelo` para hablar mientras se camina.
- Durante la cinemática: sin control del jugador, enemigos en pausa, barras negras arriba y abajo, subtítulos abajo con nombre y retrato. Avanza sola por tiempo o con un botón; una tecla la salta entera.
- Disparadores: al entrar a un nivel, al cruzar una zona y al terminar la última oleada.
- **Escenas a armar** (textos en `story.md`, sección 4 y 5):
  1. Prólogo: el robo (flashback), con `bg_jewelry_flashback` y Gunther joven. Antes del P-1, solo en partida nueva.
  2. P-1: el detonante (el Agente huye).
  3. P-3: la filtración (una línea).
  4. P-5: el helicóptero, el primer cristal y el estibador.
  5. P-7: el jefe del Sindicato por los parlantes.
  6. P-8: la Caja antes de las oleadas y el Agente entrando después.
  7. Dentro de la Caja: el pasillo (`bg_corridor`), el Agente cruza una puerta, Gunther lo sigue → carga `level_4_01`.
- Los textos de los diálogos se toman tal cual de `story.md`; se pueden recortar si no entran en dos líneas de subtítulo.

## Fase 7 — Validación y cierre

- Recorrer de P-1 a P-8 con `--quit-after` (respaldar saves antes) y revisar el log de Godot.
- Revisar FPS con lluvia y muchos enemigos en la Sala de Estrés (F9).
- Actualizar `PROJECT_CONTEXT.md` (archivos de entrada nuevos) y pasar lo que quede sin verificar a la sección 1 del `ROADMAP.md`.
- No hacer commit sin que el usuario lo pida.
