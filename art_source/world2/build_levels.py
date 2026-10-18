"""Genera los 10 sectores del Mundo 2 (Valle Esmeralda): levels/chapter_2/level_2_XX.tscn.

Uso: python art_source/world2/build_levels.py
Los niveles se arman con las mismas piezas que el capítulo 4 (StaticBody2D + ColorRect bajo Environment); el arte
lo pone LevelSkin (capítulo 2) y la decoración meadow_decor.gd. Editar acá y regenerar, o editar el .tscn a mano.
Suelo: cara superior en y=556. Enemigos en y=555. Armas sobre pedestal en y=512.
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "levels", "chapter_2")

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
    "w_knife": ("Resource", "res://data/weapons/combat_knife.tres"),
    "w_bow": ("Resource", "res://data/weapons/longbow.tres"),
    "w_javelin": ("Resource", "res://data/weapons/javelin.tres"),
    "w_fire": ("Resource", "res://data/weapons/fire_staff.tres"),
    "w_ice": ("Resource", "res://data/weapons/ice_staff.tres"),
    "w_sword": ("Resource", "res://data/weapons/iron_sword.tres"),
    "w_shield": ("Resource", "res://data/weapons/wooden_shield.tres"),
    "w_hammer": ("Resource", "res://data/weapons/heavy_hammer.tres"),
}

WEAPON_NAMES = {
    "w_knife": "Cuchillo de Combate", "w_bow": "Arco Largo", "w_javelin": "Jabalina",
    "w_fire": "Báculo de Fuego", "w_ice": "Báculo de Hielo", "w_sword": "Espada de Hierro",
    "w_shield": "Escudo de Madera", "w_hammer": "Martillo Pesado",
}

TIP = "Color(0.95, 1, 0.85, 1)"
WARN = "Color(1, 0.55, 0.35, 1)"
GOOD = "Color(0.55, 1, 0.45, 1)"


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

    def body(self, name, cx, cy, w, h, color="Color(0.3, 0.45, 0.2, 1)"):
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
        self.body("Bedrock", self.length / 2.0, 660.0, self.length + 200, 60, "Color(0.25, 0.2, 0.15, 1)")

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
                          'entity_name = "Espantapájaros"\ndummy_name = "Espantapájaros"\n' % (self.uid("Dummy"), fmt(float(x))))

    def checkpoint(self, x):
        self.used.add("checkpoint")
        self.cp_n += 1
        self.nodes.append('[node name="Checkpoint%d" parent="." instance=ExtResource("checkpoint")]\nposition = Vector2(%s, 556)\ncheckpoint_id = "checkpoint_2_%02d_%s"\n'
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
        head = ('[node name="Level_2_%02d" type="Node2D"]\nscript = ExtResource("level")\nlevel_id = "2_%02d"\nlevel_title = "Sector 2-%d"\n'
                'chapter_number = 2\nnext_level_path = "%s"\n' % (num, num, num, next_path))
        if self.backdrop:
            head += 'backdrop_file = "%s"\n' % self.backdrop
        bg = ('[node name="Background" type="CanvasLayer" parent="."]\nlayer = -100\n\n'
              '[node name="ColorRect" type="ColorRect" parent="Background"]\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\n'
              'grow_horizontal = 2\ngrow_vertical = 2\nmouse_filter = 2\ncolor = Color(0.45, 0.7, 0.9, 1)\n')
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
        path = os.path.join(OUT, "level_2_%02d.tscn" % num)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("ok", os.path.relpath(path, ROOT), self.length)

    def title(self, subtitle):
        self.label(40, 380, "CAPÍTULO 2 • VALLE ESMERALDA • SECTOR 2-%d — %s" % (self.num, subtitle), "Color(0.75, 1, 0.55, 1)", 14, 760)


def next_of(num):
    return "res://levels/chapter_2/level_2_%02d.tscn" % (num + 1) if num < 10 else "res://levels/chapter_3/level_3_01.tscn"


# ============================================================================== niveles

def level_1():
    L = Level(1, "Prado del Alba", 6200)
    L.bedrock(); L.walls()
    L.floor(0, 1500); L.floor(1640, 6200)
    L.title("PRADO DEL ALBA")
    L.label(40, 470, "Un valle verde al otro lado del túnel. Empezás de cero: buscá un arma.")
    L.weapon(700, "w_knife", "Cuchillo — [Click izquierdo] para atacar")
    L.label(1350, 440, "Saltá el arroyo seco [Espacio]", TIP, 13, 360)
    L.block(2100, 70, 40); L.block(2300, 80, 70)
    L.plat(2550, 470, 200)
    L.enemies("zombie", [2800, 3150, 3500])
    L.checkpoint(3800)
    L.label(4000, 470, "Los muertos del valle se levantan... acabá con todos para abrir el portón", WARN, 13, 640)
    L.enemies("zombie", [4400, 4700, 5000, 5300], guard=True)
    L.write(next_of(1))


def level_2():
    L = Level(2, "Sendero del Arquero", 7400)
    L.bedrock(); L.walls()
    L.floor(0, 2200); L.floor(2340, 4600); L.floor(4740, 7400)
    L.title("SENDERO DEL ARQUERO")
    L.weapon(600, "w_bow", "Arco Largo — [Click] disparar, [R] recargar el carcaj")
    L.dummy(1100)
    L.label(900, 470, "Practicá con el espantapájaros: la flecha atraviesa a un enemigo", TIP, 13, 560)
    L.plat(1700, 470); L.plat(1950, 400)
    L.enemies("zombie", [2600, 2900])
    L.enemies("runner", [3300, 3700])
    L.checkpoint(4000)
    L.plat(4670, 470, 220)
    L.block(5200, 80, 60)
    L.enemies("runner", [5600, 5900], guard=True)
    L.enemies("zombie", [6200, 6500, 6800], guard=True)
    L.write(next_of(2))


def level_3():
    L = Level(3, "Colinas Floridas", 7600)
    L.bedrock(); L.walls()
    L.floor(0, 1800); L.floor(1940, 7600)
    L.title("COLINAS FLORIDAS")
    L.label(40, 470, "Los saqueadores atacan en grupo: mantené la distancia con el arco")
    L.block(900, 80, 50); L.block(1100, 80, 90 - 10)
    L.plat(1300, 420, 200)
    L.enemies("runner", [2300, 2600, 2900])
    L.checkpoint(3300)
    L.arena(4300, "runner", [4, 6], title="EMBOSCADA EN LA COLINA")
    L.checkpoint(5100)
    L.plat(5500, 460); L.plat(5800, 390); L.plat(6100, 460)
    L.enemies("runner", [6300, 6600, 6900], guard=True)
    L.write(next_of(3))


def level_4():
    L = Level(4, "Arroyo de las Piedras", 8200)
    L.walls()
    # Sin lecho de roca: los pozos de este nivel son de verdad
    L.floor(0, 1400); L.floor(1520, 2600); L.floor(2730, 4300); L.floor(4430, 8200)
    L.title("ARROYO DE LAS PIEDRAS")
    L.label(40, 470, "Cuidado: el arroyo es profundo. Si caés, volvés al último puesto de control.", WARN, 13, 640)
    L.weapon(800, "w_javelin", "Jabalina — lenta pero atraviesa 3 enemigos y perfora armadura")
    L.enemies("runner", [1900, 2300])
    L.plat(2665, 450, 160)
    L.checkpoint(3000)
    L.label(3200, 470, "Los brutos acorazados resisten las flechas: probá la jabalina", TIP, 13, 520)
    L.enemies("brute", [3700])
    L.enemies("runner", [4000])
    L.plat(4365, 450, 160)
    L.checkpoint(4700)
    L.block(5200, 90, 60); L.plat(5450, 430)
    L.enemies("brute", [6200, 7000], guard=True)
    L.enemies("runner", [6500, 6700, 7300], guard=True)
    L.write(next_of(4))


def level_5():
    L = Level(5, "Molino Abandonado", 8000)
    L.bedrock(); L.walls()
    L.floor(0, 8000)
    L.title("MOLINO ABANDONADO")
    L.label(40, 470, "Dos asaltos en los campos del molino. Recuperá vida entre oleada y oleada.")
    L.enemies("zombie", [900, 1200])
    L.checkpoint(1600)
    L.arena(2600, "runner", [5, 6], "brute", [0, 1], "ASALTO AL MOLINO")
    L.checkpoint(3400)
    L.plat(3800, 460); L.plat(4100, 390); L.plat(4400, 460)
    L.checkpoint(4900)
    L.arena(5900, "zombie", [6, 8], "brute", [1, 2], "LA HORDA DE LOS CAMPOS")
    L.checkpoint(6700)
    L.enemies("brute", [7300], guard=True)
    L.write(next_of(5))


def level_6():
    L = Level(6, "Linde del Bosque", 8000, "forest_green.jpg")
    L.bedrock(); L.walls()
    L.floor(0, 2000); L.floor(2140, 8000)
    L.title("LINDE DEL BOSQUE")
    L.weapon(700, "w_fire", "Báculo de Fuego — bolas de fuego que queman. [R] recupera maná")
    L.label(40, 470, "Entrás al bosque. Un mago dejó su báculo en el claro...")
    L.enemies("zombie", [1300, 1500, 1700])
    L.checkpoint(2500)
    L.enemies("zombie", [3000, 3200, 3400, 3600])
    L.checkpoint(4000)
    L.arena(5000, "zombie", [8, 10], title="LOS MUERTOS DEL BOSQUE")
    L.checkpoint(5800)
    L.plat(6200, 460); L.plat(6450, 390)
    L.enemies("zombie", [6800, 7000], guard=True)
    L.enemies("brute", [7300], guard=True)
    L.write(next_of(6))


def level_7():
    L = Level(7, "Bosque Susurrante", 8400, "forest_green.jpg")
    L.walls()
    L.floor(0, 1700); L.floor(1830, 3600); L.floor(3740, 5500); L.floor(5640, 8400)
    L.title("BOSQUE SUSURRANTE")
    L.label(40, 470, "Espíritus del bosque: atraviesan las paredes y te persiguen volando.", WARN, 13, 600)
    L.plat(1765, 450, 160)
    L.enemies("ghost", [2300], y=470.0)
    L.enemies("zombie", [2700, 3000])
    L.checkpoint(3300)
    L.plat(3670, 450, 160)
    L.enemies("ghost", [4200, 4700], y=470.0)
    L.plat(4400, 440); L.plat(4700, 370)
    L.checkpoint(5200)
    L.plat(5570, 450, 160)
    L.arena(6500, "ghost", [3, 4], title="EL CORO DE LOS ESPECTROS")
    L.enemies("zombie", [7500, 7800], guard=True)
    L.write(next_of(7))


def level_8():
    L = Level(8, "Claro de Escarcha", 8400, "forest_green.jpg")
    L.bedrock(); L.walls()
    L.floor(0, 8400)
    L.title("CLARO DE ESCARCHA")
    L.weapon(700, "w_ice", "Báculo de Hielo — congela y frena a los enemigos")
    L.label(40, 470, "Congelá a los rápidos y rematalos con la jabalina o el fuego.")
    L.enemies("runner", [1300, 1500, 1700, 1900])
    L.checkpoint(2300)
    L.arena(3300, "runner", [6, 8], "ghost", [1, 2], "CAZA EN EL CLARO")
    L.checkpoint(4100)
    L.block(4500, 80, 60); L.plat(4750, 430); L.block(5000, 90, 80)
    L.enemies("brute", [5400])
    L.checkpoint(5800)
    L.arena(6800, "ghost", [3, 4], "brute", [1, 1], "ESPECTROS DE HIELO")
    L.enemies("runner", [7700, 7900], guard=True)
    L.write(next_of(8))


def level_9():
    L = Level(9, "Camino al Castillo", 9200, "castle_sunset.jpg")
    L.bedrock(); L.walls()
    L.floor(0, 3000); L.floor(3140, 9200)
    L.title("CAMINO AL CASTILLO")
    L.weapon(700, "w_sword", "Espada de Hierro — tajos amplios para el cuerpo a cuerpo")
    L.label(40, 470, "La guardia del castillo vigila el camino. Tres puestos te separan de la muralla.")
    L.enemies("sentinel", [1500])
    L.enemies("runner", [1800, 2100])
    L.checkpoint(2600)
    L.arena(3900, "zombie", [8], "brute", [2], "PUESTO 1: LA ALDEA ARRASADA")
    L.checkpoint(4700)
    L.arena(5800, "runner", [6, 8], "sentinel", [1, 1], "PUESTO 2: EL PUENTE")
    L.checkpoint(6600)
    L.arena(7600, "ghost", [4, 5], "brute", [1, 2], "PUESTO 3: LA MURALLA")
    L.enemies("sentinel", [8600], guard=True)
    L.write(next_of(9))


def level_10():
    L = Level(10, "Castillo del Rey Caído", 9600, "castle_sunset.jpg")
    L.bedrock(); L.walls()
    L.floor(0, 9600)
    L.title("CASTILLO DEL REY CAÍDO [JEFE]")
    L.label(40, 470, "El patio del castillo. Preparate: el Rey Caído espera al final.")
    L.enemies("zombie", [1000, 1300])
    L.checkpoint(1700)
    L.arena(2700, "runner", [6, 8], "brute", [1, 2], "LA GUARDIA REAL")
    L.checkpoint(3500)
    L.plat(3900, 460); L.plat(4200, 390); L.plat(4500, 460)
    L.arena(5600, "ghost", [4, 6], "sentinel", [1, 1], "EL SALÓN DE LOS ESPECTROS")
    L.checkpoint(6500)
    L.label(7100, 400, "EL REY CAÍDO — su onda de choque se esquiva saltando", WARN, 18, 900)
    L.arena(7900, "runner", [1], "boss", [1])
    L.weapon(8800, "w_hammer")
    L.gate_reward = "Martillo Pesado"
    L.write(next_of(10))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for fn in (level_1, level_2, level_3, level_4, level_5, level_6, level_7, level_8, level_9, level_10):
        fn()
