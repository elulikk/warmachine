extends Node
## Emboscadas del Mundo 1: los enemigos sueltos del nivel no esperan parados a la vista. Arrancan escondidos
## (invisibles, sin colisión ni proceso) y, cuando el jugador se acerca, salen de su escondite:
## - **ratas**: saltan de adentro del tacho o contenedor más cercano (la tapa se sacude), o asoman por una
##   boca de alcantarilla dibujada en la vereda;
## - **humanos** (asaltante, pistoleros, matones): salen caminando desde atrás del edificio más cercano
##   (dibujados detrás de la fachada hasta pasar el borde), o de la penumbra si no hay edificio cerca.
## Solo mira a los enemigos que ya están en el .tscn al arrancar: los de arena y oleadas nacen después y no se tocan.
## Un enemigo con la meta `no_ambush` se queda como está. Sin class_name: lo crea LevelBase (`preload`).

const LevelSkinScript = preload("res://levels/level_skin.gd")

## Distancia horizontal al jugador a la que sale cada tipo.
const TRIGGER_RAT: float = 200.0
const TRIGGER_HUMAN: float = 620.0
## Distancia máxima a un tacho o al borde de un edificio para usarlo de escondite.
const TRASH_REACH: float = 300.0
const BUILDING_REACH: float = 360.0
const TRASH_ART: Array[String] = ["dumpster", "trash_can", "trash_bags"]
## Ratas sin tacho cerca que están a menos de esto entre sí salen todas por la MISMA alcantarilla, una tras otra.
const HOLE_SHARE: float = 520.0
const RAT_STAGGER: float = 0.35
## Boca de desagüe al pie de la fachada (arte de Flow, detrás del jugador): la rata sale de ahí hacia la calle.
## Sin el archivo se dibuja una reja de respaldo en la vereda y la rata sube desde abajo. Alto en juego (px).
const SEWER_TEX: String = "res://assets/art/world1/sewer_hole.png"
const SEWER_HEIGHT: float = 48.0
## Búsqueda de fachada para la boca: hasta qué distancia del grupo de ratas, en pasos de cuánto, y medio ancho
## de pared opaca que tiene que haber detrás (la boca mide ~120 px a SEWER_HEIGHT).
const FACADE_SEARCH: float = 420.0
const FACADE_STEP: float = 20.0
const FACADE_HALF: float = 70.0
const RAT_KINDS: Array[String] = ["rat"]
const HUMAN_KINDS: Array[String] = ["thief", "thug", "gunman", "bouncer", "hitman_smg", "hitman_elite"]
## Detrás de los edificios (z -2) aunque las manos del rig sumen +3 de z relativo.
const BEHIND_Z: int = -6
## Cuánto se mete el humano detrás del edificio antes de salir, y a partir de qué distancia del borde vuelve al frente.
const HIDE_DEPTH: float = 60.0
const STEP_OUT_TIMEOUT: float = 2.5
const CHECK_PERIOD: float = 0.1

## { "node": BasicRunner, "kind": "rat"|"human", "layer", "mask", "hurt_layer", "hurt_mask" }
var _lurkers: Array[Dictionary] = []
## Humanos saliendo de atrás de un edificio: { "node", "edge": float, "out": float (+1/-1), "time": float }
var _stepping: Array[Dictionary] = []
var _timer: float = 0.0
var _decor: Node2D = null
var _decor_back: Node2D = null
var _sewer_tex: Texture2D = null
## Imagen de cada textura de edificio (para leer el alfa de la fachada).
var _facade_images: Dictionary = {}


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
	_sewer_tex = load(SEWER_TEX) as Texture2D if ResourceLoader.exists(SEWER_TEX) else null
	_assign_rat_sources()
	if _lurkers.is_empty():
		set_process(false)


func _process(delta: float) -> void:
	_update_stepping(delta)
	_timer -= delta
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
			if entry["kind"] == "rat":
				_release_rat_group(int(entry.get("group", -1)), entry, player)
				return
			_lurkers.remove_at(i)
			_emerge_human(entry, player)


## Suelta a todas las ratas que comparten escondite con `first`, una detrás de otra.
func _release_rat_group(group: int, first: Dictionary, player: Node2D) -> void:
	var batch: Array[Dictionary] = [first]
	if group >= 0:
		for entry: Dictionary in _lurkers:
			if entry != first and int(entry.get("group", -2)) == group:
				batch.append(entry)
	for entry: Dictionary in batch:
		_lurkers.erase(entry)
	for k: int in batch.size():
		var entry: Dictionary = batch[k]
		if k == 0:
			_emerge_rat(entry, player)
		else:
			get_tree().create_timer(RAT_STAGGER * k).timeout.connect(func() -> void:
				if is_instance_valid(entry["node"]):
					_emerge_rat(entry, player))


