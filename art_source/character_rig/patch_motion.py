"""Integra core/art/weapon_motion.gd (agarre y animación por arma) en WeaponManager, ItemIcons y CharacterRig."""
import os, re
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))


def load(path):
    return open(os.path.join(ROOT, path), encoding="utf-8").read()


def save(path, s):
    open(os.path.join(ROOT, path), "w", encoding="utf-8").write(s)


def rep(s, old, new):
    assert s.count(old) == 1, old
    return s.replace(old, new, 1)


# ------------------------------------------------------------------ WeaponManager
p = "core/weapon_manager.gd"
s = load(p)
assert "WeaponMotion" not in s
s = rep(s, 'const ItemIconsScript = preload("res://ui/components/item_icons.gd")\n',
        'const ItemIconsScript = preload("res://ui/components/item_icons.gd")\nconst WeaponMotion = preload("res://core/art/weapon_motion.gd")\n')
s = rep(s, "var _hand_tween: Tween = null\n", '''var _hand_tween: Tween = null

## Última animación disparada (la lee CharacterRig al recibir `weapon_fired`):
## {"body": fotogramas del cuerpo, "length": duración en s, "recoil": factor de retroceso del torso}
var last_motion: Dictionary = {}
var _swing_index: int = 0
var _current_swing: Dictionary = {}
''')

# reposo (hold) del arma melee
s = rep(s, "	_sprite_rest_position = Vector2(HAND_OFFSET_X, 0.0)\n", '''	_sprite_rest_position = Vector2(HAND_OFFSET_X, 0.0)
	if current_weapon.weapon_type == WeaponData.WeaponType.MELEE:
		# Cada arma melee se sostiene a su manera (ver weapon_motion.gd)
		var hold: Dictionary = WeaponMotion.profile_for(current_weapon).get("hold", {}) as Dictionary
		if not hold.is_empty():
			_sprite_rest_position += hold.get("pos", Vector2.ZERO) as Vector2
			_sprite_rest_rotation += deg_to_rad(float(hold.get("rot_deg", 0.0)))
''')

# ataque melee: elige el tajo del combo, arranca la animación y retrasa el golpe si el arma lo pide
s = rep(s, '''func _execute_melee_attack() -> void:
	var aim_dir: Vector2''', '''func _execute_melee_attack() -> void:
	var swings: Array = WeaponMotion.profile_for(current_weapon).get("swings", []) as Array
	_current_swing = {}
	if not swings.is_empty():
		_current_swing = swings[_swing_index % swings.size()] as Dictionary
		_swing_index += 1
	var total: float = maxf(current_weapon.swing_duration, 0.05) * float(_current_swing.get("length", 1.0))
	last_motion = {"body": _current_swing.get("body", []), "length": total, "recoil": 0.0}

	if not infinite_ammo:
		fire_cooldown_timer = current_weapon.get_fire_interval()
	else:
		fire_cooldown_timer = 0.08

	var delay: float = float(_current_swing.get("hit_delay", 0.0))
	if delay <= 0.0:
		_melee_strike(false)
		weapon_fired.emit(current_weapon)
		return

	# El golpe llega con el impacto de la animación (martillo): el cuerpo y el arma empiezan ya
	var swung: WeaponData = current_weapon
	if _has_weapon_sprite():
		_play_melee_swing(swung.swing_arc_degrees, swung.swing_duration)
	weapon_fired.emit(swung)
	await get_tree().create_timer(delay).timeout
	if current_weapon != swung or player == null or not is_instance_valid(player):
		return
	_melee_strike(true)


## Crea el golpe efectivo del arma melee: hitbox, impulso y onda de choque.
func _melee_strike(visual_done: bool) -> void:
	var aim_dir: Vector2''')
s = rep(s, '''	if _has_weapon_sprite():
		_play_melee_swing(current_weapon.swing_arc_degrees, current_weapon.swing_duration)
		var slash: Node2D''', '''	if _has_weapon_sprite():
		if not visual_done:
			_play_melee_swing(current_weapon.swing_arc_degrees, current_weapon.swing_duration)
		var slash: Node2D''')
