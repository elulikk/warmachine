extends Node
## Capa de Invisibilidad (Fase de ideas a futuro). Lo agrega Player en `_ready`.
## Con el ítem equipado (`Player.has_cloak`) la acción `cloak` activa la invisibilidad: los enemigos pierden el agro
## (ver `Player.is_invisible`, que leen BasicRunner, brutos, centinelas, fantasmas y el escáner de blancos).
## Dura DURATION y después tiene recarga.
##
## Robo de la capa: si mientras es invisible un enemigo lo toca o le pega, el enemigo más cercano le roba la capa:
## la invisibilidad se corta y ese enemigo queda invisible. El jugador no puede volver a usar la capa hasta que ese
## enemigo muera (por cualquier causa); lo tiene que encontrar por el contorno tenue y el sonido que hace al moverse.
## Sin class_name a propósito: se carga por preload (ver class-name-cache-gotcha).

const SfxScript = preload("res://core/sfx.gd")

const DURATION: float = 8.0
const COOLDOWN: float = 10.0
const PLAYER_ALPHA: float = 0.35
const THIEF_ALPHA: float = 0.14
## Distancia máxima a la que un enemigo cuenta como el que robó la capa.
const STEAL_RADIUS: float = 420.0

var _player: Player = null
var _time_left: float = 0.0
var _cooldown_left: float = 0.0
var _thief: Node2D = null
var _thief_sound_left: float = 0.0


func _ready() -> void:
	_player = get_parent() as Player


func _exit_tree() -> void:
	_release_thief()


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _player.is_invisible:
		_time_left -= delta
		if _time_left <= 0.0 or not _player.has_cloak:
			_end_invisibility(true)
	if _thief != null:
		_update_thief(delta)
	if InputMap.has_action(&"cloak") and Input.is_action_just_pressed(&"cloak"):
		_toggle()


func _toggle() -> void:
	if not _player.has_cloak:
		return
	if _thief != null:
		_popup("La capa sigue robada: encontrá al ladrón", Color(1.0, 0.5, 0.4, 1.0))
		return
	if _player.is_invisible:
		_end_invisibility(true)
	elif _cooldown_left > 0.0:
		_popup("Capa recargándose (%d s)" % ceili(_cooldown_left), Color(0.8, 0.8, 0.9, 1.0))
	else:
		_begin_invisibility()


func _begin_invisibility() -> void:
	_player.is_invisible = true
	_time_left = DURATION
	_player.modulate.a = PLAYER_ALPHA
	SfxScript.play(self, &"cloak_on", Vector2.INF, -4.0)
	_popup("Invisible", Color(0.6, 0.85, 1.0, 1.0))


func _end_invisibility(with_cooldown: bool) -> void:
	if not _player.is_invisible:
		return
	_player.is_invisible = false
	_player.modulate.a = 1.0
	if with_cooldown:
		_cooldown_left = COOLDOWN
	SfxScript.play(self, &"cloak_off", Vector2.INF, -4.0)


## Lo llama Player.take_damage: si estaba invisible, el enemigo más cercano se queda con la capa.
func on_player_hit() -> void:
	if _player == null or not _player.is_invisible or _thief != null:
		return
	var best: Node2D = null
	var best_dist: float = STEAL_RADIUS
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		var dist: float = enemy.global_position.distance_to(_player.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	if best == null:
		return
	_end_invisibility(false)
	_thief = best
	_thief.set_meta(&"is_invisible", true)
	_thief.modulate.a = THIEF_ALPHA
	_thief.tree_exiting.connect(_on_thief_gone, CONNECT_ONE_SHOT)
	_popup("¡Te robaron la capa!", Color(1.0, 0.4, 0.3, 1.0))


func _on_thief_gone() -> void:
	_thief = null
	_cooldown_left = 0.0
	if _player != null and is_instance_valid(_player) and _player.has_cloak:
		_popup("Recuperaste la capa", Color(0.5, 1.0, 0.6, 1.0))


func _release_thief() -> void:
	if _thief != null and is_instance_valid(_thief):
		_thief.remove_meta(&"is_invisible")
		_thief.modulate.a = 1.0
	_thief = null


## El ladrón invisible delata su posición con un roce de tela cada tanto, atenuado por la distancia.
func _update_thief(delta: float) -> void:
	if not is_instance_valid(_thief):
		return
	_thief_sound_left -= delta
	if _thief_sound_left <= 0.0:
		_thief_sound_left = 1.1
		SfxScript.play(self, &"cloak_on", _thief.global_position, -10.0, 0.7)


func _popup(text: String, color: Color) -> void:
	var host: Node = get_tree().current_scene
	if host == null or _player == null:
		return
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 4)
	label.add_theme_font_size_override(&"font_size", 15)
	label.z_index = 100
	label.global_position = _player.global_position + Vector2(-70.0, -110.0)
	host.add_child(label)
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40.0, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.5)
	tween.finished.connect(label.queue_free)
