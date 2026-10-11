"""Tanda de ajustes: cuchillo, pistolas a una mano, monedas, XP, bruto, opciones de juego (ganchos)."""
import os, re
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))


def load(p):
    return open(os.path.join(ROOT, p), encoding="utf-8").read()


def save(p, s):
    open(os.path.join(ROOT, p), "w", encoding="utf-8").write(s)


def rep(s, old, new, count=1):
    assert s.count(old) >= 1, old
    return s.replace(old, new, count)


# ---------------------------------------------------------------- cuchillo
s = load("data/weapons/combat_knife.tres")
s = rep(s, "swing_arc_degrees = 80.0", "swing_arc_degrees = 70.0")
s = rep(s, "swing_duration = 0.11", "swing_duration = 0.08")
s = rep(s, "melee_hitbox_scale = 0.7", "melee_hitbox_scale = 0.55")
s = rep(s, "damage = 30.0", "damage = 15.0")
s = rep(s, "fire_rate = 3.2", "fire_rate = 4.6")
s = rep(s, "knockback_force = 200.0", "knockback_force = 120.0")
save("data/weapons/combat_knife.tres", s)

# ---------------------------------------------------------------- perfiles de arma
s = load("core/art/weapon_motion.gd")
s = rep(s, '''	"combat_knife": {
		"hold"''', '''	"combat_knife": {
		"scale": 0.72,
		"hold"''')
pistol_hold = '"pose": {"two_hand": false}, "hold": {"pos": Vector2(7.0, 0.0), "rot_deg": 0.0}, '
for pid in ["pistol", "pistol_9mm", "desert_eagle", "revolver", "colt_44", "rust_revolver"]:
    s = rep(s, '"%s": {"kick"' % pid, '"%s": {%s"kick"' % (pid, pistol_hold))
s = rep(s, "##   kick    solo armas de fuego:", "##   scale   multiplica el tamaño del arma en mano (1.0 = el de `weapon_art.gd`)\n##   kick    solo armas de fuego:")
s = rep(s, "##   hold    solo melee: pose de reposo del arma en mano. `pos` en px de juego (espacio del pivote), `rot_deg` en grados.",
        "##   hold    pose de reposo del arma en mano. `pos` en px de juego (espacio del pivote), `rot_deg` en grados.\n"
        "##           En armas de fuego solo cuenta `pos.x`: adelanta el arma y estira el brazo (pistolas a una mano).")
save("core/art/weapon_motion.gd", s)

s = load("core/weapon_manager.gd")
s = rep(s, '''	var scale_factor: float = float(pose.get("scale", 1.5)) * WEAPON_SCALE
''', '''	var scale_factor: float = float(pose.get("scale", 1.5)) * WEAPON_SCALE
	scale_factor *= float(WeaponMotion.profile_for(current_weapon).get("scale", 1.0))
''')
s = rep(s, '''	if current_weapon.weapon_type == WeaponData.WeaponType.MELEE:
		# Cada arma melee se sostiene a su manera (ver weapon_motion.gd)
		var hold: Dictionary = WeaponMotion.profile_for(current_weapon).get("hold", {}) as Dictionary
		if not hold.is_empty():
			_sprite_rest_position += hold.get("pos", Vector2.ZERO) as Vector2
			_sprite_rest_rotation += deg_to_rad(float(hold.get("rot_deg", 0.0)))
''', '''	# Cada arma se sostiene a su manera (ver weapon_motion.gd)
	var hold: Dictionary = WeaponMotion.profile_for(current_weapon).get("hold", {}) as Dictionary
	if not hold.is_empty():
		var hold_pos: Vector2 = hold.get("pos", Vector2.ZERO) as Vector2
		if current_weapon.weapon_type == WeaponData.WeaponType.MELEE:
			_sprite_rest_position += hold_pos
			_sprite_rest_rotation += deg_to_rad(float(hold.get("rot_deg", 0.0)))
		else:
			# Armas de fuego: solo se adelanta, para que el cañón y los disparos sigan sobre la línea de puntería
			_sprite_rest_position.x += hold_pos.x
''')
s = rep(s, "muzzle.position = Vector2(HAND_OFFSET_X + (tip_x - grip.x) * scale_factor, 0.0)",
        "muzzle.position = Vector2(_sprite_rest_position.x + (tip_x - grip.x) * scale_factor, 0.0)")
