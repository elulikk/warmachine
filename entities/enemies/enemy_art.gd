extends Node2D
## Arte de enemigos y aliados con aspecto humano o mecánico. Sin class_name: se usa por `attach()`.
##
## Cubre el rectángulo de color o el sprite que traía la escena (se oculta con alfa 0, pero sigue
## existiendo: los scripts de combate lo usan para el parpadeo de impacto y los tintes de estado) y
## copia ese color como tinte sobre el arte nuevo, así el flash blanco, el hielo y el fuego se ven igual.
##
## Tipos:
##   "runner", "brute", "sentinel": ilustración (`MOBS` de `armor_art.gd`) partida en torso y dos piernas
##       (cortes en `MOB_SPLIT`) con ciclo de marcha procedural y una embestida al atacar.
##   "dummy": una sola ilustración con balanceo.
##   "skeleton", "zombie", "ghost": esqueleto modular (`CharacterRig`) con el cuerpo base de ese nombre.
##   "turret" (base + cañón de francotirador que apunta al jugador), "training_turret" (ballesta de
##       práctica que mira al jugador) y "drone" (núcleo flotante).

const RigScript = preload("res://entities/player/character_rig.gd")
const ArtScript = preload("res://core/art/art.gd")
const ArmorArt = preload("res://core/art/armor_art.gd")

const PROPS_DIR: String = "res://assets/art/props/"

## Cuánto se amplifica como máximo el tinte (el flash blanco parte de un gris oscuro).
const MAX_TINT: float = 2.4
## Las ilustraciones de `MOBS` están exportadas al triple de su tamaño en juego.
const MOB_TEX_SCALE: float = 1.0 / 3.0

var kind: String = ""

var _tint_rect: ColorRect = null
var _tint_item: CanvasItem = null
var _base_color: Color = Color.WHITE
var _art: Node2D = null
var _gun: Sprite2D = null
var _gun_pivot_px: float = 0.0
var _muzzle: Node2D = null
var _target: Node2D = null
var _host: CharacterBody2D = null
var _time: float = 0.0
var _alpha: float = 1.0
var _sprite_mob: bool = false

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


## Crea y devuelve el nodo de arte dentro del `Visuals` del anfitrión (o del anfitrión mismo).
static func attach(host: Node2D, art_kind: String) -> Node2D:
	var parent: Node2D = host.get_node_or_null("Visuals") as Node2D
	if parent == null:
		parent = host
	var existing: Node = parent.get_node_or_null("EnemyArt")
	if existing != null:
		return existing as Node2D
	var node: Node2D = (load("res://entities/enemies/enemy_art.gd") as GDScript).new() as Node2D
	node.name = "EnemyArt"
	node.set("kind", art_kind)
	parent.add_child(node)
	return node


func _ready() -> void:
	_art = Node2D.new()
	_art.name = "Art"
	add_child(_art)
	_host = _find_body()
	_find_tint_source()
	_hide_originals()
	match kind:
		"runner":
			_build_mob("runner")
		"brute":
			_build_mob("brute")
		"sentinel":
			_build_mob("sentinel")
		"dummy":
			_build_mob("practice_dummy")
		"skeleton":
			_build_person({"skin": "skeleton"}, 0.8)
		"zombie":
			_build_person({"skin": "zombie"}, 0.84)
		"ghost":
			_alpha = 0.78
			_build_person({"skin": "ghost"}, 0.86)
		"turret":
			_build_sniper_turret()
		"training_turret":
			_build_training_turret()
		"drone":
			_build_drone()


func _find_body() -> CharacterBody2D:
	var node: Node = get_parent()
	while node != null:
		if node is CharacterBody2D:
			return node as CharacterBody2D
		node = node.get_parent()
	return null


