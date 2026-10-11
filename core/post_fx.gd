extends Node
## Posprocesado de pantalla, colgado del preajuste de calidad (ver `QUALITY_PRESETS` en `core/settings.gd`).
## Sin class_name: lo crea `SettingsHost` con `load()` y vive bajo la raíz (también en pausa y entre escenas).
##
## Dos capas con un `ColorRect` que lee la pantalla (`hint_screen_texture`, funciona en `gl_compatibility`):
## - **Mundo** (capa 1, debajo del HUD que está en la 2): viñeta, grano de película y resplandor (bloom barato
##   de 12 muestras sobre lo brillante). Solo tiñe el juego, no la interfaz.
## - **Daltonismo** (capa 250, sobre todo, incluida la ventana de opciones): corrección por daltonización (LMS)
##   para protanopia, deuteranopia o tritanopia, con intensidad ajustable.
## Si un efecto está apagado su capa se oculta y no cuesta nada.

const WORLD_LAYER: int = 1
const COLORBLIND_LAYER: int = 250

const WORLD_SHADER: String = """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vignette = 0.0;
uniform float grain = 0.0;
uniform float bloom = 0.0;
uniform float seed = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;
	if (bloom > 0.0) {
		vec3 acc = vec3(0.0);
		vec2 px = SCREEN_PIXEL_SIZE;
		for (int i = 0; i < 12; i++) {
			float a = float(i) * 0.5235988;
			float r = (i % 2 == 0) ? 5.0 : 10.0;
			vec3 s = texture(screen_tex, uv + vec2(cos(a), sin(a)) * px * r).rgb;
			acc += max(s - vec3(0.62), vec3(0.0));
		}
		col += acc / 12.0 * bloom * 2.2;
	}
	if (vignette > 0.0) {
		vec2 d = (uv - 0.5) * vec2(1.0, 0.82);
		col *= 1.0 - vignette * smoothstep(0.28, 0.78, length(d) * 1.35);
	}
	if (grain > 0.0) {
		float n = fract(sin(dot(uv * vec2(1280.0, 720.0) + seed, vec2(12.9898, 78.233))) * 43758.5453);
		col += (n - 0.5) * grain;
	}
	COLOR = vec4(col, 1.0);
}
"""

const COLORBLIND_SHADER: String = """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform int mode = 0;
uniform float strength = 1.0;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float L = 17.8824 * c.r + 43.5161 * c.g + 4.11935 * c.b;
	float M = 3.45565 * c.r + 27.1554 * c.g + 3.86714 * c.b;
	float S = 0.0299566 * c.r + 0.184309 * c.g + 1.46709 * c.b;
	if (mode == 1) {
		L = 2.02344 * M - 2.52581 * S;
	} else if (mode == 2) {
		M = 0.494207 * L + 1.24827 * S;
	} else if (mode == 3) {
		S = -0.395913 * L + 0.801109 * M;
	}
	vec3 sim = vec3(
		0.0809444479 * L - 0.130504409 * M + 0.116721066 * S,
		-0.0102485335 * L + 0.0540193266 * M - 0.113614708 * S,
		-0.000365296938 * L - 0.00412161469 * M + 0.693511405 * S);
	vec3 err = c - sim;
	vec3 fix = vec3(0.0, 0.7 * err.r + err.g, 0.7 * err.r + err.b);
	COLOR = vec4(clamp(c + fix * strength, 0.0, 1.0), 1.0);
}
"""

var _settings: GDScript = load("res://core/settings.gd") as GDScript

var _world_layer: CanvasLayer = null
var _world_rect: ColorRect = null
var _world_mat: ShaderMaterial = null
var _cb_layer: CanvasLayer = null
var _cb_mat: ShaderMaterial = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_world_mat = _make_material(WORLD_SHADER)
	_world_layer = _make_layer("PostFxWorld", WORLD_LAYER, _world_mat)
	_world_rect = _world_layer.get_child(0) as ColorRect
	_cb_mat = _make_material(COLORBLIND_SHADER)
	_cb_layer = _make_layer("PostFxColorblind", COLORBLIND_LAYER, _cb_mat)
	refresh()


func _make_material(code: String) -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = code
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	return mat


func _make_layer(layer_name: String, index: int, mat: ShaderMaterial) -> CanvasLayer:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = layer_name
	canvas.layer = index
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = mat
	canvas.add_child(rect)
	return canvas


## Lee las opciones y prende o apaga cada capa.
func refresh() -> void:
	if _world_mat == null:
		return
	var vignette: float = 0.32 if bool(_settings.call("get_bool", "fx_vignette")) else 0.0
	var grain: float = 0.045 if bool(_settings.call("get_bool", "fx_grain")) else 0.0
	var bloom: float = 0.55 if bool(_settings.call("get_bool", "fx_bloom")) else 0.0
	_world_mat.set_shader_parameter("vignette", vignette)
	_world_mat.set_shader_parameter("grain", grain)
	_world_mat.set_shader_parameter("bloom", bloom)
	_world_layer.visible = vignette > 0.0 or grain > 0.0 or bloom > 0.0
	var mode: int = int(_settings.call("get_int", "colorblind"))
	_cb_mat.set_shader_parameter("mode", mode)
	_cb_mat.set_shader_parameter("strength", clampf(float(_settings.call("get_float", "colorblind_strength")), 0.0, 1.0))
	_cb_layer.visible = mode > 0


func _process(_delta: float) -> void:
	# El grano cambia cada cuadro (en tiempo real, aunque el juego esté en pausa o en hit stop)
	if _world_layer != null and _world_layer.visible:
		_world_mat.set_shader_parameter("seed", float(Time.get_ticks_msec() % 100000) * 0.013)
		# Solo en escenas de juego: el menú principal y las pantallas de carga quedan limpios
		_world_rect.visible = _in_game()


func _in_game() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return false
	return not tree.current_scene.scene_file_path.ends_with("main_menu.tscn")
