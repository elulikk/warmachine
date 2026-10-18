extends Node
## Emboscadas del Mundo 1: los enemigos sueltos del nivel no esperan parados a la vista. Arrancan escondidos
## (invisibles, sin colisión ni proceso) y, cuando el jugador se acerca, salen de un escondite que está dibujado:
## - **ratas**: saltan de adentro del tacho o contenedor más cercano (la tapa se sacude), o salen por la abertura
##   baja de un edificio (reja de sótano, caño roto, agujero en la chapa);
## - **humanos** (asaltante, pistoleros, matones): salen por una puerta, persiana o portón de un edificio, que
##   se oscurece como si se abriera.
## Las salidas de cada edificio están marcadas en `levels/building_exits.gd` (px de su PNG). Sin salida a mano,
## el enemigo aparece desde la penumbra.
## Solo mira a los enemigos que ya están en el .tscn al arrancar: los de arena y oleadas nacen después y no se tocan.
## Un enemigo con la meta `no_ambush` se queda como está. Sin class_name: lo crea LevelBase (`preload`).

const LevelSkinScript = preload("res://levels/level_skin.gd")
const BuildingExitsScript = preload("res://levels/building_exits.gd")

## Distancia horizontal entre el jugador y el escondite a la que sale cada tipo.
const TRIGGER_RAT: float = 200.0
const TRIGGER_HUMAN: float = 620.0
## Distancia máxima del enemigo a su escondite (tacho, abertura de ratas, puerta).
const TRASH_REACH: float = 300.0
const RAT_EXIT_REACH: float = 520.0
const DOOR_REACH: float = 520.0
const TRASH_ART: Array[String] = ["dumpster", "trash_can", "trash_bags"]
const RAT_STAGGER: float = 0.35
const RAT_KINDS: Array[String] = ["rat"]
const HUMAN_KINDS: Array[String] = ["thief", "thug", "gunman", "bouncer", "hitman_smg", "hitman_elite"]
## Puerta "abierta": oscuridad sobre el hueco de la puerta mientras sale alguien.
const DOOR_DARK: Color = Color(0.02, 0.02, 0.04, 0.92)
const DOOR_OPEN_TIME: float = 1.1
const CHECK_PERIOD: float = 0.1

## { "node", "kind": "rat"|"human", "layer", "mask", "hurt_layer", "hurt_mask", "group", "src_x", "trash"|"exit" }
var _lurkers: Array[Dictionary] = []
## Salidas de los edificios del nivel: { "kind": "doors"|"rats", "rect": Rect2 (mundo) }
var _exits: Array[Dictionary] = []
var _timer: float = 0.0
var _overlay: Node2D = null


func _ready() -> void:
	_setup.call_deferred()


func _setup() -> void:
	var level: Node = get_parent()
	if level == null:
		return
	for child: Node in level.get_children():
		var body: CharacterBody2D = child as CharacterBody2D
		if body == null or not ("art_kind" in body) or body.has_meta(&"no_ambush") or body.is_in_group(&"arena_enemies"):
			continue
		var art_kind: String = str(body.get("art_kind"))
		var kind: String = "rat" if RAT_KINDS.has(art_kind) else ("human" if HUMAN_KINDS.has(art_kind) else "")
		if kind.is_empty():
			continue
		_lurkers.append(_hide(body, kind))
	_collect_exits()
	_assign_sources()
	if _lurkers.is_empty():
		set_process(false)


func _process(_delta: float) -> void:
	_timer -= _delta
	if _timer > 0.0:
		return
	_timer = CHECK_PERIOD
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	for i: int in range(_lurkers.size() - 1, -1, -1):
		var entry: Dictionary = _lurkers[i]
		var body: CharacterBody2D = entry["node"] as CharacterBody2D
		if not is_instance_valid(body):
			_lurkers.remove_at(i)
			continue
		var trigger: float = TRIGGER_RAT if entry["kind"] == "rat" else TRIGGER_HUMAN
		var from_x: float = float(entry.get("src_x", body.global_position.x))
		if absf(player.global_position.x - from_x) <= trigger \
				and absf(player.global_position.y - body.global_position.y) <= 260.0:
			_release_group(entry, player)
			return


