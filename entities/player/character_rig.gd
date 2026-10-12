extends Node2D
## Esqueleto modular de un humanoide (jugador, aliados y enemigos de forma humana).
## Sin class_name a propósito: se referencia por ruta desde las escenas.
##
## Cada parte del cuerpo es un `Sprite2D` colgado de un "hueso" (`Node2D`): torso, dos piernas que
## oscilan, botas, cabeza, casco, brazos con guante, mochila o alas y la granada al cinturón.
## El origen del nodo está en los pies.
##
## El aspecto se compone con el `loadout`:
##   skin   cuerpo base (`hero`, `no_armor`, `zombie`, `skeleton`, `ghost`): cabeza, torso, brazos, piernas y manos.
##          `hero` es de perfil y articulado (hombro/codo, cadera/rodilla/tobillo; datos en `hero_art.gd`);
##          los demás son de una pieza por miembro (`armor_art.gd`).
##   back / belt   mochila, alas y granada (piezas de `rig_art.gd`).
##
## - Con `gear_driven = true` (el jugador) el equipo puesto del EquipmentManager decide espalda y granada;
##   lo demás sale del `loadout` base. Las armaduras no se dibujan sobre el cuerpo.
## - Los brazos se orientan hacia la mano del arma en mano (cinemática inversa simple): el brazo de
##   adelante agarra la empuñadura y, si el arma es de dos manos, el de atrás apoya en el guardamanos.
## - La animación es procedural (andar, respirar, saltar, caer), así que no hay hojas de cuadros.
##
## Las texturas están en `assets/art/rig/` al triple del tamaño de juego (`TEX_SCALE`); sus medidas y
## anclas están en `core/art/armor_art.gd` (generado desde las hojas de arte de `assets/sprites/sets  mobs`).

const RigArt = preload("res://core/art/rig_art.gd")
const ArmorArt = preload("res://core/art/armor_art.gd")
const HeroArt = preload("res://core/art/hero_art.gd")
const WeaponMotion = preload("res://core/art/weapon_motion.gd")
const ArtScript = preload("res://core/art/art.gd")
const ItemIconsScript = preload("res://ui/components/item_icons.gd")

## Los PNG se exportan al triple de su tamaño en juego.
const TEX_SCALE: float = 1.0 / 3.0

## Mochilas, alas y granadas (`rig_art.gd`) están exportadas al doble de su tamaño.
const PROP_TEX_SCALE: float = 0.5

## Distancia del hombro al centro de la mano con el brazo en reposo (px de juego).
const ARM_REACH: float = 29.0
const BELT_PARTS: Dictionary = {
	"frag_grenade": "belt_grenade_frag", "ice_grenade": "belt_grenade_cryo",
	"acid_grenade": "belt_grenade_acid", "gas_bomb": "belt_gas_bomb"
}

## Aspecto base. Se puede reemplazar con `set_loadout()`.
var loadout: Dictionary = {
	"skin": "hero",
	"back": "",
	"belt": ""
}

## true: el equipo del EquipmentManager del anfitrión sobreescribe el loadout (solo el jugador).
@export var gear_driven: bool = false
## Velocidad horizontal a la que el ciclo de carrera llega a su amplitud máxima.
@export var run_reference_speed: float = 240.0
## true: solo respira y muestra el equipo (muñeco de la ventana de equipamiento); ignora movimiento y arma.
@export var preview_mode: bool = false

var _host: CharacterBody2D = null
var _player: Player = null

var _back: Node2D
var _back_sprite: Sprite2D
var _wing_l: Sprite2D
var _wing_r: Sprite2D
var _leg_l: Node2D
var _leg_r: Node2D
var _leg_l_sprite: Sprite2D
var _leg_r_sprite: Sprite2D
var _body: Node2D
var _torso: Sprite2D
var _belt: Sprite2D
var _head: Sprite2D
var _arm_back: Node2D
var _arm_back_sprite: Sprite2D
var _glove_back: Sprite2D
var _arm_front: Node2D
var _arm_front_sprite: Sprite2D
var _glove_front: Sprite2D

