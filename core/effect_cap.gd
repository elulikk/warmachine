extends RefCounted
## Tope de efectos persistentes del mismo tipo (nubes de gas, charcos de fuego, redes...): al pasarse, el más viejo
## se apaga con un desvanecido corto. Protege contra la lluvia de granadas y los lanzallamas en ráfaga.
## Sin class_name a propósito: se usa por `preload`.
##
## El efecto debe tener un método `expire()` (si no, se libera sin más).

static var _lists: Dictionary = {}


static func register(key: StringName, node: Node, max_alive: int) -> void:
	var list: Array = _lists.get(key, [])
	list.append(node)
	_lists[key] = list
	node.tree_exiting.connect(_forget.bind(key, node), CONNECT_ONE_SHOT)
	while list.size() > max_alive:
		var oldest: Variant = list.pop_front()
		if not is_instance_valid(oldest):
			continue
		if (oldest as Object).has_method("expire"):
			(oldest as Object).call("expire")
		else:
			(oldest as Node).queue_free()


static func count(key: StringName) -> int:
	return (_lists.get(key, []) as Array).size()


static func _forget(key: StringName, node: Node) -> void:
	var list: Array = _lists.get(key, [])
	list.erase(node)
