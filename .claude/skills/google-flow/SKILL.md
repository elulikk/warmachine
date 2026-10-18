---
name: google-flow
description: Generar sprites, íconos, fondos, props y video con Google Flow (modo Agente) para warmachine: prompts en lote, hojas con varios objetos, descarga 1K y paso a assets/ con flow_tools.py y los process.py de cada mundo. Usar cuando el usuario pida imágenes, sprites, proyectiles, personajes, UI, íconos o arte generado con Google Flow, o cuando add-enemy, add-item, add-level o parallax-level-background necesiten arte nuevo. Para música usar generate-audio.
---

# Google Flow para sprites de warmachine

Maestro del arte generado: `add-enemy`, `add-item`, `add-level` y `parallax-level-background` vienen acá. El navegador, descargas y créditos están en **`asset-browser`** (leerlo una vez por sesión). El usuario inicia sesión a mano; nunca escribir credenciales. Video, subir imágenes y coordenadas: **`REFERENCE.md`** (solo si hace falta).

## Qué pedir y adónde va

| Asset | Prompt base | Destino |
|---|---|---|
| **Enemigo (mob)** | cuerpo entero de lado, mirando a la derecha, **fondo negro liso**, 2D de videojuego, sin sombra | `art_source/worldN/<mob>.jpg` → `process.py` (`MOB_SRC`) → `assets/art/worldN/mob_<id>.png` + `MOBS` en `core/art/armor_art.gd` (ver `add-enemy`) |
| **Ícono de ítem** (siempre que se agrega un ítem) | **simplificado**: silueta única gruesa, pocos colores planos, sin detalle fino, centrada ~80% del cuadro, 1:1, fondo negro liso, brillo sutil del color del ítem, sin texto; debe leerse a 32×32 | `assets/art/items/<item_id>.png` (ver `add-item`) |
| **Arma en mano** | arma de lado apuntando a la derecha, fondo negro liso, sin manos | `assets/art/weapons/<id>.png` + `WeaponArt`/`WeaponMotion` (ver `add-item`) |
| **Prop / decoración / plataforma** | hoja con N objetos separados sobre negro liso, misma escala | `art_source/worldN/*.jpg` → `process.py` → `assets/art/worldN/` |
| **Fondo de nivel** | escena 16:9 sin personajes | skill `parallax-level-background` |
| **Retrato / cinemática** | busto o escena, fondo liso | `assets/art/portraits/` |

Estilo del juego: **2D, no pixel art** (no escribir "pixel art" en los prompts). Prompt base:
`Genera una imagen de <descripción>, estilo 2D de videojuego, bordes nítidos, vista lateral, aislado sobre fondo negro liso, brillo sutil cian, sin texto, sin sombra de suelo, sprite pequeño.`

## Flujo (orden obligatorio)

1. **Generar todo primero**, sin descargar en el medio. **Una variante por prompt** (x1), nunca elegir entre dos.
2. **Hojas** (una imagen con N objetos separados, igual escala) en vez de un prompt por sprite: más rápido y estilo coherente.
3. **Modo Agente:** chip "Agente" en la caja inferior. Antes del primer pedido, ajustes → "Confirmar antes de generar: **Nunca**", imágenes **x1**, relación de aspecto. Un solo mensaje puede pedir **varias imágenes distintas** ("Genera 10 imágenes separadas... 1) 'nombre' 16:9: ... 2) ..."): 10 tardan ~1 min.
4. Clicar la caja antes de escribir (si el texto no aparece, volver a clicar); enviar con la flecha.
5. **Ubicar controles por etiqueta, no por coordenada** (tabla "Controles por etiqueta" de `REFERENCE.md`): un `find` por control al empezar la sesión y reutilizar las referencias; coordenadas solo si un `find` falla.
6. **Descargar todo junto** en una pasada, tamaño **1K**: abrir la primera tarjeta (editor) y repetir descarga → 1K → tecla `Right`, hasta 25 acciones por `browser_batch`. Detalle y coordenadas en `REFERENCE.md`. No sustituir una descarga fallida por capturas, ni pedirle al usuario que apriete "Descargar".
7. Los nombres salen del título que inventa el agente (en inglés): identificar por contenido.

