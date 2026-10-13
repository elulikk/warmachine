class_name MainMenu
extends Control
## Pantalla de Inicio y Menú Principal de WARMACHINE.
## Gestiona el selector de perfiles con 3 ranuras independientes (JSON),
## modal de creación de personaje con LineEdit y modal de confirmación de borrado.

const ArtScript = preload("res://core/art/art.gd")
const SteamSkin = preload("res://ui/components/steam_skin.gd")
const SettingsScript = preload("res://core/settings.gd")

@onready var main_buttons_container: VBoxContainer = %MainButtonsContainer
@onready var slots_container: VBoxContainer = %SlotsContainer
@onready var btn_play: Button = %BtnPlay
@onready var btn_sandbox: Button = %BtnSandbox
@onready var btn_quit: Button = %BtnQuit
@onready var btn_back_slots: Button = %BtnBackSlots

# Slot 1 UI
@onready var slot_1_title: Label = %Slot1Title
@onready var slot_1_sub: Label = %Slot1Sub
@onready var slot_1_btn_play: Button = %Slot1BtnPlay
@onready var slot_1_btn_del: Button = %Slot1BtnDel

# Slot 2 UI
@onready var slot_2_title: Label = %Slot2Title
@onready var slot_2_sub: Label = %Slot2Sub
@onready var slot_2_btn_play: Button = %Slot2BtnPlay
@onready var slot_2_btn_del: Button = %Slot2BtnDel

# Slot 3 UI
@onready var slot_3_title: Label = %Slot3Title
@onready var slot_3_sub: Label = %Slot3Sub
@onready var slot_3_btn_play: Button = %Slot3BtnPlay
@onready var slot_3_btn_del: Button = %Slot3BtnDel

# Modal Creación
@onready var modal_create: ColorRect = %ModalCreate
@onready var create_input: LineEdit = %CreateInput
@onready var create_btn_confirm: Button = %CreateBtnConfirm
@onready var create_btn_cancel: Button = %CreateBtnCancel
@onready var create_error_label: Label = %CreateErrorLabel

# Modal Borrado
@onready var modal_delete: ColorRect = %ModalDelete
@onready var delete_warning_label: Label = %DeleteWarningLabel
@onready var delete_btn_confirm: Button = %DeleteBtnConfirm
@onready var delete_btn_cancel: Button = %DeleteBtnCancel

var _pending_create_slot: int = 1
var _pending_delete_slot: int = 1


func _get_save_manager() -> SaveManager:
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		return sm
	var node: Node = get_node_or_null("SaveManager")
	if node is SaveManager:
		return node as SaveManager
	return null


func _ready() -> void:
	_apply_steam_skin()
	get_tree().paused = false
	GameFeel.music_set_base(self, &"menu")
	if GameManager != null and "current_state" in GameManager:
		GameManager.current_state = 0 # PLAYING
	
	if btn_play != null:
		btn_play.pressed.connect(_on_play_pressed)
		btn_play.grab_focus()
	if btn_sandbox != null:
		btn_sandbox.pressed.connect(_on_sandbox_pressed)
	if btn_quit != null:
		btn_quit.pressed.connect(_on_quit_pressed)
	_add_options_button()
	_add_version_label()
	if btn_back_slots != null:
		btn_back_slots.pressed.connect(_on_back_slots_pressed)
	
	_connect_slot_actions()
	_connect_modals()
	_refresh_slot_cards()


## Versión del juego (config/version en project.godot) en la esquina inferior derecha.
func _add_version_label() -> void:
	var label: Label = Label.new()
	label.name = "VersionLabel"
	label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "dev"))
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.65, 0.6, 0.55, 0.8))
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


## Botón OPCIONES entre el banco de pruebas y SALIR (copia el estilo del banco de pruebas).
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


