extends "res://core/cinematics/cinematic_command.gd"
## move {id, to, s}: lleva un actor ("player", id de spawn o "@Ruta/Del/Nodo") a `to` en `s` segundos.


func required() -> PackedStringArray:
	return PackedStringArray(["id", "to"])


func check(step: Dictionary) -> String:
	return "" if step["to"] is Vector2 else "'to' tiene que ser un Vector2"


func run(ctx, step: Dictionary) -> void:
	var actor: Node2D = ctx.actor(str(step["id"]))
	if actor == null:
		ctx.warn("'move': no existe el actor '%s'" % str(step["id"]))
		return
	await ctx.tween(actor, {"global_position": step["to"] as Vector2}, float(step.get("s", 1.0)))
