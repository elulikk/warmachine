# Políticas vigentes y registro de lo que se rehízo

Leer al empezar cualquier trabajo de niveles, enemigos, ítems o arte. **Actualizar al terminar** (agregar una línea en el registro de abajo y, si cambia una regla, en las políticas).

## Políticas (decididas por el usuario)

1. **Prohibido generar arte o audio desde el navegador por mi cuenta (desde 2026-10-18).** No usar el skill `google-flow`, `generate-audio` ni `parallax-level-background` para generar, ni Claude in Chrome (`mcp__claude-in-chrome__*`): gasta mucha cuota. Solo se levanta si el usuario lo pide de nuevo en palabras.
2. **Arte nuevo = prompts para el usuario.** Si un nivel necesita props, edificios, enemigos o fondos que no existen, antes de armarlo dar una lista: nombre del archivo, tamaño en juego (px), proporción, y un prompt listo para pegar en Flow. El usuario los genera y pasa los archivos; mientras tanto se usa arte existente o bloques de color de prueba (`WorldProp` sin arte).
3. **Orden de trabajo:** primero mapas, combates y mecánicas; después historia y cinemáticas (dejar ganchos `cine` vacíos).
4. **Plantilla de diseño:** `LEVEL_DESIGN.md` (largo, ritmo, tramos, props, línea del piso). Mundo 1 = 3 niveles (calle, alcantarillas, torre y techos): ver `ROADMAP.md` sección 1b.
5. **Pruebas siempre sin sonido** (`--audio-driver Dummy`, ya en `smoke.sh`).
6. **Un nivel editado a mano no se regenera:** `build_levels.py` borra lo hecho a mano (el 1-01).
7. **Commit/PR solo si lo pide;** `gh` no está instalado (dar el enlace `compare`).

## Registro de sprites y arte rehechos

(Agregar: fecha · qué · archivo · quién lo generó)

- 2026-10-18 · `city_parallax_street.webp`: conos de los faroles pasados a luz suave (procesado con script, sin Flow).
- Pendiente de rehacer cuando se haga el rework de niveles: props y edificios de las alcantarillas y de la torre (ver ROADMAP 1b).
- 2026-10-18 · rata animada por cuadros (caminar, ataque, golpe, cadáver): `assets/art/world1/rat/`; hojas generadas por el usuario en Flow, procesadas con `art_source/process_anim.py`. Receta: `add-enemy/animacion.md`.
- Pendiente: lo mismo para ladrón, matón, pistolero, patovica, sicarios y agente del tiempo (los prompts salen de `add-enemy/animacion.md`).

- **Pendiente (nivel 2, alcantarillas, 2026-10-18)** — archivos y prompts para Flow:
  - `assets/art/items/hamelin_flute.png` (ícono, se ve a 32x32, 1:1): `Genera una imagen de un ícono simplificado de una flauta de hueso (flauta de Hamelin) con una nota musical verde, silueta simple y gruesa, pocos colores planos, bordes nítidos, estilo 2D de videojuego, centrado, aislado sobre fondo negro liso, brillo sutil verde, sin texto, sin sombra.` Pasarlo con `python art_source/flow_tools.py place <jpg> --kind item --id hamelin_flute`.
  - Rata Gigante: hojas `walk` / `attack` / `hitdeath` iguales a las de la rata (receta en `add-enemy/animacion.md`), una rata enorme de pelaje sucio y ojos rojos, ~3x el tamaño de la común. Hoy usa la rata común agrandada (`ART_EXTRA_SCALE` en `giant_rat.gd`).
  - Rata de techo (opcional): hojas de la rata agarrada al techo con las patas hacia arriba; hoy es la rata común volteada.
  - Rata aliada: variante de la rata con pelaje limpio y un lazo o brillo verde (hoy: tinte verde).
  - Props de alcantarilla (rejilla, caño con goteo, escalera, barandas) y fondo propio si se quiere distinto del `city_sewer.jpg`.
  - Audio real: goteos y ambiente de alcantarilla (ElevenLabs), música del nivel y del jefe (hoy suenan `nivel1`/`boss` y goteos sintetizados).

## Registro de cambios de diseño por nivel

(Agregar: fecha · nivel · qué cambió y por qué)

- 2026-10-18 · 1-01 · el asaltante del px 4600 (`Assaulter`) deja el revólver (`dropped_weapon`, solo ese); se quitó el revólver del suelo del px 5000. Cuatro ladrones (`Thief1`–`Thief4`) en los px 1600, 6450, 9100 y 15600.
- 2026-10-18 · 1-03 (nivel 2, alcantarillas) · rehecho: pasillo de 16.000 px con piso, techo y charcos, solo ratas, jefe Rata Gigante que deja la Flauta de Hamelin, goteos sintetizados, sin emboscadas. Generador: `art_source/world1/build_sewer.py`. El 1-01 ahora apunta a este nivel.
- 2026-10-18 · 1-01 · largo 34.000 px, tramos de ratas/asaltantes, props y plataformas, mitad de edificios, pedestales fuera, piso al borde del sprite. Detalle en `LEVEL_DESIGN.md`.
