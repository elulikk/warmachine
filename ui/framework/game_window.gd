extends DraggableWindow
## Base de las ventanas modulares: se arman 100 % por código, sin escena .tscn.
## Sin class_name a propósito: las ventanas hijas hacen `extends "res://ui/framework/game_window.gd"`.
##
## Una ventana nueva es un script que:
##   1. Sobrescribe `_configure()` para fijar `window_id`, `window_title`, `window_size` y (opcional)
##      `toggle_action`. (No sobrescribir `_init`: la base arma ahí el marco.)
##   2. Sobrescribe `_build(root)` para crear sus controles con `UiKit` (una sola vez).
##   3. Sobrescribe `_on_opened()` para refrescar datos cada vez que se abre.
##   4. Se anota en `WindowRegistry.WINDOWS` (ui/framework/window_registry.gd).
## La base pone el marco, la cabecera arrastrable, el botón de cerrar, el centrado, la tecla para
## abrir/cerrar, Esc para cerrar y el grupo `window_<id>` para abrirla desde cualquier lado.
## Ver el skill `add-window` (.claude/skills/add-window/SKILL.md).

const UiKit = preload("res://ui/framework/ui_kit.gd")

## Identificador corto ("codex"). Grupo `window_<id>`: `WindowRegistry.open(get_tree(), &"codex")`.
var window_id: StringName = &""
## Acción del InputMap que abre y cierra la ventana (vacía = solo se abre por código o botón).
var toggle_action: StringName = &""
## Tamaño inicial (px de la UI).
var window_size: Vector2 = Vector2(520.0, 420.0)
## Esc (ui_cancel) cierra la ventana si está abierta.
var close_on_cancel: bool = true

## Contenedor donde `_build` agrega el contenido.
var content_root: MarginContainer = null
var _positioned: bool = false


func _init() -> void:
	# Misma estructura que draggable_window.tscn: DraggableWindow busca estos nodos por ruta
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "VBox"
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	header.name = "HeaderBar"
	column.add_child(header)
	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close: Button = Button.new()
	close.name = "CloseButton"
	close.text = "X"
	close.custom_minimum_size = Vector2(22.0, 22.0)
	header.add_child(close)
	content_root = MarginContainer.new()
	content_root.name = "ContentContainer"
	content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content_root)
	_configure()


func _ready() -> void:
	super._ready()
	visible = false
	custom_minimum_size = window_size
	size = window_size
	add_to_group(&"game_windows")
	if window_id != &"":
		add_to_group(StringName("window_%s" % window_id))
	_build(content_root)


## Fija id, título, tamaño y tecla (se llama al construirse, antes de entrar al árbol). Sobrescribir.
func _configure() -> void:
	pass


## Crea los controles de la ventana (una vez). Sobrescribir.
func _build(_root: Control) -> void:
	pass


## Se llama justo antes de mostrarse: refrescar datos acá. Sobrescribir.
func _on_opened() -> void:
	pass


## Se llama al cerrarse. Sobrescribir si hace falta soltar algo.
func _on_closed() -> void:
	pass


func open_window() -> void:
	_on_opened()
	super.open_window()
	if not _positioned:
		_positioned = true
		_center.call_deferred()


func close_window() -> void:
	var was_open: bool = visible
	super.close_window()
	if was_open:
		_on_closed()


func _unhandled_input(event: InputEvent) -> void:
	if toggle_action != &"" and InputMap.has_action(toggle_action) and event.is_action_pressed(toggle_action):
		get_viewport().set_input_as_handled()
		toggle_window()
	elif visible and close_on_cancel and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_window()


func _center() -> void:
	var vp: Vector2 = get_viewport_rect().size
	global_position = ((vp - size) * 0.5).clamp(Vector2.ZERO, (vp - size).max(Vector2.ZERO))
