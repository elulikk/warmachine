extends "res://core/cinematics/cinematic_command.gd"
## sfx {name, db?}: efecto de sonido de la biblioteca de Sfx (no suena si se está saltando).


func required() -> PackedStringArray:
	return PackedStringArray(["name"])


func run(ctx, step: Dictionary) -> void:
	if ctx.skipping or ctx.host == null or not is_instance_valid(ctx.host):
		return
	GameFeel.sfx(ctx.host, StringName(str(step["name"])), Vector2.INF, float(step.get("db", -2.0)))
