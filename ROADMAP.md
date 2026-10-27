# ROADMAP — Lo que falta hacer

Solo figura lo pendiente. Lo ya construido se documenta en `PROJECT_CONTEXT.md` (mapa técnico) y en el historial de git. Cuando algo se termina y se valida, se **borra de acá**.

**Estado en una línea:** el primer mundo está completo (sectores 1-1 a 1-10 con jefe), con armas, runas, escudos, invocaciones, comercio, opciones y herramientas de editor. Falta validarlo a mano, balancearlo, darle arte y sonido finales, y validar los Capítulos 2 (Valle Esmeralda) y 3 (Abismo Ígneo), ya armados.

---

## 1. Validar a mano (armado, sin verificar en F5)

Marcar y borrar cada punto al comprobarlo. Si algo falla, pasa a la sección 4 o 7.

- [ ] Manchas de sangre y tripas en el piso: ahora usan `assets/sprites/efectos/blood_pool_0..3.png` con el método del charco de ácido (cuelgan, se aplastan, rebotan al aparecer). Revisar tamaño y que no ensucien con muchos enemigos (`combat/blood_fx.gd`, `POOL_WIDTH_MULT`).

- [ ] **Calle (1-01), pase de ritmo del 2026-10-18:** jugarla entera; primer matón suelto en el px 19700 y tres arenas nuevas sin armas de fuego (px 22000 ladrones + matón; 28800 ladrones + matones; 32800 ratas 8/10/12 + matones) con checkpoints antes (21100, 28000). Ver si el matón es demasiado resistente en grupo.
- [ ] **Ataque con aviso y niveles de enemigo (2026-10-18):** probar que los enemigos de melé se frenan, se ve la animación de ataque y recién ahí pegan (tocarlos ya no lastima), y que se puede esquivar saltando o alejándose. Ajustar `PROFILES` de `entities/enemies/melee_attack.gd` (aviso, descanso, alcance) por tipo. Verificar que el aviso se lea en los enemigos de ilustración partida (matón, patovica: solo se inclinan y se lanzan). Niveles: rata 1, ladrón 2, matón y asaltante 3, rata gigante 4, patovica 5, sicario 6, agente 7, élite 8; desvío por mundo en `LevelBase.CHAPTER_ENEMY_LEVEL_OFFSET` (2: +6, 3: +8, 4: +4, 5: +12; valores a ojo, ajustar). Con 4 niveles o más de diferencia no dan experiencia.
- [ ] **Obstáculos rompibles (2026-10-18):** barriles, cajas, tachos, bolsas de basura y buzones de los niveles del mundo 1 (`destructible = true` en `WorldProp`, vida en `BREAKABLE_HEALTH` de `art_source/world1/bake_decor_props.py`) se rompen a tiros, tajos y explosiones, con tres dibujos (`<arte>_dmg1/_dmg2.png` al 66 % y 33 % de vida, generados por `bake_prop_damage.py`; se pueden pisar con arte de Flow). Al romperse sueltan trozos y, con poca chance, una moneda (7 %), experiencia (4 %), munición (2,5 %), vida (1,2 %) o el powerup de munición (0,5 %): ver los `loot_*_chance` del prop. Probar sensación, vida de cada prop, que no estorbe subir escalones de props y si conviene ampliar a contenedores o a otros mundos.
- [ ] **Sectores 1-5 a 1-10:** recorrerlos completos; que ningún enemigo quede trabado y que las arenas de 12 a 18 enemigos sean jugables.
- [ ] **Rework de oleadas 1-2 a 1-6:** bruto solo en el 1-4, 10 ladrones en el 1-3, ritmo general.
- [ ] **Jefe del 1-10 (Coloso del Núcleo):** si 1200 de vida es mucho o poco, y si la franja roja de la onda de choque se lee a tiempo.
- [ ] **Escudo de madera y Escudo espejo:** sensación del clic derecho mantenido, tamaño de la zona de reflejo, rebote contra plataformas reflectantes.
- [ ] **Red arraigadora, Boomerang, Casco láser, Capa de invisibilidad:** que se compren, se usen desde la barra y se sientan bien (en especial el robo de la capa y el 70 dps del láser).
- [ ] **Mjolnir (arma pesada legendaria):** rayo en cadena de 7 rebotes al conectar un golpe melee (`data/weapons/mjolnir.tres`, `combat/chain_lightning.gd`); probar balance (daño 140, rayo 50%), sensación y que el martillo en mano calce (agarre/escala en `weapon_art.gd`). Está en el Banco de Pruebas y en el comerciante.
- [ ] **Invocaciones separadas (Fase J):** seis esqueletos en la Sala de Estrés; que 70 px de distancia sea buena.
- [ ] **Opciones (segunda tanda):** cuenta regresiva de 15 s al cambiar resolución, selección de monitor, reasignación de mando, dificultades, accesibilidad, posprocesado por calidad.
- [ ] **Animaciones de arma:** recarga propia por arma, ráfaga sostenida de las automáticas, tajo de espada y katana a dos manos, doble empuñe y casillero M2.
- [ ] **Posturas con 3 alturas de disparo (2026-10-19, hecho, sin validar jugando):** de pie (arma a -54), agachado con rodilla en tierra (mantener abajo, arma a -35, 40 px) y cuerpo a tierra (doble toque de abajo o Alt; arma a -10 adelante de la cabeza, 18 px, se arrastra al 30 %, apunta ±22°; arriba/salto/Alt levanta). Los enemigos apuntan al centro del cuerpo en la postura actual: cambiar de postura esquiva tiros en vuelo. Constantes en `player.gd` y `character_rig.gd`.
- [ ] **Pulido visual:** aura de los objetos del piso, pose agachado, brazos abiertos al saltar, borde rojo y latido con poca vida, llama sobre enemigos que arden.
- [ ] **Progresión:** con 15 de EXP por enemigo, en qué punto del 1-2 se llega al nivel 5; presión de enemigos con la vida subida (ladrón 70, bruto 250, centinela 70).
- [ ] **Piezas de editor:** armar una arena y una plataforma desde `platform.tscn` / `arena.tscn`, y correr un nivel con F6 y el equipo de prueba activo.
- [ ] **Props arrastrables (nivel 1):** `entities/world/props/` (cajas S/M/L, cerco, casa, caseta, **paredón** `wall.tscn`; script `world_prop.gd`). Los bloques `Block*`/`JumpBlock*` de los niveles ya son props placeholder (cajas) y 2_02, 2_08, 3_04, 3_08, 4_01 y 4_04 llevan un paredón de 520 px caminable por arriba (`WallStep` + `Wall`); PNG pendientes: `crate_*`, `wall`, etc. En el mundo 1 la decoración automática (`levels/city_decor.gd`, `SOLID_PROPS`) pone contenedores, tachos, buzones, bancas y cajas como sólidos escalonados (grupos de 1 a 3, alturas 48–115 px); los enemigos los saltan (`entities/enemies/obstacle_hop.gd`). Pendiente: lo mismo para `meadow_decor` / `hell_decor`. Generar con Flow los PNG en `assets/art/world4/props/` con el nombre de la escena (`crate_small.png`, `house.png`...), probar saltos en `levels/chapter_4/props_playground.tscn` y ajustar tamaños/hitboxes.
- [ ] **Capítulo 2 — Valle Esmeralda (hecho, sin verificar):** recorrer 2-1 a 2-10; saltos de los pozos reales del 2-4 y 2-7; balance de Arco Largo, Jabalina, Báculo de Fuego y de Hielo (`data/weapons/*.tres`); agarre en mano del arco y los báculos (`weapon_art.gd`); densidad de árboles/flores y cantidad de hojas (`levels/meadow_decor.gd`); jefe del 2-10. Al entrar al mundo 2 el jugador conserva su arsenal del mundo 4 (las armas medievales llegan por pedestal).
- [ ] **Capítulo 3 — Abismo Ígneo (hecho, sin verificar):** recorrer 3-1 a 3-10; saltos de los pozos de lava del 3-3, 3-5 y 3-7; balance de Guadaña, Ballesta Infernal, Tridente Infernal, Báculo de Almas (3 rebotes), Cetro de Azufre (estallido `combat/throwables/sulfur_burst.tscn`), Espada Demoníaca y Hacha del Abismo (`data/weapons/*.tres`); agarre en mano de la ballesta, la guadaña y el hacha (`weapon_art.gd`, `ALIASES` en `weapon_motion.gd`); oscuridad de fondos y suelo (`CHAPTER_THEMES` en `level_skin.gd`); cantidad de brasas, cadenas y braseros (`levels/hell_decor.gd`); **lava que daña** (20 % de la vida + llama + rebote de 800 px/s al tocarla, `LAVA_DAMAGE_FRACTION` / `LAVA_BOUNCE`: que se pueda salir del pozo y no sea injusta); jefe del 3-10 (reusa `brute_boss`).
- [ ] **Capítulo 1 — El Presente (hecho, sin verificar):** recorrer P-1 a P-8 con una partida nueva (el P-1 se rehízo: arranca sin armas, cuchillo en el piso, ratas de a 1-2-3 a modo de tutorial y un asaltante esperando al final que deja la 9 mm; sin props ni obstáculos ni cinemáticas). Revisar: legibilidad de lluvia y fondos (`CHAPTER_THEMES[4]` en `level_skin.gd`), escala de props de `city_decor.gd` (`SECTORS`), pozos de agua del P-3 y P-5, balance de ratas/ladrones/matones/asaltantes/patovicas/sicarios (`entities/enemies/city_*.tscn`, `armed_enemy.gd`), evento del helicóptero del P-5 y el portal de P-6/P-7, cristales de tiempo en el HUD, textos y tiempos de las 7 cinemáticas (`core/cinematics/cinematic_library.gd`), oleadas del P-8 y salida por la Caja a `level_4_01`. FPS con lluvia y muchos enemigos en la Sala de Estrés (F9).
- [ ] **Música de la discoteca:** poner `ost/club.ogg` (el 4-7 ya pide la pista `club`).
- [ ] **Arte del presente por pulir:** el rig de Gunther (`art_source/world1/gunther_parts.jpg` está bajado pero no se usa; hoy sigue el rig actual), enemigos con una sola ilustración (sin ataque propio), toldo y escalera de incendio como plataformas (hoy chapa y madera lisas).
- [ ] **Sonido:** `fire_ignite`, `net_deploy`, `laser_beam`, `cloak_on/off`, `heartbeat`.

