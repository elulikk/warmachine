@echo off
cd /d "%~dp0"
echo ========================================================
echo               INICIANDO WARMACHINE
echo ========================================================
echo.
if exist "C:\GODOT\Godot_v4.7.2-stable_win64.exe" (
    "C:\GODOT\Godot_v4.7.2-stable_win64.exe"
    goto :EOF
)
if exist "C:\GODOT\Godot_v4.7.2-stable_win64_console.exe" (
    "C:\GODOT\Godot_v4.7.2-stable_win64_console.exe"
    goto :EOF
)
echo [ERROR] No se encontro Godot en C:\GODOT
pause
