class_name CheckpointTerminal
extends Area2D
## Terminal de Checkpoint.
## Guarda la posición de reaparición del jugador al entrar en su área.
## Los contratos de zona viven en la terminal separada ContractTerminal.

const PropSkin = preload("res://entities/props/prop_skin.gd")
## Altura del borde de arriba del LED sobre el piso.
const LED_TOP_Y: float = -44.0

signal checkpoint_activated(checkpoint_id: String)

@export var checkpoint_id: String = "checkpoint_track_mid"

@onready var status_light: CanvasItem = get_node_or_null("Visuals/StatusLight") as CanvasItem
@onready var prompt_ui: Node2D = get_node_or_null("PromptUI") as Node2D

var is_registered: bool = false
var _prompt_tween: Tween = null


func _ready() -> void:
	# Del checkpoint solo queda el LED (rojo = sin tomar, verde = tomado): sin cartel, terminal ni aviso
	var visuals: Node2D = get_node_or_null("Visuals") as Node2D
	if visuals != null:
		for child: Node in visuals.get_children():
			if child.name != "StatusLight":
				visuals.remove_child(child)
				child.queue_free()
		PropSkin._swap_led(visuals, LED_TOP_Y)
	status_light = get_node_or_null("Visuals/StatusLight") as CanvasItem
	if prompt_ui != null:
		prompt_ui.queue_free()
		prompt_ui = null
	collision_layer = 0
	collision_mask = 2 # Player

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Consultar persistencia en SaveManager: si el flag existe, arrancar en verde
	if SaveManager.has_world_flag(checkpoint_id):
		_set_status(true, false)
	else:
		_set_status(false, false)



func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_register_checkpoint()
		_show_prompt(true)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_show_prompt(false)


func _register_checkpoint() -> void:
	# 1. Registrar nueva posición de reaparición en SaveManager y TestLevel
	var respawn_pos: Vector2 = global_position + Vector2(0.0, -16.0)
	SaveManager.set_respawn_point(respawn_pos)
	var test_level: TestLevel = get_tree().current_scene as TestLevel
	if test_level != null:
		test_level.initial_spawn_position = respawn_pos

	# Al cargar la partida se vuelve a este checkpoint (solo en sectores de campaña, no en salas de prueba)
	var scene: Node = get_tree().current_scene
	if scene != null and scene.scene_file_path.begins_with("res://levels/chapter_"):
		SaveManager.set_resume_point(scene.scene_file_path, respawn_pos)
		var sm: SaveManager = SaveManager.get_instance()
		if sm != null:
			sm.save_to_disk()

	# 2. Encender luz en verde y persistir flag
	_set_status(true, true)
	checkpoint_activated.emit(checkpoint_id)
	GameFeel.sfx(self, &"checkpoint", global_position)
	print("[CheckpointTerminal] Checkpoint '%s' alcanzado. Reaparición fijada en %s." % [checkpoint_id, global_position])


func _set_status(registered: bool, persist_flag: bool = false) -> void:
	is_registered = registered
	if status_light != null:
		# Rojo = inactivo (no registrado), Verde = registrado
		var tint: Color = Color(0.2, 1.0, 0.4, 1.0) if registered else Color(1.0, 0.22, 0.22, 1.0)
		if status_light is ColorRect:
			(status_light as ColorRect).color = tint
		else:
			# El LED es una lente blanca: el color va por modulate
			status_light.modulate = tint

	if persist_flag:
		SaveManager.set_world_flag(checkpoint_id, true)


func _show_prompt(show_ui: bool) -> void:
	if prompt_ui == null:
		return

	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()

	if show_ui:
		prompt_ui.visible = true
		prompt_ui.scale = Vector2(0.85, 0.85)
		prompt_ui.modulate.a = 0.0
		_prompt_tween = create_tween().set_parallel(true)
		_prompt_tween.tween_property(prompt_ui, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_prompt_tween.tween_property(prompt_ui, "modulate:a", 1.0, 0.15)
	else:
		_prompt_tween = create_tween().set_parallel(true)
		_prompt_tween.tween_property(prompt_ui, "scale", Vector2(0.85, 0.85), 0.12)
		_prompt_tween.tween_property(prompt_ui, "modulate:a", 0.0, 0.12)
		_prompt_tween.chain().tween_callback(func() -> void: prompt_ui.visible = false)