func _find_tint_source() -> void:
	var parent: Node = get_parent()
	var host: Node = parent.get_parent() if parent != null and parent.name == &"Visuals" else parent
	for path: String in ["ColorRect", "VisualRect"]:
		var candidate: ColorRect = parent.get_node_or_null(path) as ColorRect
		if candidate == null and host != null:
			candidate = host.get_node_or_null(path) as ColorRect
		if candidate != null:
			_tint_rect = candidate
			_base_color = candidate.color
			return
	var anim: CanvasItem = parent.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if anim != null:
		_tint_item = anim


## El arte reemplaza todo lo que dibujaba la escena (el rectángulo de tinte queda invisible pero vivo).
func _hide_originals() -> void:
	var parent: Node = get_parent()
	for child: Node in parent.get_children():
		if child == self:
			continue
		if child is ColorRect:
			var rect: ColorRect = child as ColorRect
			# `modulate.a = 0` oculta el dibujo sin tocar `color`, que el combate sigue leyendo
			rect.modulate.a = 0.0
		elif child is AnimatedSprite2D or child is Sprite2D:
			(child as CanvasItem).visible = false # Solo alfa no alcanza: el flash de impacto y el tinte de estado reescriben `modulate`
	# Dummy: el rectángulo cuelga del anfitrión
	var host: Node = parent.get_parent() if parent.name == &"Visuals" else parent
	if host != null and host != parent:
		var loose: ColorRect = host.get_node_or_null("VisualRect") as ColorRect
		if loose != null:
			loose.modulate.a = 0.0


## Ilustración única anclada a los pies (origen del nodo en el suelo).
func _build_mob(mob_name: String) -> void:
	var data: Dictionary = ArmorArt.MOBS.get(mob_name, {}) as Dictionary
	if data.is_empty():
		return
	var texture: Texture2D = ArtScript.tex(str(data.get("file", "")))
	if texture == null:
		return
	var size: Vector2 = data.get("size", Vector2(40.0, 56.0)) as Vector2
	var foot: Vector2 = data.get("foot", Vector2(size.x * 0.5, size.y)) as Vector2
	_split = MOB_SPLIT.get(kind, {}) as Dictionary
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


func _build_person(loadout: Dictionary, scale_factor: float) -> void:
	var rig: Node2D = RigScript.new() as Node2D
	rig.name = "Rig"
	var current: Dictionary = rig.get("loadout") as Dictionary
	for key: Variant in loadout.keys():
		current[key] = loadout[key]
	rig.scale = Vector2(scale_factor, scale_factor)
	_art.add_child(rig)
	_rig = rig


func _build_sniper_turret() -> void:
	var base_data: Dictionary = ArmorArt.MOBS.get("sniper_base", {}) as Dictionary
	var base_tex: Texture2D = ArtScript.tex(str(base_data.get("file", "")))
	var base_size: Vector2 = base_data.get("size", Vector2(30.0, 40.0)) as Vector2
	if base_tex != null:
		var base: Sprite2D = Sprite2D.new()
		base.name = "Base"
		base.texture = base_tex
		base.centered = false
		base.scale = Vector2(MOB_TEX_SCALE, MOB_TEX_SCALE)
		var foot: Vector2 = base_data.get("foot", Vector2(base_size.x * 0.5, base_size.y)) as Vector2
		base.position = Vector2(-foot.x, -base_size.y)
		base.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_art.add_child(base)
	var gun_data: Dictionary = ArmorArt.MOBS.get("sniper_gun", {}) as Dictionary
	var gun_tex: Texture2D = ArtScript.tex(str(gun_data.get("file", "")))
	if gun_tex != null:
		_gun = Sprite2D.new()
		_gun.name = "Gun"
		_gun.texture = gun_tex
		_gun.centered = false
		# La textura ya viene con la boca a la derecha; el eje de giro queda cerca de la culata
		_gun_pivot_px = float(gun_tex.get_width()) * 0.28
		_gun.offset = Vector2(-_gun_pivot_px, -float(gun_tex.get_height()) * 0.5)
		_gun.scale = Vector2(MOB_TEX_SCALE, MOB_TEX_SCALE)
		_gun.position = Vector2(0.0, -base_size.y * 0.72)
		_gun.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_art.add_child(_gun)
	_muzzle = get_parent().get_node_or_null("Muzzle") as Node2D


