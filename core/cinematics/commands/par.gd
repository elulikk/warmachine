extends "res://core/cinematics/cinematic_command.gd"
## par {steps}: ejecuta varios pasos a la vez y termina cuando terminan todos (hablar mientras se camina).
## Para una rama con varios pasos en orden, usar un `seq` dentro.

## Cuadros de gracia para que las ramas terminen después de un corte antes de seguir sin ellas.
const GRACE_FRAMES: int = 3


func required() -> PackedStringArray:
	return PackedStringArray(["steps"])


func check(step: Dictionary) -> String:
	return "" if step["steps"] is Array else "'steps' tiene que ser una lista"


func children(step: Dictionary) -> Array:
	var subs: Variant = step.get("steps", [])
	return subs as Array if subs is Array else []


func run(ctx, step: Dictionary) -> void:
	var subs: Array = step["steps"] as Array
	var pending: Array = [subs.size()]
	for sub: Variant in subs:
		_branch(ctx, sub, pending)
	var grace: int = 0
	while pending[0] > 0 and not ctx.stopped:
		if ctx.cut():
			grace += 1
			if grace > GRACE_FRAMES:
				ctx.warn("'par' siguió sin esperar %d rama(s) colgada(s)" % pending[0])
				return
		await ctx.frame()


func _branch(ctx, sub: Variant, pending: Array) -> void:
	await ctx.run_step(sub)
	pending[0] -= 1
