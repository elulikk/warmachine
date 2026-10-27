# Atmósfera, arte 2D plano y emboscadas

Pase obligatorio al crear o **rehacer** un sector (pedido del usuario, 2026-10-18). El Sector 1-01 es la referencia del **proceso** (qué pasos y qué calidad), no del estilo: el noir urbano es solo del mundo 1. Cada mundo lleva la paleta y la estética de su propio tema.

## 1. Luz y color (`levels/level_skin.gd`, `levels/city_decor.gd` o el `decor` del mundo)

- **Gradación:** clave `grade` en el sector (o en el mundo) de `CHAPTER_THEMES`: `gamma` (1.15–1.25 hunde los medios), `contrast`, `saturation`, `shadows` (tinte de las sombras) y `highlights` (tinte de las luces). Una paleta por lugar, sacada del tema del mundo y del sector (en el mundo 1, calle noir con sombras azules y luces cálidas; en otros mundos, lo que pida su tema). La aplica `core/post_fx.gd` (`set_grade`) y se apaga sola al salir del nivel.
- **Luces de escenografía:** faroles con cono y charco (`lamps` en `SECTORS` de `city_decor.gd`, uno de cada 4 parpadea y queda quieto con "reducir destellos"). En otros mundos: antorchas, lava, neones, con el mismo truco (sprites aditivos y `Polygon2D` con colores por vértice, sin `PointLight2D`).
- **Halo del jugador:** `player_glow` en el tema (Color; el alfa es la intensidad) para que se lea en lo oscuro.
- Sin oscurecer de más: el jugador y los enemigos tienen que leerse siempre. Comparar captura antes y después.

## 2. Arte 2D plano (props sólidos y edificios)

- Todo obstáculo sólido (`WorldProp`) y toda fachada en **vista frontal ortográfica plana**, silueta rectangular, base recta. Así la colisión, que es un rectángulo del tamaño del dibujo, coincide con lo que se ve. Nada de perspectiva ni pirámides: las pilas son bloques rectangulares.
- Prompts: molde de la sección "Estilo de prompt para obstáculos y props 2D" del skill `google-flow` (hoja 16:9, ~4 a 6 objetos, croma verde, "sin nada verde en los objetos"), con el estilo y la paleta del mundo que toque. El usuario los genera y los deja en Descargas.
- Recorte: `flow_tools.py split --bg green`. Después reimportar (`Godot_v4.7.2-stable_win64.exe --headless --path . --import`) y ajustar los `size` de los props en el `.tscn` a la proporción nueva.
- **Escala:** una puerta mide ~1.3 veces lo que mide Gunther (en el mundo 1, hoja de 2752 px → juego con K = 0.51). Verificarlo en una captura con el jugador al lado de una puerta.
- **Edificios sin espejar:** tienen carteles y el texto queda al revés (`flip` en `bake_buildings.py` siempre en false).

## 3. Enemigos que salen de un escondite (`levels/ambush_director.gd`)

- Los enemigos sueltos no esperan parados a la vista: arrancan escondidos y salen cuando el jugador se acerca (ratas a 200 px del escondite, humanos a 620 px).
- **Los escondites están dibujados en el arte**, nunca flotando sobre la nada:
  - ratas: tacho o contenedor cercano, o la abertura baja de un edificio (reja de sótano, caño roto, agujero en la chapa);
  - humanos: puertas, persianas y portones de los edificios (la puerta se oscurece al "abrirse").
- Cada edificio necesita **una abertura baja para ratas y al menos una puerta** en su planta baja. Si falta, se agrega editando la misma hoja en Flow ("mantené la imagen exactamente igual… el ÚNICO cambio: …"), así no cambia el resto.
- Las salidas se marcan a mano en coordenadas de la hoja dentro del procesador (mundo 1: `art_source/world1/process_buildings_2d.py`, lista `SHEETS`), que genera `levels/building_exits.gd` en px del PNG. Verificarlas dibujando los rectángulos sobre cada edificio antes de probar.
- Hoy el director se crea solo en el mundo 1 (`LevelBase`, `chapter_number == 1`). Para otro mundo: definir sus tipos de enemigo en `RAT_KINDS` / `HUMAN_KINDS` (o equivalentes), sus escondites y crear el director desde `LevelBase`.
- Un enemigo que tiene que quedarse donde está (cinemática, jefe): meta `no_ambush`.

## 4. Verificar

- Capturas con el modo silencioso (`source .claude/skills/smoke-test/scripts/quiet.sh`, ejecutable sin consola) y una escena descartable `_x` que lleve al jugador a cada escondite. Mirar: tono general, puertas a escala, escondites sobre el dibujo, enemigos saliendo.
- Mandarle al usuario una comparación antes/después.
