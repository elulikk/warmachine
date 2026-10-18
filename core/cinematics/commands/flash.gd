extends "res://core/cinematics/cinematic_command.gd"
## flash {s, color?}: destello a pantalla completa que se apaga en `s` segundos (blanco por defecto).


func run(ctx, step: Dictionary) -> void:
	var rect: ColorRect = ctx.stage.flash
	var color: Color = step.get("color", Color.WHITE) as Color
	rect.color = Color(color, 1.0)
	await ctx.tween(rect, {"color:a": 0.0}, float(step.get("s", 0.4)))