var _time: float = 0.0
var _phase: float = 0.0
var _was_on_floor: bool = true
## Cuánto están abiertos los brazos por estar en el aire (0 = pose normal, 1 = abiertos hacia afuera y arriba).
var _jump_open: float = 0.0
var _land_squash: float = 0.0
var _has_legs: bool = true
var _hover: bool = false
var _leg_base_y_l: float = -30.0
var _leg_base_y_r: float = -30.0
var _shoulder_front: Vector2 = Vector2.ZERO
var _shoulder_back: Vector2 = Vector2.ZERO
var _rest_front: Vector2 = Vector2(4.0, ARM_REACH)
var _rest_back: Vector2 = Vector2(-4.0, ARM_REACH)
var _applied: Dictionary = {}

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
var _hand_bone: Array[Node2D] = []
var _neck_bone: Node2D
var _recoil: float = 0.0
var _swipe_t: float = 99.0  # tiempo desde el último golpe de un enemigo (play_attack)
var _motion_body: Array = []
var _motion_len: float = 0.0
var _motion_t: float = 999.0
var _fire_connected: bool = false
var _off_fire_connected: bool = false
var _aim_angle: float = 0.0
var _aim_angle_off: float = 0.0
var _reach_back: float = 0.0
var _arm_len_up: Array[float] = [0.0, 0.0]
var _arm_len_low: Array[float] = [0.0, 0.0]
var _arm_dir_up: Array[float] = [0.0, 0.0]
var _arm_dir_low: Array[float] = [0.0, 0.0]


func _ready() -> void:
	process_priority = 10 # Después de WeaponPivot: los brazos siguen al arma ya orientada
	_host = _find_body()
	if _host != null and _player == null:
		_player = _host as Player
	if _player != null:
		gear_driven = true
	_build_nodes()
	_apply_loadout()


## Vincula el esqueleto a un jugador para leer su equipo (vista previa en la interfaz).
func bind_player(player: Player) -> void:
	_player = player
	gear_driven = player != null
	_applied.clear()
	if _body != null:
		_apply_loadout()


## Reemplaza el aspecto con las claves dadas (skin, back, belt).
func set_loadout(changes: Dictionary) -> void:
	for key: Variant in changes.keys():
		loadout[key] = changes[key]
	_applied.clear()
	if is_inside_tree() and _body != null:
		_apply_loadout()


func _find_body() -> CharacterBody2D:
	var node: Node = get_parent()
	while node != null:
		if node is CharacterBody2D:
			return node as CharacterBody2D
		node = node.get_parent()
	return null


# ==============================================================================
# Construcción
# ==============================================================================

