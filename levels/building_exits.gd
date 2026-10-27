extends RefCounted
## Salidas de enemigos de cada edificio del Mundo 1, en px de su PNG (`assets/art/world1/buildings/`).
## Generado por art_source/world1/process_buildings_2d.py: no editar a mano, cambiar las coordenadas allá.
##   doors  puertas, persianas y portones (humanos)
##   rats   abertura baja dibujada en la base (ratas)
## Sin class_name: lo usa `ambush_director.gd` por `preload`.

const EXITS: Dictionary = {
	"bld_01": {"doors": [Rect2(33, 619, 46, 88), Rect2(100, 622, 137, 84)], "rats": [Rect2(107, 664, 60, 42)]},
	"bld_02": {"doors": [], "rats": [Rect2(89, 681, 67, 39)]},
	"bld_03": {"doors": [Rect2(129, 522, 63, 86)], "rats": [Rect2(227, 586, 36, 25)]},
	"bld_04": {"doors": [Rect2(116, 615, 46, 84), Rect2(32, 615, 63, 86)], "rats": [Rect2(190, 680, 39, 21)]},
	"bld_05": {"doors": [Rect2(51, 158, 172, 145), Rect2(295, 197, 56, 106)], "rats": [Rect2(230, 232, 53, 71)]},
	"bld_06": {"doors": [Rect2(47, 284, 57, 117)], "rats": [Rect2(154, 373, 63, 28)]},
	"bld_07": {"doors": [Rect2(37, 445, 140, 131), Rect2(202, 438, 60, 138)], "rats": [Rect2(16, 526, 56, 50)]},
	"bld_08": {"doors": [Rect2(189, 257, 67, 131)], "rats": [Rect2(66, 362, 63, 26)]},
}
