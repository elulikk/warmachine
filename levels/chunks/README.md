# Tramos prearmados

Escenas chicas (`chunk_*.tscn`, script `level_chunk.gd`) que se arrastran dentro de un sector en el editor de Godot.

1. Abrí el sector (p. ej. `levels/chapter_1/level_1_01.tscn`) y arrastrá el `.tscn` del tramo a la **raíz** del nivel (no a `Environment`).
2. Movelo con el borde izquierdo (línea verde) donde quieras que empiece. El siguiente tramo va en `x + ancho`.
3. Al jugar, el nodo `Geometry` del tramo se pasa solo a `Environment`: el tileset y la decoración del mundo lo revisten igual que al resto.
4. Para crear uno nuevo: duplicá un `chunk_*.tscn`, editá `Geometry` (cuerpos con `ColorRect`, suelo a y=556) y los enemigos. Los checkpoints y arenas van como hijos del tramo.

Tramos hoy: pasillo de ratas, pasillo de asaltantes, arena de ratas.
