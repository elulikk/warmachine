"""Animación de caminar y atacar de los enemigos (ilustraciones partidas en cintura y piernas + esqueleto modular)."""
import os
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))


def load(p):
    return open(os.path.join(ROOT, p), encoding="utf-8").read()


def save(p, s):
    open(os.path.join(ROOT, p), "w", encoding="utf-8").write(s)


def rep(s, old, new):
    assert s.count(old) == 1, old
    return s.replace(old, new, 1)


# ------------------------------------------------------------------ enemy_art.gd
p = "entities/enemies/enemy_art.gd"
s = load(p)
assert "_attack_t" not in s

s = rep(s, '''##   "runner", "brute", "sentinel", "dummy": una sola ilustración (`MOBS` de `armor_art.gd`) con balanceo
##       procedural al moverse.''', '''##   "runner", "brute", "sentinel": ilustración (`MOBS` de `armor_art.gd`) partida en torso y dos piernas
##       (cortes en `MOB_SPLIT`) con ciclo de marcha procedural y una embestida al atacar.
##   "dummy": una sola ilustración con balanceo.''')

s = rep(s, '''var _sprite_mob: bool = false
''', '''var _sprite_mob: bool = false

## Cortes de las ilustraciones: `waist` = altura de la cintura (fracción del alto), `overlap` = px de textura que
## las piernas suben bajo el torso, `scale` = tamaño en juego, `attack` = duración de la embestida (s),
## `lunge` = avance en px y `lean` = inclinación hacia adelante en radianes.
const MOB_SPLIT: Dictionary = {
	"runner": {"waist": 0.60, "overlap": 9.0, "scale": 1.0, "attack": 0.30, "lunge": 7.0, "lean": 0.34, "step": 3.4},
	"brute": {"waist": 0.63, "overlap": 9.0, "scale": 1.25, "attack": 0.58, "lunge": 8.0, "lean": 0.28, "step": 2.6},
	"sentinel": {"waist": 0.60, "overlap": 9.0, "scale": 1.0, "attack": 0.42, "lunge": 9.0, "lean": 0.18, "step": 2.8},
}

var _upper: Sprite2D = null
var _leg_a: Sprite2D = null
var _leg_b: Sprite2D = null
var _split: Dictionary = {}
var _walk_phase: float = 0.0
var _walk_amount: float = 0.0
var _attack_t: float = 99.0
var _last_cooldown: float = 0.0
var _rig: Node2D = null
''')

# construcción: partir la ilustración
s = rep(s, '''	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Body"
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2(MOB_TEX_SCALE, MOB_TEX_SCALE)
	sprite.position = Vector2(-foot.x, -size.y)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_art.add_child(sprite)
	_sprite_mob = true
''', '''	_split = MOB_SPLIT.get(kind, {}) as Dictionary
	if not _split.is_empty():
		_art.scale = Vector2(float(_split.get("scale", 1.0)), float(_split.get("scale", 1.0)))
		_build_split_mob(texture, size, foot)
		_sprite_mob = true
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Body"
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2(MOB_TEX_SCALE, MOB_TEX_SCALE)
	sprite.position = Vector2(-foot.x, -size.y)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_art.add_child(sprite)
	_sprite_mob = true


## Parte la ilustración en torso (con cabeza y brazos) y dos piernas que pivotan en la cadera.
func _build_split_mob(texture: Texture2D, size: Vector2, foot: Vector2) -> void:
	var tex_w: float = float(texture.get_width())
	var tex_h: float = float(texture.get_height())
	var waist: float = roundf(tex_h * float(_split.get("waist", 0.6)))
	var overlap: float = float(_split.get("overlap", 8.0))
	var split_x: float = clampf(roundf(foot.x / MOB_TEX_SCALE), tex_w * 0.25, tex_w * 0.75)
	var base: Vector2 = Vector2(-foot.x, -size.y)
	var s: float = MOB_TEX_SCALE

	var legs: Array[Rect2] = [
		Rect2(0.0, waist - overlap, split_x, tex_h - waist + overlap),
		Rect2(split_x, waist - overlap, tex_w - split_x, tex_h - waist + overlap),
	]
	var leg_sprites: Array[Sprite2D] = []
	for i in range(2):
		var rect: Rect2 = legs[i]
		var leg: Sprite2D = _make_region_sprite(texture, rect, "Leg%d" % i)
		# Pivota en la cadera: arriba al centro de la pierna, a la altura de la cintura
		leg.offset = Vector2(-rect.size.x * 0.5, -overlap)
		leg.position = base + Vector2(rect.position.x + rect.size.x * 0.5, waist) * s
		_art.add_child(leg)
		leg_sprites.append(leg)
	_leg_a = leg_sprites[0]
	_leg_b = leg_sprites[1]

	_upper = _make_region_sprite(texture, Rect2(0.0, 0.0, tex_w, waist), "Torso")
	# Pivota en la cintura para poder inclinarse hacia adelante
	_upper.offset = Vector2(-tex_w * 0.5, -waist)
	_upper.position = base + Vector2(tex_w * 0.5, waist) * s
	_art.add_child(_upper)


func _make_region_sprite(texture: Texture2D, rect: Rect2, sprite_name: String) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = rect
	sprite.scale = Vector2(MOB_TEX_SCALE, MOB_TEX_SCALE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return sprite
''')