## Escondite de cada rata: el tacho más cercano, o una alcantarilla compartida por las ratas vecinas.
func _assign_rat_sources() -> void:
	var holes: Array[Vector2] = []
	var trash_groups: Dictionary = {}
	for entry: Dictionary in _lurkers:
		if entry["kind"] != "rat":
			continue
		var body: Node2D = entry["node"] as Node2D
		var trash: Node2D = _find_trash(body)
		if trash != null:
			if not trash_groups.has(trash):
				trash_groups[trash] = 1000 + trash_groups.size()
			entry["trash"] = trash
			entry["group"] = trash_groups[trash]
			entry["src_x"] = trash.global_position.x
			continue
		if not _on_ground(body):
			continue
		var at: Vector2 = body.global_position
		var index: int = -1
		for h: int in holes.size():
			if absf(holes[h].x - at.x) <= HOLE_SHARE and absf(holes[h].y - at.y) < 8.0:
				index = h
				break
		if index < 0:
			var tint: Color = Color.WHITE
			if _sewer_tex != null:
				# La boca va en la base de una fachada (nunca flotando sobre un callejón o un hueco entre edificios)
				var spot: Dictionary = _facade_spot(at)
				if spot.is_empty():
					continue
				at = spot["pos"] as Vector2
				tint = spot["tint"] as Color
			index = holes.size()
			holes.append(at)
			_add_manhole(at, tint)
		entry["hole"] = holes[index]
		entry["group"] = index
		entry["src_x"] = holes[index].x


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


# ==============================================================================
# Ratas: del tacho o de la alcantarilla
# ==============================================================================

func _emerge_rat(entry: Dictionary, player: Node2D) -> void:
	var body: CharacterBody2D = entry["node"] as CharacterBody2D
	var dir: float = signf(player.global_position.x - body.global_position.x)
	var trash: Node2D = entry.get("trash", null) as Node2D
	if trash != null and is_instance_valid(trash):
		# Aparece sobre la tapa y salta hacia el jugador
		var size: Vector2 = trash.get("size") as Vector2
		var shrink: Vector2 = trash.get("hitbox_shrink") as Vector2
		body.global_position = Vector2(trash.global_position.x, trash.global_position.y - size.y * (1.0 - shrink.y) - 2.0)
		_release(entry)
		_face(body, dir)
		body.velocity = Vector2(dir * 150.0, -330.0)
		_pop(body)
		_shake_lid(trash)
		return
	if not entry.has("hole"):
		_fade_in(entry, body)
		return
	# Alcantarilla: sube desde abajo de la vereda (el piso y la boca lo tapan) y da un saltito al salir
	var hole: Vector2 = entry["hole"] as Vector2
	var ground_y: float = hole.y
	body.global_position.x = hole.x
	dir = signf(player.global_position.x - hole.x)
	if _sewer_tex != null:
		_walk_out_of_drain(entry, body, hole, dir)
		return
	body.global_position.y = ground_y + 36.0
	body.visible = true
	body.z_index = -1
	_face(body, dir)
	# El tween va en el director: el cuerpo sigue con el proceso apagado hasta que sale
	var tw: Tween = create_tween()
	tw.tween_property(body, "global_position:y", ground_y - 6.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(body):
			return
		body.z_index = 0
		_release(entry)
		body.velocity = Vector2(dir * 120.0, -200.0))


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


## true si el enemigo está parado sobre un sólido grueso (suelo, no una plataforma delgada).
func _on_ground(body: Node2D) -> bool:
	for rect: Rect2 in LevelSkinScript.solid_rects():
		if rect.size.y > 40.0 and absf(rect.position.y - body.global_position.y) < 8.0 \
				and body.global_position.x > rect.position.x + 30.0 and body.global_position.x < rect.end.x - 30.0:
			return true
	return false


## Punto en la base de una fachada cerca de `at`: { "pos": Vector2 (en la línea del piso), "tint": Color del
## edificio }. Exige pared opaca en todo el ancho de la boca y hasta su alto; vacío si no hay ninguna a mano.
func _facade_spot(at: Vector2) -> Dictionary:
	var holder: Node = get_parent().get_node_or_null("Buildings")
	if holder == null:
		return {}
	var offsets: Array[float] = [0.0]
	var d: float = FACADE_STEP
	while d <= FACADE_SEARCH:
		offsets.append(d)
		offsets.append(-d)
		d += FACADE_STEP
	for off: float in offsets:
		var x: float = at.x + off
		for child: Node in holder.get_children():
			var sprite: Sprite2D = child as Sprite2D
			if sprite != null and _wall_behind(sprite, x, at.y):
				var tint: Color = sprite.modulate * (holder as CanvasItem).modulate
				return {"pos": Vector2(x, at.y), "tint": tint}
	return {}


