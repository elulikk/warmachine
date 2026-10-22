---
name: add-window
description: Agregar o cambiar una ventana, menú, panel o pantalla de UI en WARMACHINE (códice, bestiario, misiones, mapa, tienda, crafteo, logros, diálogo, menú de NPC, etc.) usando el sistema modular de ventanas (GameWindow + UiKit + WindowRegistry) y el tema intercambiable (UiTheme). También para cambiar el aspecto gráfico de toda la UI (colores, fuentes, marcos, texturas). Usar cuando el usuario pida una ventana, menú, pantalla, panel, pestaña nueva o "cambiar los gráficos de la interfaz".
---

# Ventanas y menús modulares

La UI nueva se arma **por código**, sin `.tscn`, con tres piezas (POO) y un tema (datos):

| Pieza | Archivo | Para qué |
|---|---|---|
| `UiTheme` | `ui/framework/ui_theme.gd` + `ui/themes/steam_theme.tres` | **Todos** los gráficos: carpeta de texturas 9-slice, reemplazos puntuales, colores, fuentes, tamaños. |
| `SteamSkin` | `ui/components/steam_skin.gd` | Fábrica de estilos (marco de ventana, inset, pergamino, botones, pestañas). Lee el tema. También estiliza las ventanas viejas (`.tscn`). |
| `UiKit` | `ui/framework/ui_kit.gd` | Widgets ya estilizados: `label`, `paragraph`, `section`, `parchment`, `stat_grid`/`stat_row`, `button`, `tabs`/`tab`, `scroll_list`, `list_detail`, `list_entry`, `image`, `bar`, `separator`, `spacer`, `clear`, `reset_list`, `rarity_color`. |
| `GameWindow` | `ui/framework/game_window.gd` | Clase base: marco, cabecera arrastrable, cerrar (X y Esc), centrado, tecla para abrir/cerrar, grupo `window_<id>`. |
| `WindowRegistry` | `ui/framework/window_registry.gd` | Lista `WINDOWS`. El HUD (presente en cada nivel y en el campamento) las instala todas. `open/toggle/find/close_all(tree, id)`. |

Ejemplo de referencia completo: **`ui/windows/codex_window.gd`** (pestañas + lista/ficha + siluetas de lo bloqueado).

## Receta: ventana nueva

1. **Datos aparte de la vista.** Si la ventana muestra datos del juego, la lógica va en un script de datos sin UI (`core/<tema>/<tema>.gd`, `extends RefCounted`, funciones `static`), como `core/codex/codex.gd`. Lo persistente va en `MetricsManager` (serializa por slot) o en `SaveManager`. La ventana solo lee y dibuja.
2. **Script de la ventana** en `ui/windows/<id>_window.gd`:
   ```gdscript
   extends "res://ui/framework/game_window.gd"
   ## Qué muestra y con qué tecla se abre.

   var _value: Label = null

   func _configure() -> void:          # NO sobrescribir _init
       window_id = &"quests"
       window_title = "MISIONES [Y]"
       toggle_action = &"toggle_quests"  # vacío = solo por código/botón
       window_size = Vector2(520, 420)

   func _build(root: Control) -> void:  # una vez
       var body: VBoxContainer = UiKit.section(root, "ACTIVAS")
       var grid: GridContainer = UiKit.stat_grid(body)
       _value = UiKit.stat_row(grid, "Completadas:", "0")
       UiKit.button(body, "Abandonar", _on_abandon)

   func _on_opened() -> void:           # cada vez que se abre: refrescar
       _value.text = str(QuestLog.completed_count())
   ```
3. **Registrarla:** sumar `preload("res://ui/windows/<id>_window.gd")` a `WINDOWS` en `window_registry.gd`.
4. **Tecla (si tiene):** en `core/input_manager.gd`, `_configure_action("toggle_<id>", 0.2, [_create_key_event(KEY_?)])` (mirar qué teclas están libres con `grep -n "KEY_" core/input_manager.gd`; hoy libre: Y), y el rótulo en `REMAPPABLE` de `core/settings.gd` para que aparezca en Opciones > Controles.
5. **Abrirla desde otro lado** (NPC, botón, menú, interactuable): `WindowRegistryScript.open(get_tree(), &"<id>")` con `const WindowRegistryScript = preload("res://ui/framework/window_registry.gd")`.
6. Probar con el skill **smoke-test** (campamento y un nivel). Para mirarla, una escena descartable que la abra y guarde captura (ver memoria runtime-smoke-check).