func _connect_slot_actions() -> void:
	if slot_1_btn_play != null:
		slot_1_btn_play.pressed.connect(_on_slot_play_clicked.bind(1))
	if slot_1_btn_del != null:
		slot_1_btn_del.pressed.connect(_on_slot_delete_clicked.bind(1))
	
	if slot_2_btn_play != null:
		slot_2_btn_play.pressed.connect(_on_slot_play_clicked.bind(2))
	if slot_2_btn_del != null:
		slot_2_btn_del.pressed.connect(_on_slot_delete_clicked.bind(2))
	
	if slot_3_btn_play != null:
		slot_3_btn_play.pressed.connect(_on_slot_play_clicked.bind(3))
	if slot_3_btn_del != null:
		slot_3_btn_del.pressed.connect(_on_slot_delete_clicked.bind(3))


func _connect_modals() -> void:
	if create_btn_confirm != null:
		create_btn_confirm.pressed.connect(_on_create_confirm_pressed)
	if create_btn_cancel != null:
		create_btn_cancel.pressed.connect(_on_create_cancel_pressed)
	if create_input != null:
		create_input.text_submitted.connect(_on_create_input_submitted)
	
	if delete_btn_confirm != null:
		delete_btn_confirm.pressed.connect(_on_delete_confirm_pressed)
	if delete_btn_cancel != null:
		delete_btn_cancel.pressed.connect(_on_delete_cancel_pressed)


func _on_play_pressed() -> void:
	main_buttons_container.visible = false
	slots_container.visible = true
	_refresh_slot_cards()
	if slot_1_btn_play != null:
		slot_1_btn_play.grab_focus()


func _on_back_slots_pressed() -> void:
	slots_container.visible = false
	main_buttons_container.visible = true
	if btn_play != null:
		btn_play.grab_focus()


func _refresh_slot_cards() -> void:
	var sm: SaveManager = _get_save_manager()
	if sm == null:
		return
	
	_update_card_ui(1, slot_1_title, slot_1_sub, slot_1_btn_play, slot_1_btn_del)
	_update_card_ui(2, slot_2_title, slot_2_sub, slot_2_btn_play, slot_2_btn_del)
	_update_card_ui(3, slot_3_title, slot_3_sub, slot_3_btn_play, slot_3_btn_del)


func _update_card_ui(slot_id: int, title_lbl: Label, sub_lbl: Label, play_btn: Button, del_btn: Button) -> void:
	var sm: SaveManager = _get_save_manager()
	if sm == null:
		return
	
	var preview: Dictionary = sm.get_slot_preview(slot_id)
	var exists: bool = bool(preview.get("exists", false))
	
	if exists:
		var c_name: String = str(preview.get("name", "OPERADOR"))
		var lvl: int = int(preview.get("level", 1))
		var coins: int = int(preview.get("coins", 0))
		var t_stamp: String = str(preview.get("timestamp", ""))
		
		title_lbl.text = "SLOT %d: %s" % [slot_id, c_name.to_upper()]
		title_lbl.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
		sub_lbl.text = "Nivel %d | 🪙 %d Monedas | Guardado: %s" % [lvl, coins, t_stamp]
		sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
		
		play_btn.text = "JUGAR"
		del_btn.visible = true
	else:
		title_lbl.text = "SLOT %d: [VACÍO]" % slot_id
		title_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
		sub_lbl.text = "Ranura Vacía - Crear Personaje"
		sub_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
		
		play_btn.text = "NUEVO"
		del_btn.visible = false


func _on_slot_play_clicked(slot_id: int) -> void:
	var sm: SaveManager = _get_save_manager()
	if sm == null:
		return
	
	var preview: Dictionary = sm.get_slot_preview(slot_id)
	if bool(preview.get("exists", false)):
		# Partida existente: cargar a disco y entrar al Hub
		sm.load_from_disk(slot_id)
		print("[MainMenu] Slot %d cargado. Entrando a Base Camp." % slot_id)
		GameManager.change_scene("res://scenes/hub/base_camp.tscn")
	else:
		# Partida vacía: abrir modal de creación
		_open_create_modal(slot_id)


func _on_slot_delete_clicked(slot_id: int) -> void:
	var sm: SaveManager = _get_save_manager()
	if sm == null:
		return
	
	var preview: Dictionary = sm.get_slot_preview(slot_id)
	if bool(preview.get("exists", false)):
		_open_delete_modal(slot_id, str(preview.get("name", "OPERADOR")))


