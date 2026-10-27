extends SceneTree
## Calcula los obstáculos sólidos de la decoración de los 8 sectores del Mundo 1 y los guarda en
## art_source/world1/decor_props.json. No corre en el juego: lo llama bake_decor_props.py, que los escribe en
## levels/chapter_1/level_1_0X.tscn como nodos `WorldProp` bajo el nodo `Props`.
##
## Uso directo: Godot --headless --path . -s res://art_source/world1/bake_decor_props.gd

const CityDecorScript = preload("res://levels/city_decor.gd")


func _initialize() -> void:
	var out: Dictionary = {}
	for n: int in range(1, 9):
		var path: String = "res://levels/chapter_1/level_1_%02d.tscn" % n
		var level: Node = (load(path) as PackedScene).instantiate()
		var solids: Array[Rect2] = _collect(level.get_node("Environment"))
		var plan: Array = CityDecorScript.plan_solids(level, solids)
		out[path] = plan
		level.free()
	var file: FileAccess = FileAccess.open("res://art_source/world1/decor_props.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "\t"))
	file.close()
	quit(0)


## Rectángulos de los sólidos del entorno (bloques con ColorRect), igual que `LevelSkin._collect_solids`.
func _collect(node: Node) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for child: Node in node.get_children():
		var body: StaticBody2D = child as StaticBody2D
		if body != null:
			var rect: ColorRect = body.get_node_or_null("ColorRect") as ColorRect
			if rect != null:
				var origin: Vector2 = body.position + Vector2(rect.offset_left, rect.offset_top)
				rects.append(Rect2(origin, Vector2(rect.offset_right - rect.offset_left, rect.offset_bottom - rect.offset_top)))
		rects.append_array(_collect(child))
	return rects
