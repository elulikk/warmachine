extends RefCounted
## Nivel de los enemigos (`enemy_level` en su escena): marca la jerarquía y decide cuándo ya no dan experiencia.
## El nivel efectivo suma el desvío del nivel de juego (`LevelBase.get_enemy_level_offset`: los mundos 2 a 5 reusan los
## enemigos del mundo 1 con un nivel más alto). Un enemigo `NO_EXP_LEVEL_GAP` niveles o más por debajo del jugador no suelta
## experiencia. Sin class_name a propósito: se carga por `preload`.

## Con esta diferencia de niveles (jugador − enemigo) o más, el enemigo no da experiencia.
const NO_EXP_LEVEL_GAP: int = 4


## Nivel del enemigo en el nivel de juego actual.
static func effective_level(host: Node) -> int:
	var level: int = int(host.get("enemy_level")) if host.get("enemy_level") != null else 1
	var scene: Node = host.get_tree().current_scene if host.is_inside_tree() else null
	if scene != null and scene.has_method("get_enemy_level_offset"):
		level += int(scene.call("get_enemy_level_offset"))
	return maxi(level, 1)


## Nombre con el nivel para la barra de vida: "Matón · Nv.3".
static func display_name(host: Node) -> String:
	return "%s · Nv.%d" % [str(host.get("entity_name")), effective_level(host)]


## ¿Este enemigo suelta experiencia al jugador actual?
static func gives_exp(host: Node) -> bool:
	if not host.is_inside_tree():
		return true
	var player: Node = host.get_tree().get_first_node_in_group(&"player")
	if player == null or player.get("stats_manager") == null:
		return true
	var player_level: int = int(player.get("stats_manager").get("level"))
	return player_level - effective_level(host) < NO_EXP_LEVEL_GAP
