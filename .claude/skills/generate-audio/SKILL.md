---
name: generate-audio
description: Generar audio real para WARMACHINE desde el navegador — música de un nivel, mundo o situación con Google Flow Music, y efectos de sonido o ambiente con ElevenLabs — y conectarlo al juego (ost/*.ogg + Music.TRACKS + base_music; sonidos por Sfx, fire_stream/hit_stream o el ambiente de la ciudad). Usar cuando el usuario pida música o un tema para un nivel, un sonido o efecto de sonido real, ambiente sonoro, o reemplazar un sonido sintetizado.
---

# Música (Flow Music) y efectos (ElevenLabs)

Navegador: leer el skill **`asset-browser`** antes del primer paso (Claude in Chrome en el Edge del usuario primero, el integrado después). Herramientas locales: ffmpeg en
`C:\Users\Usuario\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.0-full_build\bin\ffmpeg.exe`.

> **Estado:** la integración con el juego está verificada en el código (abajo). La interfaz de **Flow Music** y de **ElevenLabs** todavía **no se probó** en este proyecto: en el primer uso, anotar en la sección "Interfaz probada" la URL, los controles, qué formato descarga y cuánto dura lo que genera. No inventar pasos de UI.

## A. Música de un nivel (Google Flow Music)

### Qué existe en el juego

- `core/music.gd` → `TRACKS` (`&"clave": {"path": "res://ost/<clave>.ogg", "loop": true, "db": 0.0}`). Carga el `.ogg` aunque no esté importado (`AudioStreamOggVorbis.load_from_file`).
- Prioridad: anulaciones (tienda, derrota) > situación (`combat`, `elite`, `boss`, la elige `MusicDirector` según los enemigos cerca) > **base** del nivel.
- **Por nivel solo se cambia la base:** `LevelBase.base_music = &"clave"`. Si el archivo no existe, suena `explore` (no rompe). En los mundos 2-4 se pone con `L.music = "clave"` en `art_source/worldN/build_levels.py` y se regenera (ver `add-level`); en el capítulo 4, en el `.tscn`.
- Combate/élite/jefe son **globales**. Música de combate propia por mundo requiere tocar `MusicDirector`/`Music`: preguntar antes, no viene incluido.
- Pendiente conocido: `ost/club.ogg` para la discoteca del 4-7 (ya pide `&"club"`).

### Prompt

Instrumental, sin voz, pensado para loop, del mismo carácter que el mundo:

`Instrumental video game background music, <mood>, <instrumentos>, <tempo> BPM, seamless loop, no vocals, no intro, no fade out, consistent energy, 2D action platformer.`

| Mundo | Carácter (de los temas actuales: "Dread March", "Blood in the Cogwork") |
|---|---|
| 1 Periferia Subterránea | industrial steampunk, percusión metálica, sintes oscuros |
| 2 Valle Esmeralda | medieval, cuerdas y flautas, tambores marciales |
| 3 Abismo Ígneo | infernal, coros graves sin letra, órgano, percusión pesada |
| 4 Ciudad de Jano | noir urbano nocturno, bajo eléctrico, sintes; la discoteca: house/techno |

Exploración ~90–110 BPM, tensión media; no pedir "épico" para exploración (pisa al combate).

### Al juego

1. Descargar (permiso previo). Guardar el original en `ost/` con nombre descriptivo, como los existentes (`Dread March (Chapter Exploration).m4a`).
2. Convertir a OGG Vorbis, sin silencio al principio ni al final:
   ```bash
   "$FFMPEG" -i "<original>" -vn -af "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse" -c:a libvorbis -q:a 5 ost/<clave>.ogg
   ```
3. Igualar volumen con las pistas existentes: medir `explore.ogg` y la nueva con
   `"$FFMPEG" -i ost/explore.ogg -af loudnorm=print_format=summary -f null -`
   y ajustar `db` en `TRACKS` (± dB) en vez de re-codificar.
4. `TRACKS`: agregar la clave. Nivel: `base_music`. Importar una vez: `Godot --headless --path . --import`.
5. Verificar con `smoke-test` sobre el nivel (que no haya `ERROR` de carga) y pedirle al usuario que la escuche: el loop y la mezcla solo se validan de oído.

## B. Efectos de sonido y ambiente (ElevenLabs)

### Qué existe en el juego

- `core/sfx.gd` sintetiza todo por nombre (`GameFeel.sfx(ctx, &"nombre")`). Para reemplazar con audio real hay dos ganchos:
  - **Arma:** `fire_stream` / `hit_stream` en su `WeaponData` (`.tres`, `ext_resource` de tipo `AudioStream`; necesita importarse).
  - **Por nombre:** `Sfx.register_override(&"nombre", stream)`. **Nadie lo llama todavía.** La primera vez, agregar en `sfx.gd` una tabla `FILE_OVERRIDES: Dictionary = {&"nombre": "res://assets/audio/sfx/nombre.mp3"}` consultada en `_get_stream` antes de sintetizar, con la misma carga de reserva que `levels/city_ambience.gd::_load_stream` (si no hay `.import`, `AudioStreamMP3.load_from_file`). Desde ahí cada sonido nuevo = archivo + una línea. Se siguen aplicando `MIN_INTERVAL_MSEC` y las 20 voces.
- **Ambiente de la ciudad:** `levels/city_ambience.gd` (`LOOPS` y `EVENTS`, archivos en `assets/audio/ambiente/`, volúmenes -14 a -18 dB). Si un archivo falta se omite. Otros mundos no tienen ambiente: crear uno igual solo si el usuario lo pide.
- Pendientes del ROADMAP que conviene resolver así: `fire_ignite`, `net_deploy`, `laser_beam`, `cloak_on`, `cloak_off`, `heartbeat`.

### Prompt

En inglés, corto y físico (qué suena, material, distancia, duración):

`<objeto/acción>, <material>, <cercano|lejano>, short, no music, no voice, clean, game sound effect` — p. ej. `fuel puddle igniting, soft whoosh, close, short, no music`.

Duración: impactos y disparos 0.3–1 s; habilidades 0.5–1.5 s; loops de ambiente 10–30 s. Una variante por pedido (ver `asset-browser`, créditos).

### Al juego

1. Descargar (permiso previo) y guardar como `assets/audio/sfx/<nombre_del_sfx>.mp3` (mismo nombre que en `Sfx`; ambiente: `assets/audio/ambiente/amb_*.mp3` / `evt_*.mp3`).
2. Recortar silencio y, si hace falta, pasar a mono:
   ```bash
   "$FFMPEG" -i "<descarga>" -af "silenceremove=start_periods=1:start_threshold=-50dB" -ac 1 -b:a 128k assets/audio/sfx/<nombre>.mp3
   ```
3. Conectar con uno de los ganchos de arriba y bajar volumen con el `volume_db` de la llamada o de la tabla; los sintetizados suenan entre -6 y 0 dB.
4. `Godot --headless --path . --import`, `smoke-test` sobre el Banco de Pruebas, y que el usuario escuche.

## Cuándo NO usar este skill

- Ajustar un sonido sintetizado (más grave, más corto): eso es `game-feel` → `Sfx._build()`, sin navegador ni créditos.
- Un nivel nuevo sin pedido de música: `add-level` deja `base_music` en `explore`; no generar música por iniciativa propia.

## Interfaz probada

_(vacío: completar en el primer uso de Flow Music y de ElevenLabs con URL, controles, formato de descarga y duración real; anotar también lo que falle para no repetirlo)_
