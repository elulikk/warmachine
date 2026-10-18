extends "res://core/cinematics/cinematic_command.gd"
## release {s}: la cámara vuelve al jugador con el zoom que tenía antes de la cinemática.

const Ctx = preload("res://core/cinematics/cinematic_context.gd")


func run(ctx, step: Dictionary) -> void:
	if not ctx.has_camera():
		return
	var cam: Camera2D = ctx.camera
	var target: Vector2 = cam.global_position
	var player: Node2D = ctx.actor("player")
	if player != null:
		target = player.global_position + Ctx.EYE_OFFSET
	await ctx.tween(cam, {"global_position": target, "zoom": ctx.cam_zoom}, float(step.get("s", 0.6)), Tween.TRANS_SINE)