---

- **Mangual** (2026-10-19, `data/weapons/mangual.tres`): melé a una mano con el movimiento de la espada, arco de 230°, más alcance, empuje y 30% de perforación de armadura. Pedestal en la Armería Melee del Banco de Pruebas. Validar balance y sensación (la cadena no se mueve: el arte es una sola pieza).
- **Casco Láser estilo Cíclope** (2026-10-19): el rayo de P ahora es un haz rubí ancho que sale del visor, con chispas en el impacto y más empuje (140). Validar que no empuje demasiado.

- **Tanda noir del mundo 1: 4 armas y 4 ítems (2026-10-19, hecho, sin verificar):** Bate con Clavos (`data/weapons/nail_bat.tres`, melé pesada a dos manos, común), Escopeta Recortada (`sawed_off.tres`, a una mano, 2 tiros, 7 perdigones), Pistola de Bengalas (`flare_gun.tres`, 1 tiro, prende fuego y estalla en chispas: `combat/throwables/flare_burst.tscn`), Thompson del Sindicato (`thompson.tres`, épica, tambor de 50); Gabardina de Detective (`data/items/trench_coat.tres`, torso: +20 vida, 3 armadura), Sombrero de Ala (`fedora.tres`, cabeza: +7 % crítico, críticos +20 %), Puño Americano (`brass_knuckles.tres`, manos: +8 % daño, 1 armadura) y Cóctel Molotov (`data/items/throwables/molotov.tres`, táctico: llamarada + 3 charcos de fuego, `combat/throwables/molotov_splash.gd`). Se consiguen: en el mercader; en el Banco de Pruebas (armas en la Armería Melee, ítems en el Laboratorio Elemental); de botín de matones, patovicas y sicarios (`city_elite_loot.tres`; en la calle, `gear_loot_tier = 1`, solo bate, gabardina, sombrero, puño y molotov; en la torre, tier 2, todo); la Thompson también en un pedestal en el techo de la torre (x 950, `build_tower.py`), con frase de Gunther. **Validar:** balance (sobre todo la recortada a una mano y la Thompson), que el molotov no sea demasiado fuerte contra grupos de ratas, cuánto botín cae en la calle (6 % por élite) y el agarre en mano del arte provisorio (`weapon_art.gd`, `ALIASES` de `weapon_motion.gd`). **Arte provisorio** hecho por script (`art_source/draw_noir_placeholders.py`): armas en mano e íconos de los ítems; prompts de Flow en `add-level/politicas.md`.

