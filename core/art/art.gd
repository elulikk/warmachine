extends RefCounted
## Carga de arte del proyecto (assets/art). Sin class_name: se usa por `preload`.
##
## `load()` solo funciona con texturas ya importadas por el editor, y `run.bat` arranca el juego sin
## pasar por el editor. Por eso, si el PNG no está importado, se lee directo del disco y se arma la textura
## en memoria (mismo criterio que la música con `AudioStreamOggVorbis.load_from_file`).

static var _cache: Dictionary = {}


## Textura PNG/JPG del proyecto o null si no existe. Cachea el resultado (también los fallos).
static func tex(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _cache.has(path):
		return _cache[path] as Texture2D

	var result: Texture2D = null
	if ResourceLoader.exists(path):
		result = load(path) as Texture2D
	if result == null and FileAccess.file_exists(path):
		var image: Image = Image.load_from_file(path)
		if image != null and not image.is_empty():
			result = ImageTexture.create_from_image(image)
	_cache[path] = result
	return result


## Atajo para un archivo dentro de `res://assets/art/`.
static func art(sub_path: String) -> Texture2D:
	return tex("res://assets/art/" + sub_path)
