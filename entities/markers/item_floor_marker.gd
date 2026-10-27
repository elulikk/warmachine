extends Node2D
## Marcador de ítem al piso configurable desde el editor.
## Colócalo en el nivel, asignale un recurso (WeaponData, ItemData o RuneData)
## desde el Inspector, y al iniciar la escena instancia el pickup correspondiente
## en la posición del nodo. El nodo marcador se elimina tras instanciar el pickup.
##
## Usos:
##   - WeaponData  → instancia weapon_pickup.tscn
##   - RuneData    → instancia rune_pickup.tscn
##   - ItemData    → instancia pickup_item.tscn

const WeaponPickupScene: PackedScene = preload("res://entities/items/weapon_pickup.tscn")
const PickupItemScene: PackedScene = preload("res://entities/items/pickup_item.tscn")
const RunePickupScene: PackedScene = preload("res://entities/items/rune_pickup.tscn")

## Recurso del pickup. Puede ser WeaponData, ItemData o RuneData.
@export var pickup_data: Resource = null

## Si es false el pickup desaparece si el jugador ya lo tiene (para objetos únicos de campaña).
@export var allow_duplicates: bool = false


func _ready() -> void:
	if pickup_data == null:
		push_warning("[ItemFloorMarker] '%s' no tiene pickup_data asignado." % name)
		return
	# Diferimos el spawn: _ready() puede ocurrir mientras el padre aún inicializa hijos,
	# y add_child() directa fallaría con "Parent node is busy setting up children".
	_spawn_deferred.call_deferred()


func _spawn_deferred() -> void:
	if pickup_data == null:
		return

	var container: Node = get_tree().current_scene
	if container == null:
		container = owner if owner != null else get_parent()

	var instance: Node2D = _build_pickup()
	if instance == null:
		push_warning("[ItemFloorMarker] '%s': el recurso '%s' no es WeaponData, ItemData ni RuneData." % [name, pickup_data.resource_path])
		return

	instance.global_position = global_position
	container.add_child(instance)
	print("[ItemFloorMarker] '%s' spawneó pickup en %s." % [name, global_position])

	# El marcador ya cumplió su rol; se elimina para no contaminar la escena
	queue_free()


func _build_pickup() -> Node2D:
	if pickup_data is WeaponData:
		var p: WeaponPickup = WeaponPickupScene.instantiate() as WeaponPickup
		p.weapon_data = pickup_data as WeaponData
		p.allow_duplicates = allow_duplicates
		return p

	if pickup_data is RuneData:
		var p: RunePickup = RunePickupScene.instantiate() as RunePickup
		p.rune_data = pickup_data as RuneData
		return p

	if pickup_data is ItemData:
		var p: PickupItem = PickupItemScene.instantiate() as PickupItem
		p.item_data = pickup_data as ItemData
		p.allow_duplicates = allow_duplicates
		return p

	return null
