# Vestido, decoración y música

Paso 3 de `SKILL.md`. Solo lo que el sector necesita; lo que gasta créditos se hace solo si el usuario lo pidió.

- **Texturas y fondo:** `levels/level_skin.gd` → `CHAPTER_THEMES[N]["sectors"]["N_NN"]` pisa `edge`, `ground`, `stone`, `platform`, tonos y `backdrop`. Sin colisiones.
Por defecto el sector **reusa** fondo, texturas, decoración y música del mundo. Lo que gasta créditos (Flow, ElevenLabs) se hace solo si el usuario lo pidió:

- **Fondo con paralaje nuevo:** skill **`parallax-level-background`**.
- **Música propia del sector:** skill **`generate-audio`** (parte A); después `L.music = "<clave>"`. Sin pedido, queda `explore`.
- **Props nuevos o arte propio:** `google-flow` → `art_source/worldN/` → `process.py` → `assets/art/worldN/`, `Godot --headless --path . --import`, y cargar con `Art.tex()`.
- **Decoración:** `levels/city_decor.gd` (`SECTORS`), `meadow_decor.gd`, `hell_decor.gd`; un mundo nuevo = un `*_decor.gd` nuevo registrado en el tema.
