extends Node
## Flauta de Hamelin. Lo agrega Player en `_ready`.
## Con el accesorio equipado (`Player.has_hamelin_flute`) las ratas enemigas que se acercan al jugador dejan de serlo:
## se las reemplaza por una `RatAlly` en el mismo lugar. Hasta MAX_ALLIES a la vez. Los jefes (grupo `boss`) no se convierten.
## Canto de la plaga (acción `flute_song`, J): hechiza a las ratas en un radio mucho mayor, renueva el tiempo de las
## aliadas y, si quedan menos de SONG_MIN_ALLIES, hace salir ratas del suelo hasta completar. Recarga SONG_COOLDOWN.
## Sin class_name a propósito: se carga por preload (ver class-name-cache-gotcha).

const SfxScript = preload("res://core/sfx.gd")
const RatAllyScript = preload("res://entities/allies/rat_ally.gd")

const MAX_ALLIES: int = 8
## Segundos que dura cada rata hechizada.
const ALLY_LIFETIME: float = 25.0
## Alcance horizontal y vertical (px) desde el jugador.
const RADIUS_X: float = 320.0
const RADIUS_Y: float = 180.0
const CHECK_INTERVAL: float = 0.3
const NOTE_COLOR: Color = Color(0.6, 1.0, 0.65, 1.0)

const SONG_COOLDOWN: float = 20.0
const SONG_RADIUS_X: float = 760.0
const SONG_RADIUS_Y: float = 320.0
const SONG_MIN_ALLIES: int = 3

var _player: Player = null
var _time_left: float = 0.0
## Recarga del canto (s); la lee la UI si hace falta.
var song_cooldown_left: float = 0.0


func _ready() -> void:
	_player = get_parent() as Player
	_time_left = CHECK_INTERVAL


func _physics_process(delta: float) -> void:
	if song_cooldown_left > 0.0:
		song_cooldown_left = maxf(0.0, song_cooldown_left - delta)
	if _player == null or not _player.has_hamelin_flute:
		return
	if song_cooldown_left <= 0.0 and InputMap.has_action(&"flute_song") and Input.is_action_just_pressed(&"flute_song"):
		_play_song()
	_time_left -= delta
	if _time_left > 0.0:
		return
	_time_left = CHECK_INTERVAL
	_charm_nearby_rats()


func _play_song() -> void:
	song_cooldown_left = SONG_COOLDOWN
	SfxScript.play(self, &"flute_call", _player.global_position, 0.0, 0.85)
	GameFeel.shake(self, 2.0, 0.2)
	for i: int in 6:
		_float_note(_player.global_position + Vector2(randf_range(-60.0, 60.0), -70.0 - randf_range(0.0, 30.0)))
	# Renueva a las aliadas que ya hay
	for ally: Node in get_tree().get_nodes_in_group(RatAllyScript.GROUP_RAT_ALLIES):
		ally.call("set_lifetime", ALLY_LIFETIME)
	_charm_nearby_rats(SONG_RADIUS_X, SONG_RADIUS_Y)
	# Si no alcanza, salen ratas del suelo a los costados del jugador
	var allies: int = get_tree().get_nodes_in_group(RatAllyScript.GROUP_RAT_ALLIES).size()
	var host: Node = _player.get_parent()
	var i: int = 0
	while allies < SONG_MIN_ALLIES and host != null:
		var ally: Node2D = RatAllyScript.new() as Node2D
		host.add_child(ally)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		ally.global_position = _player.global_position + Vector2(side * (40.0 + 25.0 * float(i)), -10.0)
		ally.call("set_lifetime", ALLY_LIFETIME)
		_float_note(ally.global_position + Vector2(0.0, -46.0))
		allies += 1
		i += 1


func _charm_nearby_rats(radius_x: float = RADIUS_X, radius_y: float = RADIUS_Y) -> void:
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
		if absf(offset.x) > radius_x or absf(offset.y) > radius_y:
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
	ally.call("set_lifetime", ALLY_LIFETIME)
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
