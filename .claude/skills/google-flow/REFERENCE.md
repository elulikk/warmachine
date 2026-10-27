# google-flow — referencia (casos raros)

Solo leer cuando el flujo normal de `SKILL.md` no alcanza: video, subir imágenes, descarga por tarjeta, coordenadas. Nada de esto hace falta para generar hojas de sprites.

## Subir imágenes (de referencia o de otro lado)
- Un `ctrl+v` sintético **no funciona** (ProseMirror contenteditable; probado oct 2026 en el navegador integrado). Tampoco el botón "+" como subida (abre el buscador de recursos) ni simular el pegado por JavaScript.
- Opciones: pedirle al usuario que pegue la imagen él con Ctrl+V en la caja de Flow, o usar una imagen **ya existente en el proyecto** (ver "Referencia desde un recurso").
- Ver siempre que la imagen apareció antes de seguir.

## Referencia desde un recurso del proyecto
"+" de la caja del agente → se abre el selector de recursos (puede tardar) → elegir la imagen → **"Añadir a petición"** → escribir el prompt → flecha.

## Video en loop a partir de una imagen (probado oct 2026)
- Modelo por defecto en Ajustes del agente: **Omni 1.1 Flash** (16:9, x1). Otros: Veo 3.1 Lite / Fast / Quality. Flow no muestra el costo por modelo.
- **Sonido:** aunque "Proporcionar videos silenciosos" esté activado, Omni igual genera audio. Quitarlo después con ffmpeg (`-an`): `C:\Users\Usuario\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.0-full_build\bin\ffmpeg.exe`. Hay que descargar el archivo primero (pedir permiso).
- **Loop:** no mantiene la posición de nubes entre primer y último cuadro, no empalma. Alternativas: ping-pong (adelante y atrás) o imagen fija con scroll/parallax.
- Prompt de loop: cámara fija, vista lateral, elementos que parpadean o se mueven lento, sin personajes ni texto, "el último cuadro igual al primero".
- Tarda varios minutos ("en la cola"); esperar con `wait` y filtrar la galería por "Vídeos".
- **Duración:** pidió 3 s y generó 4 s. No se fija por prompt; recortar después.
- Metadatos (modelo, duración, prompt): abrir el video en la galería → panel de detalles.

## Descarga por tarjeta (galería, sin abrir el editor)
Controles de cada tarjeta solo al pasar el cursor. Etiquetas del menú ⋮ (oct 2026): "Marcar como favorito", "Reutilizar petición", "Animar", "Añadir a la petición", **"Descargar"** (submenú: **1K Tamaño original** / 2K Resolución mejorada / 4K con botón "Actualizar"), "Copiar", "Cambiar nombre", "Compartir", "Definir portada del proyecto", "Denunciar resultado", "Mover a la papelera" (**nunca** automatizar esta).
Cuándo usar cada método: galería = subconjunto o orden dudoso (baja justo las tarjetas elegidas); editor con `Right` = racha contigua de imágenes recién generadas. Ubicar por etiqueta (`find`), no por coordenada.
1. `find` con el nombre del objeto → `ref_N` → `scroll_to`.
2. `hover` sobre la tarjeta → ⋮ arriba a la derecha → "Descargar" → **1K – Tamaño original**. 2K gasta créditos, 4K está bloqueado.
3. Cae en `C:\Users\Usuario\Downloads` como `<Titulo>_<AAAAMMDDHHMMSS>.jpg`.
- La galería cambia de scroll al volver atrás: verificar la posición con `find`/`scroll_to` antes de clicar por coordenada.

## Controles por etiqueta (independiente del tamaño de ventana)
Verificado en Edge con Claude in Chrome (oct 2026, viewport 1912×867). `find`/`read_page` devuelven estas etiquetas accesibles; usarlas en vez de coordenadas.

| Qué | Etiqueta accesible |
|---|---|
| Caja de petición | textbox `Texto editable` |
| Enviar | button `Iniciar generación` |
| Ajustes del agente | button `Ajustes` (el de la caja inferior; hay otro `Ajustes` arriba a la derecha de la página) |
| Instrucciones del agente | button `Instrucciones del agente` |
| Añadir referencia | button `Añadir ingredientes a ventana para peticiones` (y `Menú para añadir contenido multimedia`) |
| Buscar | textbox `Buscar` · filtros: `Opciones de filtrado y ordenación` |
| Menú del proyecto | `Más opciones del proyecto` |
| Papelera | link con href `.../trash` (NO usar) |
| Hover de tarjeta | `Marcar como favorito`, `Reutilizar petición`, ⋮ → menú de arriba |

**Ajustes del agente** (leídos con `[role=radio]`, `aria-checked` dice el estado actual): relación de aspecto de imagen `16:9 / 4:3 / 1:1 / 3:4 / 9:16` y video `16:9 / 9:16`; cantidad `x1 / x2 / x3 / x4`. Al explorar estaban en 1:1 y x1 (imagen), 16:9 y x1 (video). Se puede comprobar el estado de una vez con JS de solo lectura:
`[...document.querySelectorAll('[role=radio]')].map(e => e.innerText.trim() + ':' + e.getAttribute('aria-checked'))`.

## Coordenadas conocidas (último recurso)
| Navegador | Marco | Ajustes del agente | Descarga en el editor |
|---|---|---|---|
| Integrado | 800×757 | engranaje ≈ (655, 710) | icono ≈ (692, 31) → 1K ≈ (559, 82) |
| Edge (Claude in Chrome) | 1568×750 | sliders de la caja (973, 664); relación de aspecto 1:1 en (1416, 280) → Guardar (1416, 678) | icono (1345, 31) → 1K (1380, 72) |

Probado en Edge: 3 imágenes seguidas en un solo `browser_batch` (icono → 1K → `Right`). Verificar el título del editor antes de cada descarga.

## Saldo
Menú de la cuenta (badge PLUS arriba a la derecha) → "X puntos de Google Flow". Solo mirarlo si el usuario pregunta o una generación falla por créditos.

## Ya probado (agregar hallazgos nuevos acá, con fecha)
- **2026-10-13:** subir imagen con `ctrl+v` sintético no funciona (ver arriba). No reintentar.
- **2026-10-13:** Flow dibuja rayas negras separadoras entre celdas en hojas tipo cuadrícula; `flow_tools.py split` las quita (`--line`). A veces usa fondo blanco aunque se pida negro: se detecta solo.
- **2026-10-13:** la galería cambia de scroll al volver atrás; no confiar en coordenadas vistas antes.