- **Disparos rehechos, menos 8-bit (2026-10-19, hecho, sin escuchar en juego):** los disparos ahora son WAV de 44 kHz con chasquido, explosión por bandas, golpe grave, mecánica (corredera, bomba) y eco de edificios + reverb, 3 variantes al azar por sonido (`assets/audio/sfx/`, generados por `art_source/audio/synth_guns.py`). Perfiles: pistola, revólver (y pistolas de 60+ de daño), subfusil, automática, fusil, francotirador, escopeta de bomba, recortada, enemigo armado (más lejano), clavadora, bengala y matafuegos; también `hit_flesh`, `hit_world` (con rebote a veces) y `boom_frag`. El resto de los sonidos sintetizados perdió la degradación de bits (`LOFI = false` en `core/sfx.gd`). **Validar:** volumen relativo entre armas y contra la música, que las automáticas no cansen, y si el eco de calle sobra en las alcantarillas. Para retocar: cambiar la receta en el script, correrlo y reimportar.
- **Segunda tanda noir: 3 armas (2026-10-19, hecho, sin verificar jugando):** Clavadora Neumática (`data/weapons/nail_gun.tres`: automática a una mano, cada clavo atraviesa 2 enemigos más; pedestal en el piso 3 de la torre), Llave Stillson (`pipe_wrench.tres`: melé a una mano, cada golpe aturde 0,6 s vía `ice_duration` + `STUN`; pedestal en las alcantarillas, x 1250) y Matafuegos (`extinguisher.tres`: chorro de CO2 a dos manos, casi sin daño, congela y empuja 240; bocanadas que se frenan y crecen, `combat/foam_spray.gd`; pedestal en el piso 1 de la torre). Las tres en el Banco de Pruebas (Armería Melee, x 2500–2660), en el mercader y en el botín de élites (la llave también en la calle). **Validar:** balance (el aturdimiento encadenado de la llave contra jefes, el empuje del matafuegos para tirar enemigos de los techos), alcance del chorro (0,5 s) y agarre en mano del arte provisorio.
- **Tanda de explosivos y armas especiales (2026-10-19, hecho, sin verificar jugando):** Bazuca (`data/weapons/bazooka.tres`: cohete que acelera, 40 al pegar + 110 en área, retroceso fuerte; pedestal en el último techo de la torre, x 10480) y Bazuca Dirigida (`bazooka_guided.tres`, legendaria: cohete más lento que sigue al cursor; con mando va derecho) con `combat/rocket.gd`; Bomba Racimo (`data/items/throwables/cluster_bomb.tres`: suelta 6 bombitas) y C4 (`c4.tres`: se pega a paredes y enemigos, la tecla del arrojadizo detona todas, solo a los 25 s); Pistola de Dardos Venenosos (`dart_venom.tres`: hasta 5 dosis de 3 por medio segundo durante 4 s), Pistola de Dardos de Hechizo (`dart_charm.tres`: el enemigo pelea 6 s contra los suyos, rosa; no anda con jefes) y Pistola Taser (`taser.tres`: corto alcance, aturde 1,5 s). Sonidos nuevos en `synth_guns.py` (cohete, dardo, taser, pitido del C4). Probado por código: la bazuca mata un ladrón, el C4 se pega y detona, el racimo suelta 6 bombitas, el veneno apila, el hechizado le saca 52 de vida a otro ladrón y vuelve a la normalidad, el taser aturde. En el Banco de Pruebas (bazucas, dardos y taser en x 960–1390; racimo y C4 en x 5060–5140), en el mercader y en el botín de élites (taser también en la calle). **Validar:** balance del C4 y del racimo contra arenas, que el cohete guiado se controle bien, si el hechizo dura mucho y si el retroceso de la bazuca tira al jugador de los techos. El molotov ya estaba (tanda noir).
- **Armas míticas (2026-10-19, hecho, sin verificar jugando; todas legendarias, en el mercader y en el Banco de Pruebas junto al arranque, x -120 a 280):** Tridente de Poseidón (`data/weapons/poseidon_trident.tres`: melé a dos manos, cada estocada suelta una ola por el piso que atraviesa, empuja y ralentiza), Rayo de Zeus (`zeus_bolt.tres`: rayo casi instantáneo, estallido que aturde 0,6 s y cadena a 5 enemigos, `combat/zeus_bolt.gd`), Hacha Leviatán (`leviathan_axe.tres`: se lanza girando, congela, atraviesa a todos y vuelve sola a la mano cortando otra vez, `combat/returning_axe.gd`), Gungnir (`gungnir.tres`: lanza que busca sola al enemigo más cercano y atraviesa el terreno), Excalibur (`excalibur.tres`: cada tajo lanza una media luna de luz que atraviesa 3) y Báculo del Rey Mono (`monkey_staff.tres`: barrido de 220° con 70 px de alcance extra y mucho empuje). Mecánica nueva reutilizable: `WeaponData.melee_projectile_*` (proyectil que sale con el tajo) y `Projectile.pass_through_terrain`. Sonidos nuevos en `synth_guns.py` (trueno, ola, tajo de luz, hacha que vuela y vuelve, lanza). Probado por código: todas pegan (el hacha 125 entre ida y vuelta, Zeus 105 + cadena, Gungnir da la vuelta sola). **Validar:** balance (son fuertes a propósito), dónde se consiguen en la campaña (¿premio de jefes o de un mundo cada una?) y el agarre en mano del arte provisorio (recoloreado de armas existentes, `art_source/draw_myth_placeholders.py`).
- **Armadura de hierro estilo Iron Man (2026-10-19, hecho, sin verificar jugando; íconos por defecto):** Casco de Hierro (cabeza: 4 de armadura, +8 % crítico), Pechera de Hierro (pecho, legendaria: +40 vida, 6 de armadura y el unirrayo: el rayo del Casco Láser sale azul desde el reactor, con P), Guanteletes de Hierro (manos: +12 % daño), Botas de Hierro (vuelo propulsado como el jetpack, +20 velocidad) y Reactor de Arco (accesorio: +25 vida, +5 % daño). Archivos `data/items/iron_*.tres` y `arc_reactor.tres`, tag `IRON_SUIT` (sin bonus de set por ahora). En el Banco de Pruebas sobre la plataforma de la sala 1 (x -300 a 250) y en el mercader. **Validar:** que la plataforma se alcance, el vuelo con las botas y si conviene un bonus por traje completo.

