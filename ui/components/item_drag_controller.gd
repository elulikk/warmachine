extends CanvasLayer
## Controlador global de "ítem en mano" (arrastrar y soltar propio, reemplaza el drag nativo de Godot).
## Sin class_name a propósito: se carga por `preload` desde quien lo usa (ver ItemSlot).
##
## Es genérico: no conoce ItemSlot ni ninguna ventana. Trabaja con un protocolo de duck typing, así
## cualquier Control nuevo (ranuras de otro menú, un cofre del mundo, etc.) puede participar:
##
## ORIGEN (quien llama a begin_press):
##   - set_carried(carried: bool)         atenuar o restaurar su ícono mientras el ítem está en mano
##   - get_item() -> Resource             ítem que contiene (el controlador cancela si ya no coincide)
##
## DESTINO (Control del grupo "drop_targets"):
##   - can_accept_carried(res: Resource, payload: Dictionary) -> bool
##   - receive_carried(payload: Dictionary)   ejecuta la transferencia (el destino emite su señal)
##   - set_drop_state(state: int)             0 ninguno, 1 candidato, 2 sobre válido, 3 sobre inválido
##   - get_item() -> Resource
##   - play_drop_pop()                        (opcional) rebote al recibir
##
## PAYLOAD (Dictionary, lo arma el origen): "resource" y lo que cada ventana necesite
## ("context_tag", "slot_index", ...) más datos de dibujo: "display_color", "display_text",
## "rarity_color" y opcionalmente "icon" (Texture2D).
##
## Al validar un swap, el controlador pregunta al origen si acepta el ítem desplazado con un payload
## reducido que incluye "is_displaced": true (el casillero de origen quedará libre).
##
## El ítem nunca sale de su contenedor hasta que el destino acepta el drop: cancelar es siempre seguro.

enum CarryState { IDLE, PRESSED, CARRYING }
enum CarryMode { DRAG, STICKY }

const TARGETS_GROUP: StringName = &"drop_targets"
const WINDOWS_GROUP: StringName = &"draggable_windows"

const DROP_NONE: int = 0
const DROP_CANDIDATE: int = 1
const DROP_HOVER_OK: int = 2
const DROP_HOVER_BAD: int = 3

const DRAG_THRESHOLD: float = 5.0
const FOLLOW_SPEED: float = 26.0
const CARRY_SCALE: float = 1.14
const SETTLE_SCALE: float = 1.02
const MAX_TILT: float = 0.22
const CANDIDATE_REFRESH_SECONDS: float = 0.2
const SHAKE_SECONDS: float = 0.22
const SOUND_RATE: int = 22050

var _state: CarryState = CarryState.IDLE
var _mode: CarryMode = CarryMode.DRAG
var _source: Control = null
var _resource: Resource = null
var _payload: Dictionary = {}
var _carry_on_click: bool = true
var _press_pos: Vector2 = Vector2.ZERO
var _swallow_release: bool = false

var _ghost: ItemGhost = null
var _hover: Control = null
var _candidates: Array[Control] = []
var _refresh_timer: float = 0.0
var _ghost_velocity: float = 0.0
var _shake_left: float = 0.0

var _sfx_player: AudioStreamPlayer = null
var _sounds: Dictionary = {}


## Representación visual del ítem en mano.
class ItemGhost extends Control:
	var fill_color: Color = Color(0.6, 0.6, 0.6, 1.0)
	var border_color: Color = Color.WHITE
	var label_text: String = ""
	var icon: Texture2D = null

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(Vector2(4.0, 5.0), size), Color(0.0, 0.0, 0.0, 0.35))
		draw_rect(rect, Color(0.1, 0.12, 0.16, 0.96))
		if icon != null:
			draw_texture_rect(icon, rect.grow(-4.0), false)
		else:
			draw_rect(rect.grow(-4.0), fill_color)
			var font: Font = ThemeDB.fallback_font
			draw_string(font, Vector2(0.0, size.y * 0.5 + 5.0), label_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color.WHITE)
		draw_rect(rect, border_color, false, 2.0)


