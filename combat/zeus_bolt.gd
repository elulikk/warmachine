extends Projectile
## Rayo de Zeus: proyectil rapidísimo. Al pegarle a un enemigo descarga un rayo en cadena que salta entre los
## cercanos (el mismo de Mjolnir) además del estallido eléctrico de `impact_scene`.

const ChainLightning = preload("res://combat/chain_lightning.gd")

@export var chain_bounces: int = 5
@export var chain_damage_mult: float = 0.6
@export var chain_range: float = 280.0


func _handle_collision(target: Node) -> void:
	var already: bool = _has_impacted
	super._handle_collision(target)
	if already or payload == null or not _has_impacted:
		return
	var receiver: Node = target
	if not receiver.has_method("take_hit") and receiver.get_parent() != null:
		receiver = receiver.get_parent()
	if receiver is Node2D and receiver.is_in_group(&"enemies"):
		ChainLightning.spawn(self, receiver as Node2D, payload.source_node, payload.base_damage * chain_damage_mult,
				chain_bounces, chain_range)
