@echo off
rem Compila WARMACHINE en un unico .exe (pck embebido) -> build\WARMACHINE.exe
rem y un .zip listo para compartir -> build\WARMACHINE_<version>.zip
rem Requiere las plantillas de exportacion de Godot 4.7.2 (Editor > Administrar plantillas de exportacion).
rem El icono (icon.ico) y la version del .exe salen de export_presets.cfg; la version del juego, de project.godot.
setlocal
cd /d "%~dp0"
set GODOT=C:\GODOT\Godot_v4.7.2-stable_win64_console.exe
if not exist "%GODOT%" set GODOT=C:\GODOT\Godot_v4.7.2-stable_win64.exe
if not exist "%GODOT%" (
    echo [ERROR] No se encontro Godot en C:\GODOT
    pause
    exit /b 1
)
if not exist "%APPDATA%\Godot\export_templates\4.7.2.stable\windows_release_x86_64.exe" (
    echo [ERROR] Faltan las plantillas de exportacion 4.7.2.stable.
    echo         Abri el editor ^> Editor ^> Administrar plantillas de exportacion ^> Descargar e instalar.
    pause
    exit /b 1
)

rem Version del juego (config/version en project.godot)
set VERSION=dev
for /f "tokens=2 delims==" %%v in ('findstr /b /c:"config/version=" project.godot') do set VERSION=%%~v
echo Version: %VERSION%

if not exist build mkdir build
if not exist build\.gdignore type nul > build\.gdignore

rem 1) Importar recursos nuevos (run.bat no pasa por el editor; sin esto faltarian texturas en el .pck)
"%GODOT%" --headless --path "%~dp0" --import
if errorlevel 1 (
    echo [ERROR] Fallo la importacion de recursos.
    pause
    exit /b 1
)

rem 2) Exportar
"%GODOT%" --headless --path "%~dp0" --export-release "Windows Desktop" "%~dp0build\WARMACHINE.exe"
if errorlevel 1 (
    echo [ERROR] La exportacion fallo.
    pause
    exit /b 1
)
if not exist build\WARMACHINE.exe (
    echo [ERROR] No se genero build\WARMACHINE.exe
    pause
    exit /b 1
)

rem 3) Empaquetar para compartir
if exist "build\WARMACHINE_%VERSION%.zip" del /q "build\WARMACHINE_%VERSION%.zip"
powershell -NoProfile -Command "Compress-Archive -Path 'build\WARMACHINE.exe' -DestinationPath 'build\WARMACHINE_%VERSION%.zip'"

echo.
echo Listo: build\WARMACHINE.exe y build\WARMACHINE_%VERSION%.zip
echo Prueba en una PC limpia: copiar el .zip, descomprimir y abrir. Los errores quedan en
echo %%APPDATA%%\Godot\app_userdata\WARMACHINE\logs\errors_*.log
pause
