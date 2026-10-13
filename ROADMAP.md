# ROADMAP — Lo que falta hacer

Solo figura lo pendiente. Lo ya construido se documenta en `PROJECT_CONTEXT.md` (mapa técnico) y en el historial de git. Cuando algo se termina y se valida, se **borra de acá**.

**Estado en una línea:** el primer mundo está completo (sectores 1-1 a 1-10 con jefe), con armas, runas, escudos, invocaciones, comercio, opciones y herramientas de editor. Falta validarlo a mano, balancearlo, darle arte y sonido finales, y validar los Capítulos 2 (Valle Esmeralda) y 3 (Abismo Ígneo), ya armados.

---

## 1. Validar a mano (armado, sin verificar en F5)

Marcar y borrar cada punto al comprobarlo. Si algo falla, pasa a la sección 4 o 7.

- [ ] Manchas de sangre y tripas en el piso: ahora usan `assets/sprites/efectos/blood_pool_0..3.png` con el método del charco de ácido (cuelgan, se aplastan, rebotan al aparecer). Revisar tamaño y que no ensucien con muchos enemigos (`combat/blood_fx.gd`, `POOL_WIDTH_MULT`).

- [ ] **Sectores 1-5 a 1-10:** recorrerlos completos; que ningún enemigo quede trabado y que las arenas de 12 a 18 enemigos sean jugables.
- [ ] **Rework de oleadas 1-2 a 1-6:** bruto solo en el 1-4, 10 ladrones en el 1-3, ritmo general.
- [ ] **Jefe del 1-10 (Coloso del Núcleo):** si 1200 de vida es mucho o poco, y si la franja roja de la onda de choque se lee a tiempo.
- [ ] **Escudo de madera y Escudo espejo:** sensación del clic derecho mantenido, tamaño de la zona de reflejo, rebote contra plataformas reflectantes.
- [ ] **Red arraigadora, Boomerang, Casco láser, Capa de invisibilidad:** que se compren, se usen desde la barra y se sientan bien (en especial el robo de la capa y el 70 dps del láser).
- [ ] **Invocaciones separadas (Fase J):** seis esqueletos en la Sala de Estrés; que 70 px de distancia sea buena.
- [ ] **Opciones (segunda tanda):** cuenta regresiva de 15 s al cambiar resolución, selección de monitor, reasignación de mando, dificultades, accesibilidad, posprocesado por calidad.
- [ ] **Animaciones de arma:** recarga propia por arma, ráfaga sostenida de las automáticas, tajo de espada y katana a dos manos, doble empuñe y casillero M2.
- [ ] **Pulido visual:** aura de los objetos del piso, pose agachado, brazos abiertos al saltar, borde rojo y latido con poca vida, llama sobre enemigos que arden.
- [ ] **Progresión:** con 15 de EXP por enemigo, en qué punto del 1-2 se llega al nivel 5; presión de enemigos con la vida subida (ladrón 70, bruto 250, centinela 70).
- [ ] **Piezas de editor:** armar una arena y una plataforma desde `platform.tscn` / `arena.tscn`, y correr un nivel con F6 y el equipo de prueba activo.
- [ ] **Props arrastrables (nivel 1):** `entities/world/props/` (cajas S/M/L, cerco, casa, caseta, **paredón** `wall.tscn`; script `world_prop.gd`). Los bloques `Block*`/`JumpBlock*` de los niveles ya son props placeholder (cajas) y 2_02, 2_08, 3_04, 3_08, 4_01 y 4_04 llevan un paredón de 520 px caminable por arriba (`WallStep` + `Wall`); PNG pendientes: `crate_*`, `wall`, etc. En el mundo 4 la decoración automática (`levels/city_decor.gd`, `SOLID_PROPS`) pone contenedores, tachos, buzones, bancas y cajas como sólidos escalonados (grupos de 1 a 3, alturas 48–115 px); los enemigos los saltan (`entities/enemies/obstacle_hop.gd`). Pendiente: lo mismo para `meadow_decor` / `hell_decor`. Generar con Flow los PNG en `assets/art/world/props/` con el nombre de la escena (`crate_small.png`, `house.png`...), probar saltos en `levels/chapter_1/props_playground.tscn` y ajustar tamaños/hitboxes.
- [ ] **Capítulo 2 — Valle Esmeralda (hecho, sin verificar):** recorrer 2-1 a 2-10; saltos de los pozos reales del 2-4 y 2-7; balance de Arco Largo, Jabalina, Báculo de Fuego y de Hielo (`data/weapons/*.tres`); agarre en mano del arco y los báculos (`weapon_art.gd`); densidad de árboles/flores y cantidad de hojas (`levels/meadow_decor.gd`); jefe del 2-10. Al entrar al mundo 2 el jugador conserva su arsenal del mundo 1 (las armas medievales llegan por pedestal).
- [ ] **Capítulo 3 — Abismo Ígneo (hecho, sin verificar):** recorrer 3-1 a 3-10; saltos de los pozos de lava del 3-3, 3-5 y 3-7; balance de Guadaña, Ballesta Infernal, Tridente Infernal, Báculo de Almas (3 rebotes), Cetro de Azufre (estallido `combat/throwables/sulfur_burst.tscn`), Espada Demoníaca y Hacha del Abismo (`data/weapons/*.tres`); agarre en mano de la ballesta, la guadaña y el hacha (`weapon_art.gd`, `ALIASES` en `weapon_motion.gd`); oscuridad de fondos y suelo (`CHAPTER_THEMES` en `level_skin.gd`); cantidad de brasas, cadenas y braseros (`levels/hell_decor.gd`); **lava que daña** (20 % de la vida + llama + rebote de 800 px/s al tocarla, `LAVA_DAMAGE_FRACTION` / `LAVA_BOUNCE`: que se pueda salir del pozo y no sea injusta); jefe del 3-10 (reusa `brute_boss`).
- [ ] **Capítulo 4 — El Presente (hecho, sin verificar):** recorrer P-1 a P-8 con una partida nueva (arranca en el P-1 con la 9 mm, prólogo del robo y cuchillo en el piso). Revisar: legibilidad de lluvia y fondos (`CHAPTER_THEMES[4]` en `level_skin.gd`), escala de props de `city_decor.gd` (`SECTORS`), pozos de agua del P-3 y P-5, balance de ratas/ladrones/matones/asaltantes/patovicas/sicarios (`entities/enemies/city_*.tscn`, `armed_enemy.gd`), evento del helicóptero del P-5 y el portal de P-6/P-7, cristales de tiempo en el HUD, textos y tiempos de las 7 cinemáticas (`core/cinematics/cinematic_library.gd`), oleadas del P-8 y salida por la Caja a `level_1_01`. FPS con lluvia y muchos enemigos en la Sala de Estrés (F9).
- [ ] **Música de la discoteca:** poner `ost/club.ogg` (el 4-7 ya pide la pista `club`).
- [ ] **Arte del presente por pulir:** el rig de Gunther (`art_source/world4/gunther_parts.jpg` está bajado pero no se usa; hoy sigue el rig actual), enemigos con una sola ilustración (sin ataque propio), toldo y escalera de incendio como plataformas (hoy chapa y madera lisas).
- [ ] **Sonido:** `fire_ignite`, `net_deploy`, `laser_beam`, `cloak_on/off`, `heartbeat`.

