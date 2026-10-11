extends Area2D
## PNJ comerciante genérico. Con [E] abre la ventana de comercio (`ui/trade_window.tscn`) con el
## `TraderData` asignado en `trader_data`: para sumar otro comerciante basta con instanciar esta
## escena (o heredarla, como `merchant_npc.tscn`) y asignarle un recurso distinto.
## Sin class_name a propósito: se hereda por ruta (ver class-name-cache-gotcha).

const PropSkin = preload("res://entities/props/prop_skin.gd")
const TradeWindowScene = preload("res://ui/trade_window.tscn")
const DefaultTrader = preload("res://data/traders/merchant.tres")

## Qué vende, a cuánto y qué compra (core/trade/trader_data.gd). Vacío = el mercader por defecto.
@export var trader_data: Resource = null
## Arte del escenario que se aplica (ver PropSkin.apply).
@export var prop_kind: String = "merchant"

@onready var prompt_container: PanelContainer = get_node_or_null("Visuals/PromptContainer") as PanelContainer

var _player_in_range: bool = false
var _trade_window: DraggableWindow = null


func _ready() -> void:
	PropSkin.apply(self, prop_kind)
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
	_toggle_trade()


func _is_player_near() -> bool:
	if _player_in_range:
		return true
	var player_node: Player = get_tree().get_first_node_in_group(&"player") as Player
	return player_node != null and is_instance_valid(player_node) and global_position.distance_to(player_node.global_position) < 80.0


func _active_trader() -> Resource:
	return trader_data if trader_data != null else DefaultTrader


func _toggle_trade() -> void:
	_ensure_window()
	if _trade_window == null:
		return
	var trader: Resource = _active_trader()
	if bool(_trade_window.call(&"is_trading_with", trader)):
		_trade_window.close_window()
	else:
		_trade_window.call(&"open_trade", trader)


func _ensure_window() -> void:
	if _trade_window != null and is_instance_valid(_trade_window):
		return

	_trade_window = get_tree().get_first_node_in_group(&"trade_window") as DraggableWindow
	if _trade_window != null:
		return

	_trade_window = TradeWindowScene.instantiate() as DraggableWindow
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 20
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(canvas)
	canvas.add_child(_trade_window)


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
		if _trade_window != null and is_instance_valid(_trade_window) and _trade_window.visible \
				and bool(_trade_window.call(&"is_trading_with", _active_trader())):
			_trade_window.close_window()
