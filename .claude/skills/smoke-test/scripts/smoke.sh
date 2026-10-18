#!/usr/bin/env bash
# Lanza una escena de WARMACHINE unos cuadros y reporta errores de script.
# Respalda y restaura saves/ y settings.cfg del usuario (siempre con un respaldo NUEVO).
# Uso: smoke.sh <escena res://...> [cuadros=90] [timeout_s=100]
set -u

SCENE="${1:-}"
FRAMES="${2:-90}"
LIMIT="${3:-100}"
if [ -z "$SCENE" ]; then
	echo "Uso: smoke.sh <res://escena.tscn> [cuadros=90] [timeout_s=100]"
	exit 2
fi

PROJECT="$(cd "$(dirname "$0")/../../../.." && pwd)"
# El ejecutable SIN consola: el _console.exe abre una ventana de consola en primer plano cuando se lanza desde
# un proceso sin consola (como Claude Code) y le corta al usuario lo que esté mirando. La salida igual se captura.
GODOT="/c/GODOT/Godot_v4.7.2-stable_win64.exe"
[ -f "$GODOT" ] || GODOT="/c/GODOT/Godot_v4.7.2-stable_win64_console.exe"
if [ ! -f "$GODOT" ]; then
	echo "No se encontró Godot en C:\\GODOT"
	exit 2
fi

USERDATA="$(cygpath -u "$APPDATA")/Godot/app_userdata/WARMACHINE"
BACKUP="$(mktemp -d)"
OUTLOG="$BACKUP/run.log"

# --- respaldo (siempre nuevo) ---
if [ -d "$USERDATA/saves" ]; then
	cp -r "$USERDATA/saves" "$BACKUP/saves"
fi
if [ -f "$USERDATA/settings.cfg" ]; then
	cp "$USERDATA/settings.cfg" "$BACKUP/settings.cfg"
fi

restore() {
	if [ -d "$BACKUP/saves" ]; then
		rm -rf "$USERDATA/saves"
		cp -r "$BACKUP/saves" "$USERDATA/saves"
	fi
	if [ -f "$BACKUP/settings.cfg" ]; then
		cp "$BACKUP/settings.cfg" "$USERDATA/settings.cfg"
	fi
}
trap 'restore; quiet_restore' EXIT

echo ">> Escena: $SCENE  (cuadros: $FRAMES, timeout: ${LIMIT}s)"
cd "$PROJECT" || exit 2
source "$PROJECT/.claude/skills/smoke-test/scripts/quiet.sh"
timeout "$LIMIT" "$GODOT" --audio-driver Dummy --path . "$SCENE" --quit-after "$FRAMES" > "$OUTLOG" 2>&1
CODE=$?

if [ "$CODE" -eq 124 ]; then
	echo ">> TIMEOUT: la escena no terminó en ${LIMIT}s (colgada o demasiado pesada)"
fi

# Ruido conocido que no es un error nuevo
NOISE='resources still in use|ObjectDB instances leaked|Leaked instance|leaked at exit'
ERRORS="$(grep -E 'SCRIPT ERROR|ERROR:|Parse Error|Failed to load script|Could not resolve class' "$OUTLOG" | grep -Ev "$NOISE" | sort | uniq -c | sort -rn | head -40)"

if [ -n "$ERRORS" ]; then
	echo "$ERRORS"
fi

# Godot colgado
if tasklist 2>/dev/null | grep -qi "Godot_v4"; then
	echo ">> AVISO: queda un proceso de Godot abierto (puede ser el juego del usuario)."
fi

echo ">> Log completo de esta corrida: $OUTLOG"
echo ">> Nota: esta corrida rotó los logs de Godot del usuario (godot.log)."
if [ -n "$ERRORS" ] || [ "$CODE" -eq 124 ]; then
	echo "RESULTADO: FALLÓ"
	exit 1
fi
echo "RESULTADO: OK"