## true si el edificio tapa con pared opaca el rectángulo de la boca centrada en `x` sobre el piso `ground_y`.
func _wall_behind(sprite: Sprite2D, x: float, ground_y: float) -> bool:
	var image: Image = _facade_image(sprite.texture)
	if image == null:
		return false
	for dx: float in [-FACADE_HALF, -FACADE_HALF * 0.5, 0.0, FACADE_HALF * 0.5, FACADE_HALF]:
		for dy: float in [-6.0, -SEWER_HEIGHT * 0.5, -SEWER_HEIGHT - 8.0]:
			var local: Vector2 = sprite.to_local(Vector2(x + dx, ground_y + dy))
			if sprite.centered:
				local += sprite.texture.get_size() * 0.5
			local -= sprite.offset
			var px: Vector2i = Vector2i(floori(local.x), floori(local.y))
			if px.x < 0 or px.y < 0 or px.x >= image.get_width() or px.y >= image.get_height():
				return false
			if image.get_pixelv(px).a < 0.9:
				return false
	return true


func _facade_image(tex: Texture2D) -> Image:
	if tex == null:
		return null
	if not _facade_images.has(tex):
		var image: Image = tex.get_image()
		if image != null and image.is_compressed():
			image.decompress()
		_facade_images[tex] = image
	return _facade_images[tex] as Image


## Sale de la boca de desagüe de la pared: aparece oscura y chica en el hueco y se agranda mientras avanza a la luz.
func _walk_out_of_drain(entry: Dictionary, body: CharacterBody2D, hole: Vector2, dir: float) -> void:
	body.global_position = hole + Vector2(0.0, -2.0)
	body.visible = true
	body.modulate = Color(0.15, 0.15, 0.2, 1.0)
	_face(body, dir)
	var visuals: Node2D = body.get_node_or_null("Visuals") as Node2D
	var full: Vector2 = visuals.scale if visuals != null else Vector2.ONE
	if visuals != null:
		visuals.scale = full * 0.55
	var tw: Tween = create_tween().set_parallel()
	tw.tween_property(body, "modulate", Color.WHITE, 0.3)
	tw.tween_property(body, "global_position:x", hole.x + dir * 26.0, 0.3)
	if visuals != null:
		tw.tween_property(visuals, "scale", Vector2(signf(dir) * absf(full.x), full.y), 0.3)
	tw.chain().tween_callback(func() -> void:
		if not is_instance_valid(body):
			return
		_release(entry)
		body.velocity = Vector2(dir * 140.0, -120.0))


## Boca de desagüe: el arte de Flow al pie de la fachada o, sin él, una reja dibujada en la vereda.
func _add_manhole(at: Vector2, tint: Color = Color.WHITE) -> void:
	if _sewer_tex != null:
		if _decor_back == null:
			_decor_back = Node2D.new()
			_decor_back.name = "AmbushDecorBack"
			# Delante de los edificios (z -2), detrás del jugador y los enemigos
			_decor_back.z_index = -1
			get_parent().add_child(_decor_back)
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = _sewer_tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var sc: float = SEWER_HEIGHT / float(_sewer_tex.get_height())
		sprite.scale = Vector2(sc, sc)
		# Apoyada en la línea donde la fachada toca la vereda
		sprite.position = at + Vector2(0.0, -SEWER_HEIGHT * 0.5 + 2.0)
		# Mismo tono que la fachada (los edificios van teñidos), así no resalta como pegada encima
		sprite.modulate = tint
		_decor_back.add_child(sprite)
		return
	if _decor == null:
		_decor = Node2D.new()
		_decor.name = "AmbushDecor"
		get_parent().add_child(_decor)
		var environment: Node = get_parent().get_node_or_null("Environment")
		if environment != null:
			get_parent().move_child(_decor, environment.get_index() + 1)
	# Respaldo: hueco rectangular oscuro con marco y barrotes
	var w: float = 70.0
	var h: float = 22.0
	var frame: Polygon2D = Polygon2D.new()
	frame.polygon = PackedVector2Array([Vector2(-w * 0.5 - 4.0, -h - 4.0), Vector2(w * 0.5 + 4.0, -h - 4.0),
		Vector2(w * 0.5 + 4.0, 6.0), Vector2(-w * 0.5 - 4.0, 6.0)])
	frame.color = Color(0.2, 0.21, 0.25, 1.0)
	frame.position = at
	_decor.add_child(frame)
	var hole: Polygon2D = Polygon2D.new()
	hole.polygon = PackedVector2Array([Vector2(-w * 0.5, -h), Vector2(w * 0.5, -h), Vector2(w * 0.5, 4.0), Vector2(-w * 0.5, 4.0)])
	hole.color = Color(0.03, 0.03, 0.05, 1.0)
	hole.position = at
	_decor.add_child(hole)
	for i: int in 6:
		var bar: Line2D = Line2D.new()
		var bx: float = -w * 0.5 + w * (float(i) + 0.5) / 6.0
		bar.points = PackedVector2Array([Vector2(bx, -h), Vector2(bx, 4.0)])
		bar.width = 3.0
		bar.default_color = Color(0.3, 0.31, 0.36, 1.0)
		bar.position = at
		_decor.add_child(bar)


