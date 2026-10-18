extends Sprite2D
## La Caja del presente: cubo negro liso. Carga su textura por código (el PNG puede no estar importado al lanzar con
## run.bat). Una cinemática puede abrirla o cerrarla con el paso `box` (core/cinematics/commands/box.gd).

const ArtScript = preload("res://core/art/art.gd")


func _ready() -> void:
	add_to_group(&"the_box")
	if texture == null:
		texture = ArtScript.tex("res://assets/art/world1/box_closed.png")
