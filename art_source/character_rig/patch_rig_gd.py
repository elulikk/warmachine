"""Aplica los cambios del cuerpo articulado a entities/player/character_rig.gd (una sola vez)."""
import os
HERE = os.path.dirname(os.path.abspath(__file__))
p = os.path.join(HERE, "..", "..", "entities", "player", "character_rig.gd")
s = open(p, encoding="utf-8").read()
if "HeroArt" in s:
    raise SystemExit("ya aplicado")


def rep(old, new):
    global s
    assert s.count(old) >= 1, old
    s = s.replace(old, new, 1)


rep('const ArmorArt = preload("res://core/art/armor_art.gd")\n',
    'const ArmorArt = preload("res://core/art/armor_art.gd")\nconst HeroArt = preload("res://core/art/hero_art.gd")\n')
rep('''##   skin   cuerpo base (`no_armor`, `zombie`, `skeleton`, `ghost`): cabeza, torso, brazos, piernas y manos.''',
'''##   skin   cuerpo base (`hero`, `no_armor`, `zombie`, `skeleton`, `ghost`): cabeza, torso, brazos, piernas y manos.
##          `hero` es de perfil y articulado (hombro/codo, cadera/rodilla/tobillo; datos en `hero_art.gd`);
##          los demás son de una pieza por miembro (`armor_art.gd`).''')
rep('"skin": "no_armor",\n\t"back"', '"skin": "hero",\n\t"back"')
rep('''var _applied: Dictionary = {}
''', '''var _applied: Dictionary = {}

# Cuerpo articulado (`hero`): los miembros son cadenas de huesos. Índice 0 = lado lejano, 1 = lado cercano.
var _articulated: bool = false
var _cur_scale: float = TEX_SCALE
var _shin: Array[Node2D] = []
var _shin_sprite: Array[Sprite2D] = []
var _foot_bone: Array[Node2D] = []
var _foot_sprite: Array[Sprite2D] = []
var _fore: Array[Node2D] = []
var _fore_sprite: Array[Sprite2D] = []
var _hand_sprite: Array[Sprite2D] = []
var _arm_len_up: Array[float] = [0.0, 0.0]
var _arm_len_low: Array[float] = [0.0, 0.0]
var _arm_dir_up: Array[float] = [0.0, 0.0]
var _arm_dir_low: Array[float] = [0.0, 0.0]
''')
rep('''	_glove_front = _make_sprite(_arm_front, "Glove")
''', '''	_glove_front = _make_sprite(_arm_front, "Glove")
	_build_chains()


## Huesos del cuerpo articulado: espinilla y pie colgados de cada cadera, antebrazo y mano de cada hombro.
func _build_chains() -> void:
	var hips: Array[Node2D] = [_leg_l, _leg_r]
	var thighs: Array[Sprite2D] = [_leg_l_sprite, _leg_r_sprite]
	for i in range(2):
		var shin: Node2D = Node2D.new()
		shin.name = "Shin"
		hips[i].add_child(shin)
		var foot: Node2D = Node2D.new()
		foot.name = "Foot"
		shin.add_child(foot)
		_foot_sprite.append(_make_sprite(foot, "FootSprite"))
		_shin_sprite.append(_make_sprite(shin, "ShinSprite"))
		_shin.append(shin)
		_foot_bone.append(foot)
		# El muslo se dibuja sobre la espinilla
		hips[i].move_child(thighs[i], hips[i].get_child_count() - 1)
	var arms: Array[Node2D] = [_arm_back, _arm_front]
	for i in range(2):
		var fore: Node2D = Node2D.new()
		fore.name = "Fore"
		arms[i].add_child(fore)
		_fore_sprite.append(_make_sprite(fore, "ForeSprite"))
		_hand_sprite.append(_make_sprite(fore, "HandSprite"))
		_fore.append(fore)
''')
rep('''	sprite.scale = Vector2(TEX_SCALE, TEX_SCALE)
	sprite.offset = Vector2.ZERO
	sprite.region_enabled = false''', '''	sprite.scale = Vector2(_cur_scale, _cur_scale)
	sprite.offset = Vector2.ZERO
	sprite.region_enabled = false''')
