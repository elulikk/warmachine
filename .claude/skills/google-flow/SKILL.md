---
name: google-flow
description: Generar sprites e imágenes de juego con Google Flow en el navegador integrado: prompts en lote, hojas de spreadsheet con prompts, y descarga de las variantes en PNG/JPG para warmachine. Usar cuando el usuario pida imágenes, sprites, proyectiles, personajes, UI, iconos o arte generado con Google Flow.
---

# Google Flow para sprites de warmachine

Este skill es el **maestro de arte generado**: cualquier skill del proyecto que necesite imágenes (`add-enemy`, `add-item`, `add-level`, `parallax-level-background`) viene acá para el navegador, la generación y la descarga. El usuario inicia sesión a mano la primera vez; nunca escribir credenciales.

## Qué navegador usar (orden de preferencia)

1. **Claude in Chrome en el Edge de la PC del usuario** (`mcp__claude-in-chrome__*`). Es su navegador real, con la sesión de Google ya abierta y Flow en Plus.
   - Las herramientas son diferidas: cargarlas con **una sola** `ToolSearch` (`select:` con `list_connected_browsers`, `select_browser`, `tabs_context_mcp`, `tabs_create_mcp`, `navigate`, `computer`, `read_page`, `find`, `get_page_text`, `javascript_tool`, `read_console_messages`, `tabs_close_mcp`).
   - Llamar a `list_connected_browsers`. Si aparece el Edge del usuario (isLocal / onThisComputer), `select_browser` con su `deviceId`. Después `tabs_context_mcp` con `createIfEmpty`, y abrir Flow en una pestaña **nueva** (`tabs_create_mcp` + `navigate`); no reutilizar pestañas del usuario.
   - Si la lista viene **vacía**: el Edge no está abierto o la extensión no está conectada. Pedirle al usuario que abra Edge con la extensión Claude (o usar `switch_browser`, que le muestra un "Conectar"). No inventar que se conectó.
   - Leer también el skill `anthropic-skills:chrome-browser` antes del primer paso (permisos de sitio, diálogos a evitar, cuándo parar y preguntar).
   - Las coordenadas de abajo (≈ x 655, y 710) son del navegador integrado: en Edge ubicar los controles con `find` / `read_page` (refs `ref_N`) y confirmar con captura antes de clicar por coordenadas.
2. **Navegador integrado de la app** (`mcp__Claude_Browser__*`), si Chrome/Edge no está disponible. Hay que iniciar sesión a mano la primera vez.
3. **Si ninguno funciona**, no improvisar: dejar el arte como pendiente documentado (qué prompt, qué archivo, qué carpeta) y seguir con lo que no depende de imágenes. Nunca sustituir por capturas de pantalla ni por arte inventado a mano sin avisar.

Las descargas caen en la carpeta Descargas de Windows del usuario (`C:\Users\Usuario\Downloads`); pedir permiso antes de descargar, nombrar archivo y origen.

## Receta por tipo de asset (qué pedir y adónde va)

| Asset | Prompt base | Fuente → destino |
|---|---|---|
| **Enemigo (mob)** | personaje de cuerpo entero de lado, mirando a la derecha, sobre **fondo negro liso**, estilo 2D de videojuego, sin sombra de suelo | `art_source/worldN/<mob>.jpg` → `process.py` (`MOB_SRC`: recorta, voltea, escala a 3x del alto en juego) → `assets/art/worldN/mob_<id>.png` + línea `MOBS` en `core/art/armor_art.gd` (ver skill `add-enemy`) |
| **Ícono de ítem** (casco, capa, anillo, arrojadizo) | objeto único centrado, sobre fondo negro liso, brillo sutil del color del ítem, sin texto | `assets/art/items/<item_id>.png` (el `item_id` del `.tres`; ver `add-item`) |
| **Arma en mano** | arma de lado apuntando a la derecha, sobre fondo negro liso, sin manos | `assets/art/weapons/<id>.png` + entrada en `WeaponArt`/`WeaponMotion` (ver `add-item`) |
| **Prop / decoración / plataforma** | hoja con N objetos separados sobre negro liso, igual escala | `art_source/worldN/*.jpg` → `process.py` → `assets/art/worldN/` |
| **Fondo de nivel** | escena 16:9 sin personajes | skill `parallax-level-background` |
| **Retrato / cinemática** | busto o escena, fondo liso | `assets/art/portraits/` |

Reglas que valen para todos:

- **Una sola variante por prompt**, descarga **1K**. Generar todo primero y descargar todo junto.
- Preferir **hojas** (una imagen con varios objetos separados) a un prompt por sprite: es más rápido y mantiene la coherencia de estilo.
- Pedir siempre el mismo estilo que el resto del mundo (adjuntar una imagen ya aprobada como referencia, ver "Subir imágenes").
- Después de descargar: identificar por contenido (los nombres salen del título que inventa el agente), copiar a `art_source/worldN/` con un nombre claro y correr el `process.py` de ese mundo. No dejar PNG sueltos en `assets/` sin pasar por el script.
- Importar los assets nuevos una vez: `Godot --headless --path . --import`, y cargarlos en código con `Art.tex(path)`.
- Si el fondo no es negro liso (a veces Flow usa blanco), recortar con `cut_out(bg="white")` de `process.py`.

