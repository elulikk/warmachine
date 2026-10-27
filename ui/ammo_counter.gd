extends Control
## Contador de munición del arma en mano, abajo a la derecha (estilo shooter moderno: Doom, Counter-Strike, CoD).
## - Número grande: balas en el cargador. Al lado, más chico: balas de reserva.
## - Una fila de balitas (cargadores de hasta MAX_PIPS) que se apagan al disparar.
## - Con poco cargador pasa a naranja y con casi nada a rojo y parpadea; vacío pide recargar con la tecla de recarga.
## - Recargando: barra de progreso en vez del aviso.
## - Si la mano secundaria tiene un arma con cargador, aparece una línea chica con su munición.
## - Las armas cuerpo a cuerpo y los escudos no muestran el contador.
## Consulta el estado cada cuadro (barato: solo toca los nodos cuando algo cambió). Sin class_name a propósito:
## lo instancia ui/hud.gd por preload.

const ItemIconsScript = preload("res://ui/components/item_icons.gd")

const MARGIN: float = 20.0
const MAX_PIPS: int = 30
const LOW_RATIO: float = 0.3
const CRITICAL_RATIO: float = 0.15
const COLOR_NORMAL: Color = Color(0.96, 0.94, 0.88, 1.0)
const COLOR_LOW: Color = Color(1.0, 0.62, 0.15, 1.0)
const COLOR_CRITICAL: Color = Color(1.0, 0.2, 0.15, 1.0)
const COLOR_DIM: Color = Color(0.72, 0.74, 0.8, 0.85)
const PIP_ON: Color = Color(1.0, 0.82, 0.3, 1.0)
const PIP_OFF: Color = Color(0.25, 0.25, 0.3, 0.7)

var _player: Player = null
var _box: VBoxContainer = null
var _icon: TextureRect = null
var _name_label: Label = null
var _mag_label: Label = null
var _reserve_label: Label = null
var _pips_row: HBoxContainer = null
var _status_label: Label = null
var _reload_bar: ProgressBar = null
var _offhand_label: Label = null

var _weapon: WeaponData = null
var _last_mag: int = -1
var _last_reserve: int = -1
var _last_mag_size: int = -1
var _last_infinite: bool = false
var _pip_count: int = 0
var _punch: float = 0.0
var _color_state: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 0)
	_box.anchor_left = 1.0
	_box.anchor_right = 1.0
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_right = -MARGIN
	_box.offset_bottom = -MARGIN
	_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_box)

	# Nombre del arma con su ícono
	var name_row: HBoxContainer = _row(6)
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.custom_minimum_size = Vector2(22.0, 22.0)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	name_row.add_child(_icon)
	_name_label = _label(14, COLOR_DIM)
	name_row.add_child(_name_label)

	# Cargador (grande) / reserva (chico)
	var count_row: HBoxContainer = _row(4)
	_mag_label = _label(54, COLOR_NORMAL)
	_mag_label.add_theme_constant_override("outline_size", 8)
	count_row.add_child(_mag_label)
	_reserve_label = _label(26, COLOR_DIM)
	_reserve_label.size_flags_vertical = Control.SIZE_SHRINK_END
	count_row.add_child(_reserve_label)

	_pips_row = _row(2)
	_pips_row.custom_minimum_size = Vector2(0.0, 12.0)

	_reload_bar = ProgressBar.new()
	_reload_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reload_bar.custom_minimum_size = Vector2(150.0, 6.0)
	_reload_bar.show_percentage = false
	_reload_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_corner_radius_all(2)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = COLOR_LOW
	fill.set_corner_radius_all(2)
	_reload_bar.add_theme_stylebox_override("background", bg)
	_reload_bar.add_theme_stylebox_override("fill", fill)
	_reload_bar.modulate.a = 0.0 # oculta sin quitar su lugar: el contador no salta al recargar
	_box.add_child(_reload_bar)

	_status_label = _label(13, COLOR_DIM)
	_box.add_child(_status_label)

	_offhand_label = _label(12, COLOR_DIM)
	_box.add_child(_offhand_label)

	visible = false


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
		if _player == null:
			return
	var wm: WeaponManager = _player.weapon_manager
	var weapon: WeaponData = wm.current_weapon if wm != null else null
	var has_counter: bool = weapon != null and weapon.weapon_type != WeaponData.WeaponType.MELEE and weapon.grip != WeaponData.Grip.SHIELD
	if not has_counter:
		visible = false
		_weapon = null
		return
	visible = true
	if weapon != _weapon:
		_set_weapon(weapon)

	var infinite: bool = wm.infinite_ammo or wm.free_ammo_active
	var no_magazine: bool = weapon.magazine_size <= 0
	var mag: int = 0 if no_magazine else wm.get_weapon_ammo(weapon)
	var reserve: int = 0 if no_magazine else wm.get_reserve(weapon)
	if mag != _last_mag or reserve != _last_reserve or weapon.magazine_size != _last_mag_size or infinite != _last_infinite:
		if mag < _last_mag:
			_punch = 1.0
		_refresh_numbers(wm, weapon, mag, reserve, infinite, no_magazine)
		_last_mag = mag
		_last_reserve = reserve
		_last_mag_size = weapon.magazine_size
		_last_infinite = infinite

	_refresh_state(wm, weapon, mag, reserve, infinite, no_magazine)
	_refresh_offhand(wm)

	# Golpecito del número al disparar
	if _punch > 0.0:
		_punch = maxf(0.0, _punch - delta * 7.0)
	_mag_label.pivot_offset = Vector2(_mag_label.size.x, _mag_label.size.y * 0.6)
	var s: float = 1.0 + 0.14 * _punch
	_mag_label.scale = Vector2(s, s)