---

## 2. Contenido nuevo

1. **Mundo del presente:** armado (ver sección 1). Falta validarlo y pulirlo; `PROMPT_MUNDO_MODERNO.md` queda como referencia del plan.
2. **Capítulo 2 (pendiente sobre lo armado):** enemigos con aspecto medieval propio (hoy reusa zombis, ladrones, brutos, fantasmas y centinelas) y un jefe propio para el Rey Caído; runas y movilidad avanzada; HUD sin estética steampunk en este mundo.
3. **Capítulo 3 (pendiente sobre lo armado):** enemigos demoníacos propios (hoy reusa los mismos cinco tipos) y un jefe propio para el Señor del Abismo; sonido de lava y braseros.
4. **Capítulos 4 y 5** y el total de 50 niveles. Sin fecha.
5. **Reintegrar mecánicas en stand-by** (ya existen en código, fuera de la campaña): jetpack, alas, vuelo mágico, gancho de anclaje, baliza de translocación, runas avanzadas, mercenarios y drones, contratos de zona. Decidir en qué capítulo entra cada una.

---

## 3. Visión: el multiverso y la máquina del tiempo

Idea rectora del juego a largo plazo. Todavía es diseño, no hay nada armado. Los mundos se van a ir sumando a medida que el usuario los defina; no inventar mundos nuevos sin consultarlo.