### Patrones

- **Lista + ficha** (bestiario, tienda, logros): `var v := UiKit.list_detail(root, 200)` → `v.list`, `v.detail`; filas con `UiKit.list_entry(v.list, texto, icono, _show.bind(dato, i), bloqueado)`; en la ficha `UiKit.clear(v.detail)` y reconstruir. Para rellenar la lista de nuevo, `UiKit.reset_list(v.list)`.
- **Pestañas:** `var t := UiKit.tabs(root)`; `var page := UiKit.tab(t, "Nombre")`.
- **Bloqueado / sin descubrir:** `locked = true` en `list_entry` e `image(..., silhouette = true)`; texto "???".
- **Valores en vivo** (vida, munición): guardar el `Label` que devuelve `stat_row` y actualizarlo en `_process` solo si `visible`, cada ~0.25 s (como `stats_window.gd`).
- **Menú de botones** (pausa, NPC): `UiKit.vbox(root)` + `UiKit.button(...)` por opción.
- **Pausar el juego** mientras está abierta: en `_on_opened` `get_tree().paused = true` y `process_mode = PROCESS_MODE_ALWAYS` en `_configure`; despausar en `_on_closed`. Solo si el usuario lo pide (las ventanas actuales no pausan).

### Reglas

- **Nunca** colores, fuentes ni texturas sueltos en una ventana: rol de texto (`"body"`, `"dim"`, `"small"`, `"header"`, `"title"`, `"big"`, `"gold"`, `"good"`, `"bad"`) o campo del tema. Si hace falta un color nuevo, agregarlo como `@export` en `ui_theme.gd` y usarlo desde `UiKit`.
- Si un widget se repite en dos ventanas, va a `UiKit` (función `static`, recibe `parent`, devuelve el control, lo marca con `SKINNED`).
- Scripts nuevos **sin `class_name`**, referenciados por `preload` (gotcha de la caché de clases; ver memoria class-name-cache-gotcha).
- Las ventanas viejas con `.tscn` (`stats_window`, `inventory_window`, `stash_window`, `trade_window`, `blacksmith_window`) siguen funcionando: heredan de `DraggableWindow` y se estilizan con `SteamSkin.skin_tree`. Migrarlas a `GameWindow` solo si el usuario lo pide.

## Receta: cambiar los gráficos de la UI

- **Retoque:** abrir `ui/themes/steam_theme.tres` en el inspector de Godot y cambiar colores, fuentes, tamaños o la carpeta de texturas. Afecta a ventanas nuevas y viejas, HUD, tooltips y menú.
- **Una textura:** `texture_overrides` del `.tres`: clave = nombre de archivo que pide SteamSkin (`win_frame.png`, `inset_dark.png`, `slot_leather.png`, `parchment.png`, `btn_copper.png`, `btn_dark.png`, `btn_plate.png`, `slot_screws.png`, `slot_dark.png`, `bar_under.png`, `bar_fill.png`, `close_btn.png`), valor = textura nueva. Los márgenes 9-slice están en `SteamSkin` (`_texture_box(..., margins, content, ...)`): si la textura nueva tiene otro grosor de borde, ajustarlos ahí.
- **Tema entero nuevo** (p. ej. uno futurista para otro mundo): carpeta `assets/art/ui_<tema>/` con los mismos nombres de archivo, duplicar el `.tres` con esa `texture_dir` y colores nuevos, y apuntar `ACTIVE_PATH` en `ui_theme.gd` (o `UiTheme.use(tema)` + `SteamSkin.reload_theme()` antes de construir la UI).
- Arte nuevo de UI: lo genera el usuario en Flow (ver skill google-flow y su política vigente); recortar 9-slice con márgenes parejos.