## Suelta a todos los que comparten escondite con `first`, uno detrás de otro.
func _release_group(first: Dictionary, player: Node2D) -> void:
	var batch: Array[Dictionary] = [first]
	var group: int = int(first.get("group", -1))
	if group >= 0:
		for entry: Dictionary in _lurkers:
			if entry != first and int(entry.get("group", -2)) == group:
				batch.append(entry)
	for entry: Dictionary in batch:
		_lurkers.erase(entry)
	for k: int in batch.size():
		var entry: Dictionary = batch[k]
		if k == 0:
			_emerge(entry, player)
		else:
			get_tree().create_timer(RAT_STAGGER * k).timeout.connect(func() -> void:
				if is_instance_valid(entry["node"]):
					_emerge(entry, player))


func _emerge(entry: Dictionary, player: Node2D) -> void:
	if entry["kind"] == "rat":
		_emerge_rat(entry, player)
	else:
		_emerge_human(entry, player)


# ==============================================================================
# Escondites
# ==============================================================================

## Salidas marcadas de cada edificio del nodo `Buildings`, pasadas a coordenadas del mundo.
func _collect_exits() -> void:
	var holder: Node = get_parent().get_node_or_null("Buildings")
	if holder == null:
		return
	for child: Node in holder.get_children():
		var sprite: Sprite2D = child as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var key: String = sprite.texture.resource_path.get_file().get_basename()
		if not BuildingExitsScript.EXITS.has(key):
			continue
		var marks: Dictionary = BuildingExitsScript.EXITS[key] as Dictionary
		var origin: Vector2 = -sprite.texture.get_size() * 0.5 if sprite.centered else Vector2.ZERO
		for kind: String in ["doors", "rats"]:
			for r: Rect2 in marks.get(kind, []):
				var a: Vector2 = sprite.to_global(origin + sprite.offset + r.position)
				var b: Vector2 = sprite.to_global(origin + sprite.offset + r.end)
				_exits.append({"kind": kind, "rect": Rect2(a, b - a).abs()})


## Escondite de cada enemigo: tacho o abertura de ratas para las ratas, puerta para los humanos.
## Los que caen en el mismo escondite forman un grupo y salen juntos, escalonados.
func _assign_sources() -> void:
	var groups: Dictionary = {}
	for entry: Dictionary in _lurkers:
		var body: Node2D = entry["node"] as Node2D
		var key: Variant = null
		if entry["kind"] == "rat":
			var trash: Node2D = _find_trash(body)
			if trash != null:
				entry["trash"] = trash
				entry["src_x"] = trash.global_position.x
				key = trash
			else:
				var hole: int = _nearest_exit(body, "rats", RAT_EXIT_REACH)
				if hole >= 0:
					entry["exit"] = hole
					entry["src_x"] = (_exits[hole]["rect"] as Rect2).get_center().x
					key = hole
		else:
			var door: int = _nearest_exit(body, "doors", DOOR_REACH)
			if door >= 0:
				entry["exit"] = door
				entry["src_x"] = (_exits[door]["rect"] as Rect2).get_center().x
				# Los humanos no se agrupan: cada uno sale cuando el jugador llega a su puerta
		if key != null:
			if not groups.has(key):
				groups[key] = groups.size()
			entry["group"] = groups[key]


## Índice de la salida de tipo `kind` más cercana al enemigo (a la altura de sus pies), o -1.
func _nearest_exit(body: Node2D, kind: String, reach: float) -> int:
	var best: int = -1
	var best_d: float = reach
	for i: int in _exits.size():
		var ex: Dictionary = _exits[i]
		if ex["kind"] != kind:
			continue
		var rect: Rect2 = ex["rect"] as Rect2
		# La base de la salida tiene que estar en el piso del enemigo (no en un piso de arriba)
		if absf(rect.end.y - body.global_position.y) > 40.0:
			continue
		var d: float = absf(rect.get_center().x - body.global_position.x)
		if d < best_d:
			best_d = d
			best = i
	return best


