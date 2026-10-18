"""Abre WARMACHINE directamente en un sector, el campamento u otra escena, sin pasar por el menú.

Uso:
  python -I .claude/skills/open-game/open_game.py <destino> [--import] [--dry-run]

Destinos:
  1_03            sector 3 del mundo 1 (levels/chapter_1/level_1_03.tscn); el primer número es el mundo
  base            campamento (scenes/hub/base_camp.tscn)
  test            sala de pruebas (core/test_level.tscn)
  stress          sala de estrés (scenes/hub/stress_room.tscn)
  cine            banco de cinemáticas (scenes/hub/cinematic_bench.tscn)
  menu            menú principal (scenes/main_menu.tscn)
  res://... o ruta relativa al proyecto, para cualquier otra escena

  --import    reimporta el arte antes de abrir (hace falta si se agregó arte nuevo; tarda un poco)
  --dry-run   solo muestra la escena que abriría, sin lanzar Godot

Godot se lanza desligado de esta terminal: la ventana queda abierta y el script termina enseguida.
No toca saves ni settings: el juego guarda lo que el usuario haga dentro de la partida.
"""
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
GODOT = r"C:\GODOT\Godot_v4.7.2-stable_win64.exe"
ALIASES = {
    "base": "scenes/hub/base_camp.tscn",
    "test": "core/test_level.tscn",
    "stress": "scenes/hub/stress_room.tscn",
    "cine": "scenes/hub/cinematic_bench.tscn",
    "menu": "scenes/main_menu.tscn",
}
DETACHED_PROCESS = 0x00000008
CREATE_NEW_PROCESS_GROUP = 0x00000200


def resolve(target):
    """Devuelve la escena relativa al proyecto (p. ej. levels/chapter_1/level_1_03.tscn)."""
    if target in ALIASES:
        return ALIASES[target]
    match = re.fullmatch(r"(\d)_(\d{2})", target)
    if match:
        hits = glob.glob(os.path.join(ROOT, "levels", "chapter_%s" % match.group(1), "level_%s.tscn" % target))
        if not hits:
            raise SystemExit("No existe el sector %s (buscado en levels/chapter_%s/)." % (target, match.group(1)))
        return os.path.relpath(hits[0], ROOT).replace("\\", "/")
    rel = re.sub(r"^res://", "", target)
    if os.path.isfile(os.path.join(ROOT, rel)):
        return rel
    raise SystemExit("Destino desconocido: %s. Usá un sector (1_03), base, test, stress, cine, menu o una ruta de escena." % target)


def godot_running():
    out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq Godot_v4.7.2-stable_win64.exe"],
                         capture_output=True, text=True).stdout
    return "Godot_v4.7.2" in out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        raise SystemExit(__doc__)
    scene = resolve(args[0])
    if "--dry-run" in sys.argv:
        print("Escena:", scene)
        return
    if not os.path.isfile(GODOT):
        raise SystemExit("No encuentro Godot en %s." % GODOT)
    if "--import" in sys.argv:
        subprocess.run([GODOT, "--headless", "--path", ROOT, "--import"], cwd=ROOT, capture_output=True)
        print("Arte reimportado.")
    if godot_running():
        print("Aviso: ya hay una ventana de Godot abierta; esta abre otra.")
    subprocess.Popen([GODOT, "--path", ROOT, "res://" + scene], cwd=ROOT,
                     creationflags=DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP, close_fds=True)
    print("Abriendo WARMACHINE en", scene)


if __name__ == "__main__":
    main()
