"""Genera el nivel 2 del mundo 1, Las alcantarillas: levels/chapter_1/level_1_03.tscn.

Uso: python art_source/world1/build_sewer.py
Aparte de build_levels.py a propósito: ese script reescribe TODOS los sectores (y borra el 1-01 horneado a mano).
Este solo escribe el 1-03. Reusa la clase `Level` del otro.

Diseño (ROADMAP 1b): un pasillo con piso y techo, solo ratas, sin personas, plataformeo para no caer en los charcos
(huecos de agua sin lecho: caer devuelve al último puesto de control) y, al final, la Rata Gigante, que suelta la
Flauta de Hamelin. Alto libre del pasillo: 266 px (el salto llega a 138). El jugador avanza ~140 px/s y un salto
cubre ~140 px, por eso los huecos de más de ~110 llevan tablones para pisar en el medio.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_levels as bl  # noqa: E402

bl.RES["giant_rat"] = ("PackedScene", "res://entities/enemies/giant_rat.tscn")
bl.RES["ceiling_rat"] = ("PackedScene", "res://entities/enemies/ceiling_rat.tscn")

LENGTH = 16000
CEILING_BOTTOM = 290.0   # cara inferior del techo (el piso está en 556)
CEILING_TOP = -100.0
# Las ratas de techo se agarran un poco debajo de la cara del techo
CEILING_Y = CEILING_BOTTOM + 2.0


class Sewer(bl.Level):
    def ceiling(self):
        """Techo corrido: losa sólida encima de todo el pasillo (LevelSkin la dibuja como piedra de techo)."""
        h = CEILING_BOTTOM - CEILING_TOP
        self.body("Ceiling", self.length / 2.0, CEILING_TOP + h / 2.0, self.length + 200, h)

    def ceiling_rats(self, xs):
        """Ratas que caminan por el techo y se sueltan sobre el jugador (entities/enemies/ceiling_rat.gd)."""
        self.enemies("ceiling_rat", xs, y=CEILING_Y)

    def checkpoint(self, x):
        self.used.add("checkpoint")
        self.cp_n += 1
        self.nodes.append('[node name="Checkpoint%d" parent="." instance=ExtResource("checkpoint")]\nposition = Vector2(%s, 556)\n'
                          'checkpoint_id = "checkpoint_4_03_%s"\n' % (self.cp_n, bl.fmt(float(x)), "abcdefgh"[self.cp_n - 1]))

    def write(self, next_path):
        ext = []
        for key in sorted(self.used):
            t, path = bl.RES[key]
            ext.append('[ext_resource type="%s" path="%s" id="%s"]' % (t, path, key))
        subs = ['[sub_resource type="RectangleShape2D" id="%s"]\nsize = Vector2(%d, %d)\n' % (k, w, h) for k, (w, h) in self.shapes.items()]
        head = ('[node name="Level_1_03" type="Node2D"]\nscript = ExtResource("level")\nlevel_id = "1_03"\nlevel_title = "%s"\n'
                'chapter_number = 1\nnext_level_path = "%s"\n' % (self.name, next_path))
        bg = ('[node name="Background" type="CanvasLayer" parent="."]\nlayer = -100\n\n'
              '[node name="ColorRect" type="ColorRect" parent="Background"]\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\n'
              'grow_horizontal = 2\ngrow_vertical = 2\nmouse_filter = 2\ncolor = Color(0.03, 0.04, 0.07, 1)\n')
        tail = ('[node name="SpawnPoint" type="Marker2D" parent="."]\nposition = Vector2(160, 545)\n\n'
                '[node name="Player" parent="." instance=ExtResource("player")]\nposition = Vector2(160, 545)\n\n'
                '[node name="Camera2D" type="Camera2D" parent="." node_paths=PackedStringArray("target")]\nposition = Vector2(160, 510)\nzoom = Vector2(1.1, 1.1)\n'
                'limit_left = 0\nlimit_top = 60\nlimit_right = %d\nlimit_bottom = 700\nposition_smoothing_enabled = true\nscript = ExtResource("camera")\ntarget = NodePath("../Player")\n\n'
                '[node name="ExitGate" parent="." instance=ExtResource("gate")]\nposition = Vector2(%d, 556)\n\n'
                '[node name="HUD" parent="." instance=ExtResource("hud")]\n\n'
                '[node name="ProjectilePool" type="Node" parent="." groups=["projectile_pool"]]\nscript = ExtResource("pool")\n\n'
                '[node name="SaveManager" type="Node" parent="." groups=["save_manager"]]\nscript = ExtResource("save")\n\n'
                '[node name="ZoneModifierManager" type="Node" parent="." groups=["zone_modifier_manager"]]\nscript = ExtResource("zone")\n'
                % (self.length, self.length - 250))
        text = "[gd_scene format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n".join(subs) + "\n" + head + "\n" + bg + "\n" + \
            "[node name=\"Environment\" type=\"Node2D\" parent=\".\"]\n" + "\n".join(self.env) + "\n" + "\n".join(self.nodes) + "\n" + tail
        path = os.path.join(bl.OUT, "level_1_03.tscn")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("ok", os.path.relpath(path, bl.ROOT), self.length)


def level_sewer():
    L = Sewer(3, "Las alcantarillas", LENGTH)
    L.walls()
    L.ceiling()
    # Charcos: huecos entre tramos de piso. (x inicial, ancho). Los de más de ~110 llevan tablones (abajo).
    pits = [(2200, 110), (3600, 280), (5400, 120), (7300, 340), (9300, 260), (11200, 280), (13000, 110)]
    x = 0.0
    for px, pw in pits:
        L.floor(x, px)
        x = px + pw
    L.floor(x, LENGTH)

    # Tablones sobre los charcos anchos (y = cara superior); el segundo del charco 4 es más alto: salto de a dos
    L.plat(3740, 500, 110)
    L.plat(7390, 500, 100); L.plat(7550, 440, 100)
    L.plat(9430, 490, 110)
    L.plat(11340, 500, 110)
    # Ruta alta opcional (esquivar a la manada por arriba); queda a 100 px del techo
    L.plat(4400, 430, 160); L.plat(4640, 430, 160)
    L.plat(8200, 430, 160)
    L.plat(10200, 430, 160)
    # Caño caído que se salta o se rodea
    L.block(10600, 120, 50)

    # Tramos de ratas (más cada vez); todas vienen a buscarte
    L.enemies("rat", [1000, 1400, 1800])
    L.ceiling_rats([1500, 1900])
    L.enemies("rat", [2700, 2850, 3000, 3150])
    L.ceiling_rats([2900, 3250])
    L.checkpoint(3400)
    L.enemies("rat", [4300, 4450, 4600, 4750, 5000])
    L.ceiling_rats([4500, 4850, 5200])
    L.arena(6200, "rat", [8, 10, 12], title="LA PLAGA")
    L.checkpoint(7000)
    L.enemies("rat", [8000, 8100, 8300, 8500, 8600, 8900])
    L.ceiling_rats([8200, 8550, 8800, 9100])
    L.checkpoint(9800)
    L.enemies("rat", [10000, 10150, 10300, 10450, 10700, 10850, 11000])
    L.ceiling_rats([10100, 10400, 10750, 10950])
    L.arena(12100, "rat", [10, 12, 14], title="EL NIDO")
    L.checkpoint(12700)

    # Sala de la Rata Gigante: primero su manada (ronda 1) y después ella sola (ronda 2, elite_per_round = [0, 1])
    L.arena(14200, "rat", [6, 1], "giant_rat", [0, 1], "LA REINA DE LAS RATAS")
    L.write("res://levels/chapter_1/level_1_04.tscn")


if __name__ == "__main__":
    level_sewer()
