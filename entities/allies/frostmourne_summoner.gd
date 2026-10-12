extends Node
## Invocador de la espada Frostmourne. Hijo del Player.
## Al matar un enemigo con la Frostmourne (golpe melee del jugador), alza un esqueleto aliado junto al cadáver.
## Lleva la cuenta de los esqueletos vivos: tope de 5 y penalidad de vida máxima (5 % de la base por esqueleto).
## Se engancha al HealthComponent de cada enemigo (hit_resolved): así sirve para cualquier clase de enemigo
## y no toca el WeaponManager ni los spawners.

const FROSTMOURNE_PATH: String = "res://data/weapons/frostmourne.tres"
const SKELETON_SCENE: PackedScene = preload("res://entities/allies/frostmourne_skeleton.tscn")
const MAX_SKELETONS: int = 5
## Fracción de la vida máxima BASE que quita cada esqueleto vivo (suma lineal).
const PENALTY_FRACTION: float = 0.05

var _stats: StatsManager = null
var _tree: SceneTree = null
var _alive: Array[Node] = []


func _ready() -> void:
	var player: Player = get_parent() as Player
	_stats = player.stats_manager if player != null else null
	_tree = get_tree()
	_tree.node_added.connect(_on_node_added)
	for enemy: Node in _tree.get_nodes_in_group(&"enemies"):
		for child: Node in enemy.get_children():
			_track_health(child)


func _exit_tree() -> void:
	if _tree != null and _tree.node_added.is_connected(_on_node_added):
		_tree.node_added.disconnect(_on_node_added)
	# Al salir del jugador se devuelve la penalidad y se libera lo que quedó vivo.
	var count: int = _alive.size()
	var living: Array[Node] = _alive.duplicate()
	_alive.clear()
	# Diferido: las señales de stats no deben llegar al HUD mientras el árbol se desarma.
	if count > 0 and _stats != null and is_instance_valid(_stats):
		_stats.call_deferred("add_modifier", "max_health", penalty_per_skeleton() * float(count))
	for skeleton: Node in living:
		if is_instance_valid(skeleton):
			skeleton.queue_free()


## Cantidad de vida máxima que quita un esqueleto (5 % de la base del jugador).
func penalty_per_skeleton() -> float:
	if _stats == null:
		return 0.0
	return _stats.base_max_health * PENALTY_FRACTION


func alive_count() -> int:
	return _alive.size()


func _on_node_added(node: Node) -> void:
	_track_health(node)


func _track_health(node: Node) -> void:
	if not node is HealthComponent:
		return
	var enemy: Node = node.get_parent()
	if enemy == null or not enemy.is_in_group(&"enemies") or node.has_meta(&"frostmourne_tracked"):
		return
	node.set_meta(&"frostmourne_tracked", true)
	node.hit_resolved.connect(_on_hit_resolved.bind(node))


## hit_resolved llega después de aplicar el daño: si el HealthComponent ya está muerto, este golpe fue el que mató.
func _on_hit_resolved(payload: HitPayload, _damage: float, _is_critical: bool, health: HealthComponent) -> void:
	if not health.is_dead or not _is_frostmourne_strike(payload):
		return
	_summon_at((health.get_parent() as Node2D).global_position)


func _is_frostmourne_strike(payload: HitPayload) -> bool:
	var player: Player = get_parent() as Player
	if player == null or payload == null or payload.source_node != player:
		return false
	if player.weapon_manager == null:
		return false
	var weapon: WeaponData = player.weapon_manager.current_weapon
	return weapon != null and weapon.weapon_type == WeaponData.WeaponType.MELEE and _is_frostmourne(weapon)


func _is_frostmourne(weapon: WeaponData) -> bool:
	var path: String = weapon.source_resource_path if not weapon.source_resource_path.is_empty() else weapon.resource_path
	return path == FROSTMOURNE_PATH


func _summon_at(pos: Vector2) -> void:
	if _alive.size() >= MAX_SKELETONS:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var skeleton: Node = SKELETON_SCENE.instantiate()
	skeleton.set(&"is_hired", true)
	_alive.append(skeleton)
	skeleton.connect(&"tree_exited", _on_skeleton_gone.bind(skeleton))
	_change_penalty(-penalty_per_skeleton())
	# Diferido: el golpe que mata llega dentro de una señal de física y AllyBase cambia la hurtbox al entrar.
	_add_skeleton.call_deferred(scene_root, skeleton, pos)
	print("[Frostmourne] Esqueleto invocado. Vivos: %d/%d" % [_alive.size(), MAX_SKELETONS])


func _add_skeleton(scene_root: Node, skeleton: Node, pos: Vector2) -> void:
	scene_root.add_child(skeleton)
	(skeleton as Node2D).global_position = pos


## Un esqueleto sale del árbol al morir o al liberarse la escena: se quita de la cuenta y vuelve la vida máxima.
func _on_skeleton_gone(skeleton: Node) -> void:
	if not _alive.has(skeleton):
		return
	_alive.erase(skeleton)
	_change_penalty(penalty_per_skeleton())


func _change_penalty(delta: float) -> void:
	if _stats == null or not is_instance_valid(_stats):
		return
	_stats.add_modifier("max_health", delta)
