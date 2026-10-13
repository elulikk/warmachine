extends CanvasLayer
## Motor de cinemáticas: una cinemática es una lista de pasos (diccionarios) que se ejecutan en orden.
## Sin class_name: se usa por `preload` (`CinematicPlayer.play(contexto, pasos)`).
##
## Pasos (clave "t"):
##   wait {s}                      espera
##   say {who, text, portrait?, s?}  subtítulo con retrato (dura por el largo del texto si no hay `s`)
##   title {text, s}               texto grande centrado (sobre negro)
##   fade {to, s}                  fundido a negro (to = 1) o desde negro (to = 0)
##   flash {s}                     destello blanco
##   bg {file}                     fondo pintado a pantalla completa (assets/art/bg/); "" lo quita
##   show {id, file, x, y, h}      sprite en pantalla (x, y en fracción; h = alto en fracción); hide {id}
##   spawn {id, file, pos, h, flip?}  sprite en el mundo (assets/art/world4/); move {id, to, s} lo desplaza
##   remove {id}                   quita un actor
##   focus {pos | id, zoom, s}     la cámara se acerca a un punto o actor (id "player" = jugador); release {s} la suelta
##   shake {amp, s}                sacudida de cámara
##   sfx {name}                    efecto de sonido
##   box {state}                   la Caja del nivel (grupo `the_box`): "open" / "closed"
##   call {fn}                     ejecuta un Callable
##   goto {path}                   cambia de escena (termina la cinemática)
##   par {steps}                   varios pasos a la vez (hablar mientras se camina)
## Durante la cinemática: el juego queda en pausa (jugador y enemigos quietos), barras negras arriba y abajo,
## [Enter]/clic avanza la línea y [Esc] la salta entera (los pasos que cambian el estado se ejecutan igual).

signal finished

const ArtScript = preload("res://core/art/art.gd")

const BAR_HEIGHT: float = 64.0
const WORLD_DIR: String = "res://assets/art/world4/"
const BG_DIR: String = "res://assets/art/bg/"
const PORTRAIT_DIR: String = "res://assets/art/portraits/"
const PORTRAITS: Dictionary = {
	"GUNTHER": "gunther", "COMPAÑERO": "partner", "AGENTE": "agent", "AGENTE DEL TIEMPO": "agent",
	"JEFE DEL SINDICATO": "syndicate_boss", "VIAJERO": "traveler", "ESTIBADOR": "stevedore",
}
const NAME_COLORS: Dictionary = {
	"GUNTHER": Color(0.95, 0.85, 0.6), "COMPAÑERO": Color(0.6, 0.8, 1.0), "AGENTE": Color(0.7, 0.95, 1.0),
	"JEFE DEL SINDICATO": Color(1.0, 0.55, 0.55), "ESTIBADOR": Color(1.0, 0.8, 0.5),
}

static var active: bool = false

var _steps: Array = []
var _skip: bool = false
var _advance: bool = false
var _stop: bool = false
var _paused_by_me: bool = false
var _level: Node = null
var _camera: Camera2D = null
var _cam_zoom: Vector2 = Vector2.ONE
var _cam_smoothing: bool = false
var _actors: Dictionary = {}
var _screen_sprites: Dictionary = {}
var _hidden_huds: Array[CanvasItem] = []

var _root: Control
var _bg: TextureRect
var _fade: ColorRect
var _flash: ColorRect
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _panel: PanelContainer
var _portrait: TextureRect
var _name_label: Label
var _text_label: Label
var _title_label: Label
var _hint: Label


## Crea el reproductor en la escena actual y arranca. Devuelve el nodo (señal `finished`) o null si ya hay una.
static func play(ctx: Node, steps: Array, on_done: Callable = Callable()) -> Node:
	if active or ctx == null or not ctx.is_inside_tree():
		return null
	var node: CanvasLayer = (load("res://core/cinematics/cinematic_player.gd") as GDScript).new() as CanvasLayer
	node.set("_steps", steps)
	if on_done.is_valid():
		node.connect("finished", on_done)
	var holder: Node = ctx.get_tree().current_scene
	if holder == null:
		holder = ctx
	holder.add_child(node)
	return node