# ==============================================================================
# Humanos: de atrás de un edificio o de la penumbra
# ==============================================================================

func _emerge_human(entry: Dictionary, player: Node2D) -> void:
	var body: CharacterBody2D = entry["node"] as CharacterBody2D
	var edge: Vector2 = _nearest_building_edge(body)
	if edge.y == 0.0:
		_fade_in(entry, body)
		return
	# edge.x = borde; edge.y = hacia dónde queda la calle libre (+1 derecha, -1 izquierda)
	body.global_position.x = edge.x - edge.y * HIDE_DEPTH
	body.z_index = BEHIND_Z
	body.modulate = Color(0.35, 0.35, 0.42, 1.0)
	_release(entry)
	_face(body, edge.y)
	body.velocity.x = edge.y * 120.0
	# La barra de vida se dibuja por encima de todo: se oculta hasta que sale de atrás del edificio
	_set_bar_visible(body, false)
	_stepping.append({"node": body, "edge": edge.x, "out": edge.y, "time": 0.0})


func _update_stepping(delta: float) -> void:
	for i: int in range(_stepping.size() - 1, -1, -1):
		var step: Dictionary = _stepping[i]
		var body: CharacterBody2D = step["node"] as CharacterBody2D
		if not is_instance_valid(body):
			_stepping.remove_at(i)
			continue
		step["time"] = float(step["time"]) + delta
		var out: float = float(step["out"])
		var past: float = (body.global_position.x - float(step["edge"])) * out
		# Mientras el jugador no lo arrastre hacia otro lado, que termine de salir caminando
		if past < 0.0 and absf(body.velocity.x) < 40.0:
			body.velocity.x = out * 110.0
		if past >= 14.0 or float(step["time"]) >= STEP_OUT_TIMEOUT:
			body.z_index = 0
			_set_bar_visible(body, true)
			var tw: Tween = body.create_tween()
			tw.tween_property(body, "modulate", Color.WHITE, 0.25)
			_stepping.remove_at(i)


func _set_bar_visible(body: Node, on: bool) -> void:
	var bar: CanvasItem = body.get_node_or_null("OverheadHealthBar") as CanvasItem
	if bar != null:
		bar.visible = on


## Borde de edificio más cercano: Vector2(x del borde, lado de la calle +1/-1); (0, 0) si no hay uno a mano.
func _nearest_building_edge(body: Node2D) -> Vector2:
	var holder: Node = get_parent().get_node_or_null("Buildings")
	if holder == null:
		return Vector2.ZERO
	var best: Vector2 = Vector2.ZERO
	var best_d: float = BUILDING_REACH
	for child: Node in holder.get_children():
		var sprite: Sprite2D = child as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var rect: Rect2 = sprite.get_global_transform() * sprite.get_rect()
		rect = rect.abs()
		if body.global_position.y < rect.position.y or body.global_position.y > rect.end.y + 20.0:
			continue
		for side: Vector2 in [Vector2(rect.position.x, -1.0), Vector2(rect.end.x, 1.0)]:
			var d: float = absf(side.x - body.global_position.x)
			if d < best_d:
				best_d = d
				best = side
	return best


## Sin escondite a mano: aparece desde la penumbra (de negro y transparente a su color).
func _fade_in(entry: Dictionary, body: CharacterBody2D) -> void:
	body.modulate = Color(0.1, 0.1, 0.14, 0.0)
	_release(entry)
	var tw: Tween = body.create_tween()
	tw.tween_property(body, "modulate", Color.WHITE, 0.45)