func _make_sprite(parent: Node, sprite_name: String) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = sprite_name
	sprite.centered = false
	sprite.scale = Vector2(TEX_SCALE, TEX_SCALE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.visible = false
	parent.add_child(sprite)
	return sprite


func _make_bone(parent: Node, bone_name: String, z: int) -> Node2D:
	var bone: Node2D = Node2D.new()
	bone.name = bone_name
	# En la interfaz (vista previa) el orden de dibujo lo da el árbol: un z negativo quedaría detrás de la ventana
	bone.z_index = 0 if preview_mode else z
	parent.add_child(bone)
	return bone


func _build_nodes() -> void:
	_back = _make_bone(self, "Back", -3)
	_wing_l = _make_sprite(_back, "WingL")
	_wing_r = _make_sprite(_back, "WingR")
	_back_sprite = _make_sprite(_back, "Pack")

	_leg_l = _make_bone(self, "LegL", 0)
	_leg_l_sprite = _make_sprite(_leg_l, "Leg")
	_leg_r = _make_bone(self, "LegR", 0)
	_leg_r_sprite = _make_sprite(_leg_r, "Leg")

	_body = _make_bone(self, "Body", 0)
	_torso = _make_sprite(_body, "Torso")
	_belt = _make_sprite(_body, "Belt")
	_neck_bone = Node2D.new()
	_neck_bone.name = "Neck"
	_body.add_child(_neck_bone)
	_head = _make_sprite(_neck_bone, "Head")
	_arm_back = _make_bone(_body, "ArmBack", -2)
	_arm_back_sprite = _make_sprite(_arm_back, "Arm")
	_glove_back = _make_sprite(_arm_back, "Glove")
	# El brazo de adelante va sobre el arma (que cuelga de WeaponPivot, hermano de Visuals)
	_arm_front = _make_bone(_body, "ArmFront", 1)
	_arm_front_sprite = _make_sprite(_arm_front, "Arm")
	_glove_front = _make_sprite(_arm_front, "Glove")
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
		var hand_bone: Node2D = Node2D.new()
		hand_bone.name = "HandBone"
		fore.add_child(hand_bone)
		_hand_bone.append(hand_bone)
		_hand_sprite.append(_make_sprite(hand_bone, "HandSprite"))
		_fore.append(fore)


# ==============================================================================
# Aplicación del aspecto
# ==============================================================================

func _rig_part(part_name: String) -> Dictionary:
	return RigArt.PARTS.get(part_name, {}) as Dictionary


## Pieza de `rig_art.gd` (mochila, alas, granada) anclada en `anchor` (px de juego sobre su esquina).
## El `position` lo pone quien la llama.
func _assign(sprite: Sprite2D, part_name: String, anchor: Vector2) -> void:
	var data: Dictionary = _rig_part(part_name)
	if data.is_empty():
		sprite.visible = false
		return
	var texture: Texture2D = ArtScript.tex(str(data.get("file", "")))
	sprite.texture = texture
	sprite.visible = texture != null
	sprite.scale = Vector2(PROP_TEX_SCALE, PROP_TEX_SCALE)
	sprite.offset = -anchor / PROP_TEX_SCALE


## Pieza de `armor_art.gd`: la esquina superior izquierda de la textura queda en `pos` (coordenadas locales del padre).
func _place(sprite: Sprite2D, data: Dictionary, pos: Vector2) -> void:
	if data.is_empty():
		sprite.visible = false
		return
	var texture: Texture2D = ArtScript.tex(str(data.get("file", "")))
	sprite.texture = texture
	sprite.visible = texture != null
	sprite.scale = Vector2(_cur_scale, _cur_scale)
	sprite.offset = Vector2.ZERO
	sprite.region_enabled = false
	sprite.position = pos


func _skin_data(skin_id: String) -> Dictionary:
	var data: Dictionary = HeroArt.SKINS.get(skin_id, {}) as Dictionary
	if data.is_empty():
		data = ArmorArt.SKINS.get(skin_id, {}) as Dictionary
	if data.is_empty():
		data = ArmorArt.SKINS.get("no_armor", {}) as Dictionary
	return data


func _apply_loadout() -> void:
	var body: Dictionary = _skin_data(str(loadout.get("skin", "no_armor")))
	var back_name: String = str(loadout.get("back", ""))
	var belt_name: String = str(loadout.get("belt", ""))

	_has_legs = bool(body.get("has_legs", true))
	_hover = not _has_legs
	_articulated = bool(body.get("articulated", false))
	_cur_scale = TEX_SCALE
	var back_shift: float = float(body.get("back_shift", 0.0))

	# Torso
	var torso: Dictionary = body.get("torso", {}) as Dictionary
	_place(_torso, torso, torso.get("pos", Vector2.ZERO) as Vector2)
	var torso_size: Vector2 = torso.get("size", Vector2(18.0, 26.0)) as Vector2
	var torso_top: float = (torso.get("pos", Vector2.ZERO) as Vector2).y

	# Piernas: dos mitades que cuelgan de la cadera
	if _articulated:
		_apply_articulated_legs(body)
	else:
		_hide_chains()
		_apply_leg(_leg_l, _leg_l_sprite, body.get("leg_l", {}) as Dictionary, true)
		_apply_leg(_leg_r, _leg_r_sprite, body.get("leg_r", {}) as Dictionary, false)

	# Cabeza, anclada al cuello
	var neck: Vector2 = body.get("neck", Vector2(0.0, -62.0)) as Vector2
	var head: Dictionary = body.get("head", {}) as Dictionary
	_neck_bone.position = neck
	_place(_head, head, head.get("pos_rel", Vector2.ZERO) as Vector2)
	# De perfil, el cuello de la túnica tapa la base de la cabeza; en los cuerpos de frente la cabeza va sobre el torso y bajo los brazos
	_body.move_child(_neck_bone, 0 if _articulated else 2)

	# Granada al cinturón
	if belt_name.is_empty():
		_belt.visible = false
	else:
		var belt_size: Vector2 = (_rig_part(belt_name).get("size", Vector2(8.0, 11.0))) as Vector2
		_assign(_belt, belt_name, belt_size * 0.5)
		_belt.position = Vector2(torso_size.x * 0.32, torso_top + torso_size.y - 4.0)
		if body.has("belt_pos"):
			_belt.position = body.get("belt_pos") as Vector2

	# Espalda: alas o mochila
	_wing_l.visible = false
	_wing_r.visible = false
	_back_sprite.visible = false
	if back_name == "wings":
		var wing_size: Vector2 = (_rig_part("back_wing_l").get("size", Vector2(30.0, 36.0))) as Vector2
		_assign(_wing_l, "back_wing_l", Vector2(wing_size.x, wing_size.y * 0.55))
		_assign(_wing_r, "back_wing_r", Vector2(0.0, wing_size.y * 0.55))
		_wing_l.position = Vector2(-4.0 + back_shift, torso_top + 8.0)
		_wing_r.position = Vector2(4.0 + back_shift, torso_top + 8.0)
	elif not back_name.is_empty():
		var pack_size: Vector2 = (_rig_part(back_name).get("size", Vector2(26.0, 31.0))) as Vector2
		_assign(_back_sprite, back_name, Vector2(pack_size.x * 0.5, 0.0))
		_back_sprite.position = Vector2(back_shift, torso_top + 5.0)

	# Brazos: el origen del hueso es el hombro; la mano cuelga de la muñeca
	if _articulated:
		_rest_back = _apply_articulated_arm(0, _arm_back, _arm_back_sprite, _glove_back, body.get("arm_far", {}) as Dictionary)
		_rest_front = _apply_articulated_arm(1, _arm_front, _arm_front_sprite, _glove_front, body.get("arm_near", {}) as Dictionary)
		return
	_rest_back = _apply_arm(_arm_back, _arm_back_sprite, _glove_back, body.get("arm_l", {}) as Dictionary, body.get("hand_l", {}) as Dictionary, true)
	_rest_front = _apply_arm(_arm_front, _arm_front_sprite, _glove_front, body.get("arm_r", {}) as Dictionary, body.get("hand_r", {}) as Dictionary, false)


## Oculta las piezas extra del cuerpo articulado (cuando el aspecto es de una pieza por miembro).
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
		_hand_bone[i].rotation = 0.0
	_neck_bone.rotation = 0.0


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
	# La mano gira alrededor del agarre para seguir la orientación del arma
	_hand_bone[index].position = grip - elbow
	_place(_hand_sprite[index], hand, (hand.get("pos", Vector2.ZERO) as Vector2) - grip)
	_arm_len_up[index] = (elbow - shoulder).length()
	_arm_len_low[index] = (grip - elbow).length()
	_arm_dir_up[index] = (elbow - shoulder).angle()
	_arm_dir_low[index] = (grip - elbow).angle()
	if index == 0:
		_reach_back = _arm_len_up[0] + _arm_len_low[0]
	return grip - shoulder


func _apply_leg(bone: Node2D, leg_sprite: Sprite2D, leg: Dictionary, is_left: bool) -> void:
	if leg.is_empty() or not _has_legs:
		leg_sprite.visible = false
		bone.visible = false
		return
	bone.visible = true
	var pivot: Vector2 = leg.get("pivot", Vector2(0.0, -34.0)) as Vector2
	bone.position = pivot
	if is_left:
		_leg_base_y_l = pivot.y
	else:
		_leg_base_y_r = pivot.y
	_place(leg_sprite, leg, (leg.get("pos", Vector2.ZERO) as Vector2) - pivot)


## Coloca brazo y guante; devuelve el vector hombro -> centro de la mano en reposo (coordenadas del hueso).
func _apply_arm(bone: Node2D, arm_sprite: Sprite2D, glove_sprite: Sprite2D, arm: Dictionary, glove: Dictionary, is_back: bool) -> Vector2:
	var shoulder: Vector2 = arm.get("shoulder", Vector2(8.0 if not is_back else -8.0, -57.0)) as Vector2
	bone.position = shoulder
	if is_back:
		_shoulder_back = shoulder
	else:
		_shoulder_front = shoulder
	_place(arm_sprite, arm, (arm.get("pos", Vector2.ZERO) as Vector2) - shoulder)
	var wrist: Vector2 = arm.get("wrist", shoulder + Vector2(0.0, 20.0)) as Vector2
	var anchor_x: float = float(glove.get("anchor_x", 3.0))
	var hand: Vector2 = glove.get("hand", Vector2(3.5, 14.0)) as Vector2
	var glove_pos: Vector2 = Vector2(wrist.x - shoulder.x - anchor_x, ARM_REACH - hand.y)
	_place(glove_sprite, glove, glove_pos)
	return glove_pos + hand


## Lee el equipo puesto y lo traduce a piezas del esqueleto (solo con `gear_driven`): espalda y granada.
func _sync_gear() -> void:
	if _player == null or _player.equipment_manager == null:
		return
	var em: EquipmentManager = _player.equipment_manager
	var back_item: ItemData = em.get_equipped_item("BACK")
	var tactical_item: ItemData = em.get_equipped_item("TACTICAL")

	var key: String = "%s|%s" % [_id_of(back_item), _id_of(tactical_item)]
	if _applied.get("gear_key", "") == key:
		return

	var changes: Dictionary = {}
	var back_name: String = ""
	match _id_of(back_item):
		"jetpack":
			back_name = "back_jetpack"
		"feather_wings":
			back_name = "wings"
	changes["back"] = back_name
	changes["belt"] = str(BELT_PARTS.get(_id_of(tactical_item), ""))

	for k: Variant in changes.keys():
		loadout[k] = changes[k]
	_apply_loadout()
	_applied["gear_key"] = key


func _id_of(item: ItemData) -> String:
	return "" if item == null else item.item_id


# ==============================================================================
# Animación
# ==============================================================================

func _process(delta: float) -> void:
	if _body == null:
		return
	_time += delta
	if gear_driven:
		_sync_gear()
	_connect_fire_signal()
	_recoil = maxf(0.0, _recoil - delta * 7.0)
	_motion_t += delta
	_swipe_t += delta
	_animate_body(delta)
	_animate_arms()


func _animate_body(delta: float) -> void:
	var speed: float = 0.0
	var on_floor: bool = true
	var vertical: float = 0.0
	if _host != null and not preview_mode:
		speed = absf(_host.velocity.x)
		on_floor = _host.is_on_floor()
		vertical = _host.velocity.y
	var jetting: bool = _player != null and _player.is_using_jetpack and not preview_mode

	if on_floor and not _was_on_floor:
		_land_squash = 1.0
	_was_on_floor = on_floor
	_land_squash = maxf(0.0, _land_squash - delta * 5.0)

	var run_amount: float = clampf(speed / run_reference_speed, 0.0, 1.3) if on_floor else 0.0
	if on_floor and speed > 8.0:
		_phase += delta * (6.0 + speed * 0.045)
	else:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, minf(1.0, delta * 10.0))

	var swipe: float = sin(clampf(_swipe_t / 0.34, 0.0, 1.0) * PI)
	var swing: float = sin(_phase) * deg_to_rad(34.0) * minf(run_amount, 1.0)
	var leg_l_target: float = swing
	var leg_r_target: float = -swing
	var lift_l: float = 0.0
	var lift_r: float = 0.0
	if on_floor and run_amount > 0.05:
		lift_l = maxf(0.0, cos(_phase)) * 2.0 * minf(run_amount, 1.0)
		lift_r = maxf(0.0, -cos(_phase)) * 2.0 * minf(run_amount, 1.0)
	if not on_floor:
		if jetting:
			leg_l_target = deg_to_rad(6.0)
			leg_r_target = deg_to_rad(-4.0)
		elif vertical < 0.0:
			leg_l_target = deg_to_rad(-26.0)
			leg_r_target = deg_to_rad(18.0)
		else:
			leg_l_target = deg_to_rad(22.0)
			leg_r_target = deg_to_rad(-20.0)

	var blend: float = minf(1.0, delta * 18.0)
	_leg_l.rotation = lerp_angle(_leg_l.rotation, leg_l_target, blend)
	_leg_r.rotation = lerp_angle(_leg_r.rotation, leg_r_target, blend)
	if _articulated:
		_animate_knees(on_floor, jetting, vertical, run_amount, blend)
	_leg_l.position.y = _leg_base_y_l - lift_l
	_leg_r.position.y = _leg_base_y_r - lift_r

	# Cuerpo: respiración en reposo, rebote al correr, aplastamiento al caer
	var bob: float = sin(_time * 2.4) * 0.5
	if on_floor and run_amount > 0.05:
		bob = -absf(sin(_phase)) * 1.8 * minf(run_amount, 1.0)
	if _hover:
		# Sin piernas (fantasma): flota y se mece
		bob = -3.0 + sin(_time * 2.2) * 1.8
	_body.position.y = bob + _land_squash * 1.5
	_body.scale = Vector2(1.0 + _land_squash * 0.06, 1.0 - _land_squash * 0.08)
	_body.rotation = sin(_phase) * 0.03 * minf(run_amount, 1.0) if on_floor else 0.0
	if swipe > 0.0:
		_body.rotation += 0.22 * swipe
		_body.position.x = 3.0 * swipe
	if _articulated:
		# Retroceso del arma de fuego y movimiento del cuerpo al blandir un arma melee
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

	var back_node: Node2D = _back
	back_node.position.y = _body.position.y * 0.6


