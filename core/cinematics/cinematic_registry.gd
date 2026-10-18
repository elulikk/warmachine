extends RefCounted
## Registro de comandos de cinemática: nombre del paso ("t") -> script del comando.
## Los comandos se cargan la primera vez que se usan y quedan cacheados (son objetos sin estado).

const BUILTIN: Dictionary = {
	# Flujo
	"wait": "res://core/cinematics/commands/wait.gd",
	"par": "res://core/cinematics/commands/par.gd",
	"seq": "res://core/cinematics/commands/seq.gd",
	"call": "res://core/cinematics/commands/call.gd",
	"goto": "res://core/cinematics/commands/goto.gd",
	# Pantalla
	"say": "res://core/cinematics/commands/say.gd",
	"dialogue": "res://core/cinematics/commands/dialogue.gd",
	"title": "res://core/cinematics/commands/title.gd",
	"fade": "res://core/cinematics/commands/fade.gd",
	"flash": "res://core/cinematics/commands/flash.gd",
	"bg": "res://core/cinematics/commands/bg.gd",
	"show": "res://core/cinematics/commands/show.gd",
	"hide": "res://core/cinematics/commands/hide.gd",
	# Mundo
	"spawn": "res://core/cinematics/commands/spawn.gd",
	"remove": "res://core/cinematics/commands/remove.gd",
	"move": "res://core/cinematics/commands/move.gd",
	"box": "res://core/cinematics/commands/box.gd",
	# Cámara
	"focus": "res://core/cinematics/commands/focus.gd",
	"release": "res://core/cinematics/commands/release.gd",
	"shake": "res://core/cinematics/commands/shake.gd",
	# Sonido
	"sfx": "res://core/cinematics/commands/sfx.gd",
}

static var _extra: Dictionary = {}
static var _cache: Dictionary = {}


## Registra (o reemplaza) un comando desde fuera del motor. `script` es un GDScript o la ruta a uno.
static func register(name: String, script: Variant) -> void:
	_extra[name] = script
	_cache.erase(name)


static func has(name: String) -> bool:
	return _extra.has(name) or BUILTIN.has(name)


## Instancia cacheada del comando, o null si no existe o no carga.
static func get_command(name: String) -> RefCounted:
	if _cache.has(name):
		return _cache[name] as RefCounted
	var src: Variant = _extra.get(name, BUILTIN.get(name, null))
	if src == null:
		return null
	var script: GDScript = src if src is GDScript else null
	if script == null and src is String and ResourceLoader.exists(src as String):
		script = load(src as String) as GDScript
	if script == null:
		push_error("Cinemática: no se pudo cargar el comando '%s' (%s)" % [name, str(src)])
		return null
	var cmd: RefCounted = script.new() as RefCounted
	_cache[name] = cmd
	return cmd


## Devuelve los problemas de una lista de pasos (vacío = todo bien). Recorre `par` y `seq`.
static func validate(steps: Array, path: String = "") -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	for i: int in steps.size():
		var where: String = "%s[%d]" % [path, i]
		var problem: String = check_step(steps[i])
		if not problem.is_empty():
			problems.append("%s %s" % [where, problem])
			continue
		var step: Dictionary = steps[i] as Dictionary
		var cmd: RefCounted = get_command(str(step["t"]))
		problems.append_array(validate(cmd.call("children", step) as Array, where + "." + str(step["t"])))
	return problems


## "" si el paso se puede ejecutar, si no el motivo.
static func check_step(step: Variant) -> String:
	if not step is Dictionary:
		return "no es un diccionario: %s" % str(step)
	var dict: Dictionary = step as Dictionary
	if not dict.has("t"):
		return "sin tipo ('t'): %s" % str(dict)
	var kind: String = str(dict["t"])
	var cmd: RefCounted = get_command(kind)
	if cmd == null:
		return "comando desconocido '%s'" % kind
	for key: String in cmd.call("required") as PackedStringArray:
		if not dict.has(key):
			return "'%s' necesita la clave '%s'" % [kind, key]
	var extra: String = str(cmd.call("check", dict))
	return "" if extra.is_empty() else "'%s': %s" % [kind, extra]