### 3.1 Estructura general

1. **Mundo inicial — el presente:** ciudad moderna, de noche y con lluvia (8 sectores: calle, callejones, alcantarillas, barrio de casitas, muelle, hotel, discoteca, azotea). Es un mundo nuevo; plan de trabajo en `PROMPT_MUNDO_MODERNO.md`. La Periferia Subterránea (steampunk, Capítulo 1 actual) queda tal cual y pasa a ser un mundo tier 1.
2. **Final del presente:** sin jefe único; oleadas de lo peor del Sindicato protegiendo la Caja en la azotea.
3. **La Caja:** la "Máquina" es una caja negra lisa (estilo *Dark Matter*, 2024). Por dentro es un pasillo negro infinito con puertas; cada puerta es un mundo. Es el momento más importante del juego para el personaje.
4. **Apertura del multiverso:** la misma Caja existe en todos los mundos y lleva al mismo pasillo; desde ahí se vuelve o se salta a otro mundo. El pasillo reemplaza al selector de mapas.
5. **Costo del viaje:** cada puerta cuesta **cristales** que al principio el jugador no tiene. Detalle en `lore.md`; trama en `story.md`.

### 3.2 Cristales y Agentes del Tiempo

- **Agentes del Tiempo:** una facción que controla las dimensiones y el tiempo. Empiezan a aparecer cada tanto en la partida para capturar al jugador: llegan en helicópteros, naves o portales, como evento que interrumpe el nivel.
- **Drop:** en vez de monedas, los Agentes sueltan **cristales temporales**, la moneda exclusiva para usar la Máquina.
- **Pendiente de diseñar:** frecuencia de aparición (por tiempo, por nivel o por "nivel de búsqueda"), tipos de Agente (soldado, piloto, comandante), si escalan con el tier del mundo actual, y si se pueden rechazar o farmear.
- **Implementación probable:** una moneda nueva en el inventario/guardado, un tipo de enemigo con `loot_table` propia y un evento de aparición en `level_base.gd`.

### 3.3 Tiers de mundos

| Tier | Costo en cristales | Cómo se desbloquea | Mundos |
|---|---|---|---|
| 0 | — | Inicio | Presente (mundo moderno) |
| 1 | Bajo | Al derrotar al jefe del presente | Mitología nórdica, Mitología griega, Medieval fantástico (Valle Esmeralda, ya armado como Capítulo 2), Infierno (Abismo Ígneo, ya armado como Capítulo 3), Mundo de hielo, … |
| 2 | Alto | Tras completar algunos mundos tier 1 | Futuro (año 3000/5000), … |
| 3 | Muy alto | Tras completar algunos mundos tier 2 | Vía Láctea colonizada (tier a confirmar), … |

- **Largo variable:** no todos los mundos tienen 10 niveles. Algunos pueden tener 2, 3 o 4; otros 7 u 8, y algunos más de 10. El largo se elige según lo que pida cada mundo (un planeta chico puede ser una visita corta, una saga mitológica puede ser larga).
- La Máquina muestra los mundos bloqueados con su requisito, para que el jugador sepa qué le falta.
- Cada mundo tiene su propio botín temático: armas e ítems que solo se consiguen ahí y que el jugador se lleva al resto del multiverso.

### 3.4 Mundos confirmados