rep('''	var data: Dictionary = ArmorArt.SKINS.get(skin_id, {}) as Dictionary
	if data.is_empty():''', '''	var data: Dictionary = HeroArt.SKINS.get(skin_id, {}) as Dictionary
	if data.is_empty():
		data = ArmorArt.SKINS.get(skin_id, {}) as Dictionary
	if data.is_empty():''')
rep('''	_has_legs = bool(body.get("has_legs", true))
	_hover = not _has_legs
''', '''	_has_legs = bool(body.get("has_legs", true))
	_hover = not _has_legs
	_articulated = bool(body.get("articulated", false))
	_cur_scale = TEX_SCALE
	var back_shift: float = float(body.get("back_shift", 0.0))
''')
rep('''	# Piernas: dos mitades que cuelgan de la cadera
	_apply_leg(_leg_l, _leg_l_sprite, body.get("leg_l", {}) as Dictionary, true)
	_apply_leg(_leg_r, _leg_r_sprite, body.get("leg_r", {}) as Dictionary, false)
''', '''	# Piernas: dos mitades que cuelgan de la cadera
	if _articulated:
		_apply_articulated_legs(body)
	else:
		_hide_chains()
		_apply_leg(_leg_l, _leg_l_sprite, body.get("leg_l", {}) as Dictionary, true)
		_apply_leg(_leg_r, _leg_r_sprite, body.get("leg_r", {}) as Dictionary, false)
''')
rep('''	_place(_head, head, neck + (head.get("pos_rel", Vector2.ZERO) as Vector2))
''', '''	_place(_head, head, neck + (head.get("pos_rel", Vector2.ZERO) as Vector2))
	# De perfil, el cuello de la túnica tapa la base de la cabeza; en los cuerpos de frente la cabeza va sobre el torso y bajo los brazos
	_body.move_child(_head, 0 if _articulated else 2)
''')
rep('''		_belt.position = Vector2(torso_size.x * 0.32, torso_top + torso_size.y - 4.0)''',
    '''		_belt.position = Vector2(torso_size.x * 0.32, torso_top + torso_size.y - 4.0)
		if body.has("belt_pos"):
			_belt.position = body.get("belt_pos") as Vector2''')
rep('''		_wing_l.position = Vector2(-4.0, torso_top + 8.0)
		_wing_r.position = Vector2(4.0, torso_top + 8.0)''', '''		_wing_l.position = Vector2(-4.0 + back_shift, torso_top + 8.0)
		_wing_r.position = Vector2(4.0 + back_shift, torso_top + 8.0)''')
