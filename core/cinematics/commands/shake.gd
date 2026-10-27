extends "res://core/cinematics/cinematic_command.gd"
## shake {amp, s}: sacude la cámara `amp` píxeles durante `s` segundos. Al saltar no hace nada.


func run(ctx, step: Dictionary) -> void:
	if not ctx.has_camera() or ctx.cut():
		return
	var cam: Camera2D = ctx.camera
	var amp: float = float(step.get("amp", 6.0))
	var origin: Vector2 = cam.offset
	var timer: SceneTreeTimer = ctx.tree.create_timer(float(step.get("s", 0.4)), true)
	while timer.time_left > 0.0 and not ctx.cut() and is_instance_valid(cam):
		cam.offset = origin + Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		await ctx.frame()
	if is_instance_valid(cam):
		cam.offset = origin