## El tacho o contenedor más cercano a la misma altura, dentro de TRASH_REACH.
func _find_trash(body: Node2D) -> Node2D:
	var holder: Node = get_parent().get_node_or_null("Props")
	if holder == null:
		return null
	var best: Node2D = null
	var best_d: float = TRASH_REACH
	for child: Node in holder.get_children():
		var prop: Node2D = child as Node2D
		if prop == null or not ("art_path" in prop):
			continue
		var art: String = str(prop.get("art_path")).get_file().get_basename()
		if not TRASH_ART.has(art) or absf(prop.global_position.y - body.global_position.y) > 40.0:
			continue
		var d: float = absf(prop.global_position.x - body.global_position.x)
		if d < best_d:
			best_d = d
			best = prop
	return best


# ==============================================================================
# Esconder y soltar
# ==============================================================================

func _hide(body: CharacterBody2D, kind: String) -> Dictionary:
	var entry: Dictionary = {"node": body, "kind": kind, "layer": body.collision_layer, "mask": body.collision_mask}
	var hurtbox: Area2D = body.get_node_or_null("Hurtbox") as Area2D
	if hurtbox != null:
		entry["hurt_layer"] = hurtbox.collision_layer
		entry["hurt_mask"] = hurtbox.collision_mask
		hurtbox.set_deferred("collision_layer", 0)
		hurtbox.set_deferred("collision_mask", 0)
	body.set_deferred("collision_layer", 0)
	body.set_deferred("collision_mask", 0)
	body.visible = false
	body.process_mode = Node.PROCESS_MODE_DISABLED
	return entry


## Devuelve colisión y proceso, y lo deja persiguiendo al jugador.
func _release(entry: Dictionary) -> void:
	var body: CharacterBody2D = entry["node"] as CharacterBody2D
	body.collision_layer = int(entry["layer"])
	body.collision_mask = int(entry["mask"])
	var hurtbox: Area2D = body.get_node_or_null("Hurtbox") as Area2D
	if hurtbox != null and entry.has("hurt_layer"):
		hurtbox.collision_layer = int(entry["hurt_layer"])
		hurtbox.collision_mask = int(entry["hurt_mask"])
	body.visible = true
	body.process_mode = Node.PROCESS_MODE_INHERIT
	if "is_aggroed" in body:
		body.set("is_aggroed", true)


func _face(body: CharacterBody2D, dir: float) -> void:
	var visuals: Node2D = body.get_node_or_null("Visuals") as Node2D
	if visuals != null and dir != 0.0:
		visuals.scale.x = signf(dir)


## Sin escondite a mano: aparece desde la penumbra (de negro y transparente a su color).
func _fade_in(entry: Dictionary, body: CharacterBody2D) -> void:
	body.modulate = Color(0.1, 0.1, 0.14, 0.0)
	_release(entry)
	var tw: Tween = body.create_tween()
	tw.tween_property(body, "modulate", Color.WHITE, 0.45)


# ==============================================================================
# Ratas: del tacho o de la abertura del edificio
# ==============================================================================

func _emerge_rat(entry: Dictionary, player: Node2D) -> void:
	var body: CharacterBody2D = entry["node"] as CharacterBody2D
	var trash: Node2D = entry.get("trash", null) as Node2D
	if trash != null and is_instance_valid(trash):
		# Aparece sobre la tapa y salta hacia el jugador
		var dir: float = signf(player.global_position.x - trash.global_position.x)
		var size: Vector2 = trash.get("size") as Vector2
		var shrink: Vector2 = trash.get("hitbox_shrink") as Vector2
		body.global_position = Vector2(trash.global_position.x, trash.global_position.y - size.y * (1.0 - shrink.y) - 2.0)
		_release(entry)
		_face(body, dir)
		body.velocity = Vector2(dir * 150.0, -330.0)
		_pop(body)
		_shake_lid(trash)
		return
	if not entry.has("exit"):
		_fade_in(entry, body)
		return
	var rect: Rect2 = _exits[int(entry["exit"])]["rect"] as Rect2
	_step_out(entry, body, Vector2(rect.get_center().x, body.global_position.y), player, 0.55, 26.0)


