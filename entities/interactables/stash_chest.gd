class_name StashChest
extends Area2D
## Baúl interactivo de campamento base (Stash Chest).
## Al interactuar con la tecla [E], despliega simultáneamente
## la ventana del baúl y la mochila del jugador para intercambio directo.

const PropSkin = preload("res://entities/props/prop_skin.gd")
@onready var prompt_container: PanelContainer = $Visuals/PromptContainer
@onready var chest_body: ColorRect = get_node_or_null("Visuals/ChestBody") as ColorRect
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("Visuals/AnimatedSprite2D") as AnimatedSprite2D

var _player_in_range: bool = false
var _stash_window_instance: StashWindow = null


func _ready() -> void:
	PropSkin.swap_frames(anim_sprite, ["chest_closed.png", "chest_open.png"] as Array[String])
	collision_layer = 0
	collision_mask = 2 # Player
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt_container != null:
		prompt_container.visible = false
	if anim_sprite != null:
		anim_sprite.frame = 0


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interact()


func interact() -> void:
	_ensure_windows()
	if _stash_window_instance != null:
		_stash_window_instance.toggle_window()
		
		# Sincronizar frame del sprite (0: cerrado, 1: abierto)
		if anim_sprite != null:
			anim_sprite.frame = 1 if _stash_window_instance.visible else 0
		
		# Al abrir el baúl, abrir también la mochila del jugador
		var inv_win: InventoryWindow = get_tree().get_first_node_in_group(&"inventory_window") as InventoryWindow
		if inv_win != null and _stash_window_instance.visible:
			inv_win.open_window()


func _ensure_windows() -> void:
	if _stash_window_instance != null and is_instance_valid(_stash_window_instance):
		return
	
	_stash_window_instance = get_tree().get_first_node_in_group(&"stash_window") as StashWindow
	if _stash_window_instance == null:
		var stash_scene: PackedScene = preload("res://ui/stash_window.tscn")
		_stash_window_instance = stash_scene.instantiate() as StashWindow
		var canvas: CanvasLayer = CanvasLayer.new()
		canvas.layer = 20
		get_tree().root.add_child(canvas)
		canvas.add_child(_stash_window_instance)
	
	if _stash_window_instance != null and not _stash_window_instance.window_closed.is_connected(_on_stash_closed):
		_stash_window_instance.window_closed.connect(_on_stash_closed)


func _on_stash_closed() -> void:
	if anim_sprite != null:
		anim_sprite.frame = 0


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_in_range = true
		if prompt_container != null:
			prompt_container.visible = true
			var tw: Tween = create_tween()
			tw.tween_property(prompt_container, "modulate:a", 1.0, 0.15).from(0.0)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_in_range = false
		if prompt_container != null:
			prompt_container.visible = false