s = rep(s, '''	if not infinite_ammo:
		fire_cooldown_timer = current_weapon.get_fire_interval()
	else:
		fire_cooldown_timer = 0.08
	
	weapon_fired.emit(current_weapon)
''', '')

# retroceso del arma de fuego por arma
a = s.index("## Golpe de retroceso breve del arma de fuego al disparar.")
b = s.index("## Tajo del arma en mano")
s = s[:a] + '''## Golpe de retroceso del arma de fuego al disparar: se echa hacia atrás y el cañón sube (ver `kick` en weapon_motion.gd).
func _play_weapon_kick() -> void:
	var kick: Dictionary = WeaponMotion.profile_for(current_weapon).get("kick", {}) as Dictionary
	var power: float = 1.0
	if current_weapon != null:
		power = clampf(current_weapon.recoil_force / 60.0, 0.6, 2.0)
	var back: float = float(kick.get("back", 3.0 * power))
	var climb: float = float(kick.get("climb_deg", 4.0 * power))
	var time: float = float(kick.get("time", 0.12))
	last_motion = {"body": [], "length": time, "recoil": float(kick.get("body", 1.0))}
	if not _has_weapon_sprite():
		return
	_cancel_hand_tween()
	_weapon_sprite.position = _sprite_rest_position + Vector2(-back, 0.0) * WEAPON_SCALE
	_weapon_sprite.rotation = _sprite_rest_rotation - deg_to_rad(climb)
	_hand_tween = create_tween()
	_hand_tween.set_parallel(true)
	_hand_tween.tween_property(_weapon_sprite, "position", _sprite_rest_position, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hand_tween.tween_property(_weapon_sprite, "rotation", _sprite_rest_rotation, time * 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


''' + s[b:]

# tajo con fotogramas
s = rep(s, '''	_cancel_hand_tween()
	var half_arc: float = deg_to_rad(arc_degrees * 0.5)''', '''	_cancel_hand_tween()
	var keys: Array = _current_swing.get("keys", []) as Array
	if keys.size() >= 2:
		_play_keyed_swing(keys, swing_time_total(duration))
		return
	var half_arc: float = deg_to_rad(arc_degrees * 0.5)''')
s = rep(s, "## Deja una copia translúcida del arma en su pose actual", '''## Duración total de la animación del tajo actual (swing_duration * length del perfil).
func swing_time_total(duration: float) -> float:
	return maxf(duration, 0.05) * float(_current_swing.get("length", 1.0))


## Tajo animado con los fotogramas del perfil del arma: posición y rotación relativas al reposo.
func _play_keyed_swing(keys: Array, total: float) -> void:
	var first: Dictionary = keys[0] as Dictionary
	_weapon_sprite.position = _sprite_rest_position + (first.get("pos", Vector2.ZERO) as Vector2)
	_weapon_sprite.rotation = _sprite_rest_rotation + deg_to_rad(float(first.get("rot", 0.0)))
	_hand_tween = create_tween()
	var prev_t: float = float(first.get("t", 0.0))
	for i in range(1, keys.size()):
		var key: Dictionary = keys[i] as Dictionary
		var t: float = float(key.get("t", 1.0))
		var seg: float = maxf((t - prev_t) * total, 0.001)
		prev_t = t
		var trans: Tween.TransitionType = Tween.TRANS_LINEAR
		var ease_mode: Tween.EaseType = Tween.EASE_IN_OUT
		match str(key.get("ease", "")):
			"out":
				trans = Tween.TRANS_QUAD
				ease_mode = Tween.EASE_OUT
			"in":
				trans = Tween.TRANS_QUAD
				ease_mode = Tween.EASE_IN
			"inout":
				trans = Tween.TRANS_SINE
				ease_mode = Tween.EASE_IN_OUT
		var target_pos: Vector2 = _sprite_rest_position + (key.get("pos", Vector2.ZERO) as Vector2)
		var target_rot: float = _sprite_rest_rotation + deg_to_rad(float(key.get("rot", 0.0)))
		_hand_tween.tween_property(_weapon_sprite, "position", target_pos, seg).set_trans(trans).set_ease(ease_mode)
		_hand_tween.parallel().tween_property(_weapon_sprite, "rotation", target_rot, seg).set_trans(trans).set_ease(ease_mode)

	# Estela durante la primera mitad de la animación (la parte del golpe)
	var trail: Tween = create_tween()
	var steps: int = 6
	for i in range(steps):
		trail.tween_callback(_spawn_swing_ghost)
		trail.tween_interval(total * 0.5 / float(steps))


## Deja una copia translúcida del arma en su pose actual''')
save(p, s)

