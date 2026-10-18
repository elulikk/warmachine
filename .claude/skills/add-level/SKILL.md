---
name: add-level
description: Agregar o rehacer un sector (nivel) de WARMACHINE con el generador de niveles del mundo (art_source/worldN/build_levels.py), incluyendo geometría, enemigos, arenas, checkpoints, armas del sector, vestido (LevelSkin), decoración, música, registro y prueba. Usar cuando el usuario pida un nivel, sector o capítulo nuevo, o cambios de estructura en uno existente.
---

# Agregar un sector

Leer `PROJECT_CONTEXT.md` secciones 6 y 10. Los niveles de los mundos 2, 3 y 4 **no se editan a mano**: los genera `art_source/world{2,3,4}/build_levels.py` (clase `Level`). El capítulo 4 sí son `.tscn` a mano. El capítulo 5 son 10 esqueletos vacíos (`levels/chapter_5/`): para armarlo, copiar el generador del mundo 1.

## Paso 0: tema y diseño

- Leer la descripción del sector en `PROJECT_CONTEXT.md` / `ROADMAP.md` / `story.md`. Si no tiene temática clara, **preguntar** antes de generar.
- Elegir qué se introduce: un arma (pedestal), un enemigo nuevo (de a uno por sector, ver `add-enemy`), una mecánica (pozos, plataformas, cinemática).
- Largo típico: 6400 a 9000 px. Estructura típica: tutorial/rampa → checkpoint → arena → checkpoint → guardias → salida.

## Dónde está cada paso

Leer solo el archivo del paso en que se está; no cargar los demás de entrada.

1. **Editar el generador** → leer `api.md` (métodos de `Level`, constantes, reglas de diseño y comando para regenerar).
2. **Registrarlo** → leer `registro.md`.
3. **Vestido, decoración, música** → leer `vestido.md`.
4. **Verificar y reportar** → leer `verificar.md`.

## Trampas

- No editar a mano un `.tscn` generado: el siguiente `build_levels.py` lo pisa.
- Un script nuevo (decoración, trigger) se carga por `preload`, no por `class_name`.
- `LevelBase.gear_loot_tier` fija qué equipo cae en el sector (0 = nada).
- Cambios de escena siempre con `GameManager.change_scene()`.
- El sector 4-9/4-10 y el capítulo 5 son esqueletos: `is_implemented()` los marca pendientes en el selector hasta registrarlos.