- **Saga de Asgard (nórdico, tier 1):** recorrer los lugares clásicos de la mitología nórdica (Asgard, Jotunheim / el planeta de los gigantes, etc.); varios jefes, entre ellos un encuentro con **Loki**. Botín estrella: **Martillo de Thor**, que lanza un rayo que rebota entre todos los enemigos cercanos.
- **Mitología griega (tier 1):** encuentros con **Zeus**, **Poseidón**, **Eolo** y otros dioses. Botín estrella: **Rayo de Zeus**, arma mágica que dispara rayos (diferenciarlo del martillo: el martillo encadena, el rayo puede ser disparo directo o caída desde el cielo).
- **Futuro (tier 2):** el año 3000 o 5000; armas e ítems súper tecnológicos, por ejemplo **teletransporte** (puede reusar la baliza de translocación en stand-by).
- **Vía Láctea colonizada (tier 3 tentativo, a confirmar):** toda la galaxia está habitada y **cada planeta colonizado es un mundo propio**, con su estética, sus bichos, sus ítems para farmear y sus **tecnologías propias** que solo se consiguen ahí. Se avanza con misiones de un planeta a otro. Pensar si los planetas se eligen desde la Máquina como cualquier mundo o desde un mapa estelar que se abre al llegar a la galaxia, y si todos comparten el mismo tier.
- **Medieval fantástico (tier 1):** el Valle Esmeralda del Capítulo 2 pasa a ser uno de estos mundos.
- **Steampunk (tier 1):** la Periferia Subterránea (Capítulo 1 actual), sin cambios. Propuesta: es la primera puerta.
- **Infierno (tier 1):** el Abismo Ígneo (Capítulo 3); lore en `lore.md`.
- **Infierno (tier 1):** el Abismo Ígneo del Capítulo 3 pasa a ser uno de estos mundos.
- **Páramo Radiactivo (tier a definir):** mundo devastado tipo *Fallout*; criaturas con un aura de radiactividad que daña al jugador si está cerca (implementación probable: un `Area2D` de daño por segundo alrededor del enemigo). Recompensa final: **Reactor portátil** (uso a definir). Lore en `lore.md`.
- **Mencionados sin detalle:** Mundo de hielo. Más mundos los va a definir el usuario.

### 3.5 Historia (por escribir)

Borrador de trama en `story.md` y reglas del universo en `lore.md`. Preguntas que esos archivos todavía tienen que cerrar:

- **¿Quién es el personaje y por qué encuentra la Máquina?** ¿Fue casualidad, la buscaba, o alguien la dejó para él?
- **¿Para qué viaja de mundo en mundo juntando ítems?** Opciones a debatir: reparar o completar la Máquina; reunir artefactos legendarios (martillo, rayo, etc.) para enfrentar a quien controla a los Agentes; rescatar a alguien perdido en el tiempo; evitar que los Agentes "borren" su línea temporal.
- **¿Quiénes son los Agentes del Tiempo y por qué lo persiguen?** ¿Guardianes del orden temporal, una corporación del futuro, los dueños originales de la Máquina?
- **¿Por qué hay una copia de la Máquina en cada mundo?** Es una pista natural para el misterio central de la historia.
- **¿Cuál es el final?** Un jefe último (¿el líder de los Agentes?) en el tier más alto.

### 3.6 Motor de cinemáticas

Para contar la historia hace falta un sistema de escenas que se arme con datos, no con código a mano en cada escena.

