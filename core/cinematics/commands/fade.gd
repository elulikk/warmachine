extends "res://core/cinematics/cinematic_command.gd"
## fade {to, s}: fundido a negro (to = 1) o desde negro (to = 0).


func run(ctx, step: Dictionary) -> void:
	await ctx.tween(ctx.stage.fade, {"color:a": clampf(float(step.get("to", 1.0)), 0.0, 1.0)}, float(step.get("s", 0.6)))
