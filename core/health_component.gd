class_name HealthComponent
extends Node
## Componente modular y desacoplado para la gestión de vitalidad y daño de entidades.
## Procesa instancias de HitPayload y emite señales de daño y fallecimiento.

signal health_changed(current_health: float, max_health: float)
signal shield_changed(current: float, max_shield: float)
signal shield_broken
signal damage_taken(amount: float, is_critical: bool, damage_type: String)
## Un impacto ya resuelto: con su payload (dirección del golpe) y el daño efectivo que entró a la vida.
signal hit_resolved(payload: HitPayload, damage: float, is_critical: bool)
signal died

const DamageFxScript = preload("res://combat/damage_fx.gd")
const DeathFxQueueScript = preload("res://combat/death_fx_queue.gd")

## Puntos de vida máximos de la entidad.
@export var max_health: float = 100.0

## Probabilidad base de recibir un impacto crítico fortuito (0.0 a 1.0).
@export var crit_chance: float = 0.20

@export_group("Defensas")
## Valor de armadura base para mitigar daño que entra a la vida.
@export var armor: float = 0.0

## Escudo de energía máximo que absorbe daño plano antes de la salud.
@export var max_shield: float = 0.0

## Tiempo de espera tras recibir daño para reiniciar la recarga del escudo (segundos).
@export var shield_recharge_delay: float = 3.5

## Velocidad de recarga de escudo por segundo.
@export var shield_recharge_rate: float = 25.0

var current_health: float = 0.0
var current_shield: float = 0.0
var recharge_timer: float = 0.0
var is_dead: bool = false


func _ready() -> void:
	current_health = max_health
	current_shield = max_shield
	if max_shield > 0.0:
		shield_changed.emit(current_shield, max_shield)
	# Diferido: los enemigos fijan su vida en su propio _ready, que corre después del de este hijo
	_apply_difficulty.call_deferred()
	_attach_damage_fx.call_deferred()


## Los enemigos muestran el daño que reciben (sangre, manchas en el piso y heridas): ver combat/damage_fx.gd.
func _attach_damage_fx() -> void:
	var host: Node = get_parent()
	if host == null or not host.is_in_group(&"enemies") or host.is_in_group(&"player"):
		return
	if host.has_node("DamageFx"):
		return
	var fx: Node = DamageFxScript.new()
	fx.name = "DamageFx"
	fx.set("health", self)
	host.add_child(fx)


## Escala la vida de los enemigos según la dificultad (Opciones > Juego). Una sola vez, al aparecer.
func _apply_difficulty() -> void:
	var host: Node = get_parent()
	if host == null or not host.is_in_group(&"enemies") or host.is_in_group(&"player"):
		return
	var mult: float = float((load("res://core/settings.gd") as GDScript).call("enemy_health_mult"))
	if is_equal_approx(mult, 1.0) or is_dead:
		return
	var ratio: float = current_health / maxf(max_health, 0.001)
	max_health *= mult
	current_health = max_health * ratio
	if "max_health" in host:
		host.set("max_health", max_health)
	if "current_health" in host:
		host.set("current_health", current_health)
	health_changed.emit(current_health, max_health)


func _process(delta: float) -> void:
	if is_dead:
		return
	
	if recharge_timer > 0.0:
		recharge_timer = maxf(0.0, recharge_timer - delta)
	elif current_shield < max_shield and max_shield > 0.0:
		current_shield = minf(max_shield, current_shield + shield_recharge_rate * delta)
		shield_changed.emit(current_shield, max_shield)