# ==============================================================================
# Modal de Creación
# ==============================================================================

func _open_create_modal(slot_id: int) -> void:
	_pending_create_slot = slot_id
	if modal_create != null:
		modal_create.visible = true
	if create_input != null:
		create_input.text = ""
		create_input.grab_focus()
	if create_error_label != null:
		create_error_label.text = ""


func _on_create_input_submitted(_text: String) -> void:
	_on_create_confirm_pressed()


func _on_create_confirm_pressed() -> void:
	if create_input == null:
		return
	
	var char_name: String = create_input.text.strip_edges()
	if char_name.is_empty():
		if create_error_label != null:
			create_error_label.text = "El nombre no puede estar vacío."
		return
	
	var sm: SaveManager = _get_save_manager()
	if sm != null:
		sm.create_character(_pending_create_slot, char_name)
	
	if modal_create != null:
		modal_create.visible = false
	
	# Partida nueva: directo al P-1 del presente (el campamento queda para las partidas guardadas)
	print("[MainMenu] Personaje '%s' creado en Slot %d. Entrando al presente (P-1)." % [char_name, _pending_create_slot])
	GameManager.change_scene("res://levels/chapter_4/level_4_01.tscn")


func _on_create_cancel_pressed() -> void:
	if modal_create != null:
		modal_create.visible = false
	_refresh_slot_cards()


# ==============================================================================
# Modal de Borrado
# ==============================================================================

func _open_delete_modal(slot_id: int, char_name: String) -> void:
	_pending_delete_slot = slot_id
	if delete_warning_label != null:
		delete_warning_label.text = "¿Estás seguro de que querés borrar a %s?\nSe perderán todas sus armas, monedas y baúl de forma permanente." % char_name.to_upper()
	if modal_delete != null:
		modal_delete.visible = true
	if delete_btn_cancel != null:
		delete_btn_cancel.grab_focus()


func _on_delete_confirm_pressed() -> void:
	var sm: SaveManager = _get_save_manager()
	if sm != null:
		sm.delete_character(_pending_delete_slot)
	
	if modal_delete != null:
		modal_delete.visible = false
	
	_refresh_slot_cards()


func _on_delete_cancel_pressed() -> void:
	if modal_delete != null:
		modal_delete.visible = false


func _on_sandbox_pressed() -> void:
	SaveManager.clear_world_flags()
	print("[MainMenu] Cargando Banco de Pruebas (Modo Fruta): res://core/test_level.tscn")
	GameManager.change_scene("res://core/test_level.tscn")


func _on_quit_pressed() -> void:
	print("[MainMenu] Cerrando aplicación.")
	get_tree().quit()


## Fondo pintado de la ciudad y tarjeta del menú con marco de cobre (assets/art).
func _apply_steam_skin() -> void:
	var backdrop_tex: Texture2D = ArtScript.tex("res://assets/art/bg/city.jpg")
	var color_bg: ColorRect = get_node_or_null("Background") as ColorRect
	if backdrop_tex != null:
		var picture: TextureRect = TextureRect.new()
		picture.name = "BackdropPicture"
		picture.texture = backdrop_tex
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.set_anchors_preset(Control.PRESET_FULL_RECT)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.modulate = Color(0.62, 0.58, 0.6, 1.0)
		add_child(picture)
		move_child(picture, color_bg.get_index() + 1 if color_bg != null else 0)
	var card: PanelContainer = get_node_or_null("CenterContainer/CardPanel") as PanelContainer
	if card != null:
		card.add_theme_stylebox_override("panel", SteamSkin.window_style())
		SteamSkin.skin_tree(card)
	var modal: Node = get_node_or_null("ModalCreate")
	if modal != null:
		SteamSkin.skin_tree(modal)
	var title: Label = get_node_or_null("CenterContainer/CardPanel/VBox/Title") as Label
	if title != null:
		title.add_theme_font_override("font", SteamSkin.title_font())
		title.add_theme_color_override("font_color", SteamSkin.COLOR_TITLE)
		title.add_theme_color_override("font_outline_color", SteamSkin.COLOR_OUTLINE)
		title.add_theme_constant_override("outline_size", 6)