save("core/weapon_manager.gd", s)

# ---------------------------------------------------------------- monedas
s = load("entities/items/loot_drop.gd")
s = rep(s, '''	anim_sprite.scale = Vector2(0.5, 0.5)
''', '''	anim_sprite.scale = Vector2(0.5, 0.5)
	# El sprite se apoya sobre el borde inferior de la colisión (radio 4 px) en vez de hundirse en el suelo
	var first_frame: Texture2D = frames.get_frame_texture(&"spin", 0)
	if first_frame != null:
		var half_height: float = float(first_frame.get_height()) * 0.5 * anim_sprite.scale.y
		anim_sprite.position.y = -(half_height - 4.0)
''')
s = rep(s, "var _collected: bool = false\n", '''var _collected: bool = false

## Racha de monedas juntadas seguidas: cada una suena un semitono más agudo (hasta una sexta mayor).
static var _coin_combo: int = 0
static var _last_coin_msec: int = -10000
''')
s = rep(s, '''			GameFeel.sfx(self, &"coin", Vector2.INF, -4.0)''', '''			var now_msec: int = Time.get_ticks_msec()
			_coin_combo = mini(_coin_combo + 1, 9) if now_msec - _last_coin_msec < 420 else 0
			_last_coin_msec = now_msec
			GameFeel.sfx(self, &"coin", Vector2.INF, -1.0, pow(2.0, float(_coin_combo) / 12.0))''')
save("entities/items/loot_drop.gd", s)

s = load("core/sfx.gd")
s = rep(s, '''		&"coin":
			return _render(0.18, [
				_arp(0.0, 0.17, PackedFloat32Array([988.0, 1319.0]), sine, 0.4, 1.0),
			], 7, 1, 1.0)''', '''		&"coin":
			# "Ding" clásico: si bemol - mi agudo en onda cuadrada, con un destello una octava arriba
			return _render(0.26, [
				_arp(0.0, 0.07, PackedFloat32Array([988.0]), sq, 0.2, 1.0),
				_arp(0.065, 0.19, PackedFloat32Array([1319.0]), sq, 0.2, 1.0),
				_arp(0.065, 0.19, PackedFloat32Array([2637.0]), sine, 0.12, 1.0),
			], 7, 1, 1.0)''')
s = rep(s, "	&\"coin\": 60,", "	&\"coin\": 22,")
save("core/sfx.gd", s)

# ---------------------------------------------------------------- XP más lenta
s = load("entities/enemies/enemy_base.gd")
s = rep(s, "@export var exp_reward: float = 35.0", "@export var exp_reward: float = 20.0")
save("entities/enemies/enemy_base.gd", s)
s = load("entities/items/exp_orb.gd")
s = rep(s, "@export var exp_amount: float = 35.0", "@export var exp_amount: float = 20.0")
save("entities/items/exp_orb.gd", s)
s = load("entities/player/stats_manager.gd")
s = rep(s, "@export var exp_to_next_level: float = 100.0", "@export var exp_to_next_level: float = 150.0")
s = rep(s, "exp_to_next_level = roundf(exp_to_next_level * 1.35)", "exp_to_next_level = roundf(exp_to_next_level * 1.5)")
save("entities/player/stats_manager.gd", s)
s = load("core/managers/save_manager.gd")
s = rep(s, 'float(stats.get("exp_to_next_level", 100.0))', 'float(stats.get("exp_to_next_level", 150.0))')
save("core/managers/save_manager.gd", s)

# ---------------------------------------------------------------- bruto más grande (x1.25)
s = load("entities/enemies/armored_brute.tscn")
s = rep(s, "size = Vector2(40, 56)", "size = Vector2(50, 70)")
s = rep(s, "size = Vector2(44, 56)", "size = Vector2(56, 70)")
s = s.replace("position = Vector2(0, -28)", "position = Vector2(0, -35)")
s = rep(s, "position = Vector2(0, -64)", "position = Vector2(0, -80)")
s = rep(s, "offset_left = -20.0\noffset_top = -56.0\noffset_right = 20.0", "offset_left = -25.0\noffset_top = -70.0\noffset_right = 25.0")
save("entities/enemies/armored_brute.tscn", s)
s = load("entities/enemies/armored_brute.gd")
s = rep(s, "	super._ready()\n", '''	super._ready()
	if overhead_bar != null:
		overhead_bar.set("vertical_offset_y", -80.0)
''')
save("entities/enemies/armored_brute.gd", s)