## Después de descargar: `art_source/flow_tools.py` (en vez de hacerlo a mano)

```bash
# 1) Traer lo nuevo de Downloads con nombres limpios (no borra nada); imprime tamaño y fondo detectado
python art_source/flow_tools.py ingest --since 30 --dest art_source/worldN --prefix <mundo>_

# 2) Recortar fondo y separar cada objeto de una hoja en un PNG con alfa
python art_source/flow_tools.py split art_source/worldN/<hoja>.jpg --out art_source/worldN/_cut --name <nombre> [--size ALTO] [--holes] [--glow]

# 3) Revisar TODO con una sola imagen (damero + etiqueta con índice)
python art_source/flow_tools.py contact "art_source/worldN/_cut/*.png" --out art_source/worldN/_cut/contacto.png --cols 6
```

- **Un asset a su destino del juego** (recorta, queda con el objeto más grande, escala y guarda; no pisa sin `--force`, `--dry-run` para ver):
  `python art_source/flow_tools.py place art_source/worldN/<hoja>.jpg --kind mob|item|weapon|prop --id <id> [--world N] [--game-h ALTO] [--flip]`.
  `mob` → `assets/art/worldN/mob_<id>.png` a 3x el alto en juego e imprime la línea para `MOBS`; `item` → 32×32 en `assets/art/items/`; `weapon` → ancho 256 en `assets/art/weapons/`; `prop` → `assets/art/worldN/`.
- **Fondo automático:** detecta negro o blanco por las esquinas (Flow a veces ignora "negro" y usa blanco), y quita las rayas separadoras de cuadrícula que a veces dibuja entre celdas.
- `--holes` también quita el fondo encerrado (huecos de una valla, entre ramas); `--glow` usa la luminancia como opacidad (fuego, hielo, brillos); `--size` escala cada pieza a ese alto; `--gap` (6) fusiona partes cercanas de un mismo objeto, `--min-area` descarta motas.
- Para cualquier ajuste, leer **una sola vez** la hoja de contacto, no cada PNG.
- Los `process.py` de cada mundo siguen siendo el paso final (escala a 3x del alto en juego, `MOB_SRC`, etc.). `flow_tools.py` sirve cuando un asset **no** tiene entrada en un `process.py`, o para ver rápido qué salió.
- Después: `Godot --headless --path . --import` y cargar con `Art.tex(path)`. Nada de PNG sueltos en `assets/` sin pasar por un script.
- Un tinte no sirve para cambiar de metal (el azulado da verde-oliva): generar un sprite por metal (ver `art_source/coins/`).

## Al cerrar la tanda (mejora continua)

- Si algo **falló, tomó más pasos de lo esperado o se descubrió un atajo**, escribir una línea en **`LEARNINGS.md`** (fecha, qué pasó, qué hacer). No editar `SKILL.md` por un hallazgo suelto.
- Un hallazgo que se repite (2 veces) o que el usuario confirma pasa a la sección "Ya probado" de `REFERENCE.md` y se borra de `LEARNINGS.md`; si cambia el flujo normal, recién ahí se toca `SKILL.md` (corto: respetar el tope de ~60 líneas).
- `flow_tools.py` anota cada operación en `art_source/flow_log.jsonl` (cuántas imágenes, fondo, objetos). Para medir una tanda, leer ese archivo en vez de reconstruirla de memoria.

## Qué no hacer

- Cerrar la pestaña de Flow al terminar (`tabs_close_mcp`), aunque sea una sola tanda.
- No descargar 2K/4K sin preguntar (2K puede gastar créditos).
- No usar JavaScript para cambiar la UI (sí para leer el DOM: rects, títulos, src).
- No pedirle al usuario clics que puedo hacer yo; solo para iniciar sesión.
- Proyecto de referencia: "Pixel Art Game Projectiles" `https://flow.google.com/project/c059e5d3-9b6b-4363-9499-ef98c72dee2d`. Proyecto nuevo: tile "Nuevo proyecto" abajo a la izquierda de la grilla.