func _ready() -> void:
	active = true
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_level = get_tree().current_scene
	_camera = get_viewport().get_camera_2d()
	if _camera != null:
		_cam_zoom = _camera.zoom
		# Con el suavizado activo la cámara no se mueve mientras el juego está en pausa
		_cam_smoothing = _camera.position_smoothing_enabled
		_camera.position_smoothing_enabled = false
	_build_ui()
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_me = true
	for hud: Node in get_tree().get_nodes_in_group(&"hud"):
		if hud is CanvasItem and (hud as CanvasItem).visible:
			(hud as CanvasItem).visible = false
			_hidden_huds.append(hud as CanvasItem)
	_run.call_deferred()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_bg = TextureRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.visible = false
	_root.add_child(_bg)

	_bar_top = _make_bar(true)
	_bar_bottom = _make_bar(false)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -440.0
	_panel.offset_right = 440.0
	_panel.offset_top = -BAR_HEIGHT - 124.0
	_panel.offset_bottom = -BAR_HEIGHT - 10.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.07, 0.82)
	style.border_color = Color(0.4, 0.55, 0.8, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.visible = false
	_root.add_child(_panel)
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(68, 92)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(_portrait)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(col)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 14)
	col.add_child(_name_label)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(700, 0)
	_text_label.add_theme_font_size_override("font_size", 16)
	col.add_child(_text_label)

	_title_label = Label.new()
	_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.modulate.a = 0.0
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title_label)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)

	_hint = Label.new()
	_hint.text = "[Enter] avanzar   [Esc] saltar"
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.modulate = Color(1, 1, 1, 0.55)
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -230.0
	_hint.offset_top = -BAR_HEIGHT + 8.0
	_hint.offset_right = -12.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint)


func _make_bar(top: bool) -> ColorRect:
	var bar: ColorRect = ColorRect.new()
	bar.color = Color.BLACK
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 0.0 if top else 1.0
	bar.anchor_bottom = 0.0 if top else 1.0
	bar.offset_top = 0.0
	bar.offset_bottom = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)
	return bar


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_skip = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept") or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		_advance = true
		get_viewport().set_input_as_handled()


# ==============================================================================
# Ejecución
# ==============================================================================

func _run() -> void:
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_bar_top, "offset_bottom", BAR_HEIGHT, 0.4)
	tw.tween_property(_bar_bottom, "offset_top", -BAR_HEIGHT, 0.4)
	for step: Variant in _steps:
		await _exec(step as Dictionary)
		if _stop:
			return
	await _finish()


func _exec(step: Dictionary) -> void:
	var kind: String = str(step.get("t", ""))
	match kind:
		"wait":
			await _wait(float(step.get("s", 1.0)))
		"say":
			await _say(step)
		"title":
			await _title(str(step.get("text", "")), float(step.get("s", 2.5)))
		"fade":
			await _tween_prop(_fade, "color:a", float(step.get("to", 1.0)), float(step.get("s", 0.6)))
		"flash":
			_flash.color.a = 1.0
			await _tween_prop(_flash, "color:a", 0.0, float(step.get("s", 0.4)))
		"bg":
			var file: String = str(step.get("file", ""))
			if file.is_empty():
				_bg.visible = false
			else:
				_bg.texture = ArtScript.tex(BG_DIR + file)
				_bg.visible = _bg.texture != null
		"show":
			_show_screen_sprite(step)
		"hide":
			var sid: String = str(step.get("id", ""))
			if _screen_sprites.has(sid):
				(_screen_sprites[sid] as Node).queue_free()
				_screen_sprites.erase(sid)
		"spawn":
			_spawn_actor(step)
		"remove":
			var rid: String = str(step.get("id", ""))
			if _actors.has(rid):
				var actor: Node = _actors[rid] as Node
				if is_instance_valid(actor):
					actor.queue_free()
				_actors.erase(rid)
		"move":
			await _move(step)
		"focus":
			await _focus(step)
		"release":
			await _release(float(step.get("s", 0.6)))
		"shake":
			await _shake(float(step.get("amp", 6.0)), float(step.get("s", 0.4)))
		"sfx":
			GameFeel.sfx(self, StringName(str(step.get("name", "coin"))), Vector2.INF, -2.0)
		"box":
			_set_box(str(step.get("state", "open")))
		"call":
			var fn: Variant = step.get("fn", null)
			if fn is Callable and (fn as Callable).is_valid():
				(fn as Callable).call()
		"goto":
			_stop = true
			_cleanup()
			GameManager.change_scene(str(step.get("path", "")))
			finished.emit()
			queue_free()
		"par":
			var subs: Array = step.get("steps", []) as Array
			var counter: Array = [subs.size()]
			for sub: Variant in subs:
				_run_sub(sub as Dictionary, counter)
			while counter[0] > 0:
				await get_tree().process_frame


