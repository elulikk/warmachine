# Lanzamientos de prueba sin molestar al usuario (puede estar mirando una película):
# ventana chica, fuera de la pantalla, sin tomar el foco y sin pantalla completa.
# Uso: `source quiet.sh` desde la raíz del proyecto ANTES de lanzar Godot, y `quiet_restore` en el trap de salida.
# - override.cfg (Godot lo lee de la raíz del proyecto al arrancar) pisa modo, posición y foco de la ventana.
# - Lanzar Godot_v4.7.2-stable_win64.exe (sin consola), nunca el _console.exe: abre una consola en primer plano.
# - WARMACHINE_QUIET=1 hace que `core/settings.gd` no aplique la pantalla completa de las opciones del usuario.
export WARMACHINE_QUIET=1
QUIET_OVERRIDE="$(pwd)/override.cfg"
cat > "$QUIET_OVERRIDE" <<'CFG'
[display]

window/size/mode=0
window/size/no_focus=true
window/size/initial_position_type=0
window/size/initial_position=Vector2i(-30000, -30000)
CFG
quiet_restore() { rm -f "$QUIET_OVERRIDE"; }