## Flujo general (orden obligatorio)
1. **Primero generar TODO** lo que se necesita, prompt tras prompt, sin descargar nada en el medio.
2. **Recién después descargar todo junto**, en una sola pasada por la galería.
3. Nunca pedirle al usuario que esté al lado apretando "Descargar". Si la descarga no sale por el método rápido, probar la alternativa del editor; no improvisar capturas de pantalla ni recortes de la pantalla como sustituto de la descarga.

## Proyecto de referencia
- Proyecto "Pixel Art Game Projectiles": `https://flow.google.com/project/c059e5d3-9b6b-4363-9499-ef98c72dee2d`
- Para proyectos nuevos: en la pantalla principal de Flow, botón "Nuevo proyecto" (es un tile abajo a la izquierda de la grilla).

## Interfaz nueva (oct 2026): modo Agente — la forma más rápida
- La caja inferior tiene el chip **Agente**. Antes del primer pedido: icono de ajustes (≈ x 655, y 710 en 800×757) → "Confirmar antes de generar: **Nunca**", imágenes **x1** → Guardar.
- Un solo mensaje puede pedir **muchas imágenes distintas** a la vez ("Genera 10 imágenes separadas... 1) 'nombre' 16:9: ... 2) ..."), cada una con su relación de aspecto. Las 10 tardaron ~1 min en total.
- Hacer clic en la caja antes de escribir; si el texto no aparece, volver a clicar (justo después de cerrar un panel el foco se pierde). Enviar con la flecha.
- Descarga en lote: abrir la primera tarjeta (clic en la imagen = editor), y repetir: icono de descarga (≈ x 692, y 31) → 1K (≈ x 559, y 82) → tecla **Right** (pasa a la siguiente imagen del proyecto). Hasta 25 acciones por `browser_batch`.
- Los nombres de archivo salen del título que el agente pone en inglés (p. ej. `Four_distinct_trees_grid_...jpg`): identificar por nombre o mirando las imágenes.
- A veces ignora "fondo negro" y usa blanco (árboles): recortar igual con Pillow por color de fondo.

## Subir imágenes (de referencia o de otro lado)
- En Flow del navegador, la forma de subir una imagen es **pegarla desde el portapapeles**: no usar el botón "+" (abre el buscador de recursos, no sirve para subir) ni el diálogo de archivos.
- El usuario lo hace con Ctrl+V en la caja de chat y la imagen se sube tras un rato.
- Equivalente para Claude: 1) poner la imagen en el portapapeles (script .ps1 con `System.Windows.Forms.Clipboard.SetImage`, ejecutado con `powershell -STA -File`; un hilo STA dentro de un comando inline falla); 2) enfocar la caja de Flow (clic en "¿Qué quieres crear?", en la pantalla de 800×760 queda hacia y≈674) y mandar `ctrl+v` con `computer` (action `key`).
- **Probado (oct 2026): NO funciona.** La caja queda enfocada (es un ProseMirror contenteditable) pero el `ctrl+v` del navegador integrado no pega la imagen: no aparece nada en la caja ni hay un blob/img nuevo en la página. Con el portapapeles ya cargado, el atajo sintético no dispara el pegado nativo.
- Por eso, para subir imágenes, pedirle al usuario que la pegue con Ctrl+V él mismo en la caja de Flow (funciona en su navegador), o usar otra vía que el usuario indique. No insistir con más `ctrl+v` ni con JavaScript para simular el evento de pegado.
- Ver siempre si la imagen apareció antes de seguir; no asumir que se subió.