# esqueleto modular: guardar la referencia para atacar
s = rep(s, '''	rig.scale = Vector2(scale_factor, scale_factor)
	_art.add_child(rig)
''', '''	rig.scale = Vector2(scale_factor, scale_factor)
	_art.add_child(rig)
	_rig = rig
''')

# proceso: detectar el ataque
s = rep(s, '''func _process(delta: float) -> void:
	_time += delta
	_apply_tint()
''', '''func _process(delta: float) -> void:
	_time += delta
	_attack_t += delta
	_detect_attack()
	_apply_tint()
''')
s = rep(s, '''		"runner", "brute", "sentinel", "dummy":
			_sway_mob()
''', '''		"runner", "brute", "sentinel", "dummy":
			_sway_mob(delta)
''')

# _sway_mob completo
a = s.index("## Balanceo y rebote de las ilustraciones de una pieza")
b = s.index("## Copia el color de parpadeo/estado")
s = s[:a] + '''## El enemigo ataca cuando su tiempo de espera por contacto salta de golpe (golpe efectivo sobre el jugador).
func _detect_attack() -> void:
	if _host == null:
		return
	var cooldown_value: Variant = _host.get("contact_cooldown")
	if cooldown_value == null:
		return
	var cooldown: float = float(cooldown_value)
	if cooldown > _last_cooldown + 0.3:
		_attack_t = 0.0
		if _rig != null and _rig.has_method("play_attack"):
			_rig.call("play_attack")
	_last_cooldown = cooldown


## Ciclo de marcha y embestida de las ilustraciones partidas; balanceo simple para el resto (muñeco de práctica).
func _sway_mob(delta: float) -> void:
	if not _sprite_mob or _art == null:
		return
	var speed: float = 0.0
	var on_floor: bool = true
	if _host != null:
		speed = absf(_host.velocity.x)
		on_floor = _host.is_on_floor()
	var moving: float = clampf(speed / 90.0, 0.0, 1.0)
	var breathe: float = sin(_time * 2.2) * 0.012
	if kind == "dummy":
		_art.rotation = 0.0
		_art.scale = Vector2.ONE
		return
	if _upper == null:
		var stride: float = _time * (6.0 + moving * 6.0)
		_art.position.y = -absf(sin(stride)) * 2.2 * moving if on_floor else -1.5
		_art.rotation = sin(stride) * 0.05 * moving
		_art.scale = Vector2(1.0 - breathe, 1.0 + breathe)
		return

	# Marcha: las piernas se alternan y el torso rebota y se balancea con cada paso
	_walk_amount = lerpf(_walk_amount, moving if on_floor else 0.0, minf(1.0, delta * 10.0))
	if on_floor and moving > 0.05:
		_walk_phase += delta * (7.0 + moving * 5.0)
	var step: float = float(_split.get("step", 3.0))
	var sa: float = sin(_walk_phase)
	var sb: float = -sa
	var amount: float = _walk_amount
	var tuck: float = 0.0 if on_floor else 2.5
	_leg_a.position.y = _leg_base_y(_leg_a) - maxf(0.0, sa) * step * amount - tuck
	_leg_b.position.y = _leg_base_y(_leg_b) - maxf(0.0, sb) * step * amount - tuck
	_leg_a.rotation = sa * 0.16 * amount
	_leg_b.rotation = sb * 0.16 * amount
	_upper.position.y = _upper_base_y() - absf(sa) * step * 0.5 * amount + breathe * 30.0 * (1.0 - amount)
	_upper.rotation = sa * 0.035 * amount + 0.06 * amount
	_upper.scale = Vector2.ONE

	# Embestida: se echa hacia atrás, se lanza hacia adelante y vuelve
	var duration: float = maxf(float(_split.get("attack", 0.3)), 0.05)
	if _attack_t < duration:
		var u: float = _attack_t / duration
		var lunge: float = float(_split.get("lunge", 6.0))
		var lean: float = float(_split.get("lean", 0.25))
		var offset_x: float = 0.0
		var tilt: float = 0.0
		if u < 0.3:
			var w: float = u / 0.3
			offset_x = -lunge * 0.35 * w
			tilt = -lean * 0.4 * w
		elif u < 0.55:
			var k: float = (u - 0.3) / 0.25
			offset_x = lerpf(-lunge * 0.35, lunge, k)
			tilt = lerpf(-lean * 0.4, lean, k)
		else:
			var r: float = (u - 0.55) / 0.45
			offset_x = lerpf(lunge, 0.0, r)
			tilt = lerpf(lean, 0.0, r)
		_upper.position.x = _upper_base_x() + offset_x
		_upper.rotation += tilt
		_upper.scale = Vector2(1.0 + absf(tilt) * 0.12, 1.0 - absf(tilt) * 0.06)
		_leg_a.position.x = _leg_base_x(_leg_a) + offset_x * 0.35
		_leg_b.position.x = _leg_base_x(_leg_b) + offset_x * 0.35
	else:
		_upper.position.x = _upper_base_x()
		_leg_a.position.x = _leg_base_x(_leg_a)
		_leg_b.position.x = _leg_base_x(_leg_b)


## Posición de reposo de cada pieza (se guarda al construirla en un metadato).
func _leg_base_y(leg: Sprite2D) -> float:
	if not leg.has_meta(&"base"):
		leg.set_meta(&"base", leg.position)
	return (leg.get_meta(&"base") as Vector2).y


func _leg_base_x(leg: Sprite2D) -> float:
	if not leg.has_meta(&"base"):
		leg.set_meta(&"base", leg.position)
	return (leg.get_meta(&"base") as Vector2).x


func _upper_base_y() -> float:
	if not _upper.has_meta(&"base"):
		_upper.set_meta(&"base", _upper.position)
	return (_upper.get_meta(&"base") as Vector2).y


func _upper_base_x() -> float:
	if not _upper.has_meta(&"base"):
		_upper.set_meta(&"base", _upper.position)
	return (_upper.get_meta(&"base") as Vector2).x


''' + s[b:]
save(p, s)

