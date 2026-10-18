class_name TrainingDummy
extends Area2D
## Objetivo de entrenamiento estático para pruebas de combate en el Sandbox.
## Implementa `take_hit(payload)` para recibir impactos de proyectiles,
## ejecuta un parpadeo blanco (hit flash) y reporta las métricas de combate por consola.

const EnemyArtScript = preload("res://entities/enemies/enemy_art.gd")
@onready var visual_rect: ColorRect = $VisualRect
@onready var status_receiver: StatusReceiverComponent = get_node_or_null("StatusReceiverComponent")

@export var damage_number_scene: PackedScene = preload("res://combat/damage_number.tscn")

@export var armor: float = 0.0
@export var max_shield: float = 0.0
@export var entity_name: String = "Dummy de Prueba"
@export var dummy_name: String = ""

@onready var health_component: HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
@onready var overhead_bar: Node2D = get_node_or_null("OverheadHealthBar") as Node2D

## Tiempo sin impactos tras el cual el DPS se reinicia.
const DPS_IDLE_RESET_SEC: float = 4.0
## Ventana mínima (s) para calcular el DPS, así un solo golpe no da un valor inflado.
const DPS_MIN_WINDOW_SEC: float = 1.0

var original_color: Color = Color(0.88, 0.2, 0.2, 1.0)
var _flash_tween: Tween = null
var total_damage_received: float = 0.0

var _dps_label: Label = null
var _dps_active: bool = false
var _dps_damage: float = 0.0
var _dps_first_ms: int = 0
var _dps_last_ms: int = 0


func _ready() -> void:
	EnemyArtScript.attach(self, "dummy")
	if not dummy_name.is_empty():
		entity_name = dummy_name
	
	if visual_rect != null:
		original_color = visual_rect.color
	
	if health_component == null:
		health_component = HealthComponent.new()
		health_component.name = "HealthComponent"
		health_component.max_health = 10000.0
		health_component.armor = armor
		health_component.max_shield = max_shield
		add_child(health_component)
	else:
		health_component.max_health = 10000.0
		health_component.armor = armor
		health_component.max_shield = max_shield
	
	if not health_component.damage_taken.is_connected(_on_damage_taken):
		health_component.damage_taken.connect(_on_damage_taken)
	
	if status_receiver == null:
		status_receiver = get_node_or_null("StatusReceiverComponent") as StatusReceiverComponent
	if status_receiver == null:
		status_receiver = StatusReceiverComponent.new()
		status_receiver.name = "StatusReceiverComponent"
		status_receiver.visual_node = visual_rect
		add_child(status_receiver)
	
	if overhead_bar == null:
		overhead_bar = get_node_or_null("OverheadHealthBar") as Node2D
	# Opción "Barras de vida de enemigos" apagada: no se crea el nodo (un nodo menos por enemigo)
	if overhead_bar == null and OverheadHealthBar.bars_enabled():
		var bar_scene: PackedScene = load("res://entities/ui/overhead_health_bar.tscn")
		if bar_scene != null:
			overhead_bar = bar_scene.instantiate() as Node2D
			overhead_bar.name = "OverheadHealthBar"
			overhead_bar.set("vertical_offset_y", -52.0)
			add_child(overhead_bar)
	if overhead_bar != null and health_component != null and overhead_bar.has_method("setup"):
		overhead_bar.call("setup", health_component, entity_name)

	_setup_dps_label()


func _process(_delta: float) -> void:
	if _dps_active and Time.get_ticks_msec() - _dps_last_ms >= int(DPS_IDLE_RESET_SEC * 1000.0):
		_reset_dps()


## Receptor del impacto transportado por un HitPayload.
func take_hit(payload: HitPayload) -> void:
	if payload == null:
		return
	
	_trigger_hit_flash()
	
	if status_receiver != null:
		status_receiver.apply_payload(payload)
	
	if health_component != null:
		health_component.take_hit(payload)


func _on_damage_taken(effective_amount: float, is_crit: bool, dmg_type: String) -> void:
	total_damage_received += effective_amount
	_register_dps_hit(effective_amount)

	print("[%s] IMPACTO RECIBIDO:" % dummy_name)
	print("  - Daño efectivo entrante: %.1f" % effective_amount)
	print("  - Daño total acumulado:   %.1f" % total_damage_received)
	print("  - Armadura activa:        %.1f" % (health_component.armor if health_component != null else 0.0))
	print("  - Escudo restante:        %.1f" % (health_component.current_shield if health_component != null else 0.0))
	print("--------------------------------------------------")
	
	if damage_number_scene != null and is_inside_tree() and effective_amount > 0.0:
		var tree: SceneTree = get_tree()
		if tree != null:
			var dmg_inst: Node = damage_number_scene.instantiate()
			if dmg_inst is DamageNumber:
				var dmg_num: DamageNumber = dmg_inst as DamageNumber
				var container: Node = tree.current_scene
				if container == null:
					container = owner if owner != null else get_parent()
				if container == null:
					container = tree.root
				if container != null:
					dmg_num.global_position = global_position + Vector2(0, -48.0)
					container.add_child(dmg_num)
					dmg_num.setup(effective_amount, is_crit, dmg_type)


## Etiqueta de DPS encima del dummy (se muestra solo mientras se le dispara).
func _setup_dps_label() -> void:
	_dps_label = Label.new()
	_dps_label.name = "DpsLabel"
	_dps_label.position = Vector2(-70.0, -98.0)
	_dps_label.size = Vector2(140.0, 20.0)
	_dps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dps_label.add_theme_font_size_override("font_size", 12)
	_dps_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	_dps_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_dps_label.add_theme_constant_override("outline_size", 3)
	add_child(_dps_label)
	_refresh_dps_label()


## Acumula el daño de cada impacto de la sesión de disparo actual.
func _register_dps_hit(effective_amount: float) -> void:
	var now: int = Time.get_ticks_msec()
	if not _dps_active:
		_dps_active = true
		_dps_damage = 0.0
		_dps_first_ms = now
	_dps_damage += effective_amount
	_dps_last_ms = now
	_refresh_dps_label()


func _reset_dps() -> void:
	_dps_active = false
	_dps_damage = 0.0
	_refresh_dps_label()


## DPS promedio = daño acumulado / tiempo entre el primer y el último impacto.
func _refresh_dps_label() -> void:
	if _dps_label == null:
		return
	if not _dps_active:
		_dps_label.text = "DPS: 0.0"
		return
	var window: float = maxf(float(_dps_last_ms - _dps_first_ms) / 1000.0, DPS_MIN_WINDOW_SEC)
	_dps_label.text = "DPS: %.1f" % (_dps_damage / window)


## Ejecuta un parpadeo blanco de 0.08 segundos antes de regresar al color original.
func _trigger_hit_flash() -> void:
	if visual_rect == null:
		return
	
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	
	visual_rect.color = Color.WHITE
	_flash_tween = create_tween()
	_flash_tween.tween_property(visual_rect, "color", original_color, 0.08)
	if status_receiver != null:
		_flash_tween.finished.connect(status_receiver._update_visual_tint)
