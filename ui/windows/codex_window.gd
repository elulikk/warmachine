extends "res://ui/framework/game_window.gd"
## Códice [O]: bestiario y arsenal. Lo descubierto se ve completo; lo demás, en silueta con "???".
## Datos en core/codex/codex.gd. Ejemplo de referencia de una ventana modular (ver skill add-window).

const CodexScript = preload("res://core/codex/codex.gd")
const ItemIconsScript = preload("res://ui/components/item_icons.gd")

const RARITY_NAMES: Array[String] = ["Común", "Poco común", "Rara", "Épica", "Legendaria"]
const PORTRAIT_SIZE: Vector2 = Vector2(150.0, 130.0)

var _tabs: TabContainer = null
var _enemy_count: Label = null
var _weapon_count: Label = null
var _enemy_list: VBoxContainer = null
var _enemy_detail: VBoxContainer = null
var _weapon_list: VBoxContainer = null
var _weapon_detail: VBoxContainer = null
## Fila elegida (-1 = la primera descubierta, al abrir por primera vez).
var _enemy_pick: int = -1
var _weapon_pick: int = -1


func _configure() -> void:
	window_id = &"codex"
	window_title = "CÓDICE [O]"
	toggle_action = &"toggle_codex"
	window_size = Vector2(660.0, 470.0)


func _build(root: Control) -> void:
	_tabs = UiKit.tabs(root)
	var enemies: VBoxContainer = UiKit.tab(_tabs, "Enemigos")
	_enemy_count = UiKit.label(enemies, "", "dim")
	var e_views: Dictionary = UiKit.list_detail(enemies, 200.0)
	_enemy_list = e_views["list"]
	_enemy_detail = e_views["detail"]
	var weapons: VBoxContainer = UiKit.tab(_tabs, "Armas")
	_weapon_count = UiKit.label(weapons, "", "dim")
	var w_views: Dictionary = UiKit.list_detail(weapons, 200.0)
	_weapon_list = w_views["list"]
	_weapon_detail = w_views["detail"]


func _on_opened() -> void:
	_sweep_player_weapons()
	_fill_enemies()
	_fill_weapons()


## Lo que el jugador ya tiene (armas cargadas del guardado, mochila) cuenta como descubierto.
func _sweep_player_weapons() -> void:
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	var wm: Node = player.get("weapon_manager") as Node
	if wm != null:
		for weapon: Variant in wm.get("weapons"):
			CodexScript.record_weapon(weapon as Resource)
	var inv: Node = player.get("inventory_manager") as Node
	if inv != null:
		for res: Variant in inv.get("backpack"):
			CodexScript.record_weapon(res as Resource)


func _first_found(entries: Array[Dictionary]) -> int:
	for i: int in entries.size():
		if entries[i]["found"]:
			return i
	return 0


# ==============================================================================
# Enemigos
# ==============================================================================

func _fill_enemies() -> void:
	UiKit.reset_list(_enemy_list)
	var entries: Array[Dictionary] = CodexScript.enemy_entries()
	if _enemy_pick < 0:
		_enemy_pick = _first_found(entries)
	var found: int = 0
	for i: int in entries.size():
		var e: Dictionary = entries[i]
		var known: bool = e["found"]
		if known:
			found += 1
		var text: String = str(e["name"]) if known else "???"
		if e.get("boss", false) and known:
			text += "  ☠"
		var btn: Button = UiKit.list_entry(_enemy_list, text, CodexScript.enemy_portrait(str(e.get("kind", ""))),
				_show_enemy.bind(e, i), not known)
		if i == _enemy_pick:
			btn.button_pressed = true
	_enemy_count.text = "Enemigos registrados: %d / %d" % [found, entries.size()]
	if not entries.is_empty():
		_enemy_pick = clampi(_enemy_pick, 0, entries.size() - 1)
		_show_enemy(entries[_enemy_pick], _enemy_pick)


func _show_enemy(e: Dictionary, index: int) -> void:
	_enemy_pick = index
	UiKit.clear(_enemy_detail)
	var known: bool = e["found"]
	var portrait: Texture2D = CodexScript.enemy_portrait(str(e.get("kind", "")))
	if portrait != null:
		UiKit.image(_enemy_detail, portrait, PORTRAIT_SIZE, not known)
	UiKit.label(_enemy_detail, str(e["name"]) if known else "???", "big")
	var tags: String = str(e.get("world", ""))
	if e.get("boss", false):
		tags += "  ·  JEFE"
	UiKit.label(_enemy_detail, tags, "gold" if e.get("boss", false) else "dim")
	UiKit.separator(_enemy_detail)
	if not known:
		UiKit.paragraph(_enemy_detail, "Derrotá a este enemigo para registrarlo en el códice.", "dim")
		return
	var grid: GridContainer = UiKit.stat_grid(_enemy_detail)
	UiKit.stat_row(grid, "Bajas:", str(e.get("kills", 0)), "gold")
	if float(e.get("max_hp", 0.0)) > 0.0:
		UiKit.stat_row(grid, "Vida máxima vista:", "%.0f" % float(e["max_hp"]))
	if int(e.get("max_level", 0)) > 0:
		UiKit.stat_row(grid, "Nivel máximo visto:", str(e["max_level"]))
	var lore: VBoxContainer = UiKit.section(_enemy_detail, "Notas de Gunther")
	UiKit.paragraph(lore, str(e.get("lore", CodexScript.UNKNOWN_LORE)))


