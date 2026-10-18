extends Node
## Flauta de Hamelin. Lo agrega Player en `_ready`.
## Con el accesorio equipado (`Player.has_hamelin_flute`) las ratas enemigas que se acercan al jugador dejan de serlo:
## se las reemplaza por una `RatAlly` en el mismo lugar. Hasta MAX_ALLIES a la vez. Los jefes (grupo `boss`) no se convierten.
## Sin class_name a propósito: se carga por preload (ver class-name-cache-gotcha).

const SfxScript = preload("res://core/sfx.gd")
const RatAllyScript = preload("res://entities/allies/rat_ally.gd")

const MAX_ALLIES: int = 8
## Alcance horizontal y vertical (px) desde el jugador.
const RADIUS_X: float = 320.0
const RADIUS_Y: float = 180.0
const CHECK_INTERVAL: float = 0.3
const NOTE_COLOR: Color = Color(0.6, 1.0, 0.65, 1.0)

var _player: Player = null
var _time_left: float = 0.0


func _ready() -> void:
	_player = get_parent() as Player
	_time_left = CHECK_INTERVAL


func _physics_process(delta: float) -> void:
	if _player == null or not _player.has_hamelin_flute:
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	_time_left = CHECK_INTERVAL
	_charm_nearby_rats()


func _charm_nearby_rats() -> void:
	var allies: int = get_tree().get_nodes_in_group(RatAllyScript.GROUP_RAT_ALLIES).size()
	if allies >= MAX_ALLIES:
		return
	var converted: bool = false
	for node: Node in get_tree().get_nodes_in_group(RatAllyScript.GROUP_ENEMIES):
		if allies >= MAX_ALLIES:
			break
		var rat: Node2D = node as Node2D
		if rat == null or not _is_charmable(rat):
			continue
		var offset: Vector2 = rat.global_position - _player.global_position
		if absf(offset.x) > RADIUS_X or absf(offset.y) > RADIUS_Y:
			continue
		_convert(rat)
		allies += 1
		converted = true
	if converted:
		SfxScript.play(self, &"flute_call", _player.global_position, -4.0, randf_range(0.95, 1.05))


## Rata común: tipo de arte "rat", visible, viva y que no sea jefe.
func _is_charmable(rat: Node2D) -> bool:
	if not rat.visible or rat.is_queued_for_deletion() or rat.is_in_group(&"boss"):
		return false
	if not rat.has_method("convert_to_ally") or not ("art_kind" in rat):
		return false
	return str(rat.get("art_kind")) == "rat"


func _convert(rat: Node2D) -> void:
	var host: Node = rat.get_parent()
	if host == null:
		return
	var spot: Vector2 = rat.global_position
	var ally: Node2D = RatAllyScript.new() as Node2D
	host.add_child(ally)
	ally.global_position = spot
	rat.call("convert_to_ally")
	_float_note(spot + Vector2(0.0, -46.0))


## Una nota que sube y se desvanece sobre la rata convertida.
func _float_note(pos: Vector2) -> void:
	var host: Node = get_tree().current_scene
	if host == null:
		return
	var note: Label = Label.new()
	note.text = "♪"
	note.add_theme_font_size_override("font_size", 22)
	note.add_theme_color_override("font_color", NOTE_COLOR)
	note.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	note.add_theme_constant_override("outline_size", 4)
	note.z_index = 50
	host.add_child(note)
	note.global_position = pos + Vector2(-8.0, 0.0)
	var tween: Tween = note.create_tween()
	tween.set_parallel(true)
	tween.tween_property(note, "position:y", note.position.y - 44.0, 0.9)
	tween.tween_property(note, "modulate:a", 0.0, 0.9)
	tween.chain().tween_callback(note.queue_free)
