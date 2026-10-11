"""Agarre y animación de armas de fuego del cuerpo articulado (una sola vez)."""
import os
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))


def patch(path, pairs):
    p = os.path.join(ROOT, path)
    s = open(p, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old)
        s = s.replace(old, new, 1)
    open(p, "w", encoding="utf-8").write(s)


patch("entities/player/player.tscn", [
    ('position = Vector2(0, -42)\nscript = ExtResource("7_pivot")',
     'position = Vector2(0, -54)\nscript = ExtResource("7_pivot")'),
])

patch("core/weapon_manager.gd", [
    ('''	_cancel_hand_tween()
	_weapon_sprite.position = _sprite_rest_position + Vector2(-3.0, 0.0) * WEAPON_SCALE
	_hand_tween = create_tween()
	_hand_tween.tween_property(_weapon_sprite, "position", _sprite_rest_position, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)''',
     '''	_cancel_hand_tween()
	# Las armas pesadas patean más: el cañón sube y el arma se echa hacia atrás
	var power: float = 1.0
	if current_weapon != null:
		power = clampf(current_weapon.recoil_force / 60.0, 0.6, 2.0)
	_weapon_sprite.position = _sprite_rest_position + Vector2(-3.0 * power, 0.0) * WEAPON_SCALE
	_weapon_sprite.rotation = _sprite_rest_rotation - deg_to_rad(4.0 * power)
	_hand_tween = create_tween()
	_hand_tween.set_parallel(true)
	_hand_tween.tween_property(_weapon_sprite, "position", _sprite_rest_position, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hand_tween.tween_property(_weapon_sprite, "rotation", _sprite_rest_rotation, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)'''),
])

