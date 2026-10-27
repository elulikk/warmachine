extends "res://core/cinematics/cinematic_command.gd"
## say {who, text, thought?, s?, on?, zoom?, cut?}: línea de diálogo en primer plano.
## La cámara va a la cabeza de quien habla y abajo aparece solo el subtítulo, sin fondo ni nombre.
## Sin `s` dura según el largo del texto; [Enter]/clic la adelanta. `thought` la muestra entre paréntesis.
##
##   who  = quién habla; el actor sale del elenco (`dialogue` cast: {"GUNTHER": "player"}).
##   on   = id de actor a encuadrar, si no se quiere usar el elenco.
##   zoom = acercamiento de esta línea (el de `dialogue`, 5 por defecto).
##   cut  = true corta al plano sin deslizar la cámara.
## Si quien habla no tiene actor (un narrador, una voz en off), se muestra el subtítulo y la cámara no se mueve.

## Lo que tarda la cámara en ir de una cabeza a otra.
const GLIDE_SECONDS: float = 0.35


func required() -> PackedStringArray:
	return PackedStringArray(["text"])


func run(ctx, step: Dictionary) -> void:
	if ctx.cut():
		return
	var who: String = str(step.get("who", ""))
	var text: String = str(step["text"])
	var stage = ctx.stage
	await _frame_speaker(ctx, step, who)
	if not is_instance_valid(stage) or ctx.cut():
		return
	stage.show_subtitle("(%s)" % text if bool(step.get("thought", false)) else text)
	var seconds: float = float(step.get("s", clampf(float(text.length()) * 0.05 + 1.4, 2.2, 7.0)))
	await ctx.wait_line(seconds)
	if is_instance_valid(stage):
		stage.hide_line()


## Lleva la cámara a la cabeza de quien habla (si tiene actor).
func _frame_speaker(ctx, step: Dictionary, who: String) -> void:
	if not ctx.has_camera():
		return
	var actor_id: String = str(step.get("on", ctx.cast.get(who, "")))
	if actor_id.is_empty():
		return
	var actor: Node2D = ctx.actor(actor_id)
	if actor == null:
		ctx.warn("'say': no existe el actor '%s' (de '%s')" % [actor_id, who])
		return
	var zoom: float = float(step.get("zoom", ctx.closeup_zoom))
	var seconds: float = 0.0 if bool(step.get("cut", false)) else GLIDE_SECONDS
	await ctx.tween(ctx.camera, {"global_position": ctx.head(actor), "zoom": Vector2(zoom, zoom)}, seconds, Tween.TRANS_SINE)