## Golpe de los enemigos con el esqueleto modular: estiran los brazos hacia adelante y el cuerpo se lanza.
func play_attack() -> void:
	_swipe_t = 0.0


## Engancha el disparo del arma (de las dos manos) para que el cuerpo reaccione al retroceso (solo el jugador).
func _connect_fire_signal() -> void:
	if preview_mode or _player == null or _player.weapon_manager == null:
		return
	var main: WeaponManager = _player.weapon_manager
	if not _fire_connected:
		_fire_connected = true
		main.weapon_fired.connect(_on_weapon_fired.bind(main))
	if not _off_fire_connected and main.offhand != null:
		_off_fire_connected = true
		main.offhand.weapon_fired.connect(_on_weapon_fired.bind(main.offhand))


## `source` es el administrador de la mano que atacó: de ahí sale la animación del cuerpo (`last_motion`).
func _on_weapon_fired(_weapon: WeaponData, source: WeaponManager = null) -> void:
	var motion: Dictionary = {}
	if source != null:
		motion = source.last_motion
	elif _player != null and _player.weapon_manager != null:
		motion = _player.weapon_manager.last_motion
	_motion_body = motion.get("body", []) as Array
	_motion_len = float(motion.get("length", 0.0))
	_motion_t = 0.0
	# Armas de fuego: retroceso del torso según el arma; melee: inclinación y avance del perfil
	_recoil = float(motion.get("recoil", 1.0)) if _motion_body.is_empty() else 0.0


