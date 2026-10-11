class_name ContractTerminal
extends Area2D
## Terminal de Contratos de Riesgo de Zona (separada del Checkpoint).
## Permite elegir entre jugar sin contrato ([E]) o firmar un contrato con
## mutadores de mundo y físicas alteradas ([F]). No guarda puntos de reaparición.

const PropSkin = preload("res://entities/props/prop_skin.gd")
signal contract_chosen(contract: ZoneContract)
signal contract_cleared

@export var contract_resource: ZoneContract = preload("res://data/contracts/low_gravity_contract.tres")

@onready var status_light: ColorRect = get_node_or_null("Visuals/StatusLight") as ColorRect
@onready var prompt_ui: Node2D = get_node_or_null("PromptUI") as Node2D

var contract_active: bool = false
var _player_in_range: bool = false
var _prompt_tween: Tween = null


func _ready() -> void:
	PropSkin.apply(self, "terminal_gold")
	collision_layer = 0
	collision_mask = 2 # Player

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var mod_mgr: ZoneModifierManager = ZoneModifierManager.get_instance()
	_set_status(mod_mgr != null and mod_mgr.active_contract != null)

	if prompt_ui != null:
		prompt_ui.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return

	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_clear_contract()
	elif event.is_action_pressed("contract_sign"):
		get_viewport().set_input_as_handled()
		_sign_contract()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_in_range = true
		_show_prompt(true)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_in_range = false
		_show_prompt(false)


func _clear_contract() -> void:
	var mod_mgr: ZoneModifierManager = ZoneModifierManager.get_instance()
	if mod_mgr != null:
		mod_mgr.clear_contract()

	_set_status(false)
	_show_prompt(false)
	contract_cleared.emit()
	print("[ContractTerminal] Sin contrato: mutadores de zona desactivados.")


func _sign_contract() -> void:
	if contract_resource == null:
		contract_resource = load("res://data/contracts/low_gravity_contract.tres") as ZoneContract

	var mod_mgr: ZoneModifierManager = ZoneModifierManager.get_instance()
	if mod_mgr != null and contract_resource != null:
		mod_mgr.apply_contract(contract_resource)

	_set_status(true)
	_show_prompt(false)
	contract_chosen.emit(contract_resource)
	print("[ContractTerminal] ¡Contrato de Riesgo '%s' FIRMADO! Mutadores de zona activos." % (contract_resource.contract_title if contract_resource != null else "Desconocido"))


func _set_status(active: bool) -> void:
	contract_active = active
	if status_light != null:
		# Rojo = sin contrato, Ámbar = contrato firmado
		status_light.color = Color(1.0, 0.75, 0.2, 1.0) if active else Color(1.0, 0.22, 0.22, 1.0)


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