- **Guardia Antidisturbios (2026-10-19, hecho, sin verificar jugando):** enemigo nuevo de la torre (`entities/enemies/city_riot_guard.tscn`, `riot_guard.gd` sobre el bruto): escudo frontal que deja pasar el 10 % de las balas y el 50 % de la melé de frente; por la espalda o aturdido recibe todo. Uno en el piso 2 tapando a los asaltantes y otro en el tercer techo (x 7650). 240 de vida, 20 de armadura, nivel 5; usa el arte del patovica con un escudo provisorio. Probado por código (de frente 6 de 50, por la espalda 42, aturdido 62). **Validar:** que se lea que hay que saltarlo, que no quede trabado en las tablas de los huecos y que el escudo se dé vuelta bien con el arte.

- **Barra de vida del jefe** (2026-10-19, `ui/boss_health_bar.gd`, la crea el HUD): arriba al centro con el nombre; aparece cuando un enemigo del grupo `boss` persigue al jugador o está a menos de 900 px, y la franja clara muestra el daño reciente. Vale para la Rata Gigante y el Coloso. Validar que no tape nada en los niveles.

## 1b. Nueva estructura del primer mundo (decisión del usuario, a pulir)

**El mundo 1 pasa de 10 sectores a 3 niveles.** Todo es borrador: faltan ideas y pulido. Lo anotado:

1. **Nivel 1 — La calle (el largo).** Es el que se está armando ahora (`level_1_01.tscn`, 34.000 px, ratas y asaltantes en tramos, checkpoints, obstáculos y plataformas). Acá van **la historia y las cinemáticas** (intro, el asaltante, el paseo de Gunther; ver `story.md` sección 4 y la idea de intro). Sirve de **plantilla** para armar el resto de los niveles: largo, tramos, props, checkpoints, arma inicial débil y reserva de munición.
2. **Nivel 2 — Las alcantarillas.** Gunther entra a las alcantarillas. **Se van a rehacer más adelante** (hoy es el sector 1-03 de agua y piedra); por ahora solo se reserva el lugar.
3. **Nivel 3 — La torre y los techos.** Sale de las alcantarillas a un edificio que hay que **subir derrotando enemigos y saltando entre techos de edificios**, hasta llegar al mapa final (jefe / la Caja). Es un nivel vertical de plataformas.
4. **Pendiente por esto:** `build_levels.py`, `level_registry.gd` (10 sectores fijos por capítulo), `PROJECT_CONTEXT.md`, `story.md` (tabla de sectores P-1 a P-8) y los sectores 1-02 a 1-08 actuales (se reusan como cantera de ideas, arte y enemigos, o se descartan). Decidir qué pasa con los jefes y el guardado (`unlocked_levels`, `next_level_path` del 1-01, que hoy lleva al 1-02).
5. **Ideas por definir:** cómo se lee la subida del edificio (pisos, ascensores, escaleras de incendio), qué enemigos nuevos aparecen arriba, y qué cuenta la cinemática de entrada a las alcantarillas.
6. **Historia simple (escrita el 2026-10-19, a aprobar):** `story.md` secciones 1 a 6. Gunther recibe el encargo de recuperar una caja que robó el Sindicato; persigue a un mensajero por la calle y las alcantarillas, sube la torre y en la azotea Víctor Valmont, el Patrón (jefe del Sindicato), abre la Caja y huye por el pasillo de puertas. Cada mundo: el Patrón hizo un trato con el jefe local, Gunther lo derrota, se queda con su arma y lo sigue. Agentes del Tiempo como estorbo que suelta cristales. Plantilla por mundo: 3 niveles + jefe, una mecánica propia, 2-3 armas de época, 3 escenas cortas. Nombres elegidos: Víctor Valmont y La Voz (contacto por teléfono). Falta: arma de cada jefe, orden de mundos, y alinear `lore.md` (todavía menciona al compañero muerto, que quedó fuera).

7. **Orden de trabajo (decisión del usuario):** primero mapas, combates y mecánicas; después historia y cinemáticas. Mientras tanto, los puntos de historia quedan sin cinemática (se borraron todas el 2026-10-18; el motor está en `core/cinematics/` y se prueba en el Banco de Cinemáticas) y los textos de pantalla quedan como carteles provisorios, para no rehacer nada cuando llegue la historia.

