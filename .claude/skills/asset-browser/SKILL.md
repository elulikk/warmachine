---
name: asset-browser
description: Reglas comunes para generar assets en sitios web (Google Flow para imágenes y música, ElevenLabs para efectos de sonido) desde el navegador — qué navegador usar (Claude in Chrome en el Edge del usuario, si no el integrado), cómo conectarlo, descargas, y lo que ya se probó y falló. Lo leen google-flow y generate-audio antes del primer paso en el navegador; no se usa solo.
---

# Navegador para generar assets

Lo usan `google-flow` (imágenes, video) y `generate-audio` (música en Flow Music, efectos en ElevenLabs). Leerlo **una vez por sesión**, antes del primer paso en el navegador; si ya se conectó el navegador en esta sesión, no repetir el procedimiento.

## Orden de preferencia

1. **Claude in Chrome en el Edge de la PC del usuario** (`mcp__claude-in-chrome__*`). Tiene sus sesiones abiertas (Google con Flow Plus, ElevenLabs).
   - Herramientas diferidas: cargarlas en **una sola** `ToolSearch` (`select:` `list_connected_browsers`, `select_browser`, `switch_browser`, `tabs_context_mcp`, `tabs_create_mcp`, `navigate`, `computer`, `read_page`, `find`, `get_page_text`, `javascript_tool`, `tabs_close_mcp`).
   - `list_connected_browsers` → si aparece su Edge (`onThisComputer` / `isLocal`), `select_browser` con su `deviceId` → `tabs_context_mcp` con `createIfEmpty` → **pestaña nueva** (`tabs_create_mcp` + `navigate`). No usar pestañas que el usuario tenga abiertas.
   - Leer el skill `anthropic-skills:chrome-browser` antes del primer paso.
   - Ubicar controles con `find` / `read_page` (refs `ref_N`); las coordenadas que figuran en `google-flow` son del navegador integrado, no sirven en Edge sin una captura nueva.
2. **Navegador integrado de la app** (`mcp__Claude_Browser__*`) si el Edge no está conectado y el usuario no lo puede abrir ahora. Sus sesiones son propias: el usuario inicia sesión a mano la primera vez.
3. **Ninguno disponible:** dejar el asset como **pendiente documentado** (prompt exacto, nombre de archivo, carpeta destino) y seguir con lo que no depende de él.

## Reglas

- **Nunca escribir credenciales** ni crear cuentas; si el sitio pide iniciar sesión, pedírselo al usuario.
- **Descargas:** pedir permiso antes (archivo, sitio, tamaño aproximado). Caen en `C:\Users\Usuario\Downloads`. Verificar con `ls -lt` que llegaron antes de seguir.
- **No borrar nada de Downloads** que no hayas bajado vos en esta tarea: el usuario baja ahí sus propios audios.
- **Créditos:** Flow (puntos) y ElevenLabs (caracteres/créditos) se gastan por generación. Una variante por pedido, sin regenerar "para elegir", salvo que el usuario lo pida. Si el saldo no alcanza, avisar y parar.
- Leer el saldo solo si el usuario pregunta o si una generación falla por créditos (Flow: badge PLUS arriba a la derecha).
- Sin aceptar términos, banners de cookies "aceptar todo" ni permisos OAuth por el usuario: rechazar lo no esencial o preguntar.

## Ya probado: no repetir

- **2026-10-13:** `list_connected_browsers` devolvió `[]` (Edge cerrado o extensión sin conectar). Si vuelve vacío, **no** reintentar en bucle: pedirle una vez al usuario que abra Edge con la extensión Claude, o usar `switch_browser` (le muestra "Conectar" y espera hasta 2 min). Si no responde, pasar al integrado.
- **Subir imágenes a Flow pegando con `ctrl+v` sintético NO funciona** (ni en el integrado; la caja ProseMirror no recibe el pegado). Tampoco simular el evento por JavaScript. Para referencias, usar "+" → elegir una imagen **ya existente en el proyecto** → "Añadir a petición", o pedirle al usuario que pegue la imagen él.
- No sustituir una descarga fallida por capturas de pantalla recortadas.
- `gh` (GitHub CLI) no está instalado en esta PC: no tiene que ver con el navegador, pero para abrir PRs dar el enlace `compare` en vez de intentar el sitio de GitHub con el navegador.
