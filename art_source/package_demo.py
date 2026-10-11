"""Empaqueta una demo portable: el ejecutable de Godot + el proyecto (sin fuentes de arte). Un .zip para pasar a un amigo.
Ejecutar: python -I art_source/package_demo.py  ->  build/WARMACHINE_demo.zip"""
import os, zipfile
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
GODOT = r"C:\GODOT\Godot_v4.7.2-stable_win64.exe"
OUT = os.path.join(ROOT, "build", "WARMACHINE_demo.zip")
SKIP_DIRS = {"art_source", "tests", "build", ".claude", ".git", "editor", "PSD", "sets  mobs", "android"}
SKIP_FILES = {"ost.zip", "export_presets.cfg", "build_exe.bat", "run.bat", "run_game.bat"}
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(os.path.join(ROOT, "build", ".gdignore"), "a").close()
with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    z.write(GODOT, "WARMACHINE/WARMACHINE.exe")
    z.writestr("WARMACHINE/JUGAR.bat", '@echo off\r\ncd /d "%~dp0"\r\nstart "" WARMACHINE.exe --path "%~dp0game"\r\n')
    z.writestr("WARMACHINE/LEEME.txt", "WARMACHINE (demo)\r\n\r\nDescomprimi la carpeta completa y abri JUGAR.bat.\r\nNo hace falta instalar nada.\r\nEsc: pausa y opciones.\r\n")
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f in SKIP_FILES or f.endswith(".md"):
                continue
            full = os.path.join(base, f)
            rel = os.path.relpath(full, ROOT).replace("\\", "/")
            z.write(full, "WARMACHINE/game/" + rel)
print(round(os.path.getsize(OUT) / 1048576), "MB", OUT)
