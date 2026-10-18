class_name StatusDisplayComponent
extends Node2D
## Componente visual que renderiza indicadores de estados alterados (Fuego con stacks, Hielo)
## sobre la cabeza de la entidad contenedora (Jugador, Enemigos, Dummies).
## Posee una arquitectura abierta y desacoplada para registrar debuffs adicionales (veneno, rotura de armadura, etc.).

@export var offset_y: float = -44.0

## El cartel se arma recién cuando hace falta (la escena trae el HBoxContainer, pero se descarta al nacer):
## un enemigo que nunca se quema ni se congela se ahorra ~8 nodos y su pasada de layout.
var hbox: HBoxContainer = null
var fire_badge: HBoxContainer = null
var fire_label: Label = null
var ice_badge: HBoxContainer = null

const FIRE_ICON: Texture2D = preload("res://assets/art/status/status_fire.png")
const FREEZE_ICON: Texture2D = preload("res://assets/art/status/status_freeze.png")

var status_receiver: StatusReceiverComponent = null

## Registro de badges personalizados para debuffs adicionales { "POISON": HBoxContainer, ... }
var _custom_badges: Dictionary = {}

## Iconos de estado (assets/art/status). Si un estado no está acá, su badge usa un cuadro de color.
const ICON_PATHS: Dictionary = {
	"POISON": "res://assets/art/status/status_poison.png",
	"ACID": "res://assets/art/status/status_acid.png",
	"STUN": "res://assets/art/status/status_stun.png",
	"CRITICAL": "res://assets/art/status/status_critical.png",
	"SLOW": "res://assets/art/status/status_slow.png",
}


func _ready() -> void:
	position.y = offset_y
	var scene_box: Node = get_node_or_null("HBoxContainer")
	if scene_box != null:
		remove_child(scene_box)
		scene_box.free()
	_find_status_receiver()


## Arma el contenedor y las insignias de fuego y hielo la primera vez que se necesitan.
func _ensure_ui() -> void:
	if hbox != null:
		return
	hbox = HBoxContainer.new()
	hbox.name = "HBoxContainer"
	hbox.custom_minimum_size = Vector2(60, 14)
	hbox.offset_left = -30.0
	hbox.offset_top = -7.0
	hbox.offset_right = 30.0
	hbox.offset_bottom = 7.0
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 4)
	add_child(hbox)
	fire_badge = _make_badge("FireBadge", FIRE_ICON, true)
	ice_badge = _make_badge("IceBadge", FREEZE_ICON, false)


func _make_badge(badge_name: String, icon_tex: Texture2D, with_label: bool) -> HBoxContainer:
	var badge: HBoxContainer = HBoxContainer.new()
	badge.name = badge_name
	badge.visible = false
	badge.add_theme_constant_override("separation", 2)
	var icon: TextureRect = TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(14, 14)
	icon.texture = icon_tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.add_child(icon)
	if with_label:
		fire_label = Label.new()
		fire_label.name = "Label"
		fire_label.add_theme_color_override("font_outline_color", Color.BLACK)
		fire_label.add_theme_constant_override("outline_size", 4)
		fire_label.add_theme_font_size_override("font_size", 9)
		fire_label.text = "x1"
		fire_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(fire_label)
	hbox.add_child(badge)
	return badge


func _find_status_receiver() -> void:
	var parent: Node = get_parent()
	if parent != null:
		status_receiver = parent.get_node_or_null("StatusReceiverComponent") as StatusReceiverComponent
	if status_receiver == null:
		status_receiver = get_node_or_null("../StatusReceiverComponent") as StatusReceiverComponent
	
	if status_receiver != null:
		if not status_receiver.burn_stacks_changed.is_connected(_on_burn_stacks_changed):
			status_receiver.burn_stacks_changed.connect(_on_burn_stacks_changed)
		if not status_receiver.burn_expired.is_connected(_on_burn_expired):
			status_receiver.burn_expired.connect(_on_burn_expired)
		if not status_receiver.frozen_state_changed.is_connected(_on_frozen_state_changed):
			status_receiver.frozen_state_changed.connect(_on_frozen_state_changed)
		
		# Sincronización inicial
		_update_fire_display(status_receiver.burn_stacks)
		_update_ice_display(status_receiver.is_frozen)
		# Con el receptor enlazado las señales alcanzan: no hace falta resincronizar cada cuadro
		set_process(false)


func _process(_delta: float) -> void:
	if status_receiver == null:
		_find_status_receiver()
		return
	
	# Resincronización por frame reactiva y tolerante a fallos
	_update_fire_display(status_receiver.burn_stacks)
	_update_ice_display(status_receiver.is_frozen)


func _update_fire_display(stacks: int) -> void:
	if fire_badge == null:
		if stacks <= 0:
			return
		_ensure_ui()
	
	# Los stacks de fuego se ven como llamitas en el cuerpo (StatusReceiverComponent): el cartel queda oculto
	fire_badge.visible = false
	if stacks > 0 and fire_label != null:
		fire_label.text = "x%d" % stacks


func _update_ice_display(is_frozen: bool) -> void:
	if ice_badge == null:
		if not is_frozen:
			return
		_ensure_ui()
	ice_badge.visible = is_frozen


func _on_burn_stacks_changed(stacks: int, _max_stacks: int) -> void:
	_update_fire_display(stacks)


func _on_burn_expired() -> void:
	_update_fire_display(0)


func _on_frozen_state_changed(is_frozen: bool) -> void:
	_update_ice_display(is_frozen)


## Registra dinámicamente un nuevo indicador de debuff (ej: Veneno, Rotura de armadura) sin rehacer el layout.
func register_custom_status(status_id: String, badge_color: Color, show_label: bool = false) -> HBoxContainer:
	var key: String = status_id.to_upper()
	if _custom_badges.has(key):
		return _custom_badges[key]
	_ensure_ui()
	
	var badge: HBoxContainer = HBoxContainer.new()
	badge.name = "%sBadge" % status_id.capitalize()
	badge.visible = false
	badge.add_theme_constant_override("separation", 2)
	
	var icon_path: String = ICON_PATHS.get(key, "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var tex_icon: TextureRect = TextureRect.new()
		tex_icon.custom_minimum_size = Vector2(14, 14)
		tex_icon.texture = load(icon_path) as Texture2D
		tex_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.add_child(tex_icon)
	else:
		var icon: ColorRect = ColorRect.new()
		icon.custom_minimum_size = Vector2(12, 12)
		icon.color = badge_color
		badge.add_child(icon)
	
	if show_label:
		var lbl: Label = Label.new()
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.text = "x1"
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(lbl)
	
	hbox.add_child(badge)
	_custom_badges[key] = badge
	return badge


## Actualiza el estado visible de un debuff personalizado registrado.
func update_custom_status(status_id: String, is_active: bool, text_info: String = "") -> void:
	var key: String = status_id.to_upper()
	if not _custom_badges.has(key):
		return
	var badge: HBoxContainer = _custom_badges[key]
	badge.visible = is_active
	if is_active and not text_info.is_empty():
		for child in badge.get_children():
			if child is Label:
				(child as Label).text = text_info
