extends Sprite2D
## La Caja del presente: cubo negro liso. Carga su textura por código (el PNG puede no estar importado al lanzar con
## run.bat). La cinemática del P-8 la abre/cierra cambiando la textura (core/cinematics/cinematic_player.gd, paso `box`).

const ArtScript = preload("res://core/art/art.gd")


func _ready() -> void:
	add_to_group(&"the_box")
	if texture == null:
		texture = ArtScript.tex("res://assets/art/world4/box_closed.png")
