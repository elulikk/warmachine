extends RefCounted
## Todo lo que cae al piso (monedas, experiencia, ítems, armas, runas) desaparece al minuto: parpadea y se apaga.

const LIFETIME: float = 60.0
const BLINK_TIME: float = 3.0


## Programa la desaparición de `node`. Si ya se recogió o se liberó antes, no hace nada.
static func arm(node: Node) -> void:
	if node == null or not node.is_inside_tree():
		return
	var tree: SceneTree = node.get_tree()
	tree.create_timer(LIFETIME - BLINK_TIME, false).timeout.connect(_start_fade.bind(node))


static func _start_fade(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion():
		return
	var item: CanvasItem = node as CanvasItem
	if item == null:
		node.queue_free()
		return
	var tween: Tween = node.create_tween()
	tween.tween_property(item, "modulate:a", 0.25, 0.25).set_loops(int(BLINK_TIME / 0.5))
	tween.tween_property(item, "modulate:a", 0.0, 0.25)
	tween.tween_callback(node.queue_free)
