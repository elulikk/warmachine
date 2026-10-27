extends Node
## Avisos de vida baja del jugador: borde rojo en pantalla que crece al bajar la vida y latido en bucle
## cuando la vida está en el tramo crítico y el escudo vacío. Lo agrega Player en `_ready`.
## Sin class_name a propósito: se carga por preload (ver class-name-cache-gotcha).
##
## - Borde rojo: aparece por debajo de VIGNETTE_START (fracción de vida) y llega al máximo con la vida en 0.
##   Se dibuja en el posprocesado (`core/post_fx.gd`, uniforme `danger`). Con "reducir destellos" no pulsa.
## - Latido: por debajo de HEARTBEAT_START y con el escudo vacío. Vida 0 es la muerte, así que empieza antes;
##   el intervalo baja de HEARTBEAT_SLOW a HEARTBEAT_FAST cuanto menos vida queda.

const VIGNETTE_START: float = 0.6
const HEARTBEAT_START: float = 0.3
const HEARTBEAT_SLOW: float = 1.1
const HEARTBEAT_FAST: float = 0.45

var _player: Player = null
var _settings: GDScript = load("res://core/settings.gd") as GDScript
var _post_fx: Node = null
var _beat_left: float = 0.0
var _pulse_time: float = 0.0


func _ready() -> void:
	_player = get_parent() as Player


func _exit_tree() -> void:
	_push_danger(0.0)


func _process(delta: float) -> void:
	if _player == null or _player.stats_manager == null:
		return
	var max_hp: float = maxf(1.0, _player.stats_manager.get_max_health())
	var ratio: float = clampf(_player.stats_manager.current_health / max_hp, 0.0, 1.0)
	var dead: bool = _player.health_component != null and _player.health_component.is_dead

	# Borde rojo: 0 con vida >= VIGNETTE_START, 1 con vida 0
	var danger: float = clampf((VIGNETTE_START - ratio) / VIGNETTE_START, 0.0, 1.0)
	if danger > 0.0 and not bool(_settings.call("reduce_flashes")):
		_pulse_time += delta * lerpf(2.0, 5.0, danger)
		danger *= 0.85 + 0.15 * sin(_pulse_time)
	_push_danger(danger)

	# Latido: vida crítica y escudo vacío
	var shield_empty: bool = _player.health_component == null or _player.health_component.current_shield <= 0.0
	if dead or ratio > HEARTBEAT_START or not shield_empty:
		_beat_left = 0.0
		return
	_beat_left -= delta
	if _beat_left <= 0.0:
		var critical: float = clampf(1.0 - ratio / HEARTBEAT_START, 0.0, 1.0)
		_beat_left = lerpf(HEARTBEAT_SLOW, HEARTBEAT_FAST, critical)
		GameFeel.sfx(self, &"heartbeat", Vector2.INF, lerpf(-6.0, -1.0, critical))


func _push_danger(amount: float) -> void:
	if _post_fx == null or not is_instance_valid(_post_fx):
		_post_fx = get_tree().root.get_node_or_null("SettingsHost/PostFx") if is_inside_tree() else null
	if _post_fx != null:
		_post_fx.call("set_danger", amount)
