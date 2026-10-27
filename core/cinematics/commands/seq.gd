extends "res://core/cinematics/cinematic_command.gd"
## seq {steps}: varios pasos en orden. Sirve como rama de un `par` o para agrupar pasos reutilizables.


func required() -> PackedStringArray:
	return PackedStringArray(["steps"])


func check(step: Dictionary) -> String:
	return "" if step["steps"] is Array else "'steps' tiene que ser una lista"


func children(step: Dictionary) -> Array:
	var subs: Variant = step.get("steps", [])
	return subs as Array if subs is Array else []


func run(ctx, step: Dictionary) -> void:
	for sub: Variant in step["steps"] as Array:
		if ctx.stopped:
			return
		await ctx.run_step(sub)
