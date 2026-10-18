---
name: add-item
description: Agregar un ítem a WARMACHINE — equipo con habilidad (casco, capa, botas, anillo), arrojadizo táctico, consumible, runa o arma — con su recurso .tres, ícono generado en Google Flow, cableado en jugador/equipo/opciones, venta, botín, pedestal de prueba y verificación. Usar cuando el usuario pida un arma, ítem, equipo, consumible, arrojadizo o runa nueva.
---

# Agregar un ítem

Leer `PROJECT_CONTEXT.md` secciones 4, 5, 8 y 9. El commit `41f6de9` (Boomerang, Casco Láser, Capa de Invisibilidad) es el ejemplo completo: `git show --stat 41f6de9`.

## Paso 0: qué tipo es

| Tipo | Datos | Lógica |
|---|---|---|
| **Equipo pasivo** (stats, doble salto) | `data/items/<id>.tres` (`ItemData`, `modifiers`, `grants_extra_jump`) | ninguna: lo aplica `apply_to_stats` |
| **Equipo con habilidad** (láser, capa, dash, alas) | `data/items/<id>.tres` | flag en `Player` + controlador (ver abajo) |
| **Arrojadizo** (granada, red, boomerang) | `data/items/throwables/<id>.tres` (`equip_slot = "TACTICAL"`, `throwable_scene`) | escena en `combat/throwables/` (base `RigidBody2D` con arco y fusible) |
| **Consumible** | `data/consumables/<id>.tres` (`ConsumableData`) | `consumable_manager.gd` si el efecto es nuevo |
| **Runa** | `data/runes/<id>.tres` (`RuneData`) | efecto nuevo en el arma/proyectil |
| **Arma** | `data/weapons/<id>.tres` (`WeaponData`) | solo datos (familia, grip, daño…); mecánica nueva en `weapon_manager.gd` |

## Paso 1: el recurso `.tres`

Copiar uno parecido (`data/items/laser_helmet.tres`, `data/items/throwables/boomerang.tres`, `data/weapons/desert_eagle.tres`).

- `item_id` = nombre del archivo (el ícono y los guardados lo usan). **Nunca renombrar después**: los slots guardan la ruta.
- `rarity`: 0 COMMON … 4 LEGENDARY; `gold_value`: precio base; `description` en español con la tecla y el efecto.
- `equip_slot`: `HEAD`, `CHEST`, `GLOVES`, `BOOTS`, `BACK`, `ACCESSORY` (ocupa ACCESSORY_1/2), `TACTICAL`.
- Armas: `family` y `grip` deciden el comportamiento base (`WeaponData.FAMILY_RULES`: techo de perforación, piso de penetración, qué suelta al recargar, sonido de disparo). No leer nunca el id/nombre para decidir comportamiento: leer `family`.
- Armas con mecánica de mundo (rebotes, `impact_scene`, hielo): ya hay campos (`innate_bounces`, `impact_scene`, `ice_duration`); usarlos antes de tocar código.

## Paso 2: cablear la habilidad (solo equipo con habilidad)

1. **`entities/player/player.gd`**: bandera (`var has_<x>: bool = false`) y, si hace falta, el controlador hijo creado por `preload` (como `eye_laser.gd`, `cloak_controller.gd`). Los estados leen la bandera; **no se crean estados nuevos** por habilidad.
2. **`entities/player/equipment_manager.gd`**: un caso en el `match item.item_id` del equipar/desequipar (`player.has_<x> = is_equipping`).
3. **Acción de teclado**: `_configure_action("<accion>", 0.2, [tecla, botón])` en `core/input_manager.gd` y la entrada en `REMAPPABLE` de `core/settings.gd` (si el jugador debe poder reasignarla). Elegir una tecla libre: revisar los `_configure_action` existentes.
4. **Sonido**: un caso nuevo en `Sfx._build()` (`core/sfx.gd`) y se pide con `GameFeel.sfx(ctx, &"nombre", pos)`. Audio real después con `Sfx.register_override()`.
5. Si afecta a los enemigos (como la invisibilidad), tocar `target_scanner_component.gd` y las IA que leen `Player` (`basic_runner`, `armored_brute`, `ghost`, `shielded_sentinel`, `armed_enemy`).
6. Cosas pesadas (partículas, rayos): presupuesto de FX (`effect_cap.gd`), `DeathFxQueue`, pool de proyectiles; sin `print()` por impacto.

## Paso 3: arte (Google Flow)