8. **Nivel 2 — Las alcantarillas (rework hecho el 2026-10-18, sin validar jugando).** `levels/chapter_1/level_1_03.tscn`, generado por `art_source/world1/build_sewer.py` (aparte de `build_levels.py`, que reescribe todo). Pasillo de 16.000 px con **piso y techo**, solo **ratas** (sin personas, sin emboscadas del mundo 1), **charcos** (huecos de agua) con tablones para cruzar, ruta alta opcional, 4 checkpoints, dos arenas de ratas (LA PLAGA, EL NIDO) y al final la **Rata Gigante** (`entities/enemies/giant_rat.tscn`: 1100 de vida, persigue, sin mecánicas todavía) tras una ronda de ratas. Hay **ratas de techo** (`ceiling_rat.gd`): caminan cabeza abajo por el techo hacia el jugador y, al quedar encima, se frenan un instante (chillido) y se sueltan; al caer son ratas comunes. Suenan **goteos** sintetizados (`levels/sewer_ambience.gd`, sonido `drip`). La Rata Gigante suelta la **Flauta de Hamelin** (`data/items/hamelin_flute.tres`, accesorio): las ratas que se acercan al portador pasan a ser **aliadas** (`rat_ally.gd`, hasta 8, muerden a los enemigos; `hamelin_flute_controller.gd`). El 1-01 ahora lleva directo a este nivel (el 1-02 queda fuera del camino); este nivel apunta al 1-04, que ahora es la torre (punto 9).
   - **Botas de Goma** (`data/items/sewer_boots.tres`: +20 de velocidad, +2 de armadura, se equipan solas) en el piso al arrancar (x=600), puestas desde `build_sewer.py` con `L.item`. Ícono pendiente (`assets/art/items/sewer_boots.png`, hoy cae al pixel art de reserva).
   - **Sprites y audio pendientes de este nivel** (arte generado por el usuario en Flow; los prompts están en `.claude/skills/add-level/politicas.md`): ícono de la Flauta de Hamelin (hoy usa el de anillo), sprite propio de la Rata Gigante (hoy es la rata común agrandada 4,5x), rata aliada (hoy la rata común con tinte verde), rata de techo (hoy la rata común volteada en vertical; podría tener cuadros propios agarrada al techo), props propios de alcantarilla (tuberías, rejillas, goteras; hoy solo los decorados sueltos del 1-03), goteos y ambiente reales (hoy sintetizados), música propia del nivel y del jefe.
   - **Mecánicas de la Rata Gigante (2026-10-19, sin validar jugando):** embestida con aviso (se agacha temblando y chilla 0,75 s, corre a 560 px/s, 26 de daño y empuje; se esquiva saltando; al chocar o terminar queda aturdida 0,9 s), llamado de la plaga (cada 11 s salen 3 ratas a sus costados, tope 7 vivas; mueren con ella) y furia bajo el 40 % (roja, más rápida, embestida y crías más seguidas). Valores en las constantes de `entities/enemies/giant_rat.gd`. Validar que la embestida se lea y se pueda esquivar en el pasillo.
   - **Canto de la flauta (2026-10-19, sin validar jugando):** tecla J (remapeable, sin botón de mando todavía: están todos ocupados) hechiza ratas hasta 760 px, renueva a las aliadas y llama ratas del suelo si hay menos de 3; recarga 20 s (`hamelin_flute_controller.gd`). Falta un indicador de recarga en la UI.

9. **Nivel 3 — La torre y los techos (armado el 2026-10-18, sin validar jugando).** `levels/chapter_1/level_1_04.tscn` (id `1_04`, reemplaza al viejo "barrio de casitas"), generado por `art_source/world1/build_tower.py` (como el de las alcantarillas, aparte de `build_levels.py`, que ya no genera el 1-03 ni el 1-04). 12.000 px. **Torre** (x 0–2000): planta baja + 3 pisos de 400 px de alto; cada losa deja un hueco de 330 px alternando derecha/izquierda y en el hueco hay tres tablas de una vía (`one_way_collision`, a 100/200/300 px) que se suben saltando de a 100 px. Pared del fondo oscura con ventanas tenues (`TowerBack`, placeholder). Enemigos: ladrones y matones en la planta baja, arena de recepción en el piso 1 (ladrones + matones), asaltantes y el SMG en el piso 2, patovica y arena de seguridad en el piso 3. **Techos** (x 330–12000): cinco edificios separados por huecos al vacío (110 a 330 px; los de más de 130 llevan una tabla de 120 px al medio), cajas de cobertura, sicarios, una arena de azotea (asaltantes + patovicas) y la arena final EL SINDICATO (sicarios + patovicas) junto a la salida, que lleva al 1-08 (la azotea con la Caja). Caer de los techos devuelve al último checkpoint: `LevelBase.abyss_after_x` / `abyss_threshold_after` (a la derecha de la torre el vacío empieza más arriba). Decoración de azotea solo sobre los techos (`prop_max_y` en `city_decor.gd`); sin lluvia (nace en y = -20). Cámara con `limit_top` alto.
   - **Validar:** que las tres tablas de cada hueco se suban sin trabarse (el salto llega a ~138 px), que ningún enemigo quede en otro piso sin poder llegar, que los saltos entre techos sean justos y que la cantidad de enemigos (sin balancear) sea jugable. Los enemigos sueltos de otros pisos esperan escondidos hasta que el jugador está a ±260 px de altura (`ambush_director.gd`).
   - **Pendiente:** props y fondo propios de la torre (interior con pisos, oficinas, ascensor, escalera de incendio; hoy ventanas planas y la losa con ladrillo), enemigos nuevos de la subida, cinemática de entrada y de salida a los techos, y música propia. Prompts de arte en `.claude/skills/add-level/politicas.md`.

---

## 2. Contenido nuevo