## Rodilla y tobillo del cuerpo articulado: la pierna que avanza dobla la rodilla; en el aire se encoge un poco.
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


## Orienta cada brazo hacia el punto que debe sostener. Sin arma queda colgando con el vaivén de la marcha.
func _animate_arms() -> void:
	var hand_front: Vector2 = Vector2.ZERO
	var hand_back: Vector2 = Vector2.ZERO
	var holding: bool = false
	var two_handed: bool = false

	var weapon_sprite: Sprite2D = null
	var pose: Dictionary = {}
	var aim_angle: float = 0.0
	if not preview_mode and _player != null and _player.weapon_pivot != null and _player.weapon_manager != null:
		weapon_sprite = _player.weapon_pivot.get_node_or_null("WeaponSprite") as Sprite2D
		pose = ItemIconsScript.get_weapon_pose(_player.weapon_manager.current_weapon)
	if weapon_sprite != null and weapon_sprite.visible and weapon_sprite.texture != null and pose.has("hand"):
		holding = true
		var grip: Vector2 = pose.get("grip", Vector2.ZERO) as Vector2
		var hand_tex: Vector2 = pose.get("hand", grip) as Vector2
		hand_front = _body.to_local(weapon_sprite.to_global(hand_tex - grip))
		# Orientación del arma vista desde el cuerpo (ya con el espejo de Visuals aplicado)
		var forward: Vector2 = _body.global_transform.affine_inverse().basis_xform(weapon_sprite.global_transform.x)
		aim_angle = forward.angle()
		two_handed = bool(pose.get("two_hand", false))
		if two_handed:
			var support_tex: Vector2 = pose.get("support", hand_tex) as Vector2
			var support_local: Vector2 = _body.to_local(weapon_sprite.to_global(support_tex - grip))
			var reach_back: float = _reach_back if _articulated else _rest_back.length()
			hand_back = _reachable_support(hand_front, support_local, _shoulder_back, reach_back)

	if not holding:
		var sway: float = 0.0
		if _host != null and not preview_mode:
			sway = sin(_phase) * 5.0 * clampf(absf(_host.velocity.x) / run_reference_speed, 0.0, 1.0)
		var breathe: float = sin(_time * 2.4) * 0.6
		hand_front = _shoulder_front + _rest_front + Vector2(-sway, breathe)
		hand_back = _shoulder_back + _rest_back + Vector2(sway, -breathe)
		_arm_back.z_index = 0 if preview_mode else -2
		if _swipe_t < 0.34:
			# Zarpazo: ambos brazos se estiran hacia adelante y suben
			var reach: float = sin(clampf(_swipe_t / 0.34, 0.0, 1.0) * PI)
			hand_front = hand_front.lerp(_shoulder_front + Vector2(ARM_REACH * 0.95, -5.0), reach)
			hand_back = hand_back.lerp(_shoulder_back + Vector2(ARM_REACH * 0.9, 1.0), reach)
	else:
		if not two_handed:
			hand_back = _shoulder_back + _rest_back
		# Con dos manos el brazo de atrás también va sobre el arma
		# Con dos manos el brazo de atrás va sobre el arma; en el cuerpo de perfil el brazo queda detrás
		# y solo la mano (que envuelve el guardamanos) se dibuja encima
		if _articulated:
			_arm_back.z_index = 0 if preview_mode else -2
		else:
			_arm_back.z_index = 0 if preview_mode else (1 if two_handed else -2)

	# Mano secundaria: el brazo de atrás agarra el arma secundaria (con un arma a dos manos no hay secundaria)
	var off_holding: bool = false
	var off_angle: float = 0.0
	if not preview_mode and not two_handed and _player != null and _player.weapon_pivot != null and _player.weapon_manager != null:
		var off: WeaponManager = _player.weapon_manager.offhand
		var off_sprite: Sprite2D = _player.weapon_pivot.get_node_or_null("OffhandSprite") as Sprite2D
		if off != null and off.current_weapon != null and off_sprite != null and off_sprite.visible and off_sprite.texture != null:
			var off_pose: Dictionary = ItemIconsScript.get_weapon_pose(off.current_weapon)
			if off_pose.has("hand"):
				off_holding = true
				var off_grip: Vector2 = off_pose.get("grip", Vector2.ZERO) as Vector2
				var off_hand_tex: Vector2 = off_pose.get("hand", off_grip) as Vector2
				hand_back = _body.to_local(off_sprite.to_global(off_hand_tex - off_grip))
				off_angle = _body.global_transform.affine_inverse().basis_xform(off_sprite.global_transform.x).angle()
				if not _articulated:
					_arm_back.z_index = 1

	# En el aire los brazos que están libres se abren hacia afuera y arriba; al aterrizar vuelven a la pose normal
	var airborne: bool = not preview_mode and _host != null and not _was_on_floor
	_jump_open = move_toward(_jump_open, 1.0 if airborne else 0.0, get_process_delta_time() * (8.0 if airborne else 6.0))
	if _jump_open > 0.0:
		var ease_open: float = smoothstep(0.0, 1.0, _jump_open)
		if not holding:
			var open_front: Vector2 = _shoulder_front + Vector2(ARM_REACH * 0.7, -ARM_REACH * 0.45)
			hand_front = hand_front.lerp(open_front, ease_open)
		if not two_handed and not off_holding:
			var open_back: Vector2 = _shoulder_back + Vector2(-ARM_REACH * 0.7, -ARM_REACH * 0.45)
			hand_back = hand_back.lerp(open_back, ease_open)

	if _articulated:
		var blend: float = minf(1.0, get_process_delta_time() * 14.0)
		_aim_angle = lerp_angle(_aim_angle, aim_angle, blend)
		_aim_angle_off = lerp_angle(_aim_angle_off, off_angle, blend)
		var hand_angle: float = _aim_angle if holding else 0.0
		# Mano de adelante girada 45 grados antihorario respecto del arma (referencia de agarre de rifle)
		_aim_chain(1, _arm_front, _shoulder_front, hand_front, hand_angle + (deg_to_rad(-45.0) if holding else 0.0), holding)
		if off_holding:
			_aim_chain(0, _arm_back, _shoulder_back, hand_back, _aim_angle_off, true)
		else:
			_aim_chain(0, _arm_back, _shoulder_back, hand_back, hand_angle, two_handed)
		# Mano de atrás a dos manos: detrás del arma, solo asoman las puntas de los dedos (referencia de agarre)
		_hand_sprite[0].z_index = 3 if off_holding and not preview_mode else 0
		# La cabeza acompaña la puntería, sin llegar a girar entera
		var look: float = clampf(_aim_angle, deg_to_rad(-70.0), deg_to_rad(70.0)) * 0.35 if holding else 0.0
		_neck_bone.rotation = lerp_angle(_neck_bone.rotation, look, blend)
		return
	_aim_arm(_arm_front, _shoulder_front, hand_front, _rest_front)
	_aim_arm(_arm_back, _shoulder_back, hand_back, _rest_back)


