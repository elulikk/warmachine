extends "res://core/cinematics/cinematic_command.gd"
## title {text, s}: texto grande centrado que aparece, se queda `s` segundos y se va.


func required() -> PackedStringArray:
	return PackedStringArray(["text"])


func run(ctx, step: Dictionary) -> void:
	var label: Label = ctx.stage.title_label
	label.text = str(step["text"])
	await ctx.tween(label, {"modulate:a": 1.0}, 0.5)
	await ctx.wait(float(step.get("s", 2.5)))
	await ctx.tween(label, {"modulate:a": 0.0}, 0.5)