rep('''		_back_sprite.position = Vector2(0.0, torso_top + 5.0)''', '''		_back_sprite.position = Vector2(back_shift, torso_top + 5.0)''')
rep('''	# Brazos: el origen del hueso es el hombro; la mano cuelga de la muñeca
''', '''	# Brazos: el origen del hueso es el hombro; la mano cuelga de la muñeca
	if _articulated:
		_rest_back = _apply_articulated_arm(0, _arm_back, _arm_back_sprite, _glove_back, body.get("arm_far", {}) as Dictionary)
		_rest_front = _apply_articulated_arm(1, _arm_front, _arm_front_sprite, _glove_front, body.get("arm_near", {}) as Dictionary)
		return
''')
rep('''func _apply_leg(bone: Node2D''', '''## Oculta las piezas extra del cuerpo articulado (cuando el aspecto es de una pieza por miembro).
func _hide_chains() -> void:
	for i in range(2):
		_shin_sprite[i].visible = false
		_foot_sprite[i].visible = false
		_fore_sprite[i].visible = false
		_hand_sprite[i].visible = false
		_shin[i].rotation = 0.0
		_foot_bone[i].rotation = 0.0
		_fore[i].rotation = 0.0
		_fore[i].position = Vector2.ZERO


## Piernas del cuerpo articulado: muslo en la cadera, espinilla en la rodilla y pie en el tobillo.
## `leg_far` cuelga de `_leg_l` y `leg_near` de `_leg_r`.
func _apply_articulated_legs(body: Dictionary) -> void:
	var bones: Array[Node2D] = [_leg_l, _leg_r]
	var thighs: Array[Sprite2D] = [_leg_l_sprite, _leg_r_sprite]
	var keys: Array[String] = ["leg_far", "leg_near"]
	for i in range(2):
		var leg: Dictionary = body.get(keys[i], {}) as Dictionary
		var hip: Vector2 = leg.get("hip", Vector2(0.0, -34.0)) as Vector2
		var knee: Vector2 = leg.get("knee", hip + Vector2(0.0, 15.0)) as Vector2
		var ankle: Vector2 = leg.get("ankle", knee + Vector2(0.0, 15.0)) as Vector2
		bones[i].visible = _has_legs
		bones[i].position = hip
		if i == 0:
			_leg_base_y_l = hip.y
		else:
			_leg_base_y_r = hip.y
		var thigh: Dictionary = leg.get("thigh", {}) as Dictionary
		_place(thighs[i], thigh, (thigh.get("pos", Vector2.ZERO) as Vector2) - hip)
		_shin[i].position = knee - hip
		var shin: Dictionary = leg.get("shin", {}) as Dictionary
		_place(_shin_sprite[i], shin, (shin.get("pos", Vector2.ZERO) as Vector2) - knee)
		_foot_bone[i].position = ankle - knee
		var foot: Dictionary = leg.get("foot", {}) as Dictionary
		_place(_foot_sprite[i], foot, (foot.get("pos", Vector2.ZERO) as Vector2) - ankle)


## Brazo del cuerpo articulado. Devuelve el vector hombro -> mano (agarre) en reposo.
## `index`: 0 lejano, 1 cercano. El hueso del brazo es el hombro; el antebrazo y la mano cuelgan del codo.
func _apply_articulated_arm(index: int, bone: Node2D, upper_sprite: Sprite2D, glove_sprite: Sprite2D, arm: Dictionary) -> Vector2:
	glove_sprite.visible = false
	var shoulder: Vector2 = arm.get("shoulder", Vector2(0.0, -60.0)) as Vector2
	var elbow: Vector2 = arm.get("elbow", shoulder + Vector2(0.0, 10.0)) as Vector2
	var grip: Vector2 = arm.get("grip", elbow + Vector2(0.0, 17.0)) as Vector2
	bone.position = shoulder
	if index == 0:
		_shoulder_back = shoulder
	else:
		_shoulder_front = shoulder
	var upper: Dictionary = arm.get("upper", {}) as Dictionary
	_place(upper_sprite, upper, (upper.get("pos", Vector2.ZERO) as Vector2) - shoulder)
	_fore[index].position = elbow - shoulder
	var lower: Dictionary = arm.get("lower", {}) as Dictionary
	_place(_fore_sprite[index], lower, (lower.get("pos", Vector2.ZERO) as Vector2) - elbow)
	var hand: Dictionary = arm.get("hand", {}) as Dictionary
	_place(_hand_sprite[index], hand, (hand.get("pos", Vector2.ZERO) as Vector2) - elbow)
	_arm_len_up[index] = (elbow - shoulder).length()
	_arm_len_low[index] = (grip - elbow).length()
	_arm_dir_up[index] = (elbow - shoulder).angle()
	_arm_dir_low[index] = (grip - elbow).angle()
	return grip - shoulder


func _apply_leg(bone: Node2D''')