# ==============================================================================
# Armas
# ==============================================================================

func _fill_weapons() -> void:
	UiKit.reset_list(_weapon_list)
	var entries: Array[Dictionary] = CodexScript.weapon_entries()
	if _weapon_pick < 0:
		_weapon_pick = _first_found(entries)
	var found: int = 0
	for i: int in entries.size():
		var e: Dictionary = entries[i]
		var weapon: WeaponData = e["weapon"]
		var known: bool = e["found"]
		if known:
			found += 1
		var btn: Button = UiKit.list_entry(_weapon_list, weapon.weapon_name if known else "???",
				ItemIconsScript.get_icon_for(weapon), _show_weapon.bind(e, i), not known,
				UiKit.rarity_color(int(weapon.rarity)))
		if i == _weapon_pick:
			btn.button_pressed = true
	_weapon_count.text = "Armas registradas: %d / %d" % [found, entries.size()]
	if not entries.is_empty():
		_weapon_pick = clampi(_weapon_pick, 0, entries.size() - 1)
		_show_weapon(entries[_weapon_pick], _weapon_pick)


func _show_weapon(e: Dictionary, index: int) -> void:
	_weapon_pick = index
	UiKit.clear(_weapon_detail)
	var weapon: WeaponData = e["weapon"]
	var known: bool = e["found"]
	var art: Texture2D = ItemIconsScript.get_hd_art(weapon)
	if art == null:
		art = ItemIconsScript.get_icon_for(weapon)
	if art != null:
		UiKit.image(_weapon_detail, art, PORTRAIT_SIZE, not known)
	var title: Label = UiKit.label(_weapon_detail, weapon.weapon_name if known else "???", "big")
	if known:
		title.add_theme_color_override("font_color", UiKit.rarity_color(int(weapon.rarity)))
	var family: String = str((WeaponData.FAMILY_RULES.get(weapon.family, {}) as Dictionary).get("label", "Arma"))
	var rarity: String = RARITY_NAMES[clampi(int(weapon.rarity), 0, RARITY_NAMES.size() - 1)]
	UiKit.label(_weapon_detail, "%s  ·  %s" % [family, rarity] if known else family, "dim")
	UiKit.separator(_weapon_detail)
	if not known:
		UiKit.paragraph(_weapon_detail, "Conseguí esta arma para registrarla en el códice.", "dim")
		return
	var grid: GridContainer = UiKit.stat_grid(_weapon_detail)
	var melee: bool = weapon.weapon_type == WeaponData.WeaponType.MELEE
	var dmg: String = "%.0f" % weapon.damage
	if weapon.pellets_per_shot > 1:
		dmg += " × %d" % weapon.pellets_per_shot
	UiKit.stat_row(grid, "Daño:", dmg, "gold")
	UiKit.stat_row(grid, "Golpes por segundo:" if melee else "Disparos por segundo:", "%.1f" % weapon.fire_rate)
	if melee:
		UiKit.stat_row(grid, "Multiplicador crítico:", "×%.1f" % weapon.crit_multiplier)
	else:
		UiKit.stat_row(grid, "Cargador:", str(weapon.magazine_size))
		UiKit.stat_row(grid, "Recarga:", "%.1f s" % weapon.reload_time)
		UiKit.stat_row(grid, "Modo:", "Automática" if weapon.is_automatic else "Semiautomática")
	UiKit.stat_row(grid, "Empuñadura:", WeaponData.GRIP_LABELS[clampi(int(weapon.grip), 0, WeaponData.GRIP_LABELS.size() - 1)])
	if weapon.armor_penetration > 0.0:
		UiKit.stat_row(grid, "Perforación de armadura:", "%d %%" % roundi(weapon.armor_penetration * 100.0))
	if not weapon.innate_status_effects.is_empty():
		UiKit.stat_row(grid, "Efectos:", ", ".join(weapon.innate_status_effects))
	UiKit.stat_row(grid, "Valor:", "%d monedas" % weapon.gold_value)
	if not weapon.description.strip_edges().is_empty():
		var notes: VBoxContainer = UiKit.section(_weapon_detail, "Descripción")
		UiKit.paragraph(notes, weapon.description.strip_edges())