# ------------------------------------------------------------------ ItemIcons
p = "ui/components/item_icons.gd"
s = load(p)
assert "WeaponMotion" not in s
s = rep(s, 'const WeaponArt = preload("res://core/art/weapon_art.gd")\n',
        'const WeaponArt = preload("res://core/art/weapon_art.gd")\nconst WeaponMotion = preload("res://core/art/weapon_motion.gd")\n')
s = rep(s, '''	if not art_data.is_empty():
		return art_data
	var kind: String = _weapon_kind(weapon)''', '''	if not art_data.is_empty():
		# El perfil de movimiento puede cambiar el agarre (p. ej. martillo a dos manos)
		var override: Dictionary = (WeaponMotion.PROFILES.get(art_id, {}) as Dictionary).get("pose", {}) as Dictionary
		if not override.is_empty():
			art_data = art_data.merged(override, true)
		return art_data
	var kind: String = _weapon_kind(weapon)''')
save(p, s)

# ------------------------------------------------------------------ CharacterRig
p = "entities/player/character_rig.gd"
s = load(p)
assert "WeaponMotion" not in s
s = rep(s, 'const HeroArt = preload("res://core/art/hero_art.gd")\n',
        'const HeroArt = preload("res://core/art/hero_art.gd")\nconst WeaponMotion = preload("res://core/art/weapon_motion.gd")\n')
s = rep(s, "var _recoil: float = 0.0\n", '''var _recoil: float = 0.0
var _motion_body: Array = []
var _motion_len: float = 0.0
var _motion_t: float = 999.0
''')
s = rep(s, "	_recoil = maxf(0.0, _recoil - delta * 7.0)\n",
        "	_recoil = maxf(0.0, _recoil - delta * 7.0)\n	_motion_t += delta\n")
s = rep(s, '''func _on_weapon_fired(_weapon: WeaponData) -> void:
	_recoil = 1.0
''', '''func _on_weapon_fired(_weapon: WeaponData) -> void:
	var motion: Dictionary = {}
	if _player != null and _player.weapon_manager != null:
		motion = _player.weapon_manager.last_motion
	_motion_body = motion.get("body", []) as Array
	_motion_len = float(motion.get("length", 0.0))
	_motion_t = 0.0
	# Armas de fuego: retroceso del torso según el arma; melee: inclinación y avance del perfil
	_recoil = float(motion.get("recoil", 1.0)) if _motion_body.is_empty() else 0.0
''')
s = rep(s, '''		# Retroceso: el torso se echa hacia atrás y vuelve
		_body.rotation -= _recoil * 0.05
		_body.position.x = -_recoil * 1.2
''', '''		# Retroceso del arma de fuego y movimiento del cuerpo al blandir un arma melee
		var lean: float = 0.0
		var push: float = 0.0
		if not _motion_body.is_empty() and _motion_len > 0.0 and _motion_t < _motion_len:
			var u: float = _motion_t / _motion_len
			lean = deg_to_rad(WeaponMotion.sample(_motion_body, u, "lean"))
			push = WeaponMotion.sample(_motion_body, u, "x")
		_body.rotation += lean - _recoil * 0.05
		_body.position.x = push - _recoil * 1.2
		# El torso se inclina desde la cadera, no desde los pies
		var hip: Vector2 = Vector2(0.0, _leg_base_y_r)
		_body.position += hip - hip.rotated(_body.rotation)
''')
save(p, s)
print("ok")