# ---- animación ----
rep('''	var blend: float = minf(1.0, delta * 18.0)
	_leg_l.rotation = lerp_angle(_leg_l.rotation, leg_l_target, blend)
	_leg_r.rotation = lerp_angle(_leg_r.rotation, leg_r_target, blend)
''', '''	var blend: float = minf(1.0, delta * 18.0)
	_leg_l.rotation = lerp_angle(_leg_l.rotation, leg_l_target, blend)
	_leg_r.rotation = lerp_angle(_leg_r.rotation, leg_r_target, blend)
	if _articulated:
		_animate_knees(on_floor, jetting, vertical, run_amount, blend)
''')
rep('''## Orienta cada brazo hacia el punto que debe sostener.''', '''## Rodilla y tobillo del cuerpo articulado: la pierna que avanza dobla la rodilla; en el aire se encoge un poco.
func _animate_knees(on_floor: bool, jetting: bool, vertical: float, run_amount: float, blend: float) -> void:
	var flex: Array[float] = [0.0, 0.0]
	if on_floor:
		var amount: float = minf(run_amount, 1.0)
		flex[0] = maxf(0.0, -cos(_phase)) * deg_to_rad(42.0) * amount
		flex[1] = maxf(0.0, cos(_phase)) * deg_to_rad(42.0) * amount
	elif jetting:
		flex = [deg_to_rad(8.0), deg_to_rad(4.0)]
	elif vertical < 0.0:
		flex = [deg_to_rad(22.0), deg_to_rad(40.0)]
	else:
		flex = [deg_to_rad(10.0), deg_to_rad(16.0)]
	var hips: Array[Node2D] = [_leg_l, _leg_r]
	for i in range(2):
		_shin[i].rotation = lerp_angle(_shin[i].rotation, flex[i], blend)
		# El pie compensa parte del giro para no apuntar al suelo al levantar la pierna
		_foot_bone[i].rotation = -(hips[i].rotation + _shin[i].rotation) * 0.45


## Orienta cada brazo hacia el punto que debe sostener.''')
rep('''	_aim_arm(_arm_front, _shoulder_front, hand_front, _rest_front)
	_aim_arm(_arm_back, _shoulder_back, hand_back, _rest_back)
''', '''	if _articulated:
		_aim_chain(1, _arm_front, _shoulder_front, hand_front)
		_aim_chain(0, _arm_back, _shoulder_back, hand_back)
		return
	_aim_arm(_arm_front, _shoulder_front, hand_front, _rest_front)
	_aim_arm(_arm_back, _shoulder_back, hand_back, _rest_back)
''')
s += '''

## Cinemática inversa de dos huesos: lleva el agarre de la mano a `target` (coordenadas del cuerpo).
## El codo se dobla hacia abajo/atrás; si el punto queda fuera de alcance el brazo se estira hasta un 15 %.
func _aim_chain(index: int, bone: Node2D, shoulder_pos: Vector2, target: Vector2) -> void:
	var upper: float = _arm_len_up[index]
	var lower: float = _arm_len_low[index]
	if upper < 0.1 or lower < 0.1:
		return
	bone.position = shoulder_pos
	var want: Vector2 = target - shoulder_pos
	var dist: float = maxf(want.length(), 0.001)
	var reach: float = upper + lower
	var stretch: float = clampf(dist / reach, 1.0, 1.15)
	bone.scale = Vector2(stretch, stretch)
	var d: float = clampf(dist / stretch, absf(upper - lower) + 0.01, reach - 0.01)
	var base: float = want.angle()
	var cos_a: float = clampf((upper * upper + d * d - lower * lower) / (2.0 * upper * d), -1.0, 1.0)
	var upper_angle: float = base + acos(cos_a)
	var elbow: Vector2 = Vector2.from_angle(upper_angle) * upper
	var lower_angle: float = (want / stretch - elbow).angle()
	bone.rotation = upper_angle - _arm_dir_up[index]
	_fore[index].rotation = lower_angle - _arm_dir_low[index] - bone.rotation
'''
open(p, "w", encoding="utf-8").write(s)
print("ok")
