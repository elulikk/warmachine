extends "res://core/cinematics/cinematic_command.gd"
## hide {id}: quita un sprite de pantalla puesto con `show`.


func required() -> PackedStringArray:
	return PackedStringArray(["id"])


func run(ctx, step: Dictionary) -> void:
	ctx.stage.remove_sprite(str(step["id"]))
