extends RefCounted
## Botín de equipo de los enemigos: tira el dado de la `LootTable`, descarta lo que el jugador
## ya posee (o que sería peor que lo equipado) y deja el pickup en el suelo.
## Sin class_name a propósito: se carga por `preload` desde EnemyBase y BasicRunner.

const PICKUP_ITEM_SCENE: PackedScene = preload("res://entities/items/pickup_item.tscn")
const WEAPON_PICKUP_SCENE: PackedScene = preload("res://entities/items/weapon_pickup.tscn")


## Intenta soltar una pieza de equipo en la posición de `source`. No hace nada si la tabla no tiene
## equipo, si el nivel no lo habilita (`gear_loot_tier` 0) o si el dado no acompaña.
static func try_drop(source: Node2D, table: LootTable) -> void:
	if source == null or table == null or not source.is_inside_tree():
		return
	var tree: SceneTree = source.get_tree()
	if tree == null:
		return

	var container: Node = tree.current_scene
	if container == null:
		return

	var player: Player = tree.get_first_node_in_group(&"player") as Player
	var owned_paths: Dictionary = _collect_owned_paths(player)
	var is_excluded: Callable = _is_excluded.bind(player, owned_paths)

	# El escudo no depende del tier de botín: se tira aparte, antes de mirar el equipo del nivel
	if table.shield_item != null and randf() <= table.shield_chance and not is_excluded.call(table.shield_item):
		_spawn_pickup(table.shield_item, source.global_position + Vector2(0.0, -16.0), container)

	var tier: int = 0
	var tier_value: Variant = container.get("gear_loot_tier")
	if typeof(tier_value) == TYPE_INT:
		tier = int(tier_value)
	if tier <= 0:
		return

	var gear: Resource = table.roll_gear(tier, is_excluded)
	if gear == null:
		return

	_spawn_pickup(gear, source.global_position + Vector2(0.0, -16.0), container)


static func _spawn_pickup(gear: Resource, pos: Vector2, container: Node) -> void:
	var pickup: Node2D = null
	var weapon: WeaponData = gear as WeaponData
	var item: ItemData = gear as ItemData
	if weapon != null:
		var weapon_pickup: WeaponPickup = WEAPON_PICKUP_SCENE.instantiate() as WeaponPickup
		if weapon_pickup == null:
			return
		weapon_pickup.weapon_data = weapon
		weapon_pickup.allow_duplicates = true
		pickup = weapon_pickup
	elif item != null:
		var item_pickup: PickupItem = PICKUP_ITEM_SCENE.instantiate() as PickupItem
		if item_pickup == null:
			return
		item_pickup.item_data = item
		item_pickup.allow_duplicates = true
		pickup = item_pickup
	else:
		return

	pickup.global_position = pos
	container.add_child(pickup)

	# Salto de aparición: sube y cae a un costado, como el resto del botín piñata
	var side: float = randf_range(-26.0, 26.0)
	var tween: Tween = pickup.create_tween()
	tween.set_parallel(true)
	tween.tween_property(pickup, "global_position:x", pos.x + side, 0.4)
	tween.tween_property(pickup, "global_position:y", pos.y - 30.0, 0.2).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(pickup, "global_position:y", pos.y - 6.0, 0.2).set_ease(Tween.EASE_IN)
	print("[GearLoot] ¡Equipo dropeado: %s!" % (weapon.weapon_name if weapon != null else item.item_name))


## Rutas (.tres) de todo lo que el jugador posee: equipado, arsenal, mochila y baúl.
static func _collect_owned_paths(player: Player) -> Dictionary:
	var owned: Dictionary = {}
	if player == null:
		return owned

	if player.equipment_manager != null:
		for equipped: Variant in player.equipment_manager.equipped_items.values():
			var equipped_item: ItemData = equipped as ItemData
			if equipped_item != null and not equipped_item.resource_path.is_empty():
				owned[equipped_item.resource_path] = true

	if player.weapon_manager != null:
		for weapon: WeaponData in player.weapon_manager.weapons:
			if weapon != null and not weapon.source_resource_path.is_empty():
				owned[weapon.source_resource_path] = true

	if player.inventory_manager != null:
		for stored: Resource in player.inventory_manager.backpack:
			if stored == null:
				continue
			var path: String = stored.resource_path
			var stored_weapon: WeaponData = stored as WeaponData
			if stored_weapon != null and path.is_empty():
				path = stored_weapon.source_resource_path
			if not path.is_empty():
				owned[path] = true
	return owned


## true si la pieza no vale la pena: ya la tiene, está en el baúl o es de rareza igual o menor a lo equipado en su ranura.
static func _is_excluded(res: Resource, player: Player, owned_paths: Dictionary) -> bool:
	var path: String = res.resource_path
	if owned_paths.has(path):
		return true

	var sm: SaveManager = SaveManager.get_instance()
	if sm != null and not path.is_empty() and sm.stash_has_path(path):
		return true

	var item: ItemData = res as ItemData
	if item != null and player != null and player.equipment_manager != null:
		var equipped: ItemData = player.equipment_manager.get_equipped_item(player.equipment_manager.get_target_slot_for_item(item))
		if equipped != null and int(item.rarity) <= int(equipped.rarity):
			return true
	return false
