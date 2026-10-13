extends RefCounted
## Shaders de fuego y ácido (estilo "Shaders" de las opciones gráficas). Se escriben en código (igual que el
## posprocesado de `core/post_fx.gd`) y se comparten: un solo material por tipo, así los efectos del mismo tipo
## no rompen el lote de dibujo. La variación entre instancias sale de la posición (MODEL_MATRIX), sin parámetros
## por instancia. Sin class_name a propósito: se usa por `preload`.

const FIRE_CODE: String = """
shader_type canvas_item;
uniform vec4 core_color : source_color = vec4(1.0, 0.96, 0.6, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform vec4 edge_color : source_color = vec4(0.75, 0.12, 0.03, 1.0);
uniform float speed = 1.0;
varying vec2 seed;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	seed = MODEL_MATRIX[3].xy;
}

void fragment() {
	float h = 1.0 - UV.y;
	float t = TIME * speed;
	float n1 = vnoise(vec2(UV.x * 4.0 + seed.x * 0.37, h * 3.0 - t * 1.6));
	float n2 = vnoise(vec2(UV.x * 9.0 - seed.y * 0.21, h * 6.0 - t * 2.8));
	float shape = n1 * 0.65 + n2 * 0.35;
	float taper = clamp(1.0 - h * 0.85, 0.0, 1.0);
	// La lengua se tuerce con el ruido: no queda un cono perfecto
	float dx = abs(UV.x - 0.5 + (n1 - 0.5) * 0.5 * h) * 2.0;
	float body = smoothstep(0.0, 0.45, taper - dx * 0.9) * (1.0 - h * 0.7);
	float v = body * (0.45 + shape * 0.9);
	float a = smoothstep(0.22, 0.5, v);
	vec3 col = mix(edge_color.rgb, mid_color.rgb, smoothstep(0.25, 0.55, v));
	col = mix(col, core_color.rgb, smoothstep(0.6, 0.95, v));
	COLOR = vec4(col, a * COLOR.a);
}
"""

const ACID_CODE: String = """
shader_type canvas_item;
uniform vec4 body_color : source_color = vec4(0.38, 0.86, 0.12, 1.0);
uniform vec4 dark_color : source_color = vec4(0.1, 0.38, 0.05, 1.0);
uniform vec4 light_color : source_color = vec4(0.85, 1.0, 0.55, 1.0);
varying vec2 seed;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void vertex() {
	seed = MODEL_MATRIX[3].xy;
}

void fragment() {
	float x = UV.x;
	float ex = abs(x - 0.5) * 2.0;
	// Superficie con onda lenta; baja hacia los bordes del charco
	float wave = sin(x * 14.0 + TIME * 2.4 + seed.x * 0.11) * 0.06 + sin(x * 6.0 - TIME * 1.5 + seed.y * 0.7) * 0.05;
	float top = 0.28 + wave + ex * ex * 0.55;
	float inside = smoothstep(top, top + 0.06, UV.y);
	float edge = 1.0 - smoothstep(0.82, 1.0, ex);
	float depth = clamp((UV.y - top) / max(0.0001, 1.0 - top), 0.0, 1.0);
	vec3 col = mix(light_color.rgb, body_color.rgb, smoothstep(0.0, 0.25, depth));
	col = mix(col, dark_color.rgb, smoothstep(0.55, 1.0, depth));
	// Burbujas que suben y estallan
	float bub = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float ph = fract(TIME * (0.35 + 0.1 * fi) + hash(fi + seed.x * 0.13));
		vec2 c = vec2(0.2 + 0.6 * hash(fi * 7.1 + seed.y * 0.17), 1.0 - ph * 0.65);
		float d = distance(vec2(x, UV.y), c);
		bub = max(bub, smoothstep(0.075, 0.05, d) * (1.0 - ph));
	}
	col = mix(col, light_color.rgb, bub * 0.9);
	COLOR = vec4(col, inside * edge * COLOR.a);
}
"""

static var _white: Texture2D = null
static var _fire: Dictionary = {}
static var _acid: ShaderMaterial = null


## Cuadrado blanco 4x4: da UV 0..1 a los efectos de shader dibujados con Sprite2D o `draw_texture_rect`.
static func white_texture() -> Texture2D:
	if _white == null:
		var img: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	return _white


## Material de llama; `kind` ajusta la velocidad ("jet" más rápido, "burn" más tranquilo).
static func fire_material(kind: String) -> ShaderMaterial:
	if _fire.has(kind):
		return _fire[kind] as ShaderMaterial
	var shader: Shader = Shader.new()
	shader.code = FIRE_CODE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	match kind:
		"jet":
			mat.set_shader_parameter("speed", 2.2)
		"droplet":
			mat.set_shader_parameter("speed", 1.6)
		"burn":
			mat.set_shader_parameter("speed", 0.9)
		_:
			mat.set_shader_parameter("speed", 1.0)
	_fire[kind] = mat
	return mat


static func acid_material() -> ShaderMaterial:
	if _acid == null:
		var shader: Shader = Shader.new()
		shader.code = ACID_CODE
		_acid = ShaderMaterial.new()
		_acid.shader = shader
	return _acid
