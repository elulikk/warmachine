extends "res://core/cinematics/cinematic_command.gd"
## call {fn}: ejecuta un Callable. Si es una corrutina se la espera (cortable: con el tope de tiempo
## o al saltar, la cinemática sigue sin ella).


func required() -> PackedStringArray:
	return PackedStringArray(["fn"])


func check(step: Dictionary) -> String:
	return "" if step["fn"] is Callable else "'fn' tiene que ser un Callable"


func run(ctx, step: Dictionary) -> void:
	var fn: Callable = step["fn"] as Callable
	if not fn.is_valid():
		ctx.warn("'call' con un Callable inválido (¿se borró su objeto?)")
		return
	var done: Array = [false]
	_invoke(fn, done)
	while not done[0] and not ctx.cut():
		await ctx.frame()


func _invoke(fn: Callable, done: Array) -> void:
	await fn.call()
	done[0] = true
