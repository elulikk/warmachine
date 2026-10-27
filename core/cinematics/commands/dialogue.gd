extends "res://core/cinematics/cinematic_command.gd"
## dialogue {cast?, zoom?}: prepara los `say` que siguen.
##   cast = quién es quién en el mundo: {"GUNTHER": "player", "AGENTE": "a"} (ids de actor; se suma al anterior).
##   zoom = acercamiento del primer plano (5 por defecto).


func check(step: Dictionary) -> String:
	if step.has("cast") and not step["cast"] is Dictionary:
		return "'cast' tiene que ser un diccionario nombre -> id de actor"
	return ""


func run(ctx, step: Dictionary) -> void:
	if step.has("cast"):
		ctx.cast.merge(step["cast"] as Dictionary, true)
	if step.has("zoom"):
		ctx.closeup_zoom = maxf(float(step["zoom"]), 0.1)
