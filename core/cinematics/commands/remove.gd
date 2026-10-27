extends "res://core/cinematics/cinematic_command.gd"
## remove {id}: borra un actor creado con `spawn`.


func required() -> PackedStringArray:
	return PackedStringArray(["id"])


func run(ctx, step: Dictionary) -> void:
	ctx.remove_actor(str(step["id"]))
