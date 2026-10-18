extends RefCounted
## Base de los comandos de cinemática. Un comando no guarda estado: recibe el contexto y el paso (diccionario)
## y hace su trabajo. Hay una sola instancia por tipo (la cachea cinematic_registry.gd).
##
## Para agregar un comando:
##   1. crear `core/cinematics/commands/<nombre>.gd` con `extends "res://core/cinematics/cinematic_command.gd"`;
##   2. sumarlo a `BUILTIN` en cinematic_registry.gd (o `Registry.register("nombre", script)` desde otro lado).
##
## Reglas para que el motor sea robusto:
##   - si `ctx.cut()` da true (se saltó la cinemática, se pasó del tiempo o se cortó), terminar YA dejando el
##     estado final (posición de llegada, fundido completo…): los pasos que cambian el estado se aplican igual;
##   - esperar siempre con `ctx.wait()`, `ctx.tween()` o `ctx.frame()`, nunca con timers propios;
##   - todo nodo puede haber desaparecido después de un await: comprobar con `is_instance_valid`.


## Claves obligatorias del paso (además de "t").
func required() -> PackedStringArray:
	return PackedStringArray()


## Validación extra del paso: "" si está bien, si no el motivo.
func check(_step: Dictionary) -> String:
	return ""


## Pasos hijos (para `par` y `seq`), así la validación recorre todo el árbol.
func children(_step: Dictionary) -> Array:
	return []


## Ejecuta el paso. Puede usar await.
func run(_ctx, _step: Dictionary) -> void:
	pass
