class_name DraggableWindow
extends PanelContainer
## Ventana modular arrastrable con cabecera y botón de cierre.
## Permite ser reposicionada libremente con el ratón dentro de los límites del Viewport.
## Al interactuar con ella, prioriza su orden visual colocándose al frente.

const SteamSkin = preload("res://ui/components/steam_skin.gd")

signal window_closed

@export var window_title: String = "Ventana":
	set(val):
		window_title = val
		if title_label != null:
			title_label.text = window_title

@onready var header_bar: HBoxContainer = get_node_or_null("VBox/HeaderBar") as HBoxContainer
@onready var title_label: Label = get_node_or_null("VBox/HeaderBar/TitleLabel") as Label
@onready var close_button: Button = get_node_or_null("VBox/HeaderBar/CloseButton") as Button

var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Permite al controlador de ítem en mano saber qué ventana tapa a cuál
	add_to_group(&"draggable_windows")
	if header_bar != null:
		header_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		header_bar.gui_input.connect(_on_header_gui_input)
	
	if close_button != null:
		close_button.pressed.connect(close_window)
	
	if title_label != null:
		title_label.text = window_title

	# Aspecto steampunk: marco texturizado y estilos de los controles hijos
	SteamSkin.skin_window(self)
	visibility_changed.connect(_on_visibility_changed)


## Los ítems y botones que una ventana crea por código aparecen después de _ready: se vuelve a estilizar al mostrarla.
func _on_visibility_changed() -> void:
	if visible:
		SteamSkin.skin_tree(self)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		move_to_front()


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_dragging = true
				_drag_offset = get_global_mouse_position() - global_position
				move_to_front()
				accept_event()
			else:
				_is_dragging = false
				accept_event()


func _input(event: InputEvent) -> void:
	if _is_dragging:
		if event is InputEventMouseMotion:
			var mouse_pos: Vector2 = get_global_mouse_position()
			var target_pos: Vector2 = mouse_pos - _drag_offset
			_clamp_window_position(target_pos)
		elif event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				_is_dragging = false


func _clamp_window_position(target_pos: Vector2) -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var win_size: Vector2 = size
	var min_x: float = 0.0
	var max_x: float = maxf(0.0, vp_size.x - win_size.x)
	var min_y: float = 0.0
	var max_y: float = maxf(0.0, vp_size.y - win_size.y)
	
	global_position = Vector2(
		clampf(target_pos.x, min_x, max_x),
		clampf(target_pos.y, min_y, max_y)
	)


func open_window() -> void:
	visible = true
	move_to_front()


func close_window() -> void:
	_is_dragging = false
	visible = false
	window_closed.emit()


func toggle_window() -> void:
	if visible:
		close_window()
	else:
		open_window()
