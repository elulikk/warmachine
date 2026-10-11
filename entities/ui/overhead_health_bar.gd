class_name OverheadHealthBar
extends Node2D
## Componente visual de placa superior (Overhead UI) para entidades de combate.
## Renderiza nombre, barra de vida, barra de escudo y badge de armadura.
## Soporta alternancia global de visibilidad mediante GameManager.overhead_visibility_toggled (tecla F2).

@export var display_name: String = ""
@export var show_overhead_ui: bool = true
@export var hide_when_full: bool = false
@export var vertical_offset_y: float = -58.0

@onready var container: VBoxContainer = $VBoxContainer
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var bars_container: HBoxContainer = $VBoxContainer/BarsContainer
@onready var bars_vbox: VBoxContainer = $VBoxContainer/BarsContainer/BarsVBox
@onready var shield_bar: ProgressBar = $VBoxContainer/BarsContainer/BarsVBox/ShieldBar
@onready var health_bar: ProgressBar = $VBoxContainer/BarsContainer/BarsVBox/HealthBar
@onready var armor_badge: PanelContainer = $VBoxContainer/BarsContainer/ArmorBadge
@onready var armor_label: Label = $VBoxContainer/BarsContainer/ArmorBadge/ArmorLabel

var target_health_component: HealthComponent = null
var _current_health: float = 0.0
var _max_health: float = 100.0
var _current_shield: float = 0.0
var _max_shield: float = 0.0
var _armor: float = 0.0
var _is_dead: bool = false
var _fade_tween: Tween = null


func _ready() -> void:
	position.y = vertical_offset_y
	
	# Conexión al gestor global para alternancia en tiempo real con tecla F2
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_signal(&"overhead_visibility_toggled"):
		var sig: Signal = gm.overhead_visibility_toggled
		if not sig.is_connected(_on_global_visibility_toggled):
			sig.connect(_on_global_visibility_toggled)
		# Inicializar según el estado global actual
		if "show_overhead_bars" in gm and not bool(gm.get("show_overhead_bars")):
			show_overhead_ui = false
	
	_update_visibility()


## Configura e inicializa la placa superior con el HealthComponent de la entidad.
func setup(health_comp: HealthComponent, entity_name: String = "") -> void:
	if not entity_name.is_empty():
		display_name = entity_name
	
	if name_label != null:
		name_label.text = display_name
		name_label.visible = not display_name.is_empty()
	
	if health_comp == null:
		return
	
	# Desconectar componente previo si correspondiera
	if target_health_component != null and is_instance_valid(target_health_component):
		if target_health_component.health_changed.is_connected(_on_health_changed):
			target_health_component.health_changed.disconnect(_on_health_changed)
		if target_health_component.shield_changed.is_connected(_on_shield_changed):
			target_health_component.shield_changed.disconnect(_on_shield_changed)
		if target_health_component.died.is_connected(_on_died):
			target_health_component.died.disconnect(_on_died)
	
	target_health_component = health_comp
	
	if not target_health_component.health_changed.is_connected(_on_health_changed):
		target_health_component.health_changed.connect(_on_health_changed)
	if not target_health_component.shield_changed.is_connected(_on_shield_changed):
		target_health_component.shield_changed.connect(_on_shield_changed)
	if not target_health_component.died.is_connected(_on_died):
		target_health_component.died.connect(_on_died)
	
	_max_health = target_health_component.max_health
	_current_health = target_health_component.current_health
	_max_shield = target_health_component.max_shield
	_current_shield = target_health_component.current_shield
	_armor = target_health_component.armor
	
	_setup_bars()
	_update_visibility()


func _setup_bars() -> void:
	if health_bar != null:
		health_bar.min_value = 0.0
		health_bar.max_value = maxf(1.0, _max_health)
		health_bar.value = _current_health
	
	if shield_bar != null:
		if _max_shield > 0.0:
			shield_bar.visible = true
			shield_bar.min_value = 0.0
			shield_bar.max_value = maxf(1.0, _max_shield)
			shield_bar.value = _current_shield
		else:
			shield_bar.visible = false
	
	if armor_badge != null and armor_label != null:
		if _armor > 0.0:
			armor_badge.visible = true
			armor_label.text = "ARM: %d" % roundi(_armor)
		else:
			armor_badge.visible = false


func _on_health_changed(current: float, max_hp: float) -> void:
	_current_health = current
	_max_health = max_hp
	if health_bar != null:
		health_bar.max_value = maxf(1.0, _max_health)
		health_bar.value = _current_health
	_update_visibility()


func _on_shield_changed(current: float, max_s: float) -> void:
	_current_shield = current
	_max_shield = max_s
	if shield_bar != null:
		if _max_shield > 0.0:
			shield_bar.visible = true
			shield_bar.max_value = maxf(1.0, _max_shield)
			shield_bar.value = _current_shield
		else:
			shield_bar.visible = false
	_update_visibility()


func _on_died() -> void:
	_is_dead = true
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_fade_tween.tween_callback(func() -> void: visible = false)


func _on_global_visibility_toggled(is_visible: bool) -> void:
	show_overhead_ui = is_visible
	_update_visibility()


func _update_visibility() -> void:
	if _is_dead:
		visible = false
		return
	
	if not show_overhead_ui:
		visible = false
		return
	
	if hide_when_full:
		var is_health_full: bool = (_current_health >= _max_health)
		var is_shield_full: bool = (_max_shield <= 0.0 or _current_shield >= _max_shield)
		if is_health_full and is_shield_full:
			visible = false
			return
	
	visible = true
