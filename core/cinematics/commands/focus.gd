extends "res://core/cinematics/cinematic_command.gd"
## focus {pos | id, zoom, s}: la cámara va a un punto o a un actor (a la altura de los ojos) con ese zoom.

const Ctx = preload("res://core/cinematics/cinematic_context.gd")


func check(step: Dictionary) -> String:
	if step.has("pos"):
		return "" if step["pos"] is Vector2 else "'pos' tiene que ser un Vector2"
	return "" if step.has("id") else "necesita 'pos' o 'id'"


func run(ctx, step: Dictionary) -> void:
	if not ctx.has_camera():
		return
	var cam: Camera2D = ctx.camera
	var target: Vector2 = cam.global_position
	if step.has("pos"):
		target = step["pos"] as Vector2
	else:
		var actor: Node2D = ctx.actor(str(step["id"]))
		if actor == null:
			ctx.warn("'focus': no existe el actor '%s'" % str(step["id"]))
		else:
			target = actor.global_position + Ctx.EYE_OFFSET
	var zoom: float = float(step.get("zoom", 1.3))
	await ctx.tween(cam, {"global_position": target, "zoom": Vector2(zoom, zoom)}, float(step.get("s", 0.8)), Tween.TRANS_SINE)
