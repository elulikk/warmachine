extends Node
## Despide a los aliados que siguen al Jugador (mercenarios contratados y drones de apoyo) con la tecla T.
## Hijo del Player. Los despedidos dejan de atacar, se desvanecen y se liberan.
## No toca los esqueletos de Frostmourne: esos desaparecen solos al morir.

const FADE_TIME: float = 0.3


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dismiss_allies"):
		get_viewport().set_input_as_handled()
		dismiss_all()


func dismiss_all() -> void:
	for ally: Node in get_tree().get_nodes_in_group(&"allies"):
		if _is_dismissable(ally):
			_dismiss(ally as Node2D)


func _is_dismissable(ally: Node) -> bool:
	if ally is SupportDrone:
		return true
	return ally is MercenarySkeleton and (ally as MercenarySkeleton).is_hired


func _dismiss(ally: Node2D) -> void:
	# Sale del grupo y apaga su física para que no dispare ni se mueva mientras se desvanece
	ally.remove_from_group(&"allies")
	ally.set_physics_process(false)
	var tw: Tween = ally.create_tween()
	tw.tween_property(ally, "modulate:a", 0.0, FADE_TIME)
	tw.finished.connect(ally.queue_free)
