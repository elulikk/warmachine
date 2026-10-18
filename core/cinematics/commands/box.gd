extends "res://core/cinematics/cinematic_command.gd"
## box {state}: la Caja del nivel (grupo `the_box`) abierta ("open") o cerrada ("closed"); mantiene su alto.

const Ctx = preload("res://core/cinematics/cinematic_context.gd")


func run(ctx, step: Dictionary) -> void:
	var file: String = "box_open.png" if str(step.get("state", "open")) == "open" else "box_closed.png"
	var tex: Texture2D = ctx.texture(Ctx.WORLD_DIR, file)
	if tex == null:
		return
	for node: Node in ctx.tree.get_nodes_in_group(&"the_box"):
		var sprite: Sprite2D = node as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var keep_h: float = float(sprite.texture.get_height()) * sprite.scale.y
		sprite.texture = tex
		var k: float = keep_h / float(tex.get_height())
		sprite.scale = Vector2(k, k)
