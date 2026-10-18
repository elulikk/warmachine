class_name BaseCamp
extends Node2D
const LevelSkinScript = preload("res://levels/level_skin.gd")
## La Caja (hub).
## Pasillo de puertas: cada puerta es un mundo. Adentro está el campamento: descanso y reabastecimiento entre expediciones.
## Contiene al jugador, el baúl ilimitado (StashChest), el herrero (BlacksmithNPC) y la terminal de expediciones (MapSelector).

@onready var player: Player = $Player
@onready var stash_window: StashWindow = $UI/StashWindow
@onready var blacksmith_window: BlacksmithWindow = get_node_or_null("UI/BlacksmithWindow") as BlacksmithWindow
@onready var banner_label: Label = get_node_or_null("%BannerLabel") as Label


func _ready() -> void:
	LevelSkinScript.apply(self, 0, "box_corridor.jpg")
	GameFeel.music_set_base(self, &"camp")
	# Asegurar que el estado del juego sea PLAYING y no pausado
	get_tree().paused = false
	if GameManager != null:
		GameManager.current_state = GameManager.GameState.PLAYING
	
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		var preview: Dictionary = sm.get_slot_preview(sm.current_slot)
		if bool(preview.get("exists", false)):
			sm.load_from_disk(sm.current_slot)
		
		var hud: HUD = get_tree().get_first_node_in_group(&"hud") as HUD
		if hud == null:
			hud = get_node_or_null("HUD") as HUD
		if hud != null and player != null:
			hud.setup_with_player(player)
		
		# En el campamento ya no hay sector a medias
		SaveManager.clear_resume_point()
		# Guardar estado consolidado luego de aplicar al jugador
		sm.save_to_disk()
		
		if banner_label != null:
			banner_label.text = "LA CAJA // OPERADOR: %s" % sm.character_name.to_upper()
		
		print("[BaseCamp] Ingreso al campamento base. Operador: %s. Estado guardado a disco." % sm.character_name)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		var inv_win: InventoryWindow = get_tree().get_first_node_in_group(&"inventory_window") as InventoryWindow
		if inv_win != null:
			get_viewport().set_input_as_handled()
			inv_win.toggle_window()
