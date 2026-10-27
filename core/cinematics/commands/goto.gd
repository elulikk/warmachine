extends "res://core/cinematics/cinematic_command.gd"
## goto {path}: termina la cinemática (restaurando todo) y cambia de escena.


func required() -> PackedStringArray:
	return PackedStringArray(["path"])


func check(step: Dictionary) -> String:
	var path: String = str(step["path"])
	return "" if ResourceLoader.exists(path) else "no existe la escena " + path


func run(ctx, step: Dictionary) -> void:
	if ctx.host != null and is_instance_valid(ctx.host):
		ctx.host.stop()
	GameManager.change_scene(str(step["path"]))