1. **Mundo del presente:** armado (ver sección 1). Falta validarlo y pulirlo; `PROMPT_MUNDO_MODERNO.md` queda como referencia del plan.
2. **Capítulo 2 (pendiente sobre lo armado):** enemigos con aspecto medieval propio (hoy reusa zombis, ladrones, brutos, fantasmas y centinelas) y un jefe propio para el Rey Caído; runas y movilidad avanzada; HUD sin estética steampunk en este mundo.
3. **Capítulo 3 (pendiente sobre lo armado):** enemigos demoníacos propios (hoy reusa los mismos cinco tipos) y un jefe propio para el Señor del Abismo; sonido de lava y braseros.
4. **Capítulos 4 y 5** y el total de 50 niveles. Sin fecha.
5. **Reintegrar mecánicas en stand-by** (ya existen en código, fuera de la campaña): jetpack, alas, vuelo mágico, gancho de anclaje, baliza de translocación, runas avanzadas, mercenarios y drones, contratos de zona. Decidir en qué capítulo entra cada una.
6. **Tramos prearmados (a mano):** hecho el formato base en `levels/chunks/` (ver su README): escenas que se arrastran dentro de un sector y toman el tileset del mundo. Pendiente: más tramos (plataformas, interiores, azoteas), probarlos en un sector de verdad, y un generador que los una con semilla si hace falta.

---

## 3. Visión: el multiverso y la máquina del tiempo

Idea rectora del juego a largo plazo. Todavía es diseño, no hay nada armado. Los mundos se van a ir sumando a medida que el usuario los defina; no inventar mundos nuevos sin consultarlo.

### 3.1 Estructura general

1. **Mundo inicial — el presente:** ciudad moderna, de noche y con lluvia (8 sectores: calle, callejones, alcantarillas, barrio de casitas, muelle, hotel, discoteca, azotea). Es un mundo nuevo; plan de trabajo en `PROMPT_MUNDO_MODERNO.md`. La Periferia Subterránea (steampunk, Capítulo 4 actual) queda tal cual y pasa a ser un mundo tier 1.
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
- **Steampunk (tier 1):** la Periferia Subterránea (Capítulo 4 actual), sin cambios. Propuesta: es la primera puerta.
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
- **Presets de acciones (pedido 2026-10-17):** las acciones vienen prearmadas y el motor solo las encadena — acercarse, apuntar/amenazar, disparar, arrodillarse, hablar, morir, arrojar un objeto, etc. — más pasos de cámara (enfocar a alguien, panear de un actor a otro, seguir un proyectil, cámara lenta) y de escena (iniciar música, hacer aparecer a alguien fuera de cámara). La idea es tener muchos presets para armar escenas fácil. Hoy existe un intérprete básico en `core/cinematics/` (`focus`, `spawn`, `say`, `move`, `par`, `shake`, `release`): crecer desde ahí.
- **Pendiente del motor (pedido 2026-10-18):**
  - **Apertura del juego:** arranca en negro con subtítulos y narración; a los segundos aclara (`fade`) y enfoca una ventana de edificio con la silueta de una persona detrás del vidrio. Solo imágenes fijas 2D, sin video. Se arma con los pasos que ya existen (`fade`, `say`, `wait`, `bg`, `show`).
  - **Narración:** `say` debe aceptar un audio (voz en inglés) y un subtítulo en español por separado, sin retrato; el subtítulo dura lo que dura la línea. Hoy no verificado si `say` reproduce audio.
  - **Enfoque por punto:** `focus` hoy recibe un `id` de personaje; hace falta uno que reciba `x`, `y` y `zoom` para encuadrar un lugar (una ventana, un cartel).
  - **Saltar la cinemática** con una tecla, dejando la pantalla limpia (sin negro pegado).
  - **Voces:** la elegida es en inglés (ElevenLabs); los textos en español quedan como subtítulos. Guion del primer plano en la conversación; pendiente guardarlo en un archivo.
