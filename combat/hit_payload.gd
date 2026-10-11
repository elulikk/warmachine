class_name HitPayload
extends RefCounted
## Payload inmutable de datos transferido durante un evento de combate (impacto).
## Diseñado para transportar información sobre daño, retroceso (knockback),
## entidad causante y efectos de estado alterados aplicables al objetivo.

## Cantidad de daño base que inflige el golpe antes de mitigaciones o resistencias.
var base_damage: float = 0.0

## Magnitud de la fuerza aplicada para empujar o desplazar al objetivo.
var knockback_force: float = 0.0

## Vector de dirección normalizado en el que se aplicará el retroceso.
var knockback_direction: Vector2 = Vector2.ZERO

## Referencia al nodo de origen que originó el impacto (proyectil, atacante, trampa, etc.).
var source_node: Node2D = null

## Lista de identificadores de efectos de estado aplicables (ej: "bleed", "stun", "burn", "FIRE", "ICE").
var status_effects: Array[String] = []

## Cantidad de acumulaciones/cargas de estado que inyecta este impacto (por defecto 1).
var status_stacks_to_apply: int = 1

## Daño base por ciclo/tick para efectos periódicos (DoT).
var base_tick_damage: float = 3.0


## Cantidad de penetración de armadura (0.0 = 0%, 1.0 = 100%).
var armor_penetration: float = 0.0

## Duración personalizada del estado ICE en segundos (0.0 = usar valor por defecto del receptor).
var ice_duration: float = 0.0

## Multiplicador de velocidad restante bajo ICE (0.2 = 80% de ralentización; 0.0 = usar valor por defecto).
var ice_speed_multiplier: float = 0.0


func _init(
	p_base_damage: float = 0.0,
	p_knockback_force: float = 0.0,
	p_knockback_direction: Vector2 = Vector2.ZERO,
	p_source_node: Node2D = null,
	p_status_effects: Array[String] = [],
	p_status_stacks_to_apply: int = 1,
	p_base_tick_damage: float = 3.0,
	p_armor_penetration: float = 0.0
) -> void:
	base_damage = p_base_damage
	knockback_force = p_knockback_force
	knockback_direction = p_knockback_direction.normalized() if p_knockback_direction != Vector2.ZERO else Vector2.ZERO
	source_node = p_source_node
	status_effects = p_status_effects
	status_stacks_to_apply = p_status_stacks_to_apply
	base_tick_damage = p_base_tick_damage
	armor_penetration = p_armor_penetration


## Devuelve el vector de fuerza de retroceso completo (dirección * magnitud).
func get_knockback_velocity() -> Vector2:
	return knockback_direction * knockback_force


## Helper para clonar el payload si requiere ser modificado por buffs o perks en vuelo.
func duplicate_payload() -> HitPayload:
	var cloned_effects: Array[String] = []
	cloned_effects.append_array(status_effects)
	var cloned: HitPayload = HitPayload.new(
		base_damage,
		knockback_force,
		knockback_direction,
		source_node,
		cloned_effects,
		status_stacks_to_apply,
		base_tick_damage,
		armor_penetration
	)
	cloned.ice_duration = ice_duration
	cloned.ice_speed_multiplier = ice_speed_multiplier
	return cloned

