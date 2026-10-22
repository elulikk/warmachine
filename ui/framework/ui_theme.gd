extends Resource
## Tema visual de la interfaz: TODOS los gráficos, colores y tipografías de la UI salen de acá.
## Sin class_name a propósito: se usa por `preload` (ver SteamSkin, UiKit y GameWindow).
##
## Cambiar el aspecto del juego:
##   - Retoque: abrir `ui/themes/steam_theme.tres` en el inspector y cambiar colores, fuentes o texturas.
##   - Reemplazar una textura puntual: agregarla en `texture_overrides` ("win_frame.png" -> otra imagen).
##   - Tema entero nuevo: duplicar el .tres (otra carpeta de texturas con los mismos nombres de archivo)
##     y cambiar `ACTIVE_PATH`, o llamar a `UiTheme.use(tema)` antes de construir la UI.
## Si el .tres falta o no carga, se usan los valores por defecto de este script (aspecto steampunk).

const ACTIVE_PATH: String = "res://ui/themes/steam_theme.tres"
const SELF_PATH: String = "res://ui/framework/ui_theme.gd"
const ArtScript = preload("res://core/art/art.gd")

@export_group("Texturas")
## Carpeta de las texturas 9-slice. Archivos que se leen: win_frame, inset_dark, slot_leather, parchment,
## btn_copper, btn_dark, btn_plate, slot_screws, slot_dark, bar_under, bar_fill, close_btn (.png).
@export_dir var texture_dir: String = "res://assets/art/ui/"
## Reemplazos puntuales: nombre de archivo (p. ej. "win_frame.png") -> textura.
@export var texture_overrides: Dictionary = {}

@export_group("Colores")
@export var text: Color = Color(0.96, 0.88, 0.70, 1.0)
@export var text_dim: Color = Color(0.74, 0.64, 0.50, 1.0)
@export var gold: Color = Color(1.0, 0.82, 0.36, 1.0)
@export var title: Color = Color(0.98, 0.86, 0.60, 1.0)
@export var outline: Color = Color(0.10, 0.06, 0.04, 1.0)
@export var parchment_text: Color = Color(0.20, 0.12, 0.06, 1.0)
@export var wood: Color = Color(0.23, 0.16, 0.13, 1.0)
@export var copper: Color = Color(0.72, 0.43, 0.28, 1.0)
## Valores buenos / malos (bonos, daño recibido, alertas).
@export var good: Color = Color(0.55, 0.88, 0.45, 1.0)
@export var bad: Color = Color(0.95, 0.42, 0.32, 1.0)
## Tinte de lo bloqueado o sin descubrir (siluetas del códice).
@export var locked: Color = Color(0.05, 0.035, 0.03, 0.9)
## Fila seleccionada en listas.
@export var selected: Color = Color(1.0, 0.82, 0.36, 0.22)

@export_group("Tipografía")
## Fuente de títulos; vacía = la primera que exista de `title_font_names`.
@export var title_font: Font = null
@export var title_font_names: PackedStringArray = PackedStringArray(["Georgia", "Cambria", "Palatino Linotype", "Book Antiqua", "Times New Roman", "Serif"])
## Fuente del texto común; vacía = la del proyecto.
@export var body_font: Font = null
@export var size_big: int = 16
@export var size_title: int = 13
@export var size_header: int = 12
@export var size_body: int = 10
@export var size_small: int = 9

static var _current: Resource = null
var _title_font_cache: Font = null


## Tema activo (se carga una vez).
static func current() -> Resource:
	if _current == null:
		if ResourceLoader.exists(ACTIVE_PATH):
			_current = load(ACTIVE_PATH)
		if _current == null:
			_current = (load(SELF_PATH) as GDScript).new()
	return _current


## Cambia el tema activo. Las ventanas ya construidas conservan su aspecto hasta reconstruirse.
static func use(theme: Resource) -> void:
	_current = theme


## Textura de la carpeta del tema, o su reemplazo puntual. null si no existe (los estilos caen a planos).
func texture(file: String) -> Texture2D:
	if texture_overrides.has(file) and texture_overrides[file] is Texture2D:
		return texture_overrides[file] as Texture2D
	return ArtScript.tex(texture_dir.path_join(file))


func get_title_font() -> Font:
	if title_font != null:
		return title_font
	if _title_font_cache == null:
		var system: SystemFont = SystemFont.new()
		system.font_names = title_font_names
		system.font_weight = 700
		system.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_title_font_cache = system
	return _title_font_cache