- **Primera escena a armar con eso — el asaltante del P-1** (hoy el asaltante solo espera y pelea normal, en `level_1_01.tscn`):
  ```
  CINEMATIC START / MUSICA START
  CAMARA enfoca al personaje principal
  fuera de cámara aparece el ASALTANTE; CAMARA panea hacia él
  ASALTANTE dice "Dame la guita, amigo" + acción apuntar/amenazar
  CAMARA vuelve al personaje principal
  PERSONAJE arroja el cuchillo hacia el asaltante
  CAMARA sigue al cuchillo, alternando cámara lenta y rápida, hasta que en cámara lenta impacta
  ASALTANTE animación de muerte → muere
  ```

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
- **Hojas de sprites de animación por enemigo:** la **rata** ya está hecha (caminar, ataque, golpe, cadáver; `MOB_FRAMES` en `enemy_art.gd`). Faltan ladrón, matón, pistolero, patovica, sicarios y agente del tiempo; receta y prompts en `.claude/skills/add-enemy/animacion.md`.
- **Jefe del 1-10:** usa el arte del bruto agrandado; necesita el suyo.
- **Escudos en mano:** el espejo ya tiene arte propio (Flow, `assets/art/weapons/mirror_shield.png`); el de madera usa arte de respaldo.
- **Lanzallamas de combustible:** sprites de gota, charco animado, boquilla del arma e ícono de inventario (`ui/components/item_icons.gd`).
- **Frostmourne:** el último cuadro de la hoja de armado (`frostmoon_spawn_sheet.png`) es un caballero y el esqueleto que camina es más simple; regenerar la hoja.
- **Íconos propios:** Botas de Súper Velocidad y los ítems nuevos que hoy usan el ícono de respaldo.
- **Haz del casco láser y boomerang:** dibujo procedural, con arte propio opcional.
- **Emboscadas del Mundo 1** (`levels/ambush_director.gd`): los enemigos sueltos arrancan escondidos; las ratas saltan del tacho más cercano o salen por la abertura baja dibujada en cada edificio, y los humanos salen por sus puertas (salidas marcadas en `levels/building_exits.gd`, generado por `art_source/world1/process_buildings_2d.py`; sin salida cerca, de la penumbra). Falta validar en juego las distancias de disparo (200 ratas / 620 humanos) y el arte 2D plano de los obstáculos (tachos, pila de cajas) con fondo croma: `flow_tools.py split --bg green`.
- **Atmósfera (pase de luz y color):** Fase 1 hecha en el Sector 1-01: gradación noir por sector (`grade` en `level_skin.gd`, shader en `core/post_fx.gd`), faroles con cono de luz y charco, uno que parpadea (`lamps` en `city_decor.gd`) y halo cálido detrás del jugador (`player_glow`). Falta: validar en juego, extender a los demás sectores y mundos con su paleta (alcantarilla verdosa, discoteca, infierno), y las fases siguientes: vida en el fondo (vapor, polvo, ceniza), sonido por tramo y frases de Gunther por zona.
- **Sombras 2D:** necesitan `LightOccluder2D` en plataformas y luces por nivel; hacerlo junto con un pase de iluminación y colgarlas del preajuste Ultra.

---

- Mangual: arte provisorio dibujado por script (`art_source/draw_mangual_placeholder.py`); falta `assets/art/weapons/mangual.png` de Flow (ver prompt en `add-level/politicas.md`).

## 6. Sonido

- **Reemplazar el 8-bit provisorio por sonido de calidad** (tarea aparte, no bloquea nada): crear o importar los efectos y asignarlos arma por arma con `fire_stream` / `hit_stream`, o con `Sfx.register_override()`.
- Sin sonido a propósito: ambientes, pasos y voces.
- **Frases sueltas de Gunther (hecho, sin verificar en F5; 2026-10-19):** dice líneas cortas como subtítulo mientras avanza (al pasar puntos de 1-01, alcantarillas y torre, al ver por primera vez cada tipo de enemigo, arenas, checkpoints, vida baja, racha de bajas, reaparecer, quedarse quieto y jefe). Textos y reglas en `data/dialogue/gunther_lines.gd`; lógica en `levels/gunther_lines.gd` (lo crea `LevelBase`). **Voces:** grabar `assets/voice/gunther/<id>.ogg` con el id de cada frase y suenan solas. Revisar en juego frecuencia y textos.
- **Música invocada:** la música de pelea ya no salta con cualquier enemigo. La invocan las arenas (`ArenaEncounter.combat_music`, por defecto `combat`) y los enemigos configurados (`EnemyBase.combat_music`; jefes → `boss` y élites → `elite` por defecto). Falta decidir qué enemigos/arenas de cada mundo llevan pista propia y, si se quiere, temas distintos por arena.

---

## 7. Decisiones abiertas y cabos sueltos

- **Escudo:** ¿el bloqueo del escudo de madera debe ser direccional (solo de frente)? Hoy protege de todo mientras está levantado.
- **Función secundaria de arma** (p. ej. zoom del rifle de precisión): `has_secondary_function()` está listo pero ninguna arma lo usa; mientras tanto el clic derecho dispara la mano 2.
- **Nivel antiguo:** `levels/level_01.tscn` / `.gd` está sin conectar al registro; borrarlo o dejarlo.
- **Tests históricos:** `tests/test_phase4..8.gd` ya no se usan; borrarlos o dejarlos.

---

## 8. Técnico y distribución

- **Exportación a `.exe` (diferido hasta tener una versión final cercana):** instalar las plantillas de exportación 4.7.2 (Editor > Administrar plantillas), correr `build_exe.bat` y **probar el `.zip` en una PC limpia**, sin Godot. No se puede hacer desde el código.
- **UI modular y Códice (2026-10-19, hecho; jugabilidad sin verificar):** tema intercambiable `ui/themes/steam_theme.tres` (texturas, colores, fuentes; SteamSkin lo lee), base `GameWindow` + `UiKit` + `WindowRegistry` en `ui/framework/`, skill `add-window`. Primera ventana: Códice [O] con enemigos (se registran al matarlos, con lore) y armas (al conseguirlas), guardado en el slot. Pendiente si se quiere: migrar las ventanas viejas (`.tscn`) a `GameWindow`; retratos para Fantasma y Zombi (hoy sin imagen).
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
