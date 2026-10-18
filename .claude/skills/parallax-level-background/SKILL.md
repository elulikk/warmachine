---
name: parallax-level-background
description: Crear el fondo con paralaje de un nivel de WARMACHINE. Lee la temática del nivel, genera la imagen base en Google Flow, la separa en capas (también en Flow, con la base de referencia), convierte las capas a WebP y las conecta en levels/level_skin.gd con la imagen base como fondo fijo de respaldo. Usar cuando el usuario pida un fondo de paralaje, capas de fondo o un fondo animado para un nivel.
---

> **POLÍTICA VIGENTE (2026-10-18):** generar arte o audio desde el navegador por mi cuenta está **prohibido** (gasta mucha cuota; tampoco usar Claude in Chrome). En su lugar, dar al usuario los prompts y medidas para que él los genere. Detalle y registro de lo rehecho: `.claude/skills/add-level/politicas.md`. Este skill queda como referencia de cómo se hace cuando el usuario lo vuelva a pedir.

# Fondo con paralaje para un nivel

Resultado: un nivel con cuatro capas de paralaje (`assets/art/bg/parallax/`) y, si la opción "Fondos de paralaje (capas)" está apagada, la **imagen base** de Flow como fondo fijo (`assets/art/bg/<nivel>_base.jpg`). La base es la imagen de la que salieron las capas: nunca se usa otra imagen de respaldo.

Ejemplo ya hecho: sector 4-1 (`levels/chapter_1/level_1_01.tscn`), base `city_night_base.jpg`, capas `city_parallax_{sky,far,mid,street}.webp`.

## Paso 1: temática del nivel

- ID del nivel: `levels/chapter_N/level_N_NN.tscn` → `level_id` `N_NN` (p. ej. `4_01`).
- El tema del capítulo está en `CHAPTER_THEMES` de `levels/level_skin.gd`: el sector va en `sectors` de ese capítulo. Ahí están el fondo actual (`backdrop`), el tono (`backdrop_tone`) y los pisos/paredes.
- La descripción narrativa del sector está en `PROJECT_CONTEXT.md` y en `ROADMAP.md` (busca el ID o el nombre del sector).
- Escribí una línea con: lugar, hora, clima, paleta y elementos clave (por ejemplo "calle de ciudad de noche, lluvia, neón cian y amarillo"). Si el nivel no tiene temática clara, preguntá antes de generar.

## Paso 2: imagen base en Google Flow

Usar el skill `google-flow` para la interfaz (modo Agente, descargas 1K, navegación de la galería). **Navegador: intentar primero Claude in Chrome en el Edge de la PC del usuario** (`mcp__claude-in-chrome__*`, sesión de Google ya abierta); el navegador integrado es la alternativa. Detalle y qué hacer si no hay navegador conectado: skill `asset-browser`.

- Proyecto: `https://flow.google.com/project/81d5950a-e725-4640-9f45-d9b4c4e0d455` (el de los fondos de la ciudad).
- Ajustes del agente: confirmar "Nunca", imágenes x1, 16:9. Guardar.
- Prompt base (una sola imagen):
  `Genera una imagen de fondo de escenario de videojuego 2D: <temática del nivel>, vista lateral, estilo 2D de videojuego, bordes nítidos, sin personajes, sin texto, sin marcas de agua. Formato horizontal 16:9 pensado para paralaje.`
- Si el nivel debe verse como los fondos anteriores, adjuntar la base de la ciudad como referencia de estilo (ver paso 3).
- Descargar en 1K (tamaño original) y verificar en `C:\Users\Usuario\Downloads`. Copiar la imagen a `assets/art/bg/<nivel>_base.jpg` al final (paso 4).

## Paso 3: capas en Google Flow

Cuatro capas, cada una una imagen separada, generadas con la base adjunta como referencia de estilo ("+" de la caja del agente → elegir la imagen → "Añadir a petición").

Un solo mensaje puede pedir las cuatro. Texto base (adaptar la descripción de cada capa a la temática):

`Usando la imagen de referencia como estilo (mismo arte 2D de videojuego y misma paleta), genera 4 imágenes separadas en formato 16:9, cada una como capa de paralaje de la misma escena. Una imagen por capa: 1) capa_cielo: <cielo o fondo lejano, sin calle ni primer plano>. 2) capa_lejos: <siluetas lejanas en tono oscuro, sin detalle>, fondo negro liso. 3) capa_medio: <edificios o elementos medios con sus luces>, fondo negro liso. 4) capa_calle: <suelo y primer plano en la mitad inferior>, fondo negro liso. Sin texto, sin personajes, sin marcas de agua.`

Reglas:

- **Cielo: no pedir fondo negro.** Va opaco (es el fondo completo), igual que `city_parallax_sky`.
- Las capas 2 a 4 llevan fondo negro liso; el script las vuelve transparentes.
- Flow puede devolver "Error" en algunas capas y el agente puede decir que todas están listas. **Verificar en la galería/chat que estén las cuatro antes de descargar.**
- Descargar cada capa (miniatura del chat → editor → icono de descarga → 1K → volver). Confirmar cada archivo en Downloads antes de seguir. Si una capa no baja, reintentar esa sola.
- Los nombres de archivo salen del título que pone el agente (p. ej. `Distant_skyline_silhouette_video…`). Identificarlas por contenido, no por nombre.
- Las capas no tienen por qué coincidir al píxel con la base: son elementos de profundidad distinta. Lo importante es que la escena se lea coherente en reposo.

## Paso 4: convertir las capas

Desde la raíz del proyecto, con las imágenes ya en Downloads (ajustar los nombres):

```bash
python .claude/skills/parallax-level-background/scripts/build_layers.py <prefijo> --sky <cielo.jpg> --far <lejos.jpg> --mid <medio.jpg> --street <calle.jpg> --base <base.jpg> --base-out assets/art/bg/<nivel>_base.jpg
```

- `<prefijo>`: el que se usa en el nombre de las capas, p. ej. `city` (salen `city_parallax_*.webp`).
- Salida: `assets/art/bg/parallax/<prefijo>_parallax_{sky,far,mid,street}.webp` (unos 200 KB en total para un fondo) y la base como JPG.
- Umbral del negro: `LOW=10`, `HIGH=30` en el script. Si una capa deja halos oscuros o pierde siluetas, ajustar esos valores y regenerar.
- Usar siempre el mismo nombre de base para el fondo fijo y para el tema (ver paso 5).

## Paso 5: conectar en `levels/level_skin.gd`

En el sector del nivel dentro de `sectors` de su capítulo:

```gdscript
"<N_NN>": {"backdrop": "<nivel>_base.jpg", "backdrop_layers": [["<prefijo>_parallax_sky.webp", 0.15],
	["<prefijo>_parallax_far.webp", 0.35], ["<prefijo>_parallax_mid.webp", 0.65], ["<prefijo>_parallax_street.webp", 1.0]]},
```

- `backdrop` es la **imagen fija** (la base), y también el fondo que se usa cuando la opción está apagada.
- `backdrop_layers` es el paralaje, de atrás hacia adelante. Profundidad: 0 = no se mueve, 1 = se mueve como una imagen fija. Valores por defecto: cielo 0.15, lejos 0.35, medio 0.65, calle 1.0.
- **Zoom:** los fondos por capas usan `LAYER_ZOOM` (1.1, en `level_skin.gd`); la imagen fija usa 1.3. Con 1.3 las capas de 1376 px se ven muy borrosas en 1920×1080. No subir el zoom de las capas para "llenar" la pantalla.
- Las capas solo se usan si el fondo del nivel coincide con el `backdrop` del tema. Un nivel con fondo propio (`backdrop_file` de `LevelBase`) queda con imagen fija.
- La opción global es `parallax_bg` (`core/settings.gd`, default `true`) y su checkbox está en Calidad gráfica (`ui/settings_window.gd`).
- Para un capítulo nuevo, el tema debe tener `sectors` (ya existe para el capítulo 1).

## Paso 6: verificar

1. **Respaldar los saves** antes de correr el juego: `C:\Users\Usuario\AppData\Roaming\Godot\app_userdata\WARMACHINE\saves` → copiar a la carpeta temporal. Restaurar después (ver memoria `runtime-smoke-check`).
2. Importar los WebP nuevos (una sola vez, o cuando se agreguen archivos):
   `C:\GODOT\Godot_v4.7.2-stable_win64_console.exe --headless --path . --import`
3. Ver el nivel con paralaje (opción activada):
   `C:\GODOT\Godot_v4.7.2-stable_win64_console.exe --path . res://levels/chapter_N/level_N_NN.tscn --write-movie <scratch>/f.png --fixed-fps 30 --quit-after 150`
   Mirar un cuadro (p. ej. `f00000120.png`) con Read. Buscar errores con `ERROR:` y `SCRIPT ERROR:` (el aviso "resources still in use at exit" es normal).
4. Probar la opción apagada: en `%APPDATA%\Godot\app_userdata\WARMACHINE\settings.cfg`, agregar `parallax_bg=false` bajo `[settings]`, correr de nuevo, confirmar que se ve la base fija, y **restaurar el settings.cfg original**.
5. Restaurar los saves respaldados. Avisar al usuario si se pisaron sus logs de Godot.

## Qué no hacer

- No usar `city_street.jpg` ni otra imagen como respaldo: la base es la imagen fija.
- No pedir fondo negro para el cielo.
- No generar más de una variante por capa ni descargar 2K/4K.
- No confiar en que Flow terminó todas las capas sin verificar las descargas.
- No borrar archivos de Downloads que no sean del fondo (el usuario baja sus propios audios ahí).
- No hacer commit ni actualizar el ROADMAP salvo que el usuario lo pida.
