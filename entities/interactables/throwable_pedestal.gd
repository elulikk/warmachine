class_name ThrowablePedestal
extends Area2D
## Pedestal interactivo del Sandbox con suministro infinito de un arrojadizo táctico.
## Al estar cerca, [E] equipa el ítem en la ranura TACTICAL; el ítem que estuviera equipado
## se devuelve a la mochila (si hay espacio).

const ItemIconsScript = preload("res://ui/components/item_icons.gd")
@export var item_data: ItemData = null

var _player: Player = null
var _time: float = 0.0
var _name_label: Label = null
var _prompt_label: Label = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(64.0, 64.0)
	shape_node.shape = rect
	shape_node.position = Vector2(0.0, -32.0)
	add_child(shape_node)
	
	var item_name: String = item_data.item_name if item_data != null else "Pedestal vacío"
	var item_col: Color = item_data.item_color if item_data != null else Color.WHITE
	
	_name_label = _create_label(item_name, Vector2(-60.0, -86.0), 11, item_col)
	_prompt_label = _create_label("[E] Equipar", Vector2(-60.0, -72.0), 10, Color(1.0, 0.95, 0.6, 1.0))
	_prompt_label.visible = false


func _create_label(text_value: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.position = pos
	label.custom_minimum_size = Vector2(120.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	return label


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _player != null and event.is_action_pressed("interact"):
		_equip_on_player()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body as Player
		_prompt_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		_prompt_label.visible = false


func _equip_on_player() -> void:
	if item_data == null or _player == null or _player.equipment_manager == null:
		return
	
	var equipment: EquipmentManager = _player.equipment_manager
	var target_slot: String = equipment.get_target_slot_for_item(item_data)
	if target_slot.is_empty():
		target_slot = EquipmentManager.SLOT_TACTICAL

	var previous: ItemData = equipment.get_equipped_item(target_slot)
	if previous != null and previous.item_id == item_data.item_id:
		return
	
	equipment.equip_item(target_slot, item_data)
	if previous != null and _player.inventory_manager != null:
		_player.inventory_manager.add_item(previous)
	print("[ThrowablePedestal] Equipado en ranura [%s]: %s" % [target_slot, item_data.item_name])


func _draw() -> void:
	var col: Color = item_data.item_color if item_data != null else Color.WHITE

	# Base del pedestal: peana de chapa con borde de cobre
	draw_rect(Rect2(-20.0, -14.0, 40.0, 14.0), Color(0.16, 0.12, 0.11, 1.0))
	draw_rect(Rect2(-20.0, -14.0, 40.0, 3.0), Color(0.72, 0.43, 0.28, 1.0))
	draw_rect(Rect2(-14.0, -34.0, 28.0, 20.0), Color(0.22, 0.16, 0.14, 1.0))
	draw_rect(Rect2(-14.0, -34.0, 2.0, 20.0), Color(0.55, 0.34, 0.22, 1.0))
	draw_rect(Rect2(12.0, -34.0, 2.0, 20.0), Color(0.55, 0.34, 0.22, 1.0))
	draw_rect(Rect2(-20.0, -38.0, 40.0, 5.0), Color(0.72, 0.43, 0.28, 1.0))
	draw_rect(Rect2(-20.0, -38.0, 40.0, 2.0), col.lightened(0.2))

	# Arrojadizo flotante: su ícono de arte sobre un halo del color del ítem
	var bob: float = sin(_time * 3.0) * 3.0
	var orb_pos: Vector2 = Vector2(0.0, -56.0 + bob)
	var glow: Color = col
	glow.a = 0.25
	draw_circle(orb_pos, 17.0, glow)
	var icon: Texture2D = null
	if item_data != null:
		icon = ItemIconsScript.get_icon_for(item_data)
	if icon != null:
		draw_texture_rect(icon, Rect2(orb_pos - Vector2(15.0, 15.0), Vector2(30.0, 30.0)), false)
	else:
		draw_circle(orb_pos, 7.0, col.darkened(0.35))
		draw_circle(orb_pos, 5.5, col)
		draw_circle(orb_pos + Vector2(-1.5, -1.5), 1.8, col.lightened(0.6))
