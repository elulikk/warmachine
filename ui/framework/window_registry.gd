extends RefCounted
## Registro de ventanas modulares. El HUD llama a `install(self)` y crea todas las de `WINDOWS`
## (existe en cada nivel y en el campamento). Agregar una ventana = sumar su script a la lista.
## Desde cualquier lado (botón, menú, NPC, tecla): `WindowRegistry.open(get_tree(), &"codex")`.

const WINDOWS: Array[Script] = [
	preload("res://ui/windows/codex_window.gd"),
]


static func install(parent: Node) -> void:
	for script: Script in WINDOWS:
		var window: Node = script.new()
		parent.add_child(window)


static func find(tree: SceneTree, id: StringName) -> Control:
	return tree.get_first_node_in_group(StringName("window_%s" % id)) as Control


static func open(tree: SceneTree, id: StringName) -> bool:
	var window: Control = find(tree, id)
	if window == null:
		return false
	window.call("open_window")
	return true


static func toggle(tree: SceneTree, id: StringName) -> bool:
	var window: Control = find(tree, id)
	if window == null:
		return false
	window.call("toggle_window")
	return true


static func close_all(tree: SceneTree) -> void:
	for window: Node in tree.get_nodes_in_group(&"game_windows"):
		if (window as Control).visible:
			window.call("close_window")
