"""Genera el nivel 3 del mundo 1, La torre y los techos: levels/chapter_1/level_1_04.tscn.

Uso: python art_source/world1/build_tower.py
Aparte de build_levels.py a propósito (ese reescribe todos los sectores y pisa el 1-01 y el 1-03). Reusa la clase `Level`.

Diseño (ROADMAP 1b): Gunther sale de las alcantarillas a un edificio que hay que SUBIR peleando, piso por piso, y al
llegar arriba cruza los techos saltando de uno a otro hasta la salida (hacia la azotea con la Caja, el 1-08).

- Torre (x 0..2000): cinco niveles de piso separados 400 px. Cada losa de piso (100 px de grosor) deja un hueco de 330 px
  en un extremo, alternando derecha / izquierda; en el hueco hay tres tablas de una vía (a 100, 200 y 300 px) que suben hacia
  el borde de la losa de arriba (se atraviesan desde abajo). El salto llega a ~138 px: cada tabla queda a 100 de la anterior.
- Techos (x 330..12000): edificios separados por huecos al vacío. Hueco de hasta 130 px: se salta; más ancho: una tabla
  de 120 px al medio (cada salto queda en ≤ 110 px). Caer devuelve al último puesto de control (`abyss_after_x`).
- Las arenas están donde el suelo sigue continuo a ±600 px del centro (los enemigos nacen fuera de cámara).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_levels as bl  # noqa: E402

LENGTH = 12000
TW = 2000                      # ancho de la torre (pared derecha)
OPEN = 330                     # ancho del hueco de escaleras
FLOOR_GAP = 400                # distancia entre pisos
SLAB_H = 100                   # grosor de las losas
STEP_W = 110
GROUND = 556
ROOF_H = 500                   # grosor de los edificios de los techos (se ven como bloques)


def top_of(k):
    return GROUND - FLOOR_GAP * k


ROOF_Y = top_of(4)             # -1044: el techo de la torre

# Techos (x0, x1, y de la cara superior). El primero es el techo de la torre.
ROOFS = [
    (3010, 4400, -1090),
    (4700, 6500, -1000),
    (6750, 8000, -1060),
    (8120, 9800, -1060),
    (10130, LENGTH, -1060),
]
FINAL_TOP = -1060


class Tower(bl.Level):
    # ------------------------------------------------------------ geometría
    def slab(self, x0, x1, top, h=SLAB_H):
        w = x1 - x0
        self.body(self.uid("Slab"), x0 + w / 2.0, top + h / 2.0, w, h)

    def roof(self, x0, x1, top):
        self.slab(x0, x1, top, ROOF_H)

    def step(self, cx, top):
        """Escalón: tabla de una vía (se sube desde abajo y se pisa desde arriba); `top` = cara superior."""
        self.body(self.uid("Step"), float(cx), top + 10.0, STEP_W, 20)
        shape_line = 'shape = SubResource("Rect_%dx20")\n' % STEP_W
        self.env[-1] = self.env[-1].replace(shape_line, shape_line + "one_way_collision = true\n", 1)

    def cover(self, x, w, h, top):
        """Caja de cobertura sobre un techo."""
        self.body(self.uid("Block"), float(x), top - h / 2.0, w, h)

    def stairs(self, floor_top, side):
        """Tres escalones (tablas de una vía a 100, 200 y 300 px) en el hueco de la losa de arriba; el más bajo queda
        contra la pared y el más alto junto al borde de la losa, que está a 400 px."""
        for i, rise in enumerate((100, 200, 300)):
            cx = (TW - STEP_W / 2.0 - STEP_W * i) if side == "right" else (STEP_W / 2.0 + STEP_W * i)
            self.step(cx, floor_top - rise)

    # ------------------------------------------------------------ contenido a cualquier altura
    def foes(self, kind, xs, top, guard=False):
        self.enemies(kind, xs, guard, y=top - 1.0)

    def checkpoint_at(self, x, top):
        self.used.add("checkpoint")
        self.cp_n += 1
        self.nodes.append('[node name="Checkpoint%d" parent="." instance=ExtResource("checkpoint")]\nposition = Vector2(%s, %s)\n'
                          'checkpoint_id = "checkpoint_4_04_%s"\n' % (self.cp_n, bl.fmt(float(x)), bl.fmt(float(top)), "abcdefghijkl"[self.cp_n - 1]))

    def weapon_at(self, x, top, key):
        self.body(self.uid("Pedestal"), float(x), top - 9.0, 64, 18, "Color(0.5, 0.45, 0.35, 1)")
        self.used.add("wpickup")
        self.used.add(key)
        self.nodes.append('[node name="%s" parent="." instance=ExtResource("wpickup")]\nposition = Vector2(%s, %s)\nweapon_data = ExtResource("%s")\n'
                          % (self.uid("WeaponPickup"), bl.fmt(float(x)), bl.fmt(top - 44.0), key))

    def arena_at(self, x, top, kind, rounds, elite=None, elites=None):
        self.used.add("arena")
        self.used.add(kind)
        self.arena_n += 1
        n = "Arena%d" % self.arena_n
        lines = ['[node name="%s" parent="." instance=ExtResource("arena")]\nposition = Vector2(%s, %s)\n' % (n, bl.fmt(float(x)), bl.fmt(float(top))),
                 '[node name="WaveManager" parent="%s" index="2"]\nenemy_scene = ExtResource("%s")\nround_sizes = Array[int]([%s])\n'
                 % (n, kind, ", ".join(str(r) for r in rounds))]
        if elite:
            self.used.add(elite)
            lines[1] += 'elite_scene = ExtResource("%s")\nelite_per_round = Array[int]([%s])\n' % (elite, ", ".join(str(e) for e in elites))
        self.nodes.extend(lines)

    # ------------------------------------------------------------ decorado del interior
    def interior_back(self):
        """Pared del fondo de la torre (oscura, con ventanas tenues) para que el interior no sea el cielo."""
        top = ROOF_Y + SLAB_H
        parts = ['[node name="TowerBack" type="Node2D" parent="."]\nz_index = -1\n',
                 '[node name="Wall" type="ColorRect" parent="TowerBack"]\noffset_left = 0.0\noffset_top = %s\noffset_right = %s\noffset_bottom = %s\n'
                 'mouse_filter = 2\ncolor = Color(0.085, 0.095, 0.13, 1)\n' % (bl.fmt(float(top)), bl.fmt(float(TW)), bl.fmt(float(GROUND)))]
        n = 0
        for k in range(4):
            for wx in (420, 1000, 1580):
                n += 1
                y0 = top_of(k) - 270.0
                parts.append('[node name="Window%d" type="ColorRect" parent="TowerBack"]\noffset_left = %s\noffset_top = %s\noffset_right = %s\noffset_bottom = %s\n'
                             'mouse_filter = 2\ncolor = Color(0.5, 0.42, 0.24, 0.38)\n'
                             % (n, bl.fmt(float(wx - 80)), bl.fmt(y0), bl.fmt(float(wx + 80)), bl.fmt(y0 + 140.0)))
        self.back = "\n".join(parts)

    def write(self, next_path):
        ext = []
        for key in sorted(self.used):
            t, path = bl.RES[key]
            ext.append('[ext_resource type="%s" path="%s" id="%s"]' % (t, path, key))
        subs = ['[sub_resource type="RectangleShape2D" id="%s"]\nsize = Vector2(%d, %d)\n' % (k, w, h) for k, (w, h) in self.shapes.items()]
        head = ('[node name="Level_1_04" type="Node2D"]\nscript = ExtResource("level")\nlevel_id = "1_04"\nlevel_title = "%s"\n'
                'chapter_number = 1\nnext_level_path = "%s"\nabyss_after_x = %s\nabyss_threshold_after = %s\n'
                % (self.name, next_path, bl.fmt(float(TW + 60)), bl.fmt(float(FINAL_TOP + 800))))
        bg = ('[node name="Background" type="CanvasLayer" parent="."]\nlayer = -100\n\n'
              '[node name="ColorRect" type="ColorRect" parent="Background"]\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\n'
              'grow_horizontal = 2\ngrow_vertical = 2\nmouse_filter = 2\ncolor = Color(0.03, 0.04, 0.07, 1)\n')
        tail = ('[node name="SpawnPoint" type="Marker2D" parent="."]\nposition = Vector2(160, 545)\n\n'
                '[node name="Player" parent="." instance=ExtResource("player")]\nposition = Vector2(160, 545)\n\n'
                '[node name="Camera2D" type="Camera2D" parent="." node_paths=PackedStringArray("target")]\nposition = Vector2(160, 510)\nzoom = Vector2(1.1, 1.1)\n'
                'limit_left = 0\nlimit_top = %d\nlimit_right = %d\nlimit_bottom = 700\nposition_smoothing_enabled = true\nscript = ExtResource("camera")\ntarget = NodePath("../Player")\n\n'
                '[node name="ExitGate" parent="." instance=ExtResource("gate")]\nposition = Vector2(%d, %d)\n\n'
                '[node name="HUD" parent="." instance=ExtResource("hud")]\n\n'
                '[node name="ProjectilePool" type="Node" parent="." groups=["projectile_pool"]]\nscript = ExtResource("pool")\n\n'
                '[node name="SaveManager" type="Node" parent="." groups=["save_manager"]]\nscript = ExtResource("save")\n\n'
                '[node name="ZoneModifierManager" type="Node" parent="." groups=["zone_modifier_manager"]]\nscript = ExtResource("zone")\n'
                % (ROOF_Y - 700, self.length, self.length - 250, FINAL_TOP))
        text = "[gd_scene format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n".join(subs) + "\n" + head + "\n" + bg + "\n" + self.back + "\n" + \
            "[node name=\"Environment\" type=\"Node2D\" parent=\".\"]\n" + "\n".join(self.env) + "\n" + "\n".join(self.nodes) + "\n" + tail
        path = os.path.join(bl.OUT, "level_1_04.tscn")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("ok", os.path.relpath(path, bl.ROOT), self.length)


def level_tower():
    L = Tower(4, "La torre y los techos", LENGTH)
    L.interior_back()

    # --- paredes: izquierda de punta a punta; derecha de la torre hasta la losa del techo; derecha del final
    L.body("LeftWall", -20.0, (ROOF_Y - 300 + 700) / 2.0, 40, 700 - (ROOF_Y - 300))
    wall_top = ROOF_Y + SLAB_H
    L.body("TowerWall", TW + 20.0, (wall_top + 640) / 2.0, 40, 640 - wall_top)
    L.body("RightWall", LENGTH + 20.0, FINAL_TOP - 500.0, 40, 1000)

    # --- pisos: planta baja entera y cuatro losas alternando el hueco
    L.slab(0, TW, GROUND, 74)
    L.stairs(top_of(0), "right")
    L.slab(0, TW - OPEN, top_of(1))
    L.stairs(top_of(1), "left")
    L.slab(OPEN, TW, top_of(2))
    L.stairs(top_of(2), "right")
    L.slab(0, TW - OPEN, top_of(3))
    L.stairs(top_of(3), "left")
    # techo de la torre (losa) y, a su derecha, el primer techo exterior (grueso)
    L.slab(OPEN, TW + 40, ROOF_Y)
    L.roof(TW + 40, 2900, ROOF_Y)

    # --- techos separados por huecos; tabla al medio de los que no se saltan solos
    prev_x1, prev_top = 2900, ROOF_Y
    for x0, x1, top in ROOFS:
        L.roof(x0, x1, top)
        gap = x0 - prev_x1
        if gap > 130:
            L.plat((prev_x1 + x0) / 2.0, (prev_top + top) / 2.0 + 20, 120)
        prev_x1, prev_top = x1, top

    # --- planta baja: ladrones y el primer matón (de izquierda a derecha)
    L.foes("thief", [800, 1100], GROUND)
    L.checkpoint_at(1300, GROUND)
    L.foes("thug", [1500], GROUND)

    # --- piso 1: de derecha a izquierda; arena de recepción
    L.checkpoint_at(1550, top_of(1))
    L.foes("thug", [1250], top_of(1))
    L.arena_at(900, top_of(1), "thief", [5, 7], "thug", [1, 2])
    L.checkpoint_at(500, top_of(1))

    # --- piso 2: de izquierda a derecha; llegan los asaltantes y el SMG
    L.checkpoint_at(450, top_of(2))
    L.weapon_at(620, top_of(2), "w_smg")
    L.foes("gunman", [1000, 1500], top_of(2))

    # --- piso 3: de derecha a izquierda; llega el patovica y arena de seguridad
    L.checkpoint_at(1550, top_of(3))
    L.foes("gunman", [1450], top_of(3))
    L.foes("bouncer", [1100], top_of(3))
    L.arena_at(700, top_of(3), "gunman", [5, 7], "bouncer", [1, 1])
    L.checkpoint_at(450, top_of(3))

    # --- techo de la torre
    L.checkpoint_at(700, ROOF_Y)
    L.foes("hitman", [1300], ROOF_Y)
    L.foes("gunman", [1800], ROOF_Y)
    L.foes("hitman", [2300], ROOF_Y)
    L.cover(2600, 120, 50, ROOF_Y)

    # --- techos
    L.foes("gunman", [3500], ROOFS[0][2])
    L.cover(3700, 120, 60, ROOFS[0][2])
    L.foes("hitman", [3900, 4200], ROOFS[0][2])

    L.checkpoint_at(4850, ROOFS[1][2])
    L.foes("bouncer", [5200], ROOFS[1][2])
    L.arena_at(5600, ROOFS[1][2], "gunman", [6, 8], "bouncer", [1, 2])
    L.foes("hitman", [6200], ROOFS[1][2])

    L.checkpoint_at(6900, ROOFS[2][2])
    L.foes("hitman", [7200, 7500], ROOFS[2][2])
    L.foes("gunman", [7800], ROOFS[2][2])

    L.foes("hitman", [8400, 8800, 9200], ROOFS[3][2])
    L.cover(8600, 120, 50, ROOFS[3][2])
    L.cover(9000, 120, 70, ROOFS[3][2])
    L.foes("bouncer", [9500], ROOFS[3][2])

    L.checkpoint_at(10300, ROOFS[4][2])
    L.arena_at(11000, ROOFS[4][2], "hitman", [4, 5, 6], "bouncer", [0, 1, 2])

    L.write("res://levels/chapter_1/level_1_08.tscn")


if __name__ == "__main__":
    level_tower()
