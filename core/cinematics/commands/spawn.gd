extends "res://core/cinematics/cinematic_command.gd"
## spawn {id, file, pos, h, flip?, z?}: sprite en el mundo (assets/art/world1/ o ruta res://), con los pies en `pos`
## y `h` píxeles de alto. Queda como actor `id` (para move/focus/remove) y se borra al terminar la cinemática.
## `head` (Vector2 desde los pies) corrige dónde apunta el primer plano (por defecto, al 85 % del alto).

const Ctx = preload("res://core/cinematics/cinematic_context.gd")


func required() -> PackedStringArray:
	return PackedStringArray(["id", "file", "pos"])


func check(step: Dictionary) -> String:
	return "" if step["pos"] is Vector2 else "'pos' tiene que ser un Vector2"


func run(ctx, step: Dictionary) -> void:
	if ctx.level == null or not is_instance_valid(ctx.level):
		ctx.warn("'spawn' sin nivel donde poner el actor")
		return
	var tex: Texture2D = ctx.texture(Ctx.WORLD_DIR, str(step["file"]))
	if tex == null:
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	sprite.z_index = int(step.get("z", 8))
	var s: float = float(step.get("h", 60.0)) / float(tex.get_height())
	sprite.scale = Vector2(s * (-1.0 if bool(step.get("flip", false)) else 1.0), s)
	sprite.offset = Vector2(0.0, -tex.get_height() * 0.5)
	ctx.level.add_child(sprite)
	sprite.global_position = step["pos"] as Vector2
	sprite.set_meta(&"cine_head", step.get("head", Vector2(0.0, -float(step.get("h", 60.0)) * 0.85)))
	ctx.add_actor(str(step["id"]), sprite)
