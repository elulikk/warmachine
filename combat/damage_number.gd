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
const COLOR_PLAYER_HIT: Color = Color(1.0, 0.05, 0.05, 1.0) # Rojo intenso: daño que recibe el jugador
const PLAYER_HIT_FONT_SIZE: int = 26
const PLAYER_HIT_SHAKE: float = 3.0
const PLAYER_HIT_SHAKE_TIME: float = 0.5
## Tope de números vivos a la vez (Fase P, punto 3): en masacres los que sobran no se crean.
## El daño que recibe el jugador se muestra siempre.
const MAX_ALIVE: int = 40

static var _alive: int = 0

var _shake_left: float = 0.0
var _label_rest: Vector2 = Vector2.ZERO


func setup(amount: float, is_critical: bool = false, damage_type: String = "PHYSICAL") -> void:
	if not bool((load("res://core/settings.gd") as GDScript).call("get_bool", "damage_numbers")):
		queue_free()
		return
	if _alive >= MAX_ALIVE and damage_type.to_upper() != "PLAYER_HIT":
		queue_free()
		return
	_alive += 1
	tree_exiting.connect(func() -> void: _alive -= 1, CONNECT_ONE_SHOT)
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
	
	var player_hit: bool = damage_type.to_upper() == "PLAYER_HIT"
	if player_hit:
		chosen_color = COLOR_PLAYER_HIT
		label.add_theme_font_size_override("font_size", PLAYER_HIT_FONT_SIZE)
		label.add_theme_constant_override("outline_size", 7)
		# Con "reducir destellos" no tiembla
		if not bool((load("res://core/settings.gd") as GDScript).call("reduce_flashes")):
			_shake_left = PLAYER_HIT_SHAKE_TIME
			_label_rest = label.position
	label.modulate = chosen_color
	
	# 3. Animar trayectoria y desvanecimiento
	_animate(is_critical, player_hit)


func _process(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left -= delta
	if _shake_left <= 0.0:
		label.position = _label_rest
		return
	var amount: float = PLAYER_HIT_SHAKE * clampf(_shake_left / PLAYER_HIT_SHAKE_TIME, 0.3, 1.0)
	label.position = _label_rest + Vector2(randf_range(-amount, amount), randf_range(-amount, amount))


func _animate(is_critical: bool, player_hit: bool = false) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	
	# Desplazamiento vertical ascendente (30-40px) con desviación aleatoria horizontal (+/- 12px)
	var rise_y: float = randf_range(30.0, 40.0)
	var offset_x: float = randf_range(-12.0, 12.0)
	var target_position: Vector2 = position + Vector2(offset_x, -rise_y)
	
	tween.tween_property(self, "position", target_position, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Si es crítico, efecto pop con escala 1.5x inicial y rebote
	if player_hit:
		scale = Vector2(1.4, 1.4)
		var hit_tween: Tween = create_tween()
		hit_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif is_critical:
		scale = Vector2(1.5, 1.5)
		var pop_tween: Tween = create_tween()
		pop_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25)
	
	# Desvanecimiento del canal alfa en los últimos 0.2s (a partir de los 0.4s)
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_delay(0.4)
	
	# Auto-destrucción al terminar la animación total de 0.6s
	tween.chain().tween_callback(queue_free)
