class_name WeaponData
extends Resource
## Recurso de datos fuertemente tipado que define las características balísticas y mecánicas de un arma.

enum WeaponType { RANGED, MELEE }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

signal runes_changed

@export_group("Economía y Rareza")
@export var rarity: Rarity = Rarity.COMMON
@export var gold_value: int = 50
@export_multiline var description: String = ""

@export_group("Identificación")
## Ruta de origen del recurso (.tres) para persistencia tras duplicate().
@export var source_resource_path: String = ""

## Nombre legible del arma.
@export var weapon_name: String = "Arma"

## Tipo de arma (RANGED: balística con proyectiles / MELEE: cuerpo a cuerpo con tajo).
@export var weapon_type: WeaponType = WeaponType.RANGED

## Indica si el arma dispara en ráfaga continua manteniendo presionado el gatillo (automática)
## o si requiere una pulsación por disparo (semiautomática).
@export var is_automatic: bool = false

@export_group("Melee")
## Arco angular del tajo en grados sexagesimales (por defecto 110°).
@export var swing_arc_degrees: float = 110.0

## Duración en segundos del recorrido del tajo cuerpo a cuerpo.
@export var swing_duration: float = 0.16

## Multiplicador de daño crítico al impactar (por defecto 1.5, katana usa 2.0).
@export var crit_multiplier: float = 1.5

## Multiplicador del alcance y tamaño del hitbox del tajo (1.0 = estándar; el cuchillo usa menos).
@export var melee_hitbox_scale: float = 1.0

## Impulso horizontal de carrera inyectado al jugador al golpear (Katana: 380 px/s).
@export var melee_dash_impulse: float = 0.0

## Duración de intangibilidad/fase contra enemigos al realizar el tajo (Katana: 0.15s).
@export var melee_phase_duration: float = 0.0

## Si es true, al ejecutar o conectar el ataque genera una onda de choque en el suelo (Martillo Pesado).
@export var creates_ground_shockwave: bool = false
@export var shockwave_scene: PackedScene = null

@export_group("Balística y Combate")
## Daño base que infligirá cada proyectil disparado.
@export var damage: float = 20.0

## Cadencia de disparo expresada en disparos por segundo (tiros/segundo).
@export var fire_rate: float = 4.0

## Empuje que sufre el enemigo al ser golpeado (px/s aprox. = valor x 0.75; los enemigos pesados lo reducen).
## 0 = automático: retroceso del arma x 1.5 en rango, 160 en melee.
@export var knockback_force: float = 0.0

## Fuerza de retroceso físico aplicada en dirección opuesta al apuntado sobre el portador (píxeles/segundo).
@export var recoil_force: float = 60.0

## Velocidad lineal del proyectil en píxeles/segundo.
@export var projectile_speed: float = 520.0

## Cantidad de penetración de armadura (0.0 = 0%, 1.0 = 100%).
@export var armor_penetration: float = 0.0

## Tamaño del cargador; si es <= 0 o arma MELEE, no requiere recarga.
@export var magazine_size: int = 12

## Tiempo en segundos para recargar.
@export var reload_time: float = 1.4

## Cantidad de proyectiles disparados simultáneamente por disparo (ej. 5 para escopeta).
@export var pellets_per_shot: int = 1

## Dispersión angular total en grados (ej. 30.0 para +/- 15°).
@export var spread_angle_degrees: float = 0.0

## Cantidad de perforaciones innatas a enemigos que atraviesa el proyectil.
@export var innate_pierce: int = 0

## Escena del proyectil que será instanciada en cada disparo.
@export var projectile_scene: PackedScene

## Efectos de estado innatos transmitidos por los proyectiles de esta arma (ej: ["ICE"]).
@export var innate_status_effects: Array[String] = []

@export_group("Sockets y Runas")
## Cantidad máxima de ranuras de engarce disponibles para runas.
@export var max_sockets: int = 3

## Lista de runas actualmente engarzadas en este arma.
@export var socketed_runes: Array[RuneData] = []



@export_group("Sonido")
## Sonido real de disparo o tajo. Si es null se usa el efecto 8-bit sintetizado según las stats del arma.
@export var fire_stream: AudioStream = null

