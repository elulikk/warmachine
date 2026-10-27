extends "res://core/cinematics/cinematic_command.gd"
## wait {s}: espera `s` segundos (1 por defecto).


func run(ctx, step: Dictionary) -> void:
	await ctx.wait(float(step.get("s", 1.0)))