func _run_sub(step: Dictionary, counter: Array) -> void:
	await _exec(step)
	counter[0] -= 1


func _wait(seconds: float) -> void:
	if _skip:
		return
	var timer: SceneTreeTimer = get_tree().create_timer(seconds, true)
	while timer.time_left > 0.0 and not _skip:
		await get_tree().process_frame


func _tween_prop(obj: Object, prop: String, to: Variant, seconds: float) -> void:
	if _skip or seconds <= 0.0:
		obj.set_indexed(prop, to)
		return
	var tw: Tween = create_tween()
	tw.tween_property(obj, prop, to, seconds)
	while tw.is_running() and not _skip:
		await get_tree().process_frame
	tw.kill()
	obj.set_indexed(prop, to)


func _say(step: Dictionary) -> void:
	if _skip:
		return
	var who: String = str(step.get("who", ""))
	var text: String = str(step.get("text", ""))
	_name_label.text = who
	_name_label.add_theme_color_override("font_color", NAME_COLORS.get(who, Color(0.85, 0.9, 1.0)) as Color)
	_text_label.text = "(%s)" % text if bool(step.get("thought", false)) else text
	var portrait_name: String = str(step.get("portrait", PORTRAITS.get(who, "")))
	_portrait.texture = ArtScript.tex(PORTRAIT_DIR + portrait_name + ".png") if not portrait_name.is_empty() else null
	_portrait.visible = _portrait.texture != null
	_panel.visible = true
	var seconds: float = float(step.get("s", clampf(float(text.length()) * 0.05 + 1.4, 2.2, 7.0)))
	_advance = false
	var timer: SceneTreeTimer = get_tree().create_timer(seconds, true)
	while timer.time_left > 0.0 and not _skip and not _advance:
		await get_tree().process_frame
	_advance = false
	_panel.visible = false


func _title(text: String, seconds: float) -> void:
	_title_label.text = text
	if _skip:
		return
	await _tween_prop(_title_label, "modulate:a", 1.0, 0.5)
	await _wait(seconds)
	await _tween_prop(_title_label, "modulate:a", 0.0, 0.5)


func _show_screen_sprite(step: Dictionary) -> void:
	var tex: Texture2D = ArtScript.tex(WORLD_DIR + str(step.get("file", "")))
	if tex == null:
		return
	var sid: String = str(step.get("id", "s"))
	if _screen_sprites.has(sid):
		(_screen_sprites[sid] as Node).queue_free()
	var rect: TextureRect = TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view: Vector2 = get_viewport().get_visible_rect().size
	var h: float = view.y * float(step.get("h", 0.6))
	var w: float = h * float(tex.get_width()) / float(tex.get_height())
	rect.custom_minimum_size = Vector2(w, h)
	rect.size = Vector2(w, h)
	rect.position = Vector2(view.x * float(step.get("x", 0.5)) - w * 0.5, view.y * float(step.get("y", 0.9)) - h)
	rect.flip_h = bool(step.get("flip", false))
	_root.add_child(rect)
	_root.move_child(rect, _bar_top.get_index())
	_screen_sprites[sid] = rect


func _spawn_actor(step: Dictionary) -> void:
	var tex: Texture2D = ArtScript.tex(WORLD_DIR + str(step.get("file", "")))
	if tex == null or _level == null:
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	sprite.z_index = 8
	var s: float = float(step.get("h", 60.0)) / float(tex.get_height())
	sprite.scale = Vector2(s * (-1.0 if bool(step.get("flip", false)) else 1.0), s)
	sprite.offset = Vector2(0.0, -tex.get_height() * 0.5)
	sprite.global_position = step.get("pos", Vector2.ZERO) as Vector2
	_level.add_child(sprite)
	_actors[str(step.get("id", "a"))] = sprite