patch("entities/player/character_rig.gd", [
    # variables
    ('''var _fore_sprite: Array[Sprite2D] = []
var _hand_sprite: Array[Sprite2D] = []
''', '''var _fore_sprite: Array[Sprite2D] = []
var _hand_sprite: Array[Sprite2D] = []
var _hand_bone: Array[Node2D] = []
var _neck_bone: Node2D
var _recoil: float = 0.0
var _fire_connected: bool = false
var _aim_angle: float = 0.0
var _reach_back: float = 0.0
'''),
    # cabeza en un hueso de cuello
    ('''	_head = _make_sprite(_body, "Head")
''', '''	_neck_bone = Node2D.new()
	_neck_bone.name = "Neck"
	_body.add_child(_neck_bone)
	_head = _make_sprite(_neck_bone, "Head")
'''),
    ('''	_place(_head, head, neck + (head.get("pos_rel", Vector2.ZERO) as Vector2))
''', '''	_neck_bone.position = neck
	_place(_head, head, head.get("pos_rel", Vector2.ZERO) as Vector2)
'''),
    ('''	_body.move_child(_head, 0 if _articulated else 2)''', '''	_body.move_child(_neck_bone, 0 if _articulated else 2)'''),
    # mano en un hueso propio
    ('''		_fore_sprite.append(_make_sprite(fore, "ForeSprite"))
		_hand_sprite.append(_make_sprite(fore, "HandSprite"))
''', '''		_fore_sprite.append(_make_sprite(fore, "ForeSprite"))
		var hand_bone: Node2D = Node2D.new()
		hand_bone.name = "HandBone"
		fore.add_child(hand_bone)
		_hand_bone.append(hand_bone)
		_hand_sprite.append(_make_sprite(hand_bone, "HandSprite"))
'''),
    ('''		_fore[i].rotation = 0.0
		_fore[i].position = Vector2.ZERO
''', '''		_fore[i].rotation = 0.0
		_fore[i].position = Vector2.ZERO
		_hand_bone[i].rotation = 0.0
	_neck_bone.rotation = 0.0
'''),
    ('''	_place(_hand_sprite[index], hand, (hand.get("pos", Vector2.ZERO) as Vector2) - elbow)
''', '''	# La mano gira alrededor del agarre para seguir la orientación del arma
	_hand_bone[index].position = grip - elbow
	_place(_hand_sprite[index], hand, (hand.get("pos", Vector2.ZERO) as Vector2) - grip)
'''),
    ('''	_arm_dir_low[index] = (grip - elbow).angle()
	return grip - shoulder''', '''	_arm_dir_low[index] = (grip - elbow).angle()
	if index == 0:
		_reach_back = _arm_len_up[0] + _arm_len_low[0]
	return grip - shoulder'''),
    # señal de disparo
    ('''	_time += delta
	if gear_driven:
		_sync_gear()
''', '''	_time += delta
	if gear_driven:
		_sync_gear()
	_connect_fire_signal()
	_recoil = maxf(0.0, _recoil - delta * 7.0)
'''),
    ('''## Rodilla y tobillo del cuerpo articulado''', '''## Engancha el disparo del arma para que el cuerpo reaccione al retroceso (solo el jugador).
func _connect_fire_signal() -> void:
	if _fire_connected or preview_mode or _player == null or _player.weapon_manager == null:
		return
	_fire_connected = true
	_player.weapon_manager.weapon_fired.connect(_on_weapon_fired)


func _on_weapon_fired(_weapon: WeaponData) -> void:
	_recoil = 1.0


## Rodilla y tobillo del cuerpo articulado'''),
    # cuerpo: retroceso
    ('''	_body.rotation = sin(_phase) * 0.03 * minf(run_amount, 1.0) if on_floor else 0.0
''', '''	_body.rotation = sin(_phase) * 0.03 * minf(run_amount, 1.0) if on_floor else 0.0
	if _articulated:
		# Retroceso: el torso se echa hacia atrás y vuelve
		_body.rotation -= _recoil * 0.05
		_body.position.x = -_recoil * 1.2
'''),
    # brazos: ángulo del arma y alcance
    ('''	var weapon_sprite: Sprite2D = null
	var pose: Dictionary = {}
''', '''	var weapon_sprite: Sprite2D = null
	var pose: Dictionary = {}
	var aim_angle: float = 0.0
'''),
    ('''		hand_front = _body.to_local(weapon_sprite.to_global(hand_tex - grip))
''', '''		hand_front = _body.to_local(weapon_sprite.to_global(hand_tex - grip))
		# Orientación del arma vista desde el cuerpo (ya con el espejo de Visuals aplicado)
		var forward: Vector2 = _body.global_transform.affine_inverse().basis_xform(weapon_sprite.global_transform.x)
		aim_angle = forward.angle()
'''),
    ('''			hand_back = _reachable_support(hand_front, support_local, _shoulder_back, _rest_back.length())''',
     '''			var reach_back: float = _reach_back if _articulated else _rest_back.length()
			hand_back = _reachable_support(hand_front, support_local, _shoulder_back, reach_back)'''),
    ('''	if _articulated:
		_aim_chain(1, _arm_front, _shoulder_front, hand_front)
		_aim_chain(0, _arm_back, _shoulder_back, hand_back)
		return''', '''	if _articulated:
		var blend: float = minf(1.0, get_process_delta_time() * 14.0)
		_aim_angle = lerp_angle(_aim_angle, aim_angle, blend)
		var hand_angle: float = _aim_angle if holding else 0.0
		_aim_chain(1, _arm_front, _shoulder_front, hand_front, hand_angle, holding)
		_aim_chain(0, _arm_back, _shoulder_back, hand_back, hand_angle, two_handed)
		# La cabeza acompaña la puntería, sin llegar a girar entera
		var look: float = clampf(_aim_angle, deg_to_rad(-70.0), deg_to_rad(70.0)) * 0.35 if holding else 0.0
		_neck_bone.rotation = lerp_angle(_neck_bone.rotation, look, blend)
		return'''),
    ('''func _aim_chain(index: int, bone: Node2D, shoulder_pos: Vector2, target: Vector2) -> void:''',
     '''func _aim_chain(index: int, bone: Node2D, shoulder_pos: Vector2, target: Vector2, hand_angle: float, orient_hand: bool) -> void:'''),
    ('''	_fore[index].rotation = lower_angle - _arm_dir_low[index] - bone.rotation
''', '''	_fore[index].rotation = lower_angle - _arm_dir_low[index] - bone.rotation
	var hand_target: float = 0.0
	if orient_hand:
		var arm_global: float = bone.rotation + _fore[index].rotation
		hand_target = clampf(wrapf(hand_angle - arm_global, -PI, PI), deg_to_rad(-75.0), deg_to_rad(75.0))
	_hand_bone[index].rotation = lerp_angle(_hand_bone[index].rotation, hand_target, 0.35)
'''),
])
print("ok")
