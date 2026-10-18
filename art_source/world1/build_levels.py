"""Genera los 8 sectores del Mundo 1 (El Presente): levels/chapter_1/level_1_0X.tscn.

Uso: python art_source/world1/build_levels.py
Los niveles se arman con las mismas piezas que el capítulo 4 (StaticBody2D + ColorRect bajo Environment); el arte
lo pone LevelSkin (tema del capítulo 1, con cambios por sector) y la decoración city_decor.gd.
Suelo: cara superior en y=556. Enemigos en y=555. Armas sobre pedestal en y=512.
Pozos de agua (P-3 y P-5): niveles sin `bedrock()`; los huecos entre suelos se ven como agua (city_decor) y caer
devuelve al puesto de control.
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "levels", "chapter_1")

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
    "rat": ("PackedScene", "res://entities/enemies/city_rat.tscn"),
    "thief": ("PackedScene", "res://entities/enemies/city_thief.tscn"),
    "thug": ("PackedScene", "res://entities/enemies/city_thug.tscn"),
    "bouncer": ("PackedScene", "res://entities/enemies/city_bouncer.tscn"),
    "gunman": ("PackedScene", "res://entities/enemies/city_gunman.tscn"),
    "hitman": ("PackedScene", "res://entities/enemies/city_hitman_smg.tscn"),
    "hitman_elite": ("PackedScene", "res://entities/enemies/city_hitman_elite.tscn"),
    "agent": ("PackedScene", "res://entities/enemies/time_agent.tscn"),
    "the_box": ("Script", "res://levels/the_box.gd"),
    "w_knife": ("Resource", "res://data/weapons/combat_knife.tres"),
    "w_9mm": ("Resource", "res://data/weapons/pistol_9mm.tres"),
    "w_revolver": ("Resource", "res://data/weapons/revolver.tres"),
    "w_shotgun": ("Resource", "res://data/weapons/shotgun.tres"),
    "w_smg": ("Resource", "res://data/weapons/smg.tres"),
    "w_eagle": ("Resource", "res://data/weapons/desert_eagle.tres"),
}

TIP = "Color(0.85, 0.92, 1, 1)"
WARN = "Color(1, 0.6, 0.4, 1)"
GOOD = "Color(1, 0.85, 0.35, 1)"


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
        self.event = (0.0, "helicopter")  # (probabilidad, estilo) del evento de Agentes
        self.guaranteed = []
        self.music = ""

    # ---------------------------------------------------------------- utilidades
    def uid(self, prefix):
        self.count[prefix] = self.count.get(prefix, 0) + 1
        return "%s%d" % (prefix, self.count[prefix])

    def shape(self, w, h):
        key = "Rect_%dx%d" % (w, h)
        self.shapes[key] = (w, h)
        return key

    def body(self, name, cx, cy, w, h, color="Color(0.16, 0.17, 0.22, 1)"):
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
        self.body("Bedrock", self.length / 2.0, 660.0, self.length + 200, 60, "Color(0.1, 0.1, 0.14, 1)")

    def walls(self):
        self.body("LeftWall", -20.0, 240.0, 40, 800)
        self.body("RightWall", self.length + 20.0, 240.0, 40, 800)

    def block(self, x, w, h):
        """Bloque macizo apoyado en el suelo (escalón, auto estacionado, contenedor)."""
        self.body(self.uid("Block"), float(x), GROUND - h / 2.0, w, h)

    def plat(self, x, y, w=180):
        """Plataforma delgada (escalera de incendio, toldo, cerca); `y` = cara superior."""
        self.body(self.uid("Plank"), float(x), y + 10.0, w, 20)

    def pedestal(self, x):
        self.body(self.uid("Pedestal"), float(x), 547.0, 64, 18, "Color(0.5, 0.45, 0.35, 1)")

    # ---------------------------------------------------------------- contenido
    def label(self, x, y, text, color=TIP, size=13, width=520):
        # Sin textos flotantes en los niveles: el juego enseña jugando (carteles, tutorial y tips fuera)
        return
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

    def checkpoint(self, x):
        self.used.add("checkpoint")
        self.cp_n += 1
        self.nodes.append('[node name="Checkpoint%d" parent="." instance=ExtResource("checkpoint")]\nposition = Vector2(%s, 556)\ncheckpoint_id = "checkpoint_4_%02d_%s"\n'
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
        return n


    def box(self, x):
        """La Caja: cubo negro (grupo `the_box`; la cinemática del P-8 la abre)."""
        self.used.add("the_box")
        self.nodes.append('[node name="TheBox" type="Sprite2D" parent="." groups=["the_box"]]\nposition = Vector2(%s, 478)\nscale = Vector2(0.52, 0.52)\n'
                          'z_index = 2\nscript = ExtResource("the_box")\n' % fmt(float(x)))

    # ---------------------------------------------------------------- salida
    def write(self, next_path):
        num = self.num
        ext = []
        for key in sorted(self.used):
            t, path = RES[key]
            ext.append('[ext_resource type="%s" path="%s" id="%s"]' % (t, path, key))
        subs = ['[sub_resource type="RectangleShape2D" id="%s"]\nsize = Vector2(%d, %d)\n' % (k, w, h) for k, (w, h) in self.shapes.items()]
        head = ('[node name="Level_4_%02d" type="Node2D"]\nscript = ExtResource("level")\nlevel_id = "4_%02d"\nlevel_title = "P-%d · %s"\n'
                'chapter_number = 4\nnext_level_path = "%s"\n' % (num, num, num, self.name, next_path))
        if self.backdrop:
            head += 'backdrop_file = "%s"\n' % self.backdrop
        if self.guaranteed:
            head += 'guaranteed_weapon_paths = Array[String]([%s])\n' % ", ".join('"%s"' % g for g in self.guaranteed)
        if self.event[0] > 0.0:
            head += 'agent_event_chance = %s\nagent_event_style = "%s"\n' % (fmt(float(self.event[0])), self.event[1])
        if self.music:
            head += 'base_music = &"%s"\n' % self.music
        bg = ('[node name="Background" type="CanvasLayer" parent="."]\nlayer = -100\n\n'
              '[node name="ColorRect" type="ColorRect" parent="Background"]\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\n'
              'grow_horizontal = 2\ngrow_vertical = 2\nmouse_filter = 2\ncolor = Color(0.03, 0.04, 0.07, 1)\n')
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
        path = os.path.join(OUT, "level_1_%02d.tscn" % num)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("ok", os.path.relpath(path, ROOT), self.length)

    def title(self, subtitle):
        self.label(40, 380, "EL PRESENTE • SECTOR P-%d — %s" % (self.num, subtitle), "Color(0.6, 0.8, 1, 1)", 14, 760)


def next_of(num):
    # El P-8 termina en la Caja, que lleva a la Periferia Subterránea (la "primera puerta")
    return "res://levels/chapter_1/level_1_%02d.tscn" % (num + 1) if num < 8 else "res://levels/chapter_4/level_4_01.tscn"


# ============================================================================== niveles
# Ciclo de enemigos: crece un tipo antes de que entre el siguiente (ratas → ladrones → matones → asaltantes →
# patovicas → sicarios) y se repite. Pozos de agua (sin lecho): P-3 y P-5. Interiores: P-3, P-6 y P-7.

def level_1():
    # Tutorial sin decir que lo es: se arranca sin armas, el cuchillo es la primera, las ratas llegan de a 1, 2 y 3,
    # y al final espera un asaltante armado (luego será una cinemática) que deja la 9mm. Sin props ni obstáculos.
    # OJO: level_1_01.tscn tiene edificios horneados a mano; regenerarlo los borra.
    L = Level(1, "La calle", 6400)
    L.bedrock(); L.walls()
    L.floor(0, 6400)
    L.title("LA CALLE")
    L.label(40, 470, "Moverte [A/D]   Saltar [Espacio]")
    L.weapon(650, "w_knife", "Cuchillo de Combate — atacá con [Click]")
    L.label(1000, 450, "Una rata. Probá el cuchillo.")
    L.enemies("rat", [1250, 1900, 2100])
    L.checkpoint(2450)
    L.label(2500, 450, "Cuidado: vienen de a varias.")
    L.enemies("rat", [2900, 3050, 3200])
    L.checkpoint(3700)
    L.enemy("gunman", 4600)
    L.weapon(5000, "w_9mm", "Pistola 9mm — la del asaltante. Disparar [Click]   Recargar [R]")
    L.write(next_of(1))


def level_2():
    L = Level(2, "Los callejones", 7400)
    L.bedrock(); L.walls()
    L.floor(0, 7400)
    L.title("LOS CALLEJONES")
    L.label(40, 470, "Escaleras de incendio y toldos: subí para ver el callejón desde arriba.")
    L.enemies("rat", [1100, 1400])
    L.plat(1900, 470, 200); L.plat(2200, 400, 180); L.plat(2500, 330, 200)
    L.enemies("thief", [2200, 2700, 3100])
    L.checkpoint(3400)
    L.arena(4400, "thief", [5, 7], title="EMBOSCADA EN EL CALLEJÓN")
    L.checkpoint(5300)
    L.label(5400, 470, "Un matón: golpea fuerte y aguanta. Mantené la distancia.", WARN, 13, 560)
    L.enemies("thug", [6300], guard=True)
    L.enemies("thief", [6000, 6800], guard=True)
    L.write(next_of(2))


def level_3():
    L = Level(3, "Las alcantarillas", 8000)
    L.walls()
    # Canales de agua: huecos de verdad, caer devuelve al puesto de control
    L.floor(0, 1700); L.floor(1840, 3600); L.floor(3740, 5800); L.floor(5940, 8000)
    L.title("LAS ALCANTARILLAS")
    L.label(40, 470, "Canales de agua negra: si caés, volvés al último puesto de control.", WARN, 13, 640)
    L.enemies("rat", [900, 1200, 1500])
    L.plat(1770, 450, 160)
    L.enemies("rat", [2200, 2400, 2600, 2800])
    L.enemies("thief", [3100])
    L.checkpoint(3400)
    L.plat(3670, 450, 160)
    L.arena(4800, "rat", [8, 10, 12], title="LA PLAGA")
    L.checkpoint(5600)
    L.plat(5870, 450, 160)
    L.enemies("thief", [6500, 6900, 7300], guard=True)
    L.enemies("rat", [6700, 7100], guard=True)
    L.write(next_of(3))


def level_4():
    L = Level(4, "El barrio de casitas", 8400)
    L.bedrock(); L.walls()
    L.floor(0, 8400)
    L.title("EL BARRIO DE CASITAS")
    L.weapon(700, "w_revolver", "Revólver — un tiro potente por vez; apuntá y no desperdicies las balas")
    L.label(40, 470, "Cercas y techos de casitas sirven de plataforma. Cuidado: ahora hay armas de fuego.")
    L.enemies("thief", [1300, 1700, 2100])
    L.plat(2500, 470, 200); L.plat(2800, 400, 200)
    L.enemies("thug", [3000])
    L.checkpoint(3300)
    L.arena(4300, "thief", [6, 8], "gunman", [1, 2], "VECINOS ASUSTADOS")
    L.checkpoint(5200)
    L.label(5300, 470, "Un asaltante dispara de lejos: cubrite detrás de los autos y acortá distancia.", WARN, 13, 640)
    L.block(5700, 120, 50)
    L.enemies("gunman", [6300, 6800], guard=True)
    L.enemies("thug", [6600], guard=True)
    L.enemies("thief", [7200, 7500], guard=True)
    L.write(next_of(4))


def level_5():
    L = Level(5, "El muelle", 9000)
    L.walls()
    L.floor(0, 2600); L.floor(2740, 5200); L.floor(5340, 9000)
    L.title("EL MUELLE")
    L.weapon(700, "w_shotgun", "Escopeta — perdigones a corta distancia; ideal contra matones")
    L.label(40, 470, "Contenedores apilados y agua negra entre los muelles.")
    L.block(1300, 160, 70); L.block(1700, 160, 110)
    L.enemies("gunman", [1500, 2100])
    L.plat(2670, 450, 160)
    L.enemies("thug", [3300]); L.enemies("gunman", [3700])
    L.checkpoint(4000)
    L.plat(5270, 450, 160)
    L.arena(6400, "gunman", [6, 8], "thug", [1, 2], "LA CARGA DEL BARCO")
    L.checkpoint(7200)
    L.enemies("gunman", [7600, 8000], guard=True)
    L.write(next_of(5))


def level_6():
    L = Level(6, "El hotel", 9200)
    L.bedrock(); L.walls()
    L.floor(0, 9200)
    L.event = (0.25, "portal")
    L.title("EL HOTEL")
    L.weapon(700, "w_smg", "SMG — ráfagas rápidas; mantené el clic y controlá el retroceso")
    L.label(40, 470, "Lobby, pasillos y ascensores. Los patovicas del Sindicato custodian cada piso.")
    L.enemies("gunman", [1500, 1900])
    L.plat(2300, 470, 220); L.plat(2600, 400, 220)
    L.enemies("thug", [3000]); L.enemies("gunman", [3300])
    L.checkpoint(3600)
    L.label(3700, 470, "Un patovica: enorme y pesado. Disparale desde lejos.", WARN, 13, 560)
    L.enemies("bouncer", [4300])
    L.checkpoint(5200)
    L.arena(6300, "gunman", [6, 8], "bouncer", [1, 2], "EL PISO DE SEGURIDAD")
    L.checkpoint(7200)
    L.enemies("bouncer", [8100], guard=True)
    L.enemies("gunman", [7800, 8500], guard=True)
    L.write(next_of(6))


def level_7():
    L = Level(7, "La discoteca", 9600)
    L.bedrock(); L.walls()
    L.floor(0, 9600)
    L.event = (0.25, "portal")
    L.music = "club"
    L.title("LA DISCOTECA")
    L.label(40, 470, "Luces, láseres y música fuerte. El Sindicato lo tiene todo vigilado.")
    L.enemies("gunman", [1400, 1800]); L.enemies("thug", [2200])
    L.plat(2700, 460, 220); L.plat(3000, 390, 220)
    L.enemies("bouncer", [3400]); L.enemies("gunman", [3800])
    L.checkpoint(4100)
    L.arena(5200, "gunman", [8, 10], "bouncer", [2, 3], "LA PISTA DE BAILE")
    L.checkpoint(6100)
    L.enemies("bouncer", [6800, 7200], guard=True)
    L.enemies("gunman", [7000, 7600], guard=True)
    L.weapon(8800, "w_eagle", "Desert Eagle — calibre enorme, un tiro letal")
    L.gate_reward = "Desert Eagle"
    L.write(next_of(7))


def level_8():
    L = Level(8, "La azotea", 4800)
    L.bedrock(); L.walls()
    L.floor(0, 4800)
    L.title("LA AZOTEA [FINAL]")
    L.label(40, 470, "La Caja está arriba. El Sindicato manda a lo peor que tiene.")
    L.enemies("hitman", [1000, 1300])
    L.checkpoint(1700)
    L.box(2900)
    L.arena(2900, "hitman", [4, 5, 6, 6, 7, 8], "bouncer", [0, 1, 1, 2, 2, 3], "OLEADAS DEL SINDICATO")
    L.write(next_of(8))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for fn in (level_1, level_2, level_3, level_4, level_5, level_6, level_7, level_8):
        fn()
