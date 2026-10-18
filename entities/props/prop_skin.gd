extends RefCounted
## Arte para los objetos del escenario (herrero, mercader, baúl, compuerta, terminales).
## Sin class_name: se carga por `preload` desde cada interactuable.
##
## Las escenas originales arman estos objetos con rectángulos de color. Al iniciar, cada uno llama a
## `apply(self, "tipo")`: se ocultan los rectángulos decorativos (los rótulos y la luz de estado se
## conservan) y se agregan los sprites de `assets/art/props/` y, para las personas, el esqueleto modular.

const ArtScript = preload("res://core/art/art.gd")
const RigScript = preload("res://entities/player/character_rig.gd")
const SteamSkin = preload("res://ui/components/steam_skin.gd")

## Capa de los rótulos y avisos de los props (sobre el arte y las personas).
const TAG_Z_INDEX: int = 50

const PROPS_DIR: String = "res://assets/art/props/"

## Los PNG de props están al doble del tamaño de juego.
const PROP_SCALE: float = 0.5


## Cambia los cuadros de un `AnimatedSprite2D` por texturas de arte (cerrado/abierto, rojo/verde, etc.).
## Devuelve true si se aplicó.
static func swap_frames(sprite: AnimatedSprite2D, files: Array[String], base_y: float = 0.0) -> bool:
	if sprite == null or files.is_empty():
		return false
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(&"state")
	frames.set_animation_loop(&"state", false)
	frames.set_animation_speed(&"state", 0.0)
	var first: Texture2D = null
	for file: String in files:
		var texture: Texture2D = ArtScript.tex(PROPS_DIR + file)
		if texture == null:
			return false
		if first == null:
			first = texture
		frames.add_frame(&"state", texture)
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	sprite.sprite_frames = frames
	sprite.animation = &"state"
	sprite.frame = 0
	sprite.scale = Vector2(PROP_SCALE, PROP_SCALE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# El origen del sprite queda a ras de suelo: sube la mitad de su alto
	sprite.position = Vector2(0.0, base_y - first.get_height() * PROP_SCALE * 0.5)
	return true


## Sprite estático anclado al suelo (centro-abajo) en `x` dentro de `parent`.
static func add_sprite(parent: Node2D, file: String, x: float, y: float = 0.0, tone: Color = Color.WHITE, z: int = 0) -> Sprite2D:
	var texture: Texture2D = ArtScript.tex(PROPS_DIR + file)
	if texture == null:
		return null
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2(PROP_SCALE, PROP_SCALE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = Vector2(x, y - texture.get_height() * PROP_SCALE * 0.5)
	sprite.modulate = tone
	sprite.z_index = z
	parent.add_child(sprite)
	return sprite


static func add_person(parent: Node2D, x: float, loadout: Dictionary, face_left: bool = false) -> Node2D:
	var rig: Node2D = RigScript.new()
	rig.name = "PersonRig"
	rig.position = Vector2(x, 0.0)
	if face_left:
		rig.scale.x = -1.0
	for key: Variant in loadout.keys():
		(rig.get("loadout") as Dictionary)[key] = loadout[key]
	parent.add_child(rig)
	return rig


## Gira un sprite sin fin (engranajes decorativos).
static func spin(sprite: Sprite2D, seconds_per_turn: float) -> void:
	if sprite == null or not sprite.is_inside_tree():
		return
	var tween: Tween = sprite.create_tween().set_loops()
	tween.tween_property(sprite, "rotation", TAU, seconds_per_turn).from(0.0)


static func _hide_decor(visuals: Node, keep: Array[String]) -> void:
	for child: Node in visuals.get_children():
		if keep.has(child.name):
			continue
		if child is ColorRect or (child is Node2D and not (child is Sprite2D)):
			(child as CanvasItem).visible = false


## Cartel de checkpoint por capítulo (mundo). Sin entrada: queda el poste de `terminal`.
const CHECKPOINT_SIGNS: Dictionary = {
	1: "res://assets/art/world1/checkpoint_sign.png",
}
const LED_PATH: String = "res://assets/art/props/checkpoint_led.png"


## Checkpoint con el cartel de su mundo y el LED de estado. Sin cartel para el capítulo, queda el poste `terminal`.
static func apply_checkpoint(host: Node2D, chapter: int) -> void:
	var visuals: Node2D = host.get_node_or_null("Visuals") as Node2D
	if visuals == null:
		visuals = host
	if visuals.has_node("PropArt"):
		return
	var texture: Texture2D = null
	if CHECKPOINT_SIGNS.has(chapter):
		texture = ArtScript.tex(CHECKPOINT_SIGNS[chapter])
	if texture == null:
		apply(host, "terminal")
		_swap_led(visuals, -86.0)
		return
	_hide_decor(visuals, ["NameTag", "PromptContainer"])
	var art: Node2D = Node2D.new()
	art.name = "PropArt"
	visuals.add_child(art)
	var sign_height: float = texture.get_height() * PROP_SCALE
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2(PROP_SCALE, PROP_SCALE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = Vector2(0.0, -sign_height * 0.5)
	art.add_child(sprite)
	_swap_led(visuals, -sign_height)
	# El aviso sube por encima del cartel
	var prompt: Node2D = host.get_node_or_null("PromptUI") as Node2D
	if prompt != null:
		prompt.position.y = -sign_height - 24.0


## Cambia el cuadradito de estado por el LED. La lente es blanca: `CheckpointTerminal` la tiñe de rojo o verde.
static func _swap_led(visuals: Node2D, top_y: float) -> void:
	var old: Node = visuals.get_node_or_null("StatusLight")
	if old != null:
		visuals.remove_child(old)
		old.queue_free()
	var led: Sprite2D = Sprite2D.new()
	led.name = "StatusLight"
	led.texture = ArtScript.tex(LED_PATH)
	if led.texture == null:
		return
	led.scale = Vector2(PROP_SCALE, PROP_SCALE)
	led.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	led.position = Vector2(0.0, top_y - led.texture.get_height() * PROP_SCALE * 0.5)
	visuals.add_child(led)


## Punto de entrada: cambia el aspecto de un interactuable según su tipo.
static func apply(host: Node2D, kind: String) -> void:
	var visuals: Node2D = host.get_node_or_null("Visuals") as Node2D
	if visuals == null:
		visuals = host
	if visuals.has_node("PropArt"):
		return
	var art: Node2D = Node2D.new()
	art.name = "PropArt"
	match kind:
		"blacksmith":
			_hide_decor(visuals, ["NameTag", "PromptContainer"])
			visuals.add_child(art)
			add_sprite(art, "forge_large.png", 34.0)
			add_sprite(art, "anvil_stand.png", -26.0)
			var smith: Node2D = add_person(art, -8.0, {
				"skin": "no_armor"
			}, false)
			smith.scale = Vector2(0.95, 0.95)
			var gear: Sprite2D = add_sprite(art, "gear_a.png", 60.0, -92.0, Color(0.9, 0.85, 0.8), -1)
			spin(gear, 16.0)
		"merchant":
			_hide_decor(visuals, ["NameTag", "PromptContainer"])
			visuals.add_child(art)
			add_sprite(art, "cart.png", 34.0)
			add_person(art, -16.0, {
				"skin": "no_armor"
			}, false)
		"terminal":
			_hide_decor(visuals, ["StatusLight", "NameTag", "PromptContainer"])
			visuals.add_child(art)
			var pole: ColorRect = ColorRect.new()
			pole.color = Color(0.32, 0.2, 0.14, 1.0)
			pole.position = Vector2(-4.0, -44.0)
			pole.size = Vector2(8.0, 44.0)
			art.add_child(pole)
			var base: ColorRect = ColorRect.new()
			base.color = Color(0.22, 0.14, 0.1, 1.0)
			base.position = Vector2(-14.0, -6.0)
			base.size = Vector2(28.0, 6.0)
			art.add_child(base)
			add_sprite(art, "gauges.png", 0.0, -40.0)
			var light: CanvasItem = visuals.get_node_or_null("StatusLight") as CanvasItem
			if light is ColorRect:
				(light as ColorRect).position = Vector2(-4.0, -86.0)
				(light as ColorRect).size = Vector2(8.0, 8.0)
		"terminal_gold":
			apply(host, "terminal")
			var node: Node = visuals.get_node_or_null("PropArt")
			if node != null:
				(node as CanvasItem).modulate = Color(1.18, 1.02, 0.72, 1.0)
			return
		"map":
			_hide_decor(visuals, ["PromptContainer"])
			visuals.add_child(art)
			add_sprite(art, "gauges.png", 0.0, -2.0)
			var wheel: Sprite2D = add_sprite(art, "gear_big.png", 0.0, -52.0)
			spin(wheel, 22.0)
		_:
			visuals.add_child(art)
	# Rótulos y avisos por encima del arte: el arte se agrega después y los dejaba detrás de los sprites
	for child: Node in visuals.get_children():
		if child is Control and child.name != &"PropArt":
			(child as Control).z_index = TAG_Z_INDEX
	_style_tags(host)


## Rótulos y avisos en el mundo: placa de madera oscura con filo de cobre (los textos conservan su color).
static func _style_tags(node: Node) -> void:
	for child: Node in node.get_children():
		if child is PanelContainer:
			var panel: PanelContainer = child as PanelContainer
			var box: StyleBoxFlat = StyleBoxFlat.new()
			box.bg_color = Color(0.11, 0.075, 0.055, 0.92)
			box.border_color = Color(0.72, 0.43, 0.28, 1.0)
			box.set_border_width_all(2)
			box.set_corner_radius_all(4)
			box.content_margin_left = 6.0
			box.content_margin_right = 6.0
			box.content_margin_top = 2.0
			box.content_margin_bottom = 2.0
			panel.add_theme_stylebox_override("panel", box)
		elif child is Label:
			var label: Label = child as Label
			label.add_theme_color_override("font_outline_color", SteamSkin.COLOR_OUTLINE)
			label.add_theme_constant_override("outline_size", 3)
		_style_tags(child)
