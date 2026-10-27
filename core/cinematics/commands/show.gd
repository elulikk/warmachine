extends "res://core/cinematics/cinematic_command.gd"
## show {id, file, x, y, h, flip?, tint?}: sprite fijo en pantalla (detrás de las barras).
## x = centro horizontal, y = borde de abajo, h = alto; los tres en fracción de la pantalla.
## Reemplaza al sprite con el mismo id; `hide {id}` lo quita.

const Ctx = preload("res://core/cinematics/cinematic_context.gd")


func required() -> PackedStringArray:
	return PackedStringArray(["file"])


func run(ctx, step: Dictionary) -> void:
	var tex: Texture2D = ctx.texture(Ctx.WORLD_DIR, str(step["file"]))
	if tex == null:
		return
	var stage = ctx.stage
	var rect: TextureRect = TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var view: Vector2 = stage.get_viewport().get_visible_rect().size
	var h: float = view.y * float(step.get("h", 0.6))
	var w: float = h * float(tex.get_width()) / float(tex.get_height())
	rect.custom_minimum_size = Vector2(w, h)
	rect.size = Vector2(w, h)
	rect.position = Vector2(view.x * float(step.get("x", 0.5)) - w * 0.5, view.y * float(step.get("y", 0.9)) - h)
	rect.flip_h = bool(step.get("flip", false))
	if step.has("tint"):
		rect.modulate = step["tint"] as Color
	stage.add_sprite(str(step.get("id", "s")), rect)