## Procesa un impacto generado por el sistema de combate mediante HitPayload.
func take_hit(payload: HitPayload) -> void:
	if is_dead or payload == null:
		return
	
	# 1. Reiniciar temporizador de recarga de escudo
	recharge_timer = shield_recharge_delay
	
	# Determinar si el golpe es crítico considerando estadísticas del atacante y arma
	var effective_crit_chance: float = crit_chance
	var effective_crit_mult: float = 1.5
	if payload.source_node is Player:
		var p: Player = payload.source_node as Player
		if p.stats_manager != null:
			effective_crit_chance = p.stats_manager.get_crit_chance()
			effective_crit_mult = p.stats_manager.get_crit_multiplier()
		if p.weapon_manager != null and p.weapon_manager.current_weapon != null:
			if p.weapon_manager.current_weapon.crit_multiplier > 1.0:
				effective_crit_mult = p.weapon_manager.current_weapon.crit_multiplier
	
	var is_crit: bool = payload.status_effects.has("critical") or (randf() < effective_crit_chance)
	var incoming_damage: float = payload.base_damage
	if is_crit:
		incoming_damage *= effective_crit_mult
	
	# Determinar elemento según status effects
	var damage_type: String = "PHYSICAL"
	for effect in payload.status_effects:
		match effect.to_lower():
			"fire", "burn":
				damage_type = "FIRE"
				break
			"ice", "freeze":
				damage_type = "ICE"
				break
	
	# 2. Daño a Escudo: absorbe el daño plano antes de tocar la vida
	var remaining_damage: float = incoming_damage
	if current_shield > 0.0:
		if remaining_damage <= current_shield:
			current_shield -= remaining_damage
			remaining_damage = 0.0
			shield_changed.emit(current_shield, max_shield)
		else:
			remaining_damage -= current_shield
			current_shield = 0.0
			shield_changed.emit(current_shield, max_shield)
			shield_broken.emit()
	
	var shield_absorbed: bool = max_shield > 0.0 and incoming_damage > 0.0 and remaining_damage <= 0.0
	
	# 3. Mitigación por Armadura (solo afecta daño que entra a la salud)
	var effective_armor: float = maxf(0.0, armor * (1.0 - payload.armor_penetration))
	var mitigation_mult: float = 100.0 / (100.0 + effective_armor)
	var final_damage: float = remaining_damage * mitigation_mult
	
	# 4. Aplicar daño a la salud y emitir señales
	if final_damage > 0.0:
		apply_damage(final_damage, is_crit, damage_type)
	else:
		# Si todo el daño fue absorbido por escudo
		damage_taken.emit(0.0, is_crit, damage_type)

	hit_resolved.emit(payload, final_damage, is_crit)

	# 5. Game feel: crítico = hit stop, golpe fuerte = screen shake (solo impactos del jugador)
	if payload.source_node is Player:
		GameFeel.on_player_hit(self, is_crit, final_damage)
	
	# 6. Sonido de impacto
	_play_hit_sound(payload, is_crit, final_damage, effective_armor, shield_absorbed)


## Sonido del impacto sobre un blanco no jugador. El jugador tiene su propio sonido en Player.take_damage.
## Si el arma del atacante define `hit_stream`, se usa ese audio en lugar del sintetizado.
func _play_hit_sound(payload: HitPayload, is_crit: bool, final_damage: float, effective_armor: float, shield_absorbed: bool) -> void:
	if payload.base_damage <= 0.0:
		return
	var entity: Node2D = get_parent() as Node2D
	if entity == null or entity.is_in_group(&"player"):
		return
	var pos: Vector2 = entity.global_position
	var melee_hit: bool = false
	if payload.source_node is Player:
		var p: Player = payload.source_node as Player
		if p.weapon_manager != null and p.weapon_manager.current_weapon != null:
			var weapon: WeaponData = p.weapon_manager.current_weapon
			if weapon.hit_stream != null:
				GameFeel.sfx_stream(self, weapon.hit_stream, pos)
				return
			melee_hit = weapon.weapon_type == WeaponData.WeaponType.MELEE

	var sound: StringName = &"hit_flesh"
	if shield_absorbed:
		sound = &"hit_shield"
	elif effective_armor >= 30.0 and final_damage > 0.0:
		sound = &"hit_armor"
	elif is_crit:
		sound = &"hit_crit"
	elif melee_hit:
		sound = &"hit_blade"
	GameFeel.sfx(self, sound, pos, -2.0, randf_range(0.94, 1.06))


## Aplica una cantidad específica de daño y emite las señales de notificación.
func apply_damage(amount: float, is_critical: bool = false, damage_type: String = "PHYSICAL") -> void:
	if is_dead:
		return
	
	var effective_damage: float = maxf(0.0, amount)
	current_health = maxf(0.0, current_health - effective_damage)
	
	damage_taken.emit(effective_damage, is_critical, damage_type)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0.0:
		die()


## Restaura puntos de vida limitados por max_health.
func heal(amount: float) -> void:
	if is_dead:
		return
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)


## Gestiona la muerte de la entidad emitiendo la señal died.
func die() -> void:
	if is_dead:
		return
	is_dead = true
	_play_death_feedback()
	died.emit()


## Explosión de partículas y sonido al eliminar una entidad hostil (excluye jugador y aliados).
func _play_death_feedback() -> void:
	var entity: Node2D = get_parent() as Node2D
	if entity == null or entity.is_in_group(&"player") or entity.is_in_group(&"allies"):
		return
	# Encolado: si mueren muchos juntos se reparte en los cuadros siguientes (combat/death_fx_queue.gd)
	DeathFxQueueScript.burst(self, entity.global_position + Vector2(0.0, -16.0))
	GameFeel.shake(self, 2.5, 0.12)


## Retorna el porcentaje de mitigación de daño que provee la armadura actual.
func get_mitigation_percentage() -> float:
	return (armor / (100.0 + armor)) * 100.0