## Sonido real al impactar a un enemigo. Si es null se usa el efecto 8-bit según el blanco.
@export var hit_stream: AudioStream = null


## Retorna el tiempo de enfriamiento (cooldown en segundos) entre disparos consecutivos.
func get_fire_interval() -> float:
	return 1.0 / maxf(0.01, fire_rate)


## Valida si la runa puede ser engarzada (espacio disponible y tipo de arma compatible).
func can_socket_rune(rune: RuneData) -> bool:
	if rune == null:
		return false
	if socketed_runes.size() >= max_sockets:
		return false
	if not rune.allowed_weapon_types.has(weapon_type):
		return false
	return true


## Engarza una runa en el arma si cumple con las restricciones de compatibilidad y cupo.
func socket_rune(rune: RuneData) -> bool:
	if not can_socket_rune(rune):
		return false
	socketed_runes.append(rune)
	runes_changed.emit()
	return true


## Desengarza y vacía todas las runas del arma, retornándolas como array.
func clear_sockets() -> Array[RuneData]:
	var removed: Array[RuneData] = []
	for r in socketed_runes:
		if r != null:
			removed.append(r)
	socketed_runes.clear()
	runes_changed.emit()
	return removed


## Retorna la suma total de daño plano adicional conferido por las runas.
func get_total_bonus_damage() -> float:
	var total: float = 0.0
	for rune in socketed_runes:
		if rune != null:
			total += rune.bonus_damage
	return total


## Retorna el daño base del arma incrementado por el daño de las runas.
func get_effective_damage() -> float:
	return damage + get_total_bonus_damage()


## Retorna el total de rebotes contra paredes acumulados de todas las runas.
func get_total_bounces() -> int:
	var total: int = 0
	for rune in socketed_runes:
		if rune != null:
			total += rune.extra_bounces
	return total


## Retorna el total de enemigos perforables acumulados (innatos + runas).
func get_total_pierce() -> int:
	var total: int = innate_pierce
	for rune in socketed_runes:
		if rune != null:
			total += rune.extra_pierce
	return total


## Retorna el total de bifurcaciones en impacto acumuladas de todas las runas.
func get_total_forks() -> int:
	var total: int = 0
	for rune in socketed_runes:
		if rune != null:
			total += rune.extra_forks
	return total


## Retorna la lista de todas las infusiones elementales (innatas + runas).
func get_elemental_infusions() -> Array[String]:
	var infusions: Array[String] = []
	for eff in innate_status_effects:
		if not infusions.has(eff):
			infusions.append(eff)
	for rune in socketed_runes:
		if rune != null and not rune.elemental_infusion.is_empty():
			if not infusions.has(rune.elemental_infusion):
				infusions.append(rune.elemental_infusion)
	return infusions


## Calcula y retorna el DPS sostenido del arma considerando ciclo de disparo y recarga.
func get_current_sustained_dps() -> float:
	var eff_dmg: float = get_effective_damage()
	if weapon_type == WeaponType.RANGED and magazine_size > 0:
		var safe_rate: float = maxf(0.01, fire_rate)
		var cycle_time: float = (float(magazine_size) / safe_rate) + reload_time
		var total_cycle_damage: float = float(magazine_size) * eff_dmg * float(maxi(1, pellets_per_shot))
		return total_cycle_damage / maxf(0.01, cycle_time)
	else:
		return eff_dmg * fire_rate


## Retorna el texto representativo de daño por disparo (ej: "5 x 12" si hay múltiples perdigones, o "25" plano).
func get_damage_per_shot_text() -> String:
	var eff_dmg: float = get_effective_damage()
	var dmg_str: String = str(roundi(eff_dmg)) if is_equal_approx(eff_dmg, roundf(eff_dmg)) else "%.1f" % eff_dmg
	if pellets_per_shot > 1:
		return "%d x %s" % [pellets_per_shot, dmg_str]
	return dmg_str


## Retorna el cálculo de DPS sostenido del arma considerando ciclo y recarga.
func get_sustained_dps() -> float:
	return get_current_sustained_dps()

