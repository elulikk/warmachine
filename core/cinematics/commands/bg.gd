extends "res://core/cinematics/cinematic_command.gd"
## bg {file}: fondo pintado a pantalla completa (assets/art/bg/ o ruta res://); "" lo quita.

const Ctx = preload("res://core/cinematics/cinematic_context.gd")


func run(ctx, step: Dictionary) -> void:
	var rect: TextureRect = ctx.stage.bg
	var file: String = str(step.get("file", ""))
	rect.texture = ctx.texture(Ctx.BG_DIR, file) if not file.is_empty() else null
	rect.visible = rect.texture != null
