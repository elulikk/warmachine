class_name MerchantNPC
extends Area2D
## PNJ Mercader del Campamento Base.
## Con [E] abre la ventana de compra de consumibles (pociones de vida, sin recarga y velocidad).

const PropSkin = preload("res://entities/props/prop_skin.gd")
@onready var prompt_container: PanelContainer = get_node_or_null("Visuals/PromptContainer") as PanelContainer

var _player_in_range: bool = false
var _shop_window: DraggableWindow = null


func _ready() -> void:
	PropSkin.apply(self, "merchant")
	collision_layer = 0
	collision_mask = 2 # Player
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt_container != null:
		prompt_container.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if not _is_player_near():
		return

	get_viewport().set_input_as_handled()
	_toggle_shop()


func _is_player_near() -> bool:
	if _player_in_range:
		return true
	var player_node: Player = get_tree().get_first_node_in_group(&"player") as Player
	return player_node != null and is_instance_valid(player_node) and global_position.distance_to(player_node.global_position) < 80.0


func _toggle_shop() -> void:
	_ensure_window()
	if _shop_window != null:
		_shop_window.toggle_window()


func _ensure_window() -> void:
	if _shop_window != null and is_instance_valid(_shop_window):
		return

	_shop_window = get_tree().get_first_node_in_group(&"shop_window") as DraggableWindow
	if _shop_window != null:
		return

	var scene: PackedScene = preload("res://ui/shop_window.tscn")
	_shop_window = scene.instantiate() as DraggableWindow
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 20
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(canvas)
	canvas.add_child(_shop_window)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_in_range = true
		if prompt_container != null:
			prompt_container.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_in_range = false
		if prompt_container != null:
			prompt_container.visible = false
		if _shop_window != null and is_instance_valid(_shop_window) and _shop_window.visible:
			_shop_window.close_window()