func _build_training_turret() -> void:
	# La ballesta de la ilustración apunta a la izquierda
	_build_mob("training_turret")
	_muzzle = get_parent().get_node_or_null("Muzzle") as Node2D


func _build_drone() -> void:
	var core_tex: Texture2D = ArtScript.tex(PROPS_DIR + "drone_core.png")
	if core_tex == null:
		return
	var core: Sprite2D = Sprite2D.new()
	core.texture = core_tex
	core.scale = Vector2(0.5, 0.5)
	core.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_art.add_child(core)
	_art.position = Vector2.ZERO


func _process(delta: float) -> void:
	_time += delta
	_attack_t += delta
	_detect_attack()
	_apply_tint()
	match kind:
		"turret":
			_aim_gun()
		"training_turret":
			_face_player()
		"drone":
			_art.position.y = sin(_time * 3.2) * 2.0
			_art.rotation = sin(_time * 1.7) * 0.12
		"runner", "brute", "sentinel", "dummy":
			_sway_mob(delta)


## El enemigo ataca cuando su tiempo de espera por contacto salta de golpe (golpe efectivo sobre el jugador).
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
	_upper.scale = Vector2(MOB_TEX_SCALE, MOB_TEX_SCALE)

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
		_upper.scale = Vector2(1.0 + absf(tilt) * 0.12, 1.0 - absf(tilt) * 0.06) * MOB_TEX_SCALE
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


## Copia el color de parpadeo/estado del rectángulo original (o el modulate del sprite) sobre el arte.
func _apply_tint() -> void:
	if _art == null:
		return
	if _tint_rect != null:
		var base_r: float = maxf(_base_color.r, 0.12)
		var base_g: float = maxf(_base_color.g, 0.12)
		var base_b: float = maxf(_base_color.b, 0.12)
		var c: Color = _tint_rect.color
		_art.modulate = Color(
			clampf(c.r / base_r, 0.0, MAX_TINT),
			clampf(c.g / base_g, 0.0, MAX_TINT),
			clampf(c.b / base_b, 0.0, MAX_TINT), _alpha)
	elif _tint_item != null:
		var m: Color = _tint_item.modulate
		_art.modulate = Color(m.r, m.g, m.b, _alpha)
	elif _alpha < 1.0:
		_art.modulate = Color(1.0, 1.0, 1.0, _alpha)


func _player_target() -> Node2D:
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group(&"player") as Node2D
	return _target


func _aim_gun() -> void:
	if _gun == null:
		return
	var target: Node2D = _player_target()
	if target == null:
		return
	var origin: Vector2 = _gun.global_position
	var aim: Vector2 = (target.global_position + Vector2(0.0, -32.0)) - origin
	if aim.length_squared() < 1.0:
		return
	# El cañón siempre apunta en su eje X local; al mirar a la izquierda se invierte en Y para no quedar de cabeza
	_gun.global_rotation = aim.angle()
	var flip: bool = aim.x < 0.0
	_gun.scale = Vector2(MOB_TEX_SCALE, -MOB_TEX_SCALE if flip else MOB_TEX_SCALE)
	if _muzzle != null and _gun.texture != null:
		var tip_length: float = (float(_gun.texture.get_width()) - _gun_pivot_px) * MOB_TEX_SCALE
		_muzzle.global_position = origin + aim.normalized() * tip_length


## La ballesta de práctica da la cara al jugador (su ilustración apunta a la izquierda).
func _face_player() -> void:
	var target: Node2D = _player_target()
	if target == null or _art == null:
		return
	var side: float = signf(target.global_position.x - get_parent().global_position.x)
	if side == 0.0:
		return
	_art.scale.x = 1.0 if side < 0.0 else -1.0
	if _muzzle != null:
		_muzzle.position = Vector2(24.0 * side, -26.0)