func _ready() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.volume_db = -14.0
	add_child(_sfx_player)
	set_process(false)


## Indica si hay un ítem en mano (o un clic pendiente que puede convertirse en agarre).
func is_busy() -> bool:
	return _state != CarryState.IDLE


## Indica si el ítem ya está levantado (no solo presionado).
func is_carrying() -> bool:
	return _state == CarryState.CARRYING


## Llamado por el origen al presionar el botón izquierdo sobre un ítem.
func begin_press(source: Control, resource: Resource, payload: Dictionary, carry_on_click: bool) -> void:
	if _state != CarryState.IDLE or source == null or resource == null:
		return
	_dispose_ghost_now()
	_source = source
	_resource = resource
	_payload = payload
	_carry_on_click = carry_on_click
	_press_pos = get_viewport().get_mouse_position()
	_swallow_release = false
	_state = CarryState.PRESSED


func _input(event: InputEvent) -> void:
	if _state == CarryState.IDLE:
		return

	if _state == CarryState.PRESSED:
		if event is InputEventMouseMotion:
			var motion: InputEventMouseMotion = event as InputEventMouseMotion
			if motion.position.distance_to(_press_pos) >= DRAG_THRESHOLD:
				_start_carry(CarryMode.DRAG)
		elif event is InputEventMouseButton:
			var button: InputEventMouseButton = event as InputEventMouseButton
			if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
				if _carry_on_click:
					_start_carry(CarryMode.STICKY)
					get_viewport().set_input_as_handled()
				else:
					_reset_state()
		return

	# CarryState.CARRYING
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_return_to_source(false)
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			get_viewport().set_input_as_handled()
			_return_to_source(false)
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if _swallow_release and not mouse_event.pressed:
				_swallow_release = false
				get_viewport().set_input_as_handled()
			elif _mode == CarryMode.DRAG and not mouse_event.pressed:
				get_viewport().set_input_as_handled()
				_try_drop()
			elif _mode == CarryMode.STICKY and mouse_event.pressed:
				get_viewport().set_input_as_handled()
				_swallow_release = true
				_try_drop()


func _process(delta: float) -> void:
	if _state != CarryState.CARRYING:
		return

	# Cancelar si el origen desapareció, se ocultó o ya no contiene el ítem
	if not _source_still_valid():
		_abort_carry()
		return

	# Red de seguridad: se perdió el evento de soltar el botón durante un arrastre
	if _mode == CarryMode.DRAG and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_drop()
		return

	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = CANDIDATE_REFRESH_SECONDS
		_refresh_candidates()

	_update_hover()
	_update_ghost(delta)


# ==============================================================================
# Ciclo de vida del agarre
# ==============================================================================

