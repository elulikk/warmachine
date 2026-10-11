class_name DamageNumber
extends Marker2D
## Número de daño flotante efímero.
## Proyecta el impacto con código de color según el elemento, rebote crítico y desvanecimiento alpha.

@onready var label: Label = $Label

const COLOR_PHYSICAL: Color = Color(0.96, 0.96, 0.94, 1.0) # Blanco / Crema
const COLOR_CRITICAL: Color = Color(1.0, 0.85, 0.15, 1.0)  # Amarillo dorado brillante
const COLOR_FIRE: Color     = Color(1.0, 0.35, 0.15, 1.0)  # Naranja rojizo
const COLOR_ICE: Color      = Color(0.35, 0.85, 1.0, 1.0)  # Cian / celeste claro
const COLOR_STUN: Color     = Color(1.0, 0.95, 0.25, 1.0)  # Amarillo eléctrico / aturdimiento


func setup(amount: float, is_critical: bool = false, damage_type: String = "PHYSICAL") -> void:
	if not bool((load("res://core/settings.gd") as GDScript).call("get_bool", "damage_numbers")):
		queue_free()
		return
	if label == null:
		label = $Label
	
	# 1. Configurar texto (número entero y sufijo '!' en críticos)
	var text_str: String = str(roundi(amount))
	if is_critical:
		text_str += "!"
	label.text = text_str
	
	# 2. Asignar color temático
	var chosen_color: Color = COLOR_PHYSICAL
	if is_critical:
		chosen_color = COLOR_CRITICAL
	else:
		match damage_type.to_upper():
			"FIRE":
				chosen_color = COLOR_FIRE
			"ICE":
				chosen_color = COLOR_ICE
			"STUN":
				chosen_color = COLOR_STUN
			"CRITICAL":
				chosen_color = COLOR_CRITICAL
			_:
				chosen_color = COLOR_PHYSICAL
	
	label.modulate = chosen_color
	
	# 3. Animar trayectoria y desvanecimiento
	_animate(is_critical)


func _animate(is_critical: bool) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	
	# Desplazamiento vertical ascendente (30-40px) con desviación aleatoria horizontal (+/- 12px)
	var rise_y: float = randf_range(30.0, 40.0)
	var offset_x: float = randf_range(-12.0, 12.0)
	var target_position: Vector2 = position + Vector2(offset_x, -rise_y)
	
	tween.tween_property(self, "position", target_position, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Si es crítico, efecto pop con escala 1.5x inicial y rebote
	if is_critical:
		scale = Vector2(1.5, 1.5)
		var pop_tween: Tween = create_tween()
		pop_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25)
	
	# Desvanecimiento del canal alfa en los últimos 0.2s (a partir de los 0.4s)
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_delay(0.4)
	
	# Auto-destrucción al terminar la animación total de 0.6s
	tween.chain().tween_callback(queue_free)
