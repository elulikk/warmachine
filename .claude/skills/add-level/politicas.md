# Políticas vigentes y registro de lo que se rehízo

Leer al empezar cualquier trabajo de niveles, enemigos, ítems o arte. **Actualizar al terminar** (agregar una línea en el registro de abajo y, si cambia una regla, en las políticas).

## Políticas (decididas por el usuario)

1. **Prohibido generar arte o audio desde el navegador por mi cuenta (desde 2026-10-18).** No usar el skill `google-flow`, `generate-audio` ni `parallax-level-background` para generar, ni Claude in Chrome (`mcp__claude-in-chrome__*`): gasta mucha cuota. Solo se levanta si el usuario lo pide de nuevo en palabras.
2. **Arte nuevo = prompts para el usuario.** Si un nivel necesita props, edificios, enemigos o fondos que no existen, antes de armarlo dar una lista: nombre del archivo, tamaño en juego (px), proporción, y un prompt listo para pegar en Flow. El usuario los genera y pasa los archivos; mientras tanto se usa arte existente o bloques de color de prueba (`WorldProp` sin arte).
3. **Orden de trabajo:** primero mapas, combates y mecánicas; después historia y cinemáticas (dejar ganchos `cine` vacíos).
4. **Plantilla de diseño:** `LEVEL_DESIGN.md` (largo, ritmo, tramos, props, línea del piso). Mundo 1 = 3 niveles (calle, alcantarillas, torre y techos): ver `ROADMAP.md` sección 1b.
5. **Pruebas siempre sin sonido** (`--audio-driver Dummy`, ya en `smoke.sh`).
6. **Un nivel editado a mano no se regenera:** `build_levels.py` borra lo hecho a mano (el 1-01).
7. **Nivel 1 (calle): nada de arenas con asaltantes ni armas de fuego** (decisión del usuario 2026-10-18: demasiado peligroso al principio). Arenas del mundo 1 solo con ratas, ladrones y matones hasta más adelante.
8. **Commit/PR solo si lo pide;** `gh` no está instalado (dar el enlace `compare`).

## Registro de sprites y arte rehechos

(Agregar: fecha · qué · archivo · quién lo generó)

- 2026-10-18 · `city_parallax_street.webp`: conos de los faroles pasados a luz suave (procesado con script, sin Flow).
- Pendiente de rehacer cuando se haga el rework de niveles: props y edificios de las alcantarillas y de la torre (ver ROADMAP 1b).
- 2026-10-18 · rata animada por cuadros (caminar, ataque, golpe, cadáver): `assets/art/world1/rat/`; hojas generadas por el usuario en Flow, procesadas con `art_source/process_anim.py`. Receta: `add-enemy/animacion.md`.
- Pendiente: lo mismo para ladrón, matón, pistolero, patovica, sicarios y agente del tiempo (los prompts salen de `add-enemy/animacion.md`).

- **Pendiente (nivel 3, torre y techos, 2026-10-18)** — archivos y prompts para Flow:
  - `assets/art/bg/city_tower_interior.jpg` (fondo del interior, 16:9): `Genera una imagen 2D de videojuego de la pared interior de un edificio de oficinas de noche: pasillo oscuro con ventanales que dejan ver una ciudad lluviosa con luces de neón lejanas, columnas, luz fría tenue, sin personas, sin texto, vista de frente, estilo ilustración noir.`
  - Props de interior (cada uno aislado, fondo croma verde liso, vista de frente): escritorio de oficina con monitor (160x70 px), archivador metálico (60x110 px), ascensor con puertas cerradas (180x240 px), maceta alta (60x120 px), escalera de incendio exterior (varias tablas, 330x300 px).
  - Ventanas de la pared del fondo: reemplazan los rectángulos de `TowerBack` (hoy placeholder en `build_tower.py`).
