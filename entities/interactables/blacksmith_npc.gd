class_name BlacksmithNPC
extends Area2D
## PNJ Herrero en el Campamento Base (Hub).
## Permite abrir la estación de forja para engarzar y desengarzar runas.
## Requiere el flag 'blacksmith_unlocked' (por defecto true).
## Al interactuar con [E], abre simultáneamente la ventana de forja y la mochila.

const PropSkin = preload("res://entities/props/prop_skin.gd")
@onready var prompt_container: PanelContainer = $Visuals/PromptContainer
@onready var prompt_label: Label = $Visuals/PromptContainer/PromptLabel

var _player_in_range: bool = false
var _blacksmith_window_instance: BlacksmithWindow = null


func _ready() -> void:
	PropSkin.apply(self, "blacksmith")
	collision_layer = 0
	collision_mask = 2 # Player
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt_container != null:
		prompt_container.visible = false


func _unhandled_input(event: InputEvent) -> void:
	var is_interact_key: bool = event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E)
	if is_interact_key:
		var in_range: bool = _player_in_range or _is_player_overlapping()
		if not in_range:
			var player_node: Player = get_tree().get_first_node_in_group(&"player") as Player
			if player_node != null and is_instance_valid(player_node):
				if global_position.distance_to(player_node.global_position) < 80.0:
					in_range = true
		
		if in_range:
			if is_blacksmith_unlocked():
				get_viewport().set_input_as_handled()
				interact()
			else:
				print("[BlacksmithNPC] El herrero no está desbloqueado aún.")


func _is_player_overlapping() -> bool:
	for body in get_overlapping_bodies():
		if body is Player:
			return true
	return false


func is_blacksmith_unlocked() -> bool:
	return SaveManager.get_world_flag("blacksmith_unlocked", true)


func interact() -> void:
	_ensure_windows()
	if _blacksmith_window_instance != null:
		_blacksmith_window_instance.toggle_window()
		
		var inv_win: InventoryWindow = get_tree().get_first_node_in_group(&"inventory_window") as InventoryWindow
		if inv_win != null:
			if _blacksmith_window_instance.visible:
				inv_win.open_window()
				
				var vp_size: Vector2 = get_viewport_rect().size
				var bw_w: float = 340.0
				var iw_w: float = 490.0
				var spacing: float = 16.0
				var total_w: float = bw_w + iw_w + spacing
				var start_x: float = maxf(10.0, (vp_size.x - total_w) * 0.5)
				var center_y: float = maxf(10.0, (vp_size.y - 320.0) * 0.5)
				
				_blacksmith_window_instance.global_position = Vector2(start_x, center_y)
				inv_win.global_position = Vector2(start_x + bw_w + spacing, center_y)
			else:
				inv_win.close_window()


func _ensure_windows() -> void:
	if _blacksmith_window_instance != null and is_instance_valid(_blacksmith_window_instance):
		return
	
	_blacksmith_window_instance = get_tree().get_first_node_in_group(&"blacksmith_window") as BlacksmithWindow
	if _blacksmith_window_instance == null:
		var bs_scene: PackedScene = preload("res://ui/blacksmith_window.tscn")
		_blacksmith_window_instance = bs_scene.instantiate() as BlacksmithWindow
		var canvas: CanvasLayer = CanvasLayer.new()
		canvas.layer = 20
		get_tree().root.add_child(canvas)
		canvas.add_child(_blacksmith_window_instance)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_in_range = true
		if prompt_container != null:
			if is_blacksmith_unlocked():
				if prompt_label != null:
					prompt_label.text = "[E] Herrero (Forja)"
				prompt_container.visible = true
				var tw: Tween = create_tween()
				tw.tween_property(prompt_container, "modulate:a", 1.0, 0.15).from(0.0)
			else:
				if prompt_label != null:
					prompt_label.text = "Herrero (Bloqueado)"
				prompt_container.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_in_range = false
		if prompt_container != null:
			prompt_container.visible = false