**Siempre generar el ícono del ítem en Google Flow** (skill **`google-flow`**, que usa `asset-browser`), sin esperar a que el usuario lo pida; solo se omite si ya existe `assets/art/items/<item_id>.png`. Un sonido real (en vez del sintetizado) va por **`generate-audio`**, solo si el usuario lo pide; si no, un caso nuevo en `Sfx._build()` alcanza.

- **Ícono (simplificado, legible en la UI)**: se ve a 32×32 en slots/inventario/tienda, así que el prompt debe pedir un **símbolo simple**: una sola silueta grande y reconocible, formas gruesas y bordes nítidos, 2–3 colores planos con un acento del color del ítem, sin detalle fino, sin texto, sin sombra de suelo, centrado y ocupando ~80% del cuadro, fondo negro liso, 1:1. Plantilla: `Genera una imagen de un ícono simplificado de <objeto>, silueta simple y gruesa, pocos colores planos, bordes nítidos, estilo 2D de videojuego, centrado, aislado sobre fondo negro liso, brillo sutil <color>, sin texto, sin sombra.` Si hay varios ítems en la tanda, una hoja o un mensaje de Agente con todos.
- Pasarlo con `python art_source/flow_tools.py place <jpg> --kind item --id <item_id>` → `assets/art/items/<item_id>.png` (consumibles `assets/art/consumables/`, runas `assets/art/runes/`). **Revisar el resultado reducido a 32×32** (la hoja de contacto o abrir el PNG): si no se lee a ese tamaño, regenerar más simple. `ItemIcons` lo prefiere; si no existe cae a pixel art 16×16.
- **Arma en mano**: PNG de lado apuntando a la derecha en `assets/art/weapons/<id>.png`. Los datos de agarre salen de `core/art/weapon_art.gd` (generado: copiar una entrada de un arma parecida y ajustar `grip`, `hand`, `support`, `tip_x`, `scale`) y el movimiento de `core/art/weapon_motion.gd` (`PROFILES` o `ALIASES` apuntando al perfil de otra arma). Ícono sin PNG: `ItemIcons.WEAPON_POSES` por tipo.
- Importar: `Godot --headless --path . --import`; cargar con `Art.tex()`.
- Sin Flow disponible: dejar el ítem funcionando con el ícono de reserva y anotar "ícono pendiente" en el ROADMAP.

## Paso 4: que se pueda conseguir y probar

- **Comercio**: el modo prueba (`sell_everything` en `data/traders/merchant.tres`) ofrece todo `.tres` de `data/consumables`, `data/weapons`, `data/items`, `data/items/throwables` y `data/runes` automáticamente. Para un comerciante real, agregarlo a `gear_paths` del `TraderData`.
- **Botín**: agregarlo a `gear_pool` / `early_gear_pool` de la `LootTable` correspondiente (`data/loot/*.tres`); el peso lo da la rareza.
- **Arma de sector**: pedestal en el generador del nivel (`L.weapon`) o `guaranteed_weapon_paths` del `LevelBase`.
- **Banco de Pruebas**: pedestal en `core/test_level.tscn` (`ext_resource` del `.tres` + nodo con `item_data = …`, como `CloakPedestal`).
- El `known_paths` de `save_manager.gd` es solo para armas legacy sin ruta: **no** hace falta tocarlo.

## Paso 5: verificar

1. `bash .claude/skills/smoke-test/scripts/smoke.sh res://core/test_level.tscn 120`, y una corrida del campamento.
2. Si cableaste una habilidad, probarla con una escena descartable (`smoke-test`, sección "escena descartable"): equipar por código con `equipment_manager`, simular la acción y mirar el resultado con `XT`.
3. Reportar qué quedó sin validar (balance, sensación, ícono). Una sola actualización del ROADMAP por tanda, sin commit salvo que se pida.

## Trampas

- Scripts nuevos referenciados desde otros: `const X = preload("res://…")`, no `class_name` (ver `smoke-test`).
- No nombrar enums como clases globales (`State`).
- `allow_duplicates = false` en pedestales de ítems únicos; los drops de enemigos usan `true`.
- Un arma a dos manos bloquea la mano 2; un escudo solo va en la mano 2 (`grip = SHIELD`).
- Las armaduras (cascos de set, pecheras con set bonus) **se eliminaron**: no reintroducir sets sin pedido. El Casco Láser es un ítem de ranura `HEAD` con habilidad, no una armadura.