func _actor(id: String) -> Node2D:
	if id == "player":
		return get_tree().get_first_node_in_group(&"player") as Node2D
	var found: Variant = _actors.get(id, null)
	return found as Node2D if found != null and is_instance_valid(found) else null


func _set_box(state: String) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"the_box"):
		var sprite: Sprite2D = node as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var tex: Texture2D = ArtScript.tex(WORLD_DIR + ("box_open.png" if state == "open" else "box_closed.png"))
		if tex == null:
			continue
		var keep_h: float = float(sprite.texture.get_height()) * sprite.scale.y
		sprite.texture = tex
		var k: float = keep_h / float(tex.get_height())
		sprite.scale = Vector2(k, k)


func _move(step: Dictionary) -> void:
	var actor: Node2D = _actor(str(step.get("id", "")))
	if actor == null:
		return
	var to: Vector2 = step.get("to", actor.global_position) as Vector2
	var seconds: float = float(step.get("s", 1.0))
	if _skip or seconds <= 0.0:
		actor.global_position = to
		return
	var tw: Tween = create_tween()
	tw.tween_property(actor, "global_position", to, seconds)
	while tw.is_running() and not _skip:
		await get_tree().process_frame
	tw.kill()
	if is_instance_valid(actor):
		actor.global_position = to


func _focus(step: Dictionary) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var target: Vector2 = _camera.global_position
	if step.has("pos"):
		target = step["pos"] as Vector2
	elif step.has("id"):
		var actor: Node2D = _actor(str(step["id"]))
		if actor != null:
			target = actor.global_position + Vector2(0.0, -40.0)
	var zoom: float = float(step.get("zoom", 1.3))
	var seconds: float = float(step.get("s", 0.8))
	if _skip or seconds <= 0.0:
		_camera.global_position = target
		_camera.zoom = Vector2(zoom, zoom)
		return
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_camera, "global_position", target, seconds).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_camera, "zoom", Vector2(zoom, zoom), seconds).set_trans(Tween.TRANS_SINE)
	while tw.is_running() and not _skip:
		await get_tree().process_frame
	tw.kill()
	_camera.global_position = target
	_camera.zoom = Vector2(zoom, zoom)


func _release(seconds: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var player_node: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	var target: Vector2 = _camera.global_position
	if player_node != null:
		target = player_node.global_position + Vector2(0.0, -40.0)
	if _skip or seconds <= 0.0:
		_camera.zoom = _cam_zoom
		_camera.global_position = target
		return
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_camera, "global_position", target, seconds)
	tw.tween_property(_camera, "zoom", _cam_zoom, seconds)
	while tw.is_running() and not _skip:
		await get_tree().process_frame
	tw.kill()
	_camera.zoom = _cam_zoom


func _shake(amp: float, seconds: float) -> void:
	if _camera == null or not is_instance_valid(_camera) or _skip:
		return
	var origin: Vector2 = _camera.offset
	var timer: SceneTreeTimer = get_tree().create_timer(seconds, true)
	while timer.time_left > 0.0 and not _skip:
		_camera.offset = origin + Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		await get_tree().process_frame
	_camera.offset = origin


# ==============================================================================
# Cierre
# ==============================================================================

func _finish() -> void:
	_panel.visible = false
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_bar_top, "offset_bottom", 0.0, 0.3)
	tw.tween_property(_bar_bottom, "offset_top", 0.0, 0.3)
	tw.tween_property(_fade, "color:a", 0.0, 0.5)
	await tw.finished
	if _camera != null and is_instance_valid(_camera):
		_camera.zoom = _cam_zoom
		_camera.offset = Vector2.ZERO
	_cleanup()
	finished.emit()
	queue_free()


func _cleanup() -> void:
	active = false
	if _camera != null and is_instance_valid(_camera):
		_camera.position_smoothing_enabled = _cam_smoothing
		_camera.reset_smoothing()
	for actor: Variant in _actors.values():
		if is_instance_valid(actor):
			(actor as Node).queue_free()
	_actors.clear()
	if _paused_by_me:
		get_tree().paused = false
	for hud: CanvasItem in _hidden_huds:
		if is_instance_valid(hud):
			hud.visible = true
	_hidden_huds.clear()