- **Pendiente (nivel 2, alcantarillas, 2026-10-18)** — archivos y prompts para Flow:
  - `assets/art/items/hamelin_flute.png` (ícono, se ve a 32x32, 1:1): `Genera una imagen de un ícono simplificado de una flauta de hueso (flauta de Hamelin) con una nota musical verde, silueta simple y gruesa, pocos colores planos, bordes nítidos, estilo 2D de videojuego, centrado, aislado sobre fondo negro liso, brillo sutil verde, sin texto, sin sombra.` Pasarlo con `python art_source/flow_tools.py place <jpg> --kind item --id hamelin_flute`.
  - Rata Gigante: hojas `walk` / `attack` / `hitdeath` iguales a las de la rata (receta en `add-enemy/animacion.md`), una rata enorme de pelaje sucio y ojos rojos, ~3x el tamaño de la común. Hoy usa la rata común agrandada (`ART_EXTRA_SCALE` en `giant_rat.gd`).
  - Rata de techo (opcional): hojas de la rata agarrada al techo con las patas hacia arriba; hoy es la rata común volteada.
  - Rata aliada: variante de la rata con pelaje limpio y un lazo o brillo verde (hoy: tinte verde).
  - Props de alcantarilla (rejilla, caño con goteo, escalera, barandas) y fondo propio si se quiere distinto del `city_sewer.jpg`.
  - Audio real: goteos y ambiente de alcantarilla (ElevenLabs), música del nivel y del jefe (hoy suenan `nivel1`/`boss` y goteos sintetizados).
- 2026-10-19 · arte de las alcantarillas (1-03) generado por el usuario en Flow y puesto en el juego: plataformas (balsa, tablones, rejillas, caño, losa, colgante), obstáculos (barril, cajas, caño caído, ladrillos, sacos, compuerta), decoración (rejilla, caño con goteo, escalera, baranda, lámpara colgante, válvula), piso, borde, agua y fondo del túnel. Procesado con `art_source/world1/process_sewer2.py` (hojas en `art_source/world1/sewer2/`, originales viejos con prefijo `old_`). Los obstáculos se colocan en `build_sewer.py` con `L.prop(...)`; las plataformas se dibujan con `platform_sprites` del sector en `level_skin.gd`. Falta: música y ambiente real, rata aliada y rata de techo propias.

- **Pendiente (Mangual, 2026-10-19)** — `assets/art/weapons/mangual.png`, de lado apuntando a la derecha, ~256x95 px, fondo transparente o negro liso: `Genera una imagen 2D de videojuego de un mangual medieval visto de lado: mango corto de madera con empuñadura de cuero a la izquierda, cadena de hierro de cuatro eslabones horizontal, y una bola de hierro oscuro con pinchos a la derecha, silueta clara, bordes nítidos, aislado sobre fondo negro liso, sin texto, sin sombra.` Si cambia el encuadre, ajustar `grip`/`size` en `core/art/weapon_art.gd` e `impact` en `weapon_motion.gd`. Hoy usa un dibujo provisorio hecho por script.

