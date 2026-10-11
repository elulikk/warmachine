class_name VoiceComponent
extends Node2D
## Componente de expresiones vocales y diálogos flotantes (Barks).
## Muestra globos o textos breves estilizados sobre la entidad para dar feedback
## de contratación, combate, repliegue táctico o estado.

signal bark_spoken(text: String)

@export var offset_y: float = -48.0
@export var default_duration: float = 2.2

var _bark_label: Label = null
var _current_tween: Tween = null


func _ready() -> void:
	_create_bark_label()


func _create_bark_label() -> void:
	if _bark_label != null:
		return
	
	_bark_label = Label.new()
	_bark_label.name = "BarkLabel"
	_bark_label.position = Vector2(-120.0, offset_y)
	_bark_label.custom_minimum_size = Vector2(240.0, 20.0)
	_bark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bark_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bark_label.add_theme_font_size_override("font_size", 11)
	_bark_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.95))
	_bark_label.add_theme_constant_override("outline_size", 4)
	_bark_label.modulate.a = 0.0
	_bark_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bark_label)


## Emite una línea de texto flotante animada sobre la entidad.
func speak(text: String, duration: float = 0.0, font_color: Color = Color(1.0, 0.92, 0.55, 1.0)) -> void:
	if not is_inside_tree():
		return
	
	_create_bark_label()
	
	var active_duration: float = duration if duration > 0.0 else default_duration
	_bark_label.text = text
	_bark_label.add_theme_color_override("font_color", font_color)
	
	if _current_tween != null and _current_tween.is_valid():
		_current_tween.kill()
	
	_bark_label.position.y = offset_y
	_bark_label.scale = Vector2(0.8, 0.8)
	_bark_label.pivot_offset = Vector2(120.0, 10.0)
	_bark_label.modulate.a = 0.0
	
	_current_tween = create_tween()
	# Pop in
	_current_tween.tween_property(_bark_label, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_current_tween.parallel().tween_property(_bark_label, "modulate:a", 1.0, 0.12)
	# Float upward slightly
	_current_tween.parallel().tween_property(_bark_label, "position:y", offset_y - 6.0, active_duration)
	# Fade out
	_current_tween.tween_property(_bark_label, "modulate:a", 0.0, 0.35).set_delay(maxf(0.1, active_duration - 0.35))
	
	bark_spoken.emit(text)
