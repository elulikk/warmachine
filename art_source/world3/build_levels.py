"""Genera los 10 sectores del Mundo 3 (Abismo Ígneo): levels/chapter_3/level_3_XX.tscn.

Uso: python art_source/world3/build_levels.py
Los niveles se arman con las mismas piezas que el capítulo 4 (StaticBody2D + ColorRect bajo Environment); el arte
lo pone LevelSkin (tema del capítulo 3) y la decoración hell_decor.gd. Editar acá y regenerar, o editar el .tscn a mano.
Suelo: cara superior en y=556. Enemigos en y=555. Armas sobre pedestal en y=512.
Pozos de lava: niveles sin `bedrock()`; los huecos entre suelos se ven como lava (hell_decor) y caer devuelve al puesto de control.
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "levels", "chapter_3")

GROUND = 556.0
FLOOR_H = 74.0

RES = {
    "level": ("Script", "res://levels/level_base.gd"),
    "player": ("PackedScene", "res://entities/player/player.tscn"),
    "camera": ("Script", "res://core/camera_follow.gd"),
    "hud": ("PackedScene", "res://ui/hud.tscn"),
    "pool": ("Script", "res://core/projectile_pool.gd"),
    "save": ("Script", "res://core/managers/save_manager.gd"),
    "zone": ("Script", "res://core/managers/zone_modifier_manager.gd"),
    "gate": ("PackedScene", "res://entities/interactables/exit_gate.tscn"),
    "checkpoint": ("PackedScene", "res://entities/interactables/checkpoint_terminal.tscn"),
    "wpickup": ("PackedScene", "res://entities/items/weapon_pickup.tscn"),
    "arena": ("PackedScene", "res://entities/world/arena.tscn"),
    "dummy": ("PackedScene", "res://entities/enemies/training_dummy.tscn"),
    "zombie": ("PackedScene", "res://entities/enemies/zombie.tscn"),
    "runner": ("PackedScene", "res://entities/enemies/basic_runner.tscn"),
    "brute": ("PackedScene", "res://entities/enemies/armored_brute.tscn"),
    "ghost": ("PackedScene", "res://entities/enemies/ghost.tscn"),
    "sentinel": ("PackedScene", "res://entities/enemies/shielded_sentinel.tscn"),
    "boss": ("PackedScene", "res://entities/enemies/brute_boss.tscn"),
    "w_scythe": ("Resource", "res://data/weapons/scythe.tres"),
    "w_crossbow": ("Resource", "res://data/weapons/hell_crossbow.tres"),
    "w_trident": ("Resource", "res://data/weapons/hell_trident.tres"),
    "w_soul": ("Resource", "res://data/weapons/soul_staff.tres"),
    "w_sulfur": ("Resource", "res://data/weapons/sulfur_scepter.tres"),
    "w_demon": ("Resource", "res://data/weapons/demon_sword.tres"),
    "w_axe": ("Resource", "res://data/weapons/abyss_axe.tres"),
}

WEAPON_NAMES = {
    "w_scythe": "Guadaña", "w_crossbow": "Ballesta Infernal", "w_trident": "Tridente Infernal",
    "w_soul": "Báculo de Almas", "w_sulfur": "Cetro de Azufre", "w_demon": "Espada Demoníaca", "w_axe": "Hacha del Abismo",
}

TIP = "Color(1, 0.9, 0.8, 1)"
WARN = "Color(1, 0.55, 0.35, 1)"
GOOD = "Color(1, 0.8, 0.3, 1)"


def fmt(v):
    return ("%.1f" % v) if isinstance(v, float) else str(v)


class Level:
    def __init__(self, num, name, length, backdrop=""):
        self.num = num
        self.name = name
        self.length = length
        self.backdrop = backdrop
        self.used = {"level", "player", "camera", "hud", "pool", "save", "zone", "gate"}
        self.shapes = {}
        self.env = []      # bloques de Environment
        self.nodes = []    # bloques de nivel (después de Environment)
        self.count = {}
        self.gate_reward = ""
        self.arena_n = 0
        self.cp_n = 0

    # ---------------------------------------------------------------- utilidades
    def uid(self, prefix):
        self.count[prefix] = self.count.get(prefix, 0) + 1
        return "%s%d" % (prefix, self.count[prefix])

    def shape(self, w, h):
        key = "Rect_%dx%d" % (w, h)
        self.shapes[key] = (w, h)
        return key

    def body(self, name, cx, cy, w, h, color="Color(0.3, 0.15, 0.12, 1)"):
        sid = self.shape(w, h)
        self.env.append(
            '[node name="%s" type="StaticBody2D" parent="Environment" groups=["world"]]\nposition = Vector2(%s, %s)\ncollision_mask = 0\n\n'
            '[node name="CollisionShape2D" type="CollisionShape2D" parent="Environment/%s"]\nshape = SubResource("%s")\n\n'
            '[node name="ColorRect" type="ColorRect" parent="Environment/%s"]\noffset_left = %s\noffset_top = %s\noffset_right = %s\noffset_bottom = %s\nmouse_filter = 2\ncolor = %s\n'
            % (name, fmt(cx), fmt(cy), name, sid, name, fmt(-w / 2), fmt(-h / 2), fmt(w / 2), fmt(h / 2), color))

    # ---------------------------------------------------------------- geometría
    def floor(self, x0, x1, top=GROUND, h=FLOOR_H):
        w = x1 - x0
        self.body(self.uid("Floor"), x0 + w / 2.0, top + h / 2.0, w, h)

    def bedrock(self):
        self.body("Bedrock", self.length / 2.0, 660.0, self.length + 200, 60, "Color(0.2, 0.1, 0.08, 1)")

    def walls(self):
        self.body("LeftWall", -20.0, 240.0, 40, 800)
        self.body("RightWall", self.length + 20.0, 240.0, 40, 800)

    def block(self, x, w, h):
        """Bloque macizo apoyado en el suelo (escalón, roca)."""
        self.body(self.uid("Block"), float(x), GROUND - h / 2.0, w, h)

    def plat(self, x, y, w=180):
        """Plataforma de tablones; `y` = cara superior."""
        self.body(self.uid("Plank"), float(x), y + 10.0, w, 20)

    def pedestal(self, x):
        self.body(self.uid("Pedestal"), float(x), 547.0, 64, 18, "Color(0.5, 0.45, 0.35, 1)")

    # ---------------------------------------------------------------- contenido
    def label(self, x, y, text, color=TIP, size=13, width=520):
        n = self.uid("Tip")
        self.env.append(
            '[node name="%s" type="Label" parent="Environment"]\noffset_left = %s\noffset_top = %s\noffset_right = %s\noffset_bottom = %s\n'
            'theme_override_colors/font_color = %s\ntheme_override_colors/font_outline_color = Color(0, 0, 0, 1)\ntheme_override_constants/outline_size = 4\n'
            'theme_override_font_sizes/font_size = %d\ntext = "%s"\n'
            % (n, fmt(float(x)), fmt(float(y)), fmt(float(x + width)), fmt(float(y + 24)), color, size, text))

    def weapon(self, x, key, tip=None):
        self.pedestal(x)
        self.used.add("wpickup")
        self.used.add(key)
        self.nodes.append('[node name="%s" parent="." instance=ExtResource("wpickup")]\nposition = Vector2(%s, 512)\nweapon_data = ExtResource("%s")\n'
                          % (self.uid("WeaponPickup"), fmt(float(x)), key))
        if tip:
            self.label(x - 200, 430, tip, GOOD)

    def enemy(self, kind, x, y=555.0, guard=False):
        self.used.add(kind)
        groups = ' groups=["arena_enemies"]' if guard else ""
        self.nodes.append('[node name="%s" parent="."%s instance=ExtResource("%s")]\nposition = Vector2(%s, %s)\n'
                          % (self.uid(kind.capitalize()), groups, kind, fmt(float(x)), fmt(float(y))))

    def enemies(self, kind, xs, guard=False, y=555.0):
        for x in xs:
            self.enemy(kind, x, y, guard)

    def dummy(self, x):
        self.used.add("dummy")
        self.nodes.append('[node name="%s" parent="." instance=ExtResource("dummy")]\nposition = Vector2(%s, 556)\narmor = 0.0\nmax_shield = 0.0\n'
                          'entity_name = "Condenado de Paja"\ndummy_name = "Condenado de Paja"\n' % (self.uid("Dummy"), fmt(float(x))))

    def checkpoint(self, x):
        self.used.add("checkpoint")
        self.cp_n += 1
        self.nodes.append('[node name="Checkpoint%d" parent="." instance=ExtResource("checkpoint")]\nposition = Vector2(%s, 556)\ncheckpoint_id = "checkpoint_3_%02d_%s"\n'
                          % (self.cp_n, fmt(float(x)), self.num, "abcdefgh"[self.cp_n - 1]))

    def arena(self, x, kind, rounds, elite=None, elites=None, title=None):
        """Arena de oleadas centrada en x (barreras a ±530). El suelo debe ser continuo en [x-540, x+540]."""
        self.used.add("arena")
        self.used.add(kind)
        self.arena_n += 1
        n = "Arena%d" % self.arena_n
        lines = ['[node name="%s" parent="." instance=ExtResource("arena")]\nposition = Vector2(%s, 556)\n' % (n, fmt(float(x))),
                 '[node name="WaveManager" parent="%s" index="2"]\nenemy_scene = ExtResource("%s")\nround_sizes = Array[int]([%s])\n'
                 % (n, kind, ", ".join(str(r) for r in rounds))]
        if elite:
            self.used.add(elite)
            lines[1] += 'elite_scene = ExtResource("%s")\nelite_per_round = Array[int]([%s])\n' % (elite, ", ".join(str(e) for e in elites))
        self.nodes.extend(lines)
        if title:
            self.label(x - 300, 330, title, WARN, 16, 600)

    # ---------------------------------------------------------------- salida
    def write(self, next_path):
        num = self.num
        ext = []
        for key in sorted(self.used):
            t, path = RES[key]
            ext.append('[ext_resource type="%s" path="%s" id="%s"]' % (t, path, key))
        subs = ['[sub_resource type="RectangleShape2D" id="%s"]\nsize = Vector2(%d, %d)\n' % (k, w, h) for k, (w, h) in self.shapes.items()]
        head = ('[node name="Level_3_%02d" type="Node2D"]\nscript = ExtResource("level")\nlevel_id = "3_%02d"\nlevel_title = "Sector 3-%d"\n'
                'chapter_number = 3\nnext_level_path = "%s"\n' % (num, num, num, next_path))
        if self.backdrop:
            head += 'backdrop_file = "%s"\n' % self.backdrop
        bg = ('[node name="Background" type="CanvasLayer" parent="."]\nlayer = -100\n\n'
              '[node name="ColorRect" type="ColorRect" parent="Background"]\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\n'
              'grow_horizontal = 2\ngrow_vertical = 2\nmouse_filter = 2\ncolor = Color(0.12, 0.03, 0.02, 1)\n')
        env = '[node name="Environment" type="Node2D" parent="."]\n'
        gate_reward = ('reward_weapon_text = "%s"\n' % self.gate_reward) if self.gate_reward else ""
        tail = ('[node name="SpawnPoint" type="Marker2D" parent="."]\nposition = Vector2(160, 545)\n\n'
                '[node name="Player" parent="." instance=ExtResource("player")]\nposition = Vector2(160, 545)\n\n'
                '[node name="Camera2D" type="Camera2D" parent="." node_paths=PackedStringArray("target")]\nposition = Vector2(160, 510)\nzoom = Vector2(1.1, 1.1)\n'
                'limit_left = 0\nlimit_top = 60\nlimit_right = %d\nlimit_bottom = 700\nposition_smoothing_enabled = true\nscript = ExtResource("camera")\ntarget = NodePath("../Player")\n\n'
                '[node name="ExitGate" parent="." instance=ExtResource("gate")]\nposition = Vector2(%d, 556)\n%s\n'
                '[node name="HUD" parent="." instance=ExtResource("hud")]\n\n'
                '[node name="ProjectilePool" type="Node" parent="." groups=["projectile_pool"]]\nscript = ExtResource("pool")\n\n'
                '[node name="SaveManager" type="Node" parent="." groups=["save_manager"]]\nscript = ExtResource("save")\n\n'
                '[node name="ZoneModifierManager" type="Node" parent="." groups=["zone_modifier_manager"]]\nscript = ExtResource("zone")\n'
                % (self.length, self.length - 250, gate_reward))
        text = "[gd_scene format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n".join(subs) + "\n" + head + "\n" + bg + "\n" + env + "\n" + \
            "\n".join(self.env) + "\n" + "\n".join(self.nodes) + "\n" + tail
        path = os.path.join(OUT, "level_3_%02d.tscn" % num)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("ok", os.path.relpath(path, ROOT), self.length)

    def title(self, subtitle):
        self.label(40, 380, "CAPÍTULO 3 • ABISMO ÍGNEO • SECTOR 3-%d — %s" % (self.num, subtitle), "Color(1, 0.55, 0.25, 1)", 14, 760)


def next_of(num):
    return "res://levels/chapter_3/level_3_%02d.tscn" % (num + 1) if num < 10 else "res://levels/chapter_1/level_1_01.tscn"


# ============================================================================== niveles
# Ciclo de enemigos: crece un tipo antes de que entre el siguiente (zombis → saqueadores → brutos → espectros →
# centinelas) y se repite. Pozos de lava (sin lecho de roca): 3-3, 3-5 y 3-7.

def level_1():
    L = Level(1, "Puertas del Abismo", 6400)
    L.bedrock(); L.walls()
    L.floor(0, 1600); L.floor(1740, 6400)
    L.title("PUERTAS DEL ABISMO")
    L.label(40, 470, "Bajaste al Abismo. El aire quema: buscá un arma entre las ruinas.")
    L.weapon(700, "w_scythe", "Guadaña — [Click] tajos enormes que barren todo lo que tengas adelante")
    L.dummy(1150)
    L.label(1450, 440, "Saltá la grieta [Espacio]", TIP, 13, 360)
    L.block(2100, 70, 40); L.block(2300, 80, 70)
    L.plat(2550, 470, 200)
    L.enemies("zombie", [2900, 3200, 3500, 3800])
    L.checkpoint(4000)
    L.arena(5000, "zombie", [6, 8], title="LOS CONDENADOS DESPIERTAN")
    L.enemies("zombie", [5750, 5950], guard=True)
    L.write(next_of(1))


def level_2():
    L = Level(2, "Llanura de Ceniza", 7400)
    L.bedrock(); L.walls()
    L.floor(0, 2200); L.floor(2340, 7400)
    L.title("LLANURA DE CENIZA")
    L.weapon(600, "w_crossbow", "Ballesta Infernal — virotes en llamas que atraviesan y queman. [R] recargar")
    L.dummy(1100)
    L.plat(1700, 470); L.plat(1950, 400)
    L.enemies("zombie", [2700, 2950, 3200, 3450])
    L.checkpoint(3700)
    L.arena(4700, "zombie", [8, 10], title="LA HORDA DE CENIZA")
    L.checkpoint(5500)
    L.label(5600, 470, "Algo rápido corre entre la ceniza...", WARN, 13, 520)
    L.enemies("runner", [6300, 6700], guard=True)
    L.enemies("zombie", [6500, 6900], guard=True)
    L.write(next_of(2))


def level_3():
    L = Level(3, "Ríos de Fuego", 8000)
    L.walls()
    # Sin lecho de roca: los ríos de lava son pozos de verdad
    L.floor(0, 1500); L.floor(1640, 2800); L.floor(2940, 5600); L.floor(5760, 8000)
    L.title("RÍOS DE FUEGO")
    L.label(40, 470, "¡Ríos de lava! Si caés, volvés al último puesto de control.", WARN, 13, 640)
    L.enemies("zombie", [900, 1200])
    L.plat(1570, 450, 160)
    L.enemies("runner", [2200, 2500])
    L.plat(2870, 450, 160)
    L.checkpoint(3200)
    L.arena(4300, "runner", [4, 6], title="EMBOSCADA EN EL RÍO DE FUEGO")
    L.checkpoint(5200)
    L.plat(5680, 450, 180)
    L.enemies("runner", [6500, 6800, 7100], guard=True)
    L.enemies("zombie", [6900, 7300], guard=True)
    L.write(next_of(3))


def level_4():
    L = Level(4, "Forja Abandonada", 8200)
    L.bedrock(); L.walls()
    L.floor(0, 8200)
    L.title("FORJA ABANDONADA")
    L.weapon(700, "w_trident", "Tridente Infernal — atraviesa a cinco enemigos en línea y perfora armadura")
    L.label(40, 470, "Los saqueadores atacan en manada: alinealos y lanzá el tridente.")
    L.enemies("runner", [1400, 1700, 2000])
    L.checkpoint(2400)
    L.arena(3400, "runner", [6, 8], title="LOS SABUESOS DE LA FORJA")
    L.checkpoint(4200)
    L.block(4600, 80, 60); L.plat(4850, 430); L.block(5100, 90, 80)
    L.label(5300, 470, "Un bruto acorazado custodia la salida: el tridente le perfora la armadura", TIP, 13, 640)
    L.checkpoint(6200)
    L.enemies("brute", [7100], guard=True)
    L.enemies("runner", [6800, 7300, 7600], guard=True)
    L.write(next_of(4))


def level_5():
    L = Level(5, "Caverna de Lava", 8400, "lava_cavern.jpg")
    L.walls()
    L.floor(0, 1800); L.floor(1940, 3400); L.floor(3540, 6200); L.floor(6340, 8400)
    L.title("CAVERNA DE LAVA")
    L.label(40, 470, "Lagos de lava bajo la caverna. Los brutos se esconden en el calor.", WARN, 13, 600)
    L.enemies("runner", [1000, 1300])
    L.plat(1870, 450, 160)
    L.enemies("brute", [2600])
    L.enemies("runner", [2900])
    L.plat(3470, 450, 160)
    L.checkpoint(3800)
    L.arena(4900, "runner", [8, 8], "brute", [1, 2], "EL NIDO DE LA CAVERNA")
    L.checkpoint(5700)
    L.plat(6270, 450, 160)
    L.enemies("runner", [7000, 7500], guard=True)
    L.enemies("brute", [7300, 7800], guard=True)
    L.write(next_of(5))


def level_6():
    L = Level(6, "Osario", 8400, "lava_cavern.jpg")
    L.bedrock(); L.walls()
    L.floor(0, 2000); L.floor(2140, 8400)
    L.title("OSARIO")
    L.weapon(700, "w_soul", "Báculo de Almas — los orbes rebotan 3 veces: apuntá al suelo y a las paredes")
    L.label(40, 470, "Montañas de huesos. Algo se mueve entre ellos...")
    L.enemies("brute", [1500])
    L.checkpoint(2500)
    L.arena(3500, "zombie", [10, 12], "brute", [2, 2], "EL OSARIO")
    L.checkpoint(4300)
    L.label(4400, 470, "Espíritus en pena: atraviesan las paredes y te persiguen volando", WARN, 13, 620)
    L.enemies("ghost", [5100], y=470.0)
    L.plat(5300, 440); L.plat(5600, 370)
    L.checkpoint(6000)
    L.arena(7000, "brute", [2, 3], title="LOS GUARDIANES DE HUESO")
    L.enemies("ghost", [7850], guard=True, y=470.0)
    L.write(next_of(6))


def level_7():
    L = Level(7, "Puente de Cadenas", 8600, "lava_cavern.jpg")
    L.walls()
    L.floor(0, 1600); L.floor(1740, 2900); L.floor(3040, 4300); L.floor(4440, 8600)
    L.title("PUENTE DE CADENAS")
    L.label(40, 470, "El puente cuelga sobre un mar de lava. No mires abajo.", WARN, 13, 600)
    L.plat(1670, 450, 160)
    L.enemies("ghost", [2200, 2600], y=470.0)
    L.enemies("zombie", [2400])
    L.plat(2970, 450, 160)
    L.checkpoint(3300)
    L.enemies("ghost", [3700, 4000], y=470.0)
    L.enemies("brute", [3900])
    L.plat(4370, 450, 160)
    L.checkpoint(4700)
    L.arena(5800, "ghost", [3, 4], title="EL CORO DEL ABISMO")
    L.checkpoint(6600)
    L.enemies("ghost", [7300, 7700], guard=True, y=470.0)
    L.enemies("brute", [7500], guard=True)
    L.write(next_of(7))


def level_8():
    L = Level(8, "Pozos de Azufre", 8600)
    L.bedrock(); L.walls()
    L.floor(0, 8600)
    L.title("POZOS DE AZUFRE")
    L.weapon(700, "w_sulfur", "Cetro de Azufre — las bolas estallan y queman a todos los que estén cerca")
    L.label(40, 470, "El azufre arde: juntá a los enemigos y hacelos estallar.")
    L.enemies("ghost", [1400, 1800], y=470.0)
    L.enemies("runner", [1600, 2000])
    L.checkpoint(2400)
    L.arena(3400, "ghost", [4, 6], "brute", [1, 1], "NUBES DE AZUFRE")
    L.checkpoint(4200)
    L.block(4600, 80, 60); L.plat(4850, 430); L.block(5100, 90, 80)
    L.label(5300, 470, "Un centinela con escudo bloquea el paso: rompele la guardia", WARN, 13, 600)
    L.enemies("sentinel", [5700])
    L.checkpoint(6000)
    L.arena(7000, "zombie", [10, 12], "ghost", [2, 3], "LA FOSA DE LOS CONDENADOS")
    L.enemies("sentinel", [7950], guard=True)
    L.write(next_of(8))


def level_9():
    L = Level(9, "Murallas de la Ciudadela", 9200, "demon_citadel.jpg")
    L.bedrock(); L.walls()
    L.floor(0, 3000); L.floor(3140, 9200)
    L.title("MURALLAS DE LA CIUDADELA")
    L.weapon(700, "w_demon", "Espada Demoníaca — tajos rápidos y amplios que prenden fuego")
    L.label(40, 470, "La ciudadela del Señor del Abismo. Tres puestos te separan del trono.")
    L.enemies("sentinel", [1500])
    L.enemies("runner", [1800, 2100])
    L.checkpoint(2600)
    L.arena(3900, "zombie", [10], "sentinel", [1], "PUESTO 1: EL FOSO")
    L.checkpoint(4700)
    L.arena(5800, "runner", [8, 10], "sentinel", [1, 2], "PUESTO 2: LA PUERTA DE HIERRO")
    L.checkpoint(6600)
    L.arena(7600, "ghost", [5, 6], "sentinel", [2, 2], "PUESTO 3: LAS ALMENAS")
    L.enemies("sentinel", [8550, 8750], guard=True)
    L.write(next_of(9))


def level_10():
    L = Level(10, "Trono del Señor del Abismo", 9600, "demon_citadel.jpg")
    L.bedrock(); L.walls()
    L.floor(0, 9600)
    L.title("TRONO DEL SEÑOR DEL ABISMO [JEFE]")
    L.label(40, 470, "El salón del trono. Preparate: el Señor del Abismo espera al final.")
    L.enemies("zombie", [1000, 1300, 1600])
    L.checkpoint(1900)
    L.arena(2900, "runner", [8, 10], "brute", [2, 2], "LA GUARDIA DEL TRONO")
    L.checkpoint(3700)
    L.plat(4100, 460); L.plat(4400, 390); L.plat(4700, 460)
    L.arena(5800, "ghost", [6, 6], "sentinel", [2, 2], "EL SALÓN DE LAS ALMAS")
    L.checkpoint(6700)
    L.label(7100, 400, "EL SEÑOR DEL ABISMO — su onda de choque se esquiva saltando", WARN, 18, 900)
    L.arena(7900, "runner", [2], "boss", [1])
    L.weapon(8800, "w_axe")
    L.gate_reward = "Hacha del Abismo"
    L.write(next_of(10))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for fn in (level_1, level_2, level_3, level_4, level_5, level_6, level_7, level_8, level_9, level_10):
        fn()