- **Pendiente (tanda noir del mundo 1, 2026-10-19)** — hoy usan dibujos provisorios de `art_source/draw_noir_placeholders.py`. Armas de lado apuntando a la derecha, 256 px de ancho, fondo negro liso (pasar con `flow_tools.py`, después ajustar `grip`/`hand`/`support`/`size` en `core/art/weapon_art.gd`):
  - `assets/art/weapons/thompson.png` (~256x110): `Genera una imagen 2D de videojuego de un subfusil Thompson de los años 30 visto de lado, culata y empuñaduras de madera, cañón con aletas y cargador de tambor redondo, apuntando a la derecha, silueta clara, bordes nítidos, aislado sobre fondo negro liso, sin texto, sin sombra.`
  - `assets/art/weapons/sawed_off.png` (~256x110): `Genera una imagen 2D de videojuego de una escopeta recortada de dos caños vista de lado, caños cortos de acero y culata de madera serruchada como empuñadura de pistola, apuntando a la derecha, silueta clara, bordes nítidos, aislado sobre fondo negro liso, sin texto, sin sombra.`
  - `assets/art/weapons/flare_gun.png` (~256x150): `Genera una imagen 2D de videojuego de una pistola de bengalas naranja de plástico vista de lado, caño ancho y corto, apuntando a la derecha, silueta clara, bordes nítidos, aislado sobre fondo negro liso, sin texto, sin sombra.`
  - `assets/art/weapons/nail_bat.png` (~256x64): `Genera una imagen 2D de videojuego de un bate de béisbol de madera con clavos atravesados en la punta y cinta negra en el mango, horizontal con el mango a la izquierda, silueta clara, bordes nítidos, aislado sobre fondo negro liso, sin texto, sin sombra.`
  - Íconos (se ven a 32x32, 1:1), con la plantilla de `add-item` y `flow_tools.py place <jpg> --kind item --id <id>`: `trench_coat` (gabardina beige de detective con cinturón, brillo sutil ámbar), `fedora` (sombrero fedora gris oscuro con cinta roja), `brass_knuckles` (puño americano de bronce, brillo dorado), `molotov` (botella verde con un trapo encendido, brillo naranja).

## Registro de cambios de diseño por nivel

(Agregar: fecha · nivel · qué cambió y por qué)

- 2026-10-18 · 1-01 · el asaltante del px 4600 (`Assaulter`) deja el revólver (`dropped_weapon`, solo ese); se quitó el revólver del suelo del px 5000. Cuatro ladrones (`Thief1`–`Thief4`) en los px 1600, 6450, 9100 y 15600.
- 2026-10-18 · 1-03 (nivel 2, alcantarillas) · rehecho: pasillo de 16.000 px con piso, techo y charcos, solo ratas, jefe Rata Gigante que deja la Flauta de Hamelin, goteos sintetizados, sin emboscadas. Generador: `art_source/world1/build_sewer.py`. El 1-01 ahora apunta a este nivel.
- 2026-10-18 · 1-04 (nivel 3, torre y techos) · rehecho desde cero: torre de 4 pisos con tablas de una vía como escaleras y 5 techos con huecos al vacío; reemplaza al barrio de casitas. Generador: `art_source/world1/build_tower.py`; vacío por tramo con `abyss_after_x` en `level_base.gd`. Arte pendiente: ver abajo.
- 2026-10-18 · 1-01 · pase de ritmo: primer matón suelto en el px 19700 y tres arenas SIN armas de fuego (px 22000 ladrones + matón élite, 28800 ladrones + matones, 32800 ratas + matones antes de la salida); se sacaron los enemigos sueltos y los props que quedaban en esas zonas y se sumaron los checkpoints 21100 y 28000. Edición directa del `.tscn` (no hay generador).
- 2026-10-18 · 1-01 · largo 34.000 px, tramos de ratas/asaltantes, props y plataformas, mitad de edificios, pedestales fuera, piso al borde del sprite. Detalle en `LEVEL_DESIGN.md`.

