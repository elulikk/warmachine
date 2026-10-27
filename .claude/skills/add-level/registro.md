# Registrar el sector

Paso 2 de `SKILL.md`. Después de que el generador escribió el `.tscn`.

- `core/managers/level_registry.gd`: agregar la ruta a `IMPLEMENTED_LEVELS`; si el capítulo no tiene 10 sectores, `LEVEL_COUNTS`; `CHAPTER_EXIT` para el último sector (hoy todos vuelven a la Caja `HUB_PATH`); nombres de sectores en `JANO_SECTOR_NAMES` (capítulo 1).
- Encadenado: `next_level_path` lo pone `next_of(K)` del generador.
- Mundo nuevo: entrada nueva en `CHAPTER_NAMES` / `CHAPTER_COLORS` y en `LevelSkin.CHAPTER_THEMES`.