- **Qué tiene que poder hacer:** traer personajes a escena y moverlos (caminar, correr, saltar, girar); diálogos cortos tipo subtítulo mientras los personajes siguen moviéndose, con respuestas entre personajes; cámara con **acercamiento a las caras**, paneos y seguimiento; pausas, esperas y efectos (sacudón, fundido, destellos, sonido).
- **Formato:** cada cinemática como una lista de pasos en un recurso (`.tres`) o un archivo de texto simple, por ejemplo `mover A hasta X`, `decir A "..."`, `enfocar cara B`, `esperar 1 s`. Pasos en paralelo para que alguien hable mientras camina.
- **Subtítulos:** frases breves con nombre de quien habla y retrato opcional; avanzan solas por tiempo o con un botón; opción de saltar la cinemática entera.
- **Dónde se usan primero:** el encuentro con la Máquina tras el jefe del presente, la primera aparición de los Agentes del Tiempo, la llegada a cada mundo y la presentación de cada jefe (Loki, Zeus, etc.).
- **Técnico:** Godot ya trae `AnimationPlayer` y `Tween`; el motor puede ser un intérprete de pasos que los use, con la `Camera2D` del nivel y los rigs de personaje existentes (`character_rig.gd`). Bloquear el control del jugador y la IA de enemigos mientras corre.
- **Pendiente de decidir:** si los textos pasan por `tr()` desde el inicio (traducción futura) y si habrá voces.

### 3.7 Impacto en lo que ya existe

- **Capítulos → mundos:** `level_registry.gd` hoy ordena capítulos 1 a 5 en línea con 10 sectores fijos; habrá que admitir una cantidad de niveles distinta por mundo y pasar a mundos con tier y requisito de desbloqueo, elegidos desde la Máquina en vez de desde el `map_selector` lineal.
- **Hub:** la Máquina puede vivir en el hub (con acceso desde el presente tras el jefe) o ser una sala propia.
- **Guardado:** mundos visitados/completados, cristales y mundos desbloqueados.
- **Orden sugerido para construirlo:** (1) motor de cinemáticas básico; (2) cristales + Agentes del Tiempo como evento en niveles existentes; (3) la Máquina con selección de mundo, costo y su cinemática de descubrimiento; (4) tiers y desbloqueos; (5) reconvertir el Valle Esmeralda en el primer mundo tier 1; (6) mundos nuevos uno por uno.

---

## 4. Balance pendiente

- **Oleadas del 1-7 al 1-10:** cantidades sin revisar; las arenas de 16 a 18 pueden ser injustas. Los élites no tienen tope de vivos (corregir con `elite_per_round` o `round_sizes`).
- **Jefe del 1-10:** vida y armadura según el equipo real que llega; efecto del escudo de madera y del espejo.
- **Arena final del 1-5:** si 2 Centinelas a la vez es demasiado; si el MP5 llega tarde o temprano.
- **Casco láser:** 70 dps sostenido es alto; limitar con la barra de energía.
- **Dash:** distancia y tiempo de recarga.
- **Economía:** precios contra el ingreso real de monedas por nivel; el 40 % de compra para que vender no sea oro trivial; un casillero de consumible para el 1-3; segundo comerciante (herrero con runas) con `TraderData`.
- **Mercader en modo prueba:** `sell_everything = true` en `data/traders/merchant.tres`. Apagarlo y definir el stock real antes de una versión jugable.
- **Sockets de runas en armas del primer mundo:** sin runas hasta el Capítulo 2, ¿conviene quitárselos?

---

## 5. Arte pendiente

- **Enemigos por piezas** (ladrón, bruto, centinela): hoy son una ilustración partida en la cintura. Separar brazos y arma como el héroe (`assets/PSD`) para que golpeen de verdad. Arte a mano, luego `enemy_art.gd`.
- **Jefe del 1-10:** usa el arte del bruto agrandado; necesita el suyo.
- **Escudos en mano:** el espejo ya tiene arte propio (Flow, `assets/art/weapons/mirror_shield.png`); el de madera usa arte de respaldo.
- **Lanzallamas de combustible:** sprites de gota, charco animado, boquilla del arma e ícono de inventario (`ui/components/item_icons.gd`).
- **Frostmourne:** el último cuadro de la hoja de armado (`frostmoon_spawn_sheet.png`) es un caballero y el esqueleto que camina es más simple; regenerar la hoja.
- **Íconos propios:** Botas de Súper Velocidad y los ítems nuevos que hoy usan el ícono de respaldo.
- **Haz del casco láser y boomerang:** dibujo procedural, con arte propio opcional.
- **Sombras 2D:** necesitan `LightOccluder2D` en plataformas y luces por nivel; hacerlo junto con un pase de iluminación y colgarlas del preajuste Ultra.