## Punto del arma, entre la empuñadura y el apoyo, más lejano que el brazo de atrás todavía alcanza.
func _reachable_support(grip_pos: Vector2, support_pos: Vector2, shoulder: Vector2, reach: float) -> Vector2:
	var best: Vector2 = grip_pos
	var steps: int = 10
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var point: Vector2 = grip_pos.lerp(support_pos, t)
		if point.distance_to(shoulder) <= reach * 1.15:
			best = point
	return best


func _aim_arm(bone: Node2D, shoulder_pos: Vector2, target: Vector2, rest: Vector2) -> void:
	var want: Vector2 = target - shoulder_pos
	if want.length_squared() < 1.0 or rest.length_squared() < 1.0:
		return
	bone.position = shoulder_pos
	bone.rotation = want.angle() - rest.angle()
	var stretch: float = clampf(want.length() / rest.length(), 0.45, 1.15)
	bone.scale = Vector2(stretch, stretch)


## Cinemática inversa de dos huesos: lleva el agarre de la mano a `target` (coordenadas del cuerpo).
## El codo se dobla hacia abajo/atrás; si el punto queda fuera de alcance el brazo se estira hasta un 15 %.
func _aim_chain(index: int, bone: Node2D, shoulder_pos: Vector2, target: Vector2, hand_angle: float, orient_hand: bool) -> void:
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
	var hand_target: float = 0.0
	if orient_hand:
		var arm_global: float = bone.rotation + _fore[index].rotation
		hand_target = clampf(wrapf(hand_angle - arm_global, -PI, PI), deg_to_rad(-75.0), deg_to_rad(75.0))
	_hand_bone[index].rotation = lerp_angle(_hand_bone[index].rotation, hand_target, 0.35)