func _set_weapon(weapon: WeaponData) -> void:
	_weapon = weapon
	_last_mag = -1
	_last_reserve = -1
	_last_mag_size = -1
	_punch = 0.0
	_name_label.text = weapon.weapon_name.to_upper()
	var tex: Texture2D = ItemIconsScript.get_icon_for(weapon)
	_icon.texture = tex
	_icon.visible = tex != null


func _refresh_numbers(_wm: WeaponManager, weapon: WeaponData, mag: int, reserve: int, infinite: bool, no_magazine: bool) -> void:
	if no_magazine:
		_mag_label.text = "∞"
		_reserve_label.text = ""
		_set_pips(0, 0)
		return
	_mag_label.text = str(mag)
	_reserve_label.text = "/ ∞" if infinite else "/ %d" % reserve
	_set_pips(weapon.magazine_size, mag)


func _set_pips(size: int, filled: int) -> void:
	var wanted: int = size if size <= MAX_PIPS else 0
	if wanted != _pip_count:
		for child: Node in _pips_row.get_children():
			child.queue_free()
		_pip_count = wanted
		for i in range(wanted):
			var pip: ColorRect = ColorRect.new()
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pip.custom_minimum_size = Vector2(4.0, 12.0)
			_pips_row.add_child(pip)
	# Las balas se gastan de derecha a izquierda: la fila queda alineada al borde derecho
	var kids: Array[Node] = _pips_row.get_children()
	for i in range(mini(kids.size(), wanted)):
		(kids[i] as ColorRect).color = PIP_ON if i < filled else PIP_OFF


## Color, aviso y barra de recarga: cambian cada cuadro (parpadeo y progreso), por eso van aparte de los números.
func _refresh_state(wm: WeaponManager, weapon: WeaponData, mag: int, reserve: int, infinite: bool, no_magazine: bool) -> void:
	var ratio: float = 1.0 if no_magazine else float(mag) / float(maxi(1, weapon.magazine_size))
	var color: Color = COLOR_NORMAL
	var state: int = 0
	if not no_magazine and not infinite:
		if mag <= 0 or ratio <= CRITICAL_RATIO:
			color = COLOR_CRITICAL
			state = 2
		elif ratio <= LOW_RATIO:
			color = COLOR_LOW
			state = 1
	if state == 2 and not wm.is_reloading:
		color.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))
	_mag_label.add_theme_color_override("font_color", color)
	_color_state = state

	var reloading: bool = wm.is_reloading and not no_magazine
	_reload_bar.modulate.a = 1.0 if reloading else 0.0
	if reloading:
		var total: float = maxf(0.05, weapon.reload_time * WeaponManager.RELOAD_TIME_MULT)
		_reload_bar.max_value = 1.0
		_reload_bar.value = clampf(1.0 - wm.reload_timer / total, 0.0, 1.0)
		_status_label.text = "RECARGANDO"
		_status_label.add_theme_color_override("font_color", COLOR_LOW)
	elif no_magazine or infinite:
		_status_label.text = ""
	elif mag <= 0 and reserve <= 0:
		_status_label.text = "SIN BALAS"
		_status_label.add_theme_color_override("font_color", COLOR_CRITICAL)
	elif mag <= 0 or (ratio <= LOW_RATIO and reserve > 0):
		_status_label.text = "[%s] RECARGAR" % _reload_key_text()
		_status_label.add_theme_color_override("font_color", COLOR_CRITICAL if mag <= 0 else COLOR_LOW)
	else:
		_status_label.text = ""


## Línea de la mano secundaria: solo si ahí hay un arma con cargador.
func _refresh_offhand(wm: WeaponManager) -> void:
	var off: WeaponManager = wm.offhand
	var weapon: WeaponData = off.current_weapon if off != null else null
	if weapon == null or weapon.weapon_type == WeaponData.WeaponType.MELEE or weapon.magazine_size <= 0:
		_offhand_label.text = ""
		return
	_offhand_label.text = "MANO 2  %s  %d / %d" % [weapon.weapon_name, off.get_weapon_ammo(weapon), off.get_reserve(weapon)]


func _reload_key_text() -> String:
	for ev: InputEvent in InputMap.action_get_events(&"reload"):
		var key: InputEventKey = ev as InputEventKey
		if key != null:
			var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return OS.get_keycode_string(code)
	return "R"


func _row(separation: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_theme_constant_override("separation", separation)
	_box.add_child(row)
	return row


func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_SHRINK_END
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 5)
	return label