# ---------------------------------------------------------------- opciones de juego: ganchos
s = load("core/managers/game_manager.gd")
s = rep(s, "enum GameState { PLAYING, GAME_OVER, VICTORY }\n",
        'const SettingsScript = preload("res://core/settings.gd")\n\nenum GameState { PLAYING, GAME_OVER, VICTORY }\n')
s = rep(s, '''	_setup_overlay_ui()
	print("[GameManager] Inicializado en modo PLAYING.")''', '''	_setup_overlay_ui()
	SettingsScript.load_and_apply(self)
	print("[GameManager] Inicializado en modo PLAYING.")''')
s = rep(s, '''	var btn_restart: Button = _create_button("REINICIAR SECTOR", Color(0.35, 0.4, 0.5))''',
        '''	var btn_options: Button = _create_button("OPCIONES", Color(0.3, 0.5, 0.6))
	btn_options.pressed.connect(func() -> void: SettingsScript.open_window(self))
	pause_vbox.add_child(btn_options)

	var btn_restart: Button = _create_button("REINICIAR SECTOR", Color(0.35, 0.4, 0.5))''')
save("core/managers/game_manager.gd", s)

s = load("scenes/main_menu.gd")
s = rep(s, 'const SteamSkin = preload("res://ui/components/steam_skin.gd")\n',
        'const SteamSkin = preload("res://ui/components/steam_skin.gd")\nconst SettingsScript = preload("res://core/settings.gd")\n')
s = rep(s, '''	if btn_quit != null:
		btn_quit.pressed.connect(_on_quit_pressed)
''', '''	if btn_quit != null:
		btn_quit.pressed.connect(_on_quit_pressed)
	_add_options_button()
''')
s = rep(s, "func _connect_slot_actions() -> void:", '''## Botón OPCIONES entre el banco de pruebas y SALIR (copia el estilo del banco de pruebas).
func _add_options_button() -> void:
	if main_buttons_container == null or btn_sandbox == null:
		return
	var button: Button = Button.new()
	button.name = "BtnOptions"
	button.text = "OPCIONES"
	button.custom_minimum_size = Vector2(380.0, 40.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	for style_name: String in ["normal", "hover", "focus"]:
		var style: StyleBox = btn_sandbox.get_theme_stylebox(style_name)
		if style != null:
			button.add_theme_stylebox_override(style_name, style)
	button.pressed.connect(func() -> void: SettingsScript.open_window(self))
	main_buttons_container.add_child(button)
	if btn_quit != null:
		main_buttons_container.move_child(button, btn_quit.get_index())


func _connect_slot_actions() -> void:''')
save("scenes/main_menu.gd", s)

s = load("core/camera_follow.gd")
s = rep(s, "func shake(strength: float, duration: float = 0.18) -> void:\n",
        'func shake(strength_in: float, duration: float = 0.18) -> void:\n	var strength: float = strength_in * (load("res://core/settings.gd") as GDScript).call("get_float", "screen_shake") as float\n	if strength <= 0.01:\n		return\n')
save("core/camera_follow.gd", s)

s = load("core/game_feel.gd")
s = rep(s, "	emitter.amount = amount\n",
        '	emitter.amount = maxi(1, int(roundf(float(amount) * float((load("res://core/settings.gd") as GDScript).call("particle_scale")))))\n')
save("core/game_feel.gd", s)

s = load("combat/damage_number.gd")
s = rep(s, '''func setup(amount: float, is_critical: bool = false, damage_type: String = "PHYSICAL") -> void:
''', '''func setup(amount: float, is_critical: bool = false, damage_type: String = "PHYSICAL") -> void:
	if not bool((load("res://core/settings.gd") as GDScript).call("get_bool", "damage_numbers")):
		queue_free()
		return
''')
save("combat/damage_number.gd", s)
print("ok")