- **Pendiente (segunda tanda noir y guardia de la torre, 2026-10-19)** — hoy usan dibujos provisorios de `art_source/draw_noir_placeholders.py` (`python art_source/draw_noir_placeholders.py nail_gun pipe_wrench extinguisher`). Armas de lado apuntando a la derecha, 256 px de ancho, fondo negro liso (después ajustar `grip`/`hand`/`support`/`size` en `core/art/weapon_art.gd`):
  - `assets/art/weapons/nail_gun.png` (~256x130): `Genera una imagen 2D de videojuego de una clavadora neumática de obra amarilla y negra vista de lado, empuñadura de pistola, tira de clavos bajo la nariz y racor de manguera atrás, apuntando a la derecha, silueta clara, bordes nítidos, aislado sobre fondo negro liso, sin texto, sin sombra.`
  - `assets/art/weapons/pipe_wrench.png` (~256x90): `Genera una imagen 2D de videojuego de una llave Stillson de plomero, mango de hierro rojo y cabeza de acero con mandíbulas dentadas, horizontal con el mango a la izquierda, silueta clara, bordes nítidos, aislado sobre fondo negro liso, sin texto, sin sombra.`
  - `assets/art/weapons/extinguisher.png` (~256x120): `Genera una imagen 2D de videojuego de un matafuegos de CO2 rojo acostado, válvula metálica y tobera negra en forma de bocina apuntando a la derecha, silueta clara, bordes nítidos, aislado sobre fondo negro liso, sin texto, sin sombra.`
  - Proyectiles (opcional): `assets/sprites/proyectiles/clavo.png` (24x6, clavo gris) y `espuma_co2.png` (22x22, nube blanca suave con alfa).
  - Guardia Antidisturbios (`entities/enemies/city_riot_guard.tscn`): hoy es el patovica con un escudo dibujado (`assets/art/world1/riot_shield.png`, 78x156, se ve a 1/3). Arte propio: hojas `walk` / `attack` / `hitdeath` como las de la rata (`add-enemy/animacion.md`) de un guardia de seguridad con casco, chaleco negro y escudo antidisturbios transparente con franja amarilla, golpeando con el escudo.
- 2026-10-19 · disparos, impactos y explosión rehechos sin Flow ni ElevenLabs: `assets/audio/sfx/<sonido>_<n>.wav` (44 kHz, 3 variantes), sintetizados por `art_source/audio/synth_guns.py`. Se pueden pisar con audio real con el mismo nombre.

- **Pendiente (explosivos y armas especiales, 2026-10-19)** — dibujos provisorios de `art_source/draw_noir_placeholders.py` (`bazookas`, `dart_pistols`, `taser`, `throwable_icons`). Armas de lado apuntando a la derecha, fondo negro liso:
  - `assets/art/weapons/bazooka.png` (~256x100): `Genera una imagen 2D de videojuego de una bazuca militar verde oliva vista de lado, tubo largo con dos empuñaduras y mira, apuntando a la derecha, silueta clara, bordes nítidos, aislado sobre fondo negro liso, sin texto, sin sombra.`
  - `assets/art/weapons/bazooka_guided.png` (~256x100): lo mismo, gris oscuro, con una caja de guía láser con luz roja arriba.
  - `assets/art/weapons/dart_venom.png` / `dart_charm.png` (~256x140): pistola de dardos de aire comprimido con tanque bajo el caño, verde (veneno) y rosa (hechizo).
  - `assets/art/weapons/taser.png` (~256x150): pistola Taser policial amarilla y negra con cartucho al frente.
  - Íconos (32x32 en la UI): `cluster_bomb` (granada con bombitas alrededor, brillo amarillo) y `c4` (ladrillo de explosivo con detonador y LED rojo).
  - Armadura de hierro: íconos por defecto a pedido del usuario. Si se quieren: casco, pechera con reactor, guanteletes, botas y reactor de arco, rojo y dorado.
- **Pendiente (armas míticas, 2026-10-19)** — hoy recoloreadas o dibujadas por `art_source/draw_myth_placeholders.py`. De lado apuntando a la derecha, fondo negro liso: `poseidon_trident.png` (tridente dorado y turquesa con espuma, ~256x63), `zeus_bolt.png` (rayo dorado en zigzag con brillo, ~256x60), `leviathan_axe.png` (hacha nórdica de hoja azul helada con runas, ~256x116), `gungnir.png` (lanza larga dorada con runas, ~256x13), `excalibur.png` (espada larga de hoja brillante y empuñadura dorada, ~256x55), `monkey_staff.png` (bastón rojo con puntas doradas, ~256x24). Proyectiles: `ola.png`, `tajo_luz.png`, `rayo_zeus.png`, `hacha_leviatan.png`, `lanza_gungnir.png` en `assets/sprites/proyectiles/`.