---

## 6. Sonido

- **Reemplazar el 8-bit provisorio por sonido de calidad** (tarea aparte, no bloquea nada): crear o importar los efectos y asignarlos arma por arma con `fire_stream` / `hit_stream`, o con `Sfx.register_override()`.
- Sin sonido a propósito: ambientes, pasos y voces.

---

## 7. Decisiones abiertas y cabos sueltos

- **Escudo:** ¿el bloqueo del escudo de madera debe ser direccional (solo de frente)? Hoy protege de todo mientras está levantado.
- **Función secundaria de arma** (p. ej. zoom del rifle de precisión): `has_secondary_function()` está listo pero ninguna arma lo usa; mientras tanto el clic derecho dispara la mano 2.
- **Nivel antiguo:** `levels/level_01.tscn` / `.gd` está sin conectar al registro; borrarlo o dejarlo.
- **Tests históricos:** `tests/test_phase4..8.gd` ya no se usan; borrarlos o dejarlos.

---

## 8. Técnico y distribución

- **Exportación a `.exe` (diferido hasta tener una versión final cercana):** instalar las plantillas de exportación 4.7.2 (Editor > Administrar plantillas), correr `build_exe.bat` y **probar el `.zip` en una PC limpia**, sin Godot. No se puede hacer desde el código.
- **Idioma y subtítulos:** hoy solo español y sin voces. Si hace falta, pasar los textos a `tr()` con un archivo de traducción.
- **Rendimiento (reabrir solo si el registro muestra caídas):**
  1. Costo de enemigos vivos: con ~100 persiguiendo bajan a 45-48 FPS (CPU: IA y física, ~4 `Area2D` por enemigo). Auditar sensores, capas y máscaras; IA y animación más baratas fuera de cámara.
  2. Instanciado: 2 a 4 ms por enemigo al aparecer; evaluar pool de enemigos.
  3. Liberación repartida de enemigos tras una masacre (el cuadro del golpe ronda 55 ms con 300 muertes).
  - **Criterio:** 100 enemigos persiguiendo a 60 FPS estables y 200 jugables en la Sala de Estrés (tabla "FPS según enemigos vivos" del monitor, F9).
  - **Hecho (sesión del 2026-10-13):** `ViewCull` (dormir animación y redibujado fuera de cámara), tope y reciclaje de charcos de ácido/gas/fuego/redes, barra de vida de un solo nodo, enemigos lejanos como un sprite (opción `enemy_lod`), estilos de fuego y ácido sprites/partículas/shaders (opción `fire_style`), pool de proyectiles con lista de libres. En la Sala de Estrés: lluvia del cielo (F9/F11) con ácido, granadas, fuego y balas.
  - **Medido:** los shaders rinden igual o un poco mejor que los sprites y las partículas son 10-25 % más caras (en cuadros de 40-160 charcos/s). Lo caro eran las `draw_circle` de las gotas, no las áreas.
  - **Hecho (sin medir en F9):** pool de efectos de disparo (fogonazo, humo y chispas de `combat/shot_fx.gd`, hasta 40 por tipo; al cerrar el juego Godot avisa de recursos sin liberar por esa reserva, es ruido esperado).
  - **Pendiente:** pool de granadas, física de enemigos lejanos más barata, cartel de estados creado recién al quemarse/congelarse, nubes de gas con estilo partículas/shader.

---

## 9. Cómo trabajar las tareas de acá

- Una tarea por sesión, chica y verificable. Si una tarea parece pedir esfuerzo alto, partirla.
- Sonnet con esfuerzo medio por defecto; Haiku para cambios de valores en `.tres`.
- Cambios de valores: tocar solo los valores indicados, sin escenas ni scripts nuevos.
- No hacer commit ni push sin que el usuario lo pida.
- Al cerrar una tarea: actualizar `PROJECT_CONTEXT.md` solo si cambió un archivo de entrada o una regla, y borrar la tarea de este archivo.
