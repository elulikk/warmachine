extends Area2D
## Puerta que lleva a otra escena con [E] (por ahora: Campamento Base <-> Sala de Estrés).
## Sin class_name a propósito: se instancia por su escena. Arma su colisión y su arte por código,
## así la escena es solo el nodo raíz con este script.

const PropSkin = preload("res://entities/props/prop_skin.gd")

@export_file("*.tscn") var target_scene: String = ""
@export var prompt_text: String = "[E] Entrar"
@export var sign_text: String = ""
@export var accent: Color = Color(1.0, 0.55, 0.25, 1.0)

var _player_in_range: bool = false
var _prompt: Label = null
var _used: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(56.0, 64.0)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -32.0)
	add_child(collision)

	var gate: Sprite2D = PropSkin.add_sprite(self, "gate_open.png", 0.0)
	if gate == null:
		var frame: ColorRect = ColorRect.new()
		frame.color = Color(0.16, 0.13, 0.12, 1.0)
		frame.position = Vector2(-26.0, -72.0)
		frame.size = Vector2(52.0, 72.0)
		add_child(frame)
	var glow: ColorRect = ColorRect.new()
	glow.color = Color(accent.r, accent.g, accent.b, 0.85)
	glow.position = Vector2(-18.0, -86.0)
	glow.size = Vector2(36.0, 4.0)
	glow.z_index = PropSkin.TAG_Z_INDEX
	add_child(glow)

	if not sign_text.is_empty():
		var sign_label: Label = _make_label(sign_text, 10, accent)
		sign_label.position = Vector2(-80.0, -104.0)
		add_child(sign_label)

	_prompt = _make_label(prompt_text, 11, Color(1.0, 0.92, 0.75, 1.0))
	_prompt.position = Vector2(-80.0, -124.0)
	_prompt.visible = false
	add_child(_prompt)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.size = Vector2(160.0, 16.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = PropSkin.TAG_Z_INDEX
	return label


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and not _used and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_go()


func _go() -> void:
	if target_scene.is_empty():
		return
	_used = true
	GameFeel.sfx(self, &"gate_open", global_position)
	GameManager.change_scene(target_scene)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_in_range = true
		if _prompt != null:
			_prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_in_range = false
		if _prompt != null:
			_prompt.visible = false
