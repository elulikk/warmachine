# Verificar el sector

Paso 4 de `SKILL.md`.

1. `bash .claude/skills/smoke-test/scripts/smoke.sh res://levels/chapter_N/level_N_NN.tscn 150` (respalda y restaura saves).
2. Mirar un cuadro con `--write-movie` (ver `smoke-test`): que el suelo, las arenas y el fondo se lean.
3. Si hay pozos: confirmar a ojo el salto; no se puede validar sin jugar.
4. Reportar qué no se validó (balance, recorrido completo, jefe). Anotar el sector en la lista "hecho, sin verificar" del ROADMAP **una sola vez por tanda**. Sin commit salvo que se pida.