func _shake_lid(prop: Node2D) -> void:
	var art: Node2D = prop.get_node_or_null("Art") as Node2D
	if art == null:
		return
	var base: Vector2 = art.position
	var tw: Tween = art.create_tween()
	tw.tween_property(art, "position", base + Vector2(3.0, -5.0), 0.05)
	tw.tween_property(art, "position", base + Vector2(-3.0, -2.0), 0.06)
	tw.tween_property(art, "position", base, 0.08)


## Estirón al salir (squash and stretch sobre el alto de los visuales).
func _pop(body: CharacterBody2D) -> void:
	var visuals: Node2D = body.get_node_or_null("Visuals") as Node2D
	if visuals == null:
		return
	var sy: float = visuals.scale.y
	visuals.scale.y = sy * 0.4
	var tw: Tween = visuals.create_tween()
	tw.tween_property(visuals, "scale:y", sy * 1.15, 0.12)
	tw.tween_property(visuals, "scale:y", sy, 0.1)


# ==============================================================================
# Humanos: por una puerta
# ==============================================================================

func _emerge_human(entry: Dictionary, player: Node2D) -> void:
	var body: CharacterBody2D = entry["node"] as CharacterBody2D
	if not entry.has("exit"):
		_fade_in(entry, body)
		return
	var rect: Rect2 = _exits[int(entry["exit"])]["rect"] as Rect2
	_open_door(rect)
	_step_out(entry, body, Vector2(rect.get_center().x, body.global_position.y), player, 0.85, 34.0)


## Oscurece el hueco de la puerta (se "abre") y lo vuelve a cerrar después de que sale el enemigo.
func _open_door(rect: Rect2) -> void:
	if _overlay == null:
		_overlay = Node2D.new()
		_overlay.name = "AmbushDoors"
		# Delante de los edificios (z -2), detrás del jugador y los enemigos
		_overlay.z_index = -1
		get_parent().add_child(_overlay)
	var dark: Polygon2D = Polygon2D.new()
	var inset: float = 3.0
	dark.polygon = PackedVector2Array([
		rect.position + Vector2(inset, inset), Vector2(rect.end.x - inset, rect.position.y + inset),
		Vector2(rect.end.x - inset, rect.end.y), Vector2(rect.position.x + inset, rect.end.y)])
	dark.color = Color(DOOR_DARK, 0.0)
	_overlay.add_child(dark)
	var tw: Tween = dark.create_tween()
	tw.tween_property(dark, "color:a", DOOR_DARK.a, 0.15)
	tw.tween_interval(DOOR_OPEN_TIME)
	tw.tween_property(dark, "color:a", 0.0, 0.3)
	tw.tween_callback(dark.queue_free)


## Sale del hueco en `at`: aparece oscuro y algo chico, y avanza hacia el jugador mientras toma su color y tamaño.
func _step_out(entry: Dictionary, body: CharacterBody2D, at: Vector2, player: Node2D, start_scale: float, walk: float) -> void:
	var dir: float = signf(player.global_position.x - at.x)
	if dir == 0.0:
		dir = 1.0
	body.global_position = at
	body.visible = true
	body.modulate = Color(0.15, 0.15, 0.2, 1.0)
	_face(body, dir)
	var visuals: Node2D = body.get_node_or_null("Visuals") as Node2D
	var full: Vector2 = Vector2(absf(visuals.scale.x), visuals.scale.y) if visuals != null else Vector2.ONE
	if visuals != null:
		visuals.scale = Vector2(dir * full.x, full.y) * start_scale
	# El tween va en el director: el cuerpo sigue con el proceso apagado hasta que termina de salir
	var tw: Tween = create_tween().set_parallel()
	tw.tween_property(body, "modulate", Color.WHITE, 0.35)
	tw.tween_property(body, "global_position:x", at.x + dir * walk, 0.35)
	if visuals != null:
		tw.tween_property(visuals, "scale", Vector2(dir * full.x, full.y), 0.35)
	tw.chain().tween_callback(func() -> void:
		if not is_instance_valid(body):
			return
		_release(entry)
		body.velocity = Vector2(dir * 140.0, -100.0 if entry["kind"] == "rat" else 0.0))