func _start_carry(mode: CarryMode) -> void:
	_mode = mode
	_state = CarryState.CARRYING
	_shake_left = 0.0
	_ghost_velocity = 0.0
	if _source.has_method(&"set_carried"):
		_source.call(&"set_carried", true)

	_ghost = ItemGhost.new()
	var ghost_size: Vector2 = _source.size if _source.size.x > 8.0 else Vector2(40.0, 40.0)
	_ghost.size = ghost_size
	_ghost.custom_minimum_size = ghost_size
	_ghost.pivot_offset = ghost_size * 0.5
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ghost.fill_color = _payload.get("display_color", Color(0.6, 0.6, 0.6, 1.0))
	_ghost.label_text = str(_payload.get("display_text", ""))
	_ghost.border_color = _payload.get("rarity_color", Color.WHITE)
	_ghost.icon = _payload.get("icon", null) as Texture2D
	add_child(_ghost)
	_ghost.global_position = _source.get_global_rect().get_center() - ghost_size * 0.5

	# Levantar: pequeño "pop" de escala hacia el tamaño de transporte
	_ghost.scale = Vector2.ONE
	var lift: Tween = create_tween()
	lift.tween_property(_ghost, "scale", Vector2(CARRY_SCALE, CARRY_SCALE), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_play_sound(&"pick")
	_refresh_timer = 0.0
	_refresh_candidates()
	set_process(true)


func _reset_state() -> void:
	_state = CarryState.IDLE
	_source = null
	_resource = null
	_payload = {}
	_hover = null
	_swallow_release = false
	set_process(false)


func _source_still_valid() -> bool:
	if _source == null or not is_instance_valid(_source) or not _source.is_visible_in_tree():
		return false
	if _source.has_method(&"get_item"):
		return _source.call(&"get_item") == _resource
	return true


## Cancelación abrupta (origen destruido o vaciado): sin animación hacia el origen.
func _abort_carry() -> void:
	_clear_drop_states()
	if _source != null and is_instance_valid(_source) and _source.has_method(&"set_carried"):
		_source.call(&"set_carried", false)
	_dispose_ghost_now()
	_reset_state()


func _return_to_source(play_reject_sound: bool) -> void:
	_clear_drop_states()
	var src: Control = _source
	var ghost: ItemGhost = _ghost
	_ghost = null
	_reset_state()
	if play_reject_sound:
		_play_sound(&"reject")
	if ghost == null:
		return
	var dest: Vector2 = ghost.global_position
	if src != null and is_instance_valid(src):
		dest = src.get_global_rect().get_center() - ghost.size * 0.5
	var back: Tween = create_tween()
	back.set_parallel(true)
	back.tween_property(ghost, "global_position", dest, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	back.tween_property(ghost, "scale", Vector2.ONE, 0.14)
	back.tween_property(ghost, "rotation", 0.0, 0.14)
	back.chain().tween_callback(func() -> void:
		if is_instance_valid(ghost):
			ghost.queue_free()
		if src != null and is_instance_valid(src) and src.has_method(&"set_carried"):
			# No restaurar si el mismo origen volvió a agarrarse durante la animación
			if not (_state != CarryState.IDLE and _source == src):
				src.call(&"set_carried", false)
	)


func _finish_success(target: Control) -> void:
	_clear_drop_states()
	var src: Control = _source
	var ghost: ItemGhost = _ghost
	_ghost = null
	_reset_state()
	_play_sound(&"drop")
	if src != null and is_instance_valid(src) and src.has_method(&"set_carried"):
		src.call(&"set_carried", false)
	if target != null and is_instance_valid(target) and target.has_method(&"play_drop_pop"):
		target.call(&"play_drop_pop")
	if ghost != null:
		var settle: Tween = create_tween()
		settle.set_parallel(true)
		settle.tween_property(ghost, "scale", Vector2(0.9, 0.9), 0.1)
		settle.tween_property(ghost, "modulate:a", 0.0, 0.1)
		settle.chain().tween_callback(ghost.queue_free)


func _dispose_ghost_now() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null


# ==============================================================================
# Soltar
# ==============================================================================

func _try_drop() -> void:
	var target: Control = _target_under_mouse()

	# Fuera de ventanas o sobre el propio origen: el ítem vuelve a su lugar
	if target == null or target == _source:
		_return_to_source(false)
		return

	if not _can_place(target):
		_on_rejected()
		return

	var carried: Resource = _resource
	var source_ref: Control = _source
	target.call(&"receive_carried", _payload)

	# Éxito = el destino ahora contiene el ítem, o el origen ya no lo tiene
	var target_has_it: bool = is_instance_valid(target) and target.call(&"get_item") == carried
	var source_lost_it: bool = not is_instance_valid(source_ref) or source_ref.call(&"get_item") != carried
	if target_has_it or source_lost_it:
		_finish_success(target)
	else:
		_on_rejected()


## Drop inválido: en modo "clic-clic" se queda en mano con un sacudón; en arrastre vuelve al origen.
func _on_rejected() -> void:
	if _mode == CarryMode.STICKY:
		_shake_left = SHAKE_SECONDS
		_play_sound(&"reject")
	else:
		_return_to_source(true)


# ==============================================================================
# Destinos
# ==============================================================================

func _can_place(target: Control) -> bool:
	if target == null or target == _source or not target.has_method(&"can_accept_carried"):
		return false
	if not bool(target.call(&"can_accept_carried", _resource, _payload)):
		return false

	# Si el destino está ocupado, el ítem desplazado debe poder volver al origen (swap)
	var displaced: Resource = null
	if target.has_method(&"get_item"):
		displaced = target.call(&"get_item") as Resource
	if displaced != null and _source != null and _source.has_method(&"can_accept_carried"):
		var reverse_payload: Dictionary = {
			"resource": displaced,
			"is_displaced": true,
			"context_tag": str(target.get("context_tag")),
			"slot_index": int(target.get("slot_index"))
		}
		if not bool(_source.call(&"can_accept_carried", displaced, reverse_payload)):
			return false
	return true


func _refresh_candidates() -> void:
	for old_target: Control in _candidates:
		if is_instance_valid(old_target):
			old_target.call(&"set_drop_state", DROP_NONE)
	_candidates.clear()

	for node: Node in get_tree().get_nodes_in_group(TARGETS_GROUP):
		var target: Control = node as Control
		if target == null or not target.is_visible_in_tree() or not target.has_method(&"set_drop_state"):
			continue
		if _can_place(target):
			_candidates.append(target)
			target.call(&"set_drop_state", DROP_CANDIDATE)
	_hover = null


func _clear_drop_states() -> void:
	for old_target: Control in _candidates:
		if is_instance_valid(old_target):
			old_target.call(&"set_drop_state", DROP_NONE)
	_candidates.clear()
	if _hover != null and is_instance_valid(_hover):
		_hover.call(&"set_drop_state", DROP_NONE)
	_hover = null


func _update_hover() -> void:
	var under: Control = _target_under_mouse()
	if under == _hover:
		return
	if _hover != null and is_instance_valid(_hover):
		_hover.call(&"set_drop_state", DROP_CANDIDATE if _candidates.has(_hover) else DROP_NONE)
	_hover = under
	if _hover == null or _hover == _source:
		return
	_hover.call(&"set_drop_state", DROP_HOVER_OK if _candidates.has(_hover) else DROP_HOVER_BAD)


## Destino bajo el cursor, respetando qué ventana está por encima de cuál.
func _target_under_mouse() -> Control:
	var best: Control = null
	for node: Node in get_tree().get_nodes_in_group(TARGETS_GROUP):
		var target: Control = node as Control
		if target == null or not target.is_visible_in_tree():
			continue
		if not target.get_global_rect().has_point(target.get_global_mouse_position()):
			continue
		if _is_occluded(target):
			continue
		best = target
		break
	return best


func _is_occluded(target: Control) -> bool:
	var own_window: Control = _window_of(target)
	if own_window == null:
		return false
	for node: Node in get_tree().get_nodes_in_group(WINDOWS_GROUP):
		var other: Control = node as Control
		if other == null or other == own_window or not other.is_visible_in_tree():
			continue
		if not other.get_global_rect().has_point(other.get_global_mouse_position()):
			continue
		if _draws_above(other, own_window):
			return true
	return false


func _window_of(node: Node) -> Control:
	var current: Node = node
	while current != null:
		if current.is_in_group(WINDOWS_GROUP):
			return current as Control
		current = current.get_parent()
	return null


## true si `a` se dibuja encima de `b` (capa de canvas primero, luego orden en el árbol).
func _draws_above(a: Node, b: Node) -> bool:
	var layer_a: int = _layer_of(a)
	var layer_b: int = _layer_of(b)
	if layer_a != layer_b:
		return layer_a > layer_b
	var key_a: Array[int] = _tree_order_key(a)
	var key_b: Array[int] = _tree_order_key(b)
	var depth: int = mini(key_a.size(), key_b.size())
	for i in range(depth):
		if key_a[i] != key_b[i]:
			return key_a[i] > key_b[i]
	return key_a.size() > key_b.size()


func _layer_of(node: Node) -> int:
	var current: Node = node
	while current != null:
		if current is CanvasLayer:
			return (current as CanvasLayer).layer
		current = current.get_parent()
	return 0


func _tree_order_key(node: Node) -> Array[int]:
	var key: Array[int] = []
	var current: Node = node
	while current != null and current.get_parent() != null:
		key.push_front(current.get_index())
		current = current.get_parent()
	return key


# ==============================================================================
# Ítem en mano (visual)
# ==============================================================================

func _update_ghost(delta: float) -> void:
	if _ghost == null:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var target_pos: Vector2 = mouse_pos - _ghost.size * 0.5
	var target_scale: float = CARRY_SCALE

	# Sobre un destino válido el ítem se acomoda en el centro del casillero
	if _hover != null and is_instance_valid(_hover) and _hover != _source and _candidates.has(_hover):
		target_pos = _hover.get_global_rect().get_center() - _ghost.size * 0.5
		target_scale = SETTLE_SCALE

	var previous_x: float = _ghost.global_position.x
	var weight: float = 1.0 - exp(-FOLLOW_SPEED * delta)
	var next_pos: Vector2 = _ghost.global_position.lerp(target_pos, weight)

	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		next_pos.x += sin(_shake_left * 110.0) * 6.0 * (_shake_left / SHAKE_SECONDS)

	_ghost.global_position = next_pos
	var scale_now: float = lerpf(_ghost.scale.x, target_scale, weight)
	_ghost.scale = Vector2(scale_now, scale_now)

	# Inclinación según la velocidad horizontal: da sensación de peso
	var vx: float = (next_pos.x - previous_x) / maxf(delta, 0.0001)
	_ghost_velocity = lerpf(_ghost_velocity, vx, 1.0 - exp(-12.0 * delta))
	_ghost.rotation = clampf(_ghost_velocity * 0.0004, -MAX_TILT, MAX_TILT)


# ==============================================================================
# Sonidos procedurales (el proyecto no tiene assets de audio)
# ==============================================================================

func _play_sound(sound_name: StringName) -> void:
	if _sfx_player == null:
		return
	var stream: AudioStreamWAV = _get_sound(sound_name)
	if stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.pitch_scale = randf_range(0.95, 1.05)
	_sfx_player.play()


func _get_sound(sound_name: StringName) -> AudioStreamWAV:
	if _sounds.has(sound_name):
		return _sounds[sound_name] as AudioStreamWAV
	var stream: AudioStreamWAV = null
	match sound_name:
		&"pick":
			stream = _make_tone(520.0, 900.0, 0.07, 0.05)
		&"drop":
			stream = _make_tone(240.0, 110.0, 0.11, 0.25)
		&"reject":
			stream = _make_tone(150.0, 100.0, 0.13, 0.1)
	_sounds[sound_name] = stream
	return stream


func _make_tone(freq_start: float, freq_end: float, seconds: float, noise_amount: float) -> AudioStreamWAV:
	var sample_count: int = int(float(SOUND_RATE) * seconds)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var phase: float = 0.0
	for i in range(sample_count):
		var t: float = float(i) / float(sample_count)
		var envelope: float = pow(1.0 - t, 2.0)
		phase += TAU * lerpf(freq_start, freq_end, t) / float(SOUND_RATE)
		var sample: float = (sin(phase) * (1.0 - noise_amount) + randf_range(-1.0, 1.0) * noise_amount) * envelope
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0 * 0.8))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SOUND_RATE
	wav.stereo = false
	wav.data = data
	return wav