# ------------------------------------------------------------------ character_rig.gd: golpe de enemigo
p = "entities/player/character_rig.gd"
s = load(p)
assert "play_attack" not in s
s = rep(s, "var _recoil: float = 0.0\n", "var _recoil: float = 0.0\nvar _swipe_t: float = 99.0  # tiempo desde el último golpe de un enemigo (play_attack)\n")
s = rep(s, "	_motion_t += delta\n", "	_motion_t += delta\n	_swipe_t += delta\n")
s = rep(s, "## Engancha el disparo del arma", '''## Golpe de los enemigos con el esqueleto modular: estiran los brazos hacia adelante y el cuerpo se lanza.
func play_attack() -> void:
	_swipe_t = 0.0


## Engancha el disparo del arma''')
s = rep(s, '''	var swing: float = sin(_phase) * deg_to_rad(34.0) * minf(run_amount, 1.0)''', '''	var swipe: float = sin(clampf(_swipe_t / 0.34, 0.0, 1.0) * PI)
	var swing: float = sin(_phase) * deg_to_rad(34.0) * minf(run_amount, 1.0)''')
s = rep(s, '''	_body.rotation = sin(_phase) * 0.03 * minf(run_amount, 1.0) if on_floor else 0.0
''', '''	_body.rotation = sin(_phase) * 0.03 * minf(run_amount, 1.0) if on_floor else 0.0
	if swipe > 0.0:
		_body.rotation += 0.22 * swipe
		_body.position.x = 3.0 * swipe
''')
s = rep(s, '''		_arm_back.z_index = 0 if preview_mode else -2
	else:
		if not two_handed:''', '''		_arm_back.z_index = 0 if preview_mode else -2
		if _swipe_t < 0.34:
			# Zarpazo: ambos brazos se estiran hacia adelante y suben
			var reach: float = sin(clampf(_swipe_t / 0.34, 0.0, 1.0) * PI)
			hand_front = hand_front.lerp(_shoulder_front + Vector2(ARM_REACH * 0.95, -5.0), reach)
			hand_back = hand_back.lerp(_shoulder_back + Vector2(ARM_REACH * 0.9, 1.0), reach)
	else:
		if not two_handed:''')
save(p, s)
print("ok")