## Video en loop a partir de una imagen (probado oct 2026)
- Modelo de video por defecto en Ajustes del agente: **Omni 1.1 Flash** (16:9, x1). Los otros son Veo 3.1 Lite / Fast / Quality. Flow no muestra el costo por modelo en la UI.
- **Sonido:** aunque "Proporcionar videos silenciosos" esté activado, Omni 1.1 Flash igual generó video **con audio** (confirmado por el usuario). Ese toggle no alcanza para evitarlo: quitar el audio después, localmente, con ffmpeg (`-an`, ffmpeg está en `C:\Users\Usuario\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.0-full_build\bin\ffmpeg.exe`). Hay que descargar el archivo primero (pedir permiso antes de descargar).
- **Loop:** Omni no mantiene la posición de las nubes entre el primer y el último cuadro, así que el loop no empalma. Alternativa sin regenerar: reproducirlo en ping-pong (adelante y atrás) o descartar el video y usar la imagen fija con scroll/parallax.
- Para usar una imagen como referencia: clic en "+" de la caja del agente → se abre el selector de recursos (puede tardar en aparecer) → elegir la imagen → **"Añadir a petición"**. Después escribir el prompt y enviar con la flecha.
- Prompt de loop: cámara fija, vista lateral, elementos que parpadean o se mueven lento, sin personajes ni texto, "el último cuadro igual al primero".
- Tarda varios minutos (el agente dice que "está en la cola"). Esperar con `wait` y revisar la galería con el filtro "Vídeos".
- **Duración: Flow generó 4 s aunque el prompt pidió 3 s.** No se puede fijar la duración por prompt; si hace falta más corto, hay que recortarlo después.
- Para ver metadatos (modelo, duración, resolución, prompt) abrir el video en la galería: aparece el panel de detalles.
- Saldo: menú de la cuenta (badge PLUS arriba a la derecha) → muestra "X puntos de Google Flow".

## Generar
- Escribir el prompt en la caja inferior "¿Qué quieres crear?" (clic en la caja, luego escribir) y enviar con la flecha a la derecha de la caja.
- **Siempre una sola variante por prompt.** Antes del primer prompt, ajustar en la configuración de la caja la cantidad de resultados a 1 (verificar en la UI que quedó en 1). No generar dos variantes ni elegir entre ellas.
- Tarda ~40-60 s. Mientras genera, la caja está ocupada: esperar antes de mandar otro prompt.
- Al generar, el panel de chat del agente puede abrirse a la derecha. Se cierra con la X de su cabecera.
- Prompt base de sprites (estilo del juego: 2D, fondo negro liso para recortar, brillo cian). **No es pixel art, es solamente 2D:**
  `Genera una imagen de <descripción>, estilo 2D de videojuego, bordes nítidos, vista lateral, aislado sobre fondo negro liso, brillo sutil cian, sin texto, sin sombra de suelo, sprite pequeño.`
- Para hojas de spreadsheet (muchos sprites en una sola imagen): pedir una cuadrícula con N objetos distintos sobre fondo negro, separados y con igual escala, y luego recortar. Hacerlo así en vez de un prompt por sprite, que es lento.

## Descargar (después de generar todo)
La mayoría de las acciones ocurren en la galería del proyecto. Los controles de cada tarjeta aparecen solo al pasar el cursor. Repetir lo siguiente para cada tarjeta, una tras otra, sin volver a generar:
1. Ubicar la tarjeta: `find` con el nombre del objeto (por ejemplo "submachine", "dart") devuelve `ref_N`. Con `scroll_to` (ref) llega a la tarjeta. Los nombres aparecen como texto bajo cada tarjeta.
2. Pasar el cursor sobre la tarjeta (`hover`) y clicar los tres puntitos (⋮) arriba a la derecha de la tarjeta.
3. En el menú, "Descargar" abre un submenú con **1K – Tamaño original** (usar esta), 2K (resolución mejorada, puede consumir créditos) y 4K (bloqueado sin actualización). **Elegir 1K.**
4. El archivo cae en `C:\Users\Usuario\Downloads` como `<Titulo>_<AAAAMMDDHHMMSS>.jpg`. Al terminar todas, verificar con `ls -lt` en esa carpeta que estén todos los archivos esperados.
- Alternativa ya probada: abrir la tarjeta (clic en la imagen) entra al editor; allí el icono de descarga está arriba a la derecha (≈ x 692, y 31 en 800×757) y abre el mismo menú 1K/2K/4K (1K ≈ x 590, y 70).
- Cuidado con las coordenadas: la galería cambia de scroll al volver atrás. Antes de clicar una tarjeta por coordenada, verificar la posición con `find`/`scroll_to`. No confiar en una posición vista antes de volver.

## Después de descargar
- Los JPG tienen fondo negro: quitarlo con Pillow (PIL, ya instalado) antes de usarlos en el juego. Recortar, reducir a tamaño sprite (nearest neighbor) y guardar PNG con transparencia.
- Mover los PNG a `assets/sprites/proyectiles/` (o la carpeta del tipo de objeto) con el nombre de la hoja de cálculo.
- Hoja de control: `assets/sprites/proyectiles/proyectiles_basicos.xlsx` (generada por `proyectiles_basicos.py`, misma carpeta). Actualizar la columna Estado.

## Qué no hacer
- No descargar en medio de la generación: primero todas las generaciones, después todas las descargas.
- No pedir al usuario que haga clics que puedo hacer yo; solo intervenir para iniciar sesión.
- No generar dos variantes por prompt.
- No usar "pixel art" en los prompts; es 2D.
- No descargar 2K/4K sin preguntar: 2K es una mejora que puede gastar créditos.
- No usar JavaScript para cambiar la UI; sí sirve para leer el DOM (rects, títulos, src) y decidir a dónde clicar.
