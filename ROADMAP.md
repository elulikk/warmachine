# ROADMAP — SHOOTER-RPG PLATAFORMA (PROTOTIPO)

## 0. Estado Actual (Línea de Base)
* **Motor:** Godot 4.7, Jolt Physics, GDScript 2.0 con tipado estricto. Sin testing headless: la verificación es en runtime (F5).
* **Sistemas operativos:**
  - FSM del jugador (correr, saltar, coyote time, jump buffer, pared, jetpack, alas, vuelo).
  - Combate desacoplado: `HitPayload` → `HealthComponent` → `ProjectilePool`.
  - Persistencia en 3 slots JSON (`user://saves/slot_{id}.json`).
  - Baúl (`StashChest`) individual por personaje.
  - HUD, `ZoneModifierManager`, `LootTable`, `WaveManager` (oleadas continuas en el sandbox).
  - Rarezas y tooltips RPG, forja con el Herrero.
* **Ya existe y se reutiliza:** `LevelRegistry`, `MapSelector` (pestañas por capítulo y grilla de niveles), `LevelBase`, orbes de EXP.
* **Validado en juego:** Fase A (game feel) y los sectores 1-1 a 1-4 (secciones 2.1 a 2.2c). El balance fino de cada nivel sigue anotado como pendiente en su sección.
* **Armado, pendiente de validar:** Sector 1-5 (sección 2.2d) y la segunda tanda de la Fase O (opciones, posprocesado, recarga por arma, pantalla de carga, registro de errores, ícono y versión del `.exe`).
* **Hecho y validado en juego (2026-10-11):** comercio de dos columnas con venta y recompra (`TradeSession`, `TraderData`, `TradeWindow`; sección 2.3), arrastrar armas de la mochila a la barra de acceso rápido, fogonazo y humo del arma, chispas contra el entorno, sangre / manchas / heridas / tripas al dañar y matar enemigos con arte propio (`combat/damage_fx.gd`, `assets/art/fx/`), botón SIGUIENTE SECTOR en la victoria y relleno de suelos solo sobre el vacío.
* **Hecho (2026-10-11, pendiente de validar en juego):** Sala de Estrés con monitor de rendimiento, fusión de botín y orbes, experiencia con gravedad, cola de efectos de muerte (sin congelamiento al matar muchos juntos), engranaje de munición que recarga al instante. Ver sección 6c.
* **Versión:** `config/version` en `project.godot` (hoy 0.5.0); se ve en el menú principal y en las propiedades del `.exe`.
* **Sandbox separado:** `test_level.tscn` se abre solo desde el botón "Banco de Pruebas" del menú principal; no forma parte de la campaña. El Sector 1-1 es un nivel real y no es el sandbox.
* **Stand-by (no se toca por ahora):** jetpack, alas, vuelo, gancho de anclaje, baliza de translocación, runas avanzadas, alt-fire (zoom del sniper), mercenarios y drones, contratos de zona, los 50 niveles.

---

## 1. Objetivo del Prototipo
Validar un bucle simple y divertido: **llega una oleada grande de enemigos, los reventás como piñatas, recogés monedas, loot y XP, subís de nivel, mejorás armadura o arma y avanzás de nivel.**

Contenido mínimo para validarlo:
- **Armas:** 2 o 3, introducidas de a una a lo largo de los primeros niveles: **Cuchillo de Combate** (melee) y **Revólver Oxidado** (rango) en el 1-1; la pistola y la escopeta llegan después (ver 2.1).
- **Enemigos:** 1 o 2 tipos básicos.
- **Movilidad:** una sola mejora (doble salto, salto más alto o más velocidad).
- **Niveles:** 2 o 3 jugables a través del menú de niveles.

---

## 2. Fase A — Game Feel en el Sandbox
*Objetivo:* Que disparar y reventar enemigos se sienta bien antes de construir nada encima.
* **Modelo recomendado:** Sonnet, esfuerzo **medium**.
* **Alcance:**
  1. Screen shake en impactos fuertes y disparos pesados (`camera_follow.gd`).
  2. Hit stop de 0.03 s en críticos y melee.
  3. Flash de daño en enemigos.
  4. Explosión de muerte (partículas y sonido) al eliminar un enemigo.
  5. Magnetismo de pickups (monedas y orbes van hacia el jugador al acercarse).
  6. *(Agregado)* Indicador visual de recarga: barra sobre el jugador que se llena durante la recarga (`ui/reload_indicator.gd`).
* **Criterio de cierre:** En `test_level.tscn`, con F5, cada golpe y cada muerte tiene respuesta visual clara y el juego no se traba.

---

## 2.1 Fase A.1 — Nivel 1 (Sector 1-1): Tutorial de Progresión
*Estado:* Armado en `levels/chapter_1/level_1_01.tscn`, conectado al selector de expediciones. Validado en juego (`run.bat` → Campamento → Capítulo 1).
*Objetivo:* Que el jugador **sienta la progresión**: arranca con casi nada y cada herramienta nueva se gana durante el recorrido, una a la vez, con un tramo para practicarla antes de que llegue la siguiente.

**Principios de diseño (valen para los primeros niveles):**
- **Nada avanzado en el 1-1:** sin runas, armaduras, movilidad extra, arrojadizos ni contratos. Los checkpoints son solo checkpoints: los contratos viven en una terminal aparte (`ContractTerminal`) que por ahora solo existe en el sandbox.
- **Armas súper básicas:** Cuchillo de Combate (melee, 30 de daño) y Revólver Oxidado (rango, 18 de daño, 6 balas, recarga 2.0 s, cadencia lenta). No aparece la pistola criogénica ni la escopeta.
- **Una mecánica por tramo:** se presenta, se practica contra enemigos simples (solo `BasicRunner`) y recién después aparece la siguiente.
- **Niveles largos y legibles:** recorrido de ~8200 px, pasillos largos con enemigos espaciados en vez de arenas llenas.
- **Sin cambios grandes entre niveles:** el jugador debería completar uno o más niveles con este mismo equipo antes de ver una mejora fuerte (Fase C y D).

**Recorrido (posiciones en px aproximadas):**

| # | Tramo | x | Qué pasa |
|---|---|---|---|
| 1 | Calentamiento | 0–800 | Spawn y cartel de movimiento. Sin enemigos. |
| 2 | Aprender a saltar | 800–2060 | 3 bloques de altura creciente (40, 70 y 96 px) y luego 2 pozos poco profundos (140 y 180 px) con una isla en el medio. Los pozos tienen fondo: si cae, sale saltando. |
| 3 | Distancia larga | 2060–2650 | Tramo plano largo con un checkpoint (x 2350). |
| 4 | Pedestal del cuchillo | 2700 | Primera arma: **Cuchillo de Combate**. |
| 5 | Pasillo 1 | 2900–4600 | Techo bajo, 3 ladrones bien separados. Se prueba el cuchillo. |
| 6 | Descanso | 4820 | Checkpoint. |
| 7 | Pedestal del revólver | 5400 | Primera arma de rango: **Revólver Oxidado**. |
| 8 | Pasillo 2 | 5700–7500 | Muñeco de práctica y 4 ladrones. Estos 4 bloquean la compuerta (grupo `arena_enemies`), así que hay que usar el revólver. |
| 9 | Extracción | 7950 | `ExitGate`. Desbloquea el Sector 1-2. |

**Notas técnicas:**
- Se corrigió `data/weapons/rust_revolver.tres`: no tenía `projectile_scene` y no podía disparar. Ahora tiene proyectil y stats propios.
- Los pickups de arma no revisan duplicados: repetir el nivel con un personaje guardado acumula copias del cuchillo y del revólver.
- Dificultad sin balancear: ajustar cantidad de enemigos y separación después de jugarlo.

**Propuesta para los siguientes niveles (a confirmar):**
- **1-3:** primera mejora de arma como recompensa de nivel. Hecho (sección 2.4): arma nueva **Carabina de Chatarra**; la pistola criogénica y la escopeta quedan para más adelante.
- **1-4:** hecho (sección 2.2c): estrena el Bruto Acorazado y el botín de equipo.
- **1-5:** hecho (sección 2.2d): estrena el Centinela con escudo; recompensa MP5 y Runa de Perforación opcional.
- **1-6 o más:** movilidad avanzada y el resto de runas (Fases C y D; hoy en stand-by).

---

## 2.2 Fase A.2 — Nivel 2 (Sector 1-2): Oleadas
*Estado:* Armado en `levels/chapter_1/level_1_02.tscn` (validado en juego). Es la primera aplicación real de la Fase B y la primera mejora de la Fase D.
*Objetivo:* Que el jugador se defienda de oleadas con **las mismas dos armas** (cuchillo y revólver oxidado) y sienta sus límites: 6 balas, recarga de 2.0 s y cuchillo de corto alcance.

**Estructura: arena → pasillo → arena → pasillo → arena**

| # | Tramo | x | Qué pasa |
|---|---|---|---|
| 1 | Entrada | 0–800 | Cartel y checkpoint (x 560). |
| 2 | Arena 1 | 800–1740 | **Oleada de 3 ladrones.** Al entrar se cierran las barreras. |
| 3 | Pasillo 1 | 1760–3000 | Techo bajo, 2 ladrones. Checkpoint (x 3120). |
| 4 | Arena 2 | 3300–4340 | **Oleada de 4 ladrones.** |
| 5 | Pasillo 2 | 4360–5800 | Techo bajo, 3 ladrones. Checkpoint (x 5920). |
| 6 | Arena 3 | 6100–7180 | **Oleada de 6 ladrones.** |
| 7 | Pedestal | 7450 | **Botas Ligeras** (+60 de velocidad de movimiento), la recompensa del nivel. |
| 8 | Extracción | 7850 | `ExitGate`. Desbloquea el Sector 1-3. |

**Reglas y decisiones:**
- **Oleadas 3 → 4 → 6:** una ronda por arena; el pasillo con su checkpoint hace de descanso. `WaveManager` además soporta varias rondas en la misma arena con `rest_between_rounds` (se usará más adelante).
- **Barreras:** se cierran al entrar y se abren al despejar la arena. Si el jugador cae, la arena se reinicia y se puede repetir desde el checkpoint.
- **Mismo equipo:** el nivel garantiza cuchillo y revólver oxidado (`guaranteed_weapon_paths` en `LevelBase`) para que un personaje nuevo no quede desarmado.
- **Solo `BasicRunner`:** el `ArmoredBrute` queda para un nivel posterior.
- **Botas = mejora de movilidad de la Fase D:** se equipan solas en la ranura de pies si está libre; si no, van a la mochila.
- **`ExitGate` ya no anuncia "Pistola Criogénica":** `reward_weapon_text` y `reward_world_flag` están vacíos por defecto.

**Pendiente de balance:** cantidad de ladrones, separación y velocidad (el ladrón va a 65 px/s, más lento que el jugador).

---

## 2.2b Fase A.3 — Nivel 3 (Sector 1-3): Fosos y Arenas con Plataformas
*Estado:* Armado en `levels/chapter_1/level_1_03.tscn` (validado en juego). Es el primer nivel que premia con un arma nueva.
*Objetivo:* Combinar plataformeo mínimo con oleadas, y entregar una mejora clara de arma sin tocar el resto del equipo.

| # | Tramo | x | Qué pasa |
|---|---|---|---|
| 1 | Entrada | 0–1000 | Cartel y checkpoint (x 560). |
| 2 | Fosos 1 | 1000–2240 | 3 fosos (170, 200 y 280 px) con piedras de apoyo en los dos anchos. Sin enemigos. Los fosos tienen fondo a 74 px: si cae, sale saltando. Checkpoint (x 2400). |
| 3 | Pasillo 1 | 2600–3700 | Techo bajo, 3 ladrones espaciados. |
| 4 | Arena 1 | 3900–4960 | **Oleada de 5 ladrones**, con 2 plataformas elevadas. Checkpoint (x 5060). |
| 5 | Fosos 2 | 5300–6480 | 3 fosos (180, 240 y 280 px) con piedras. Sin enemigos. Checkpoint (x 6600). |
| 6 | Arena final | 6800–8200 | **2 rondas (4 y 6 ladrones)** con descanso de 5 s, con 3 plataformas elevadas. Primer uso de varias rondas en una arena. |
| 7 | Recompensa | 8450 | Pedestal con la **Carabina de Chatarra**. |
| 8 | Extracción | 8800 | `ExitGate`. Desbloquea el Sector 1-4. |

**Reglas y decisiones:**
- **Arma nueva, inventada:** `data/weapons/scrap_carbine.tres` (RANGED semiautomática, 20 de daño, 3.5 tiros/s, cargador 10, recarga 1.8 s, atraviesa 1 enemigo, 2 sockets, rareza uncommon). DPS sostenido ~43 contra ~25 del revólver oxidado.
- **Sin duplicados:** `WeaponPickup` tiene `allow_duplicates` (false por defecto). Si el jugador ya posee el arma (arsenal o mochila), el pickup desaparece al cargar el nivel. Esto también corrige la acumulación de cuchillo y revólver en el 1-1. El baúl del campamento no se revisa. Para botín repetible y vendible (legendarias, etc.) se pondrá `allow_duplicates = true`.
- **Solo `BasicRunner`:** el `ArmoredBrute` sigue para un nivel posterior.
- **Plataformas en arenas:** los ladrones no saltan, así que las plataformas dan ventaja de altura.
- **Mismo equipo garantizado:** cuchillo y revólver oxidado (`guaranteed_weapon_paths`).

**Pendiente de balance:** cantidad de ladrones, largo de los fosos y si la carabina se siente como mejora real.

---

## 2.2c Fase A.4 — Nivel 4 (Sector 1-4): El Bruto Acorazado
*Estado:* Armado en `levels/chapter_1/level_1_04.tscn` (validado en juego). Estrena el `ArmoredBrute` (220 HP, 65 de armadura, 38 px/s) y el botín de equipo.
*Objetivo:* Que el jugador entienda que la armadura enemiga reduce su daño y aprenda a resolverlo con espacio y altura, sin que el nivel sea injusto.

| # | Tramo | x | Qué pasa |
|---|---|---|---|
| 1 | Entrada | 0–1100 | Cartel del Bruto y checkpoint (x 560 y 1100). |
| 2 | Arena 1: Duelo | 1500–2700 | **Un solo Bruto**, ronda `[1]`. Arena de 1200 px con 2 plataformas. Tarda ~26 s en cruzarla. |
| 3 | Pasillo | 2900–4100 | Techo bajo, 3 ladrones. Checkpoints (x 2860 y 4400). |
| 4 | Arena 2: Mixta | 4520–5780 | **Rondas `[3, 4]`**, la segunda con 1 Bruto + 3 ladrones. 3 plataformas. |
| 5 | Desvío opcional | 5900–6700 | Escalera de 3 plataformas a la **Runa de Afilado** (+15 de daño plano). Checkpoint (x 5900 y 6800). |
| 6 | Arena final | 6900–8200 | **Rondas `[4, 6]`**, cada una con 1 Bruto. Nunca hay más de 1 Bruto vivo. |
| 7 | Recompensa | 8450 | Pedestal vacío: la armadura T1 que iba acá se eliminó junto con las armaduras. |
| 8 | Extracción | 8700 | `ExitGate`. Desbloquea el Sector 1-5. |

**Reglas y decisiones:**
- **Cómo se resuelve el Bruto:** mitigación 100/165 = 0.61, así que revólver (10.9 por bala) y carabina (12.1) necesitan ~20 y ~18 balas. Se enseña con kiteo (jugador 240 px/s contra 38) y plataformas (no salta; su único ataque es de contacto, 24 por segundo). Sin enemigos a distancia y sin presión de munición (`add_ammo()` es un no-op, solo cuentan cargador y recarga).
- **Penetración real:** revólver, carabina y cuchillo 0; katana 0.1; martillo 0.25; pistola corrosiva 0.5; rifle de precisión **0.85** (el `.tres` manda; antes se documentaba 100%); granada ácida 1.0. La runa de piercing atraviesa enemigos, no armadura; la de afilado (+15 plano) sí ayuda porque suma antes de la mitigación.
- **Runa opcional:** las runas solo se engarzan en el Herrero, así que rinde desde el 1-5.
- **Carabina garantizada:** `guaranteed_weapon_paths` = cuchillo, revólver y carabina, para que entrar al 1-4 sin la carabina no sea una trampa.
- **`WaveManager`** ahora admite `elite_scene` y `elite_per_round`: de los N enemigos de una ronda, los primeros son el elite (cuenta dentro del tamaño). Con los valores por defecto se comporta igual que antes. Acepta cualquier `BasicRunner` o `EnemyBase`.
- **`gear_loot_tier = 1`** en este nivel: los enemigos pueden soltar equipo (ver sección 4, Botín de equipo).
- **Selector bloqueado de verdad:** `MapSelector` deshabilita los sectores sin desbloquear y los no implementados (`LevelRegistry.IMPLEMENTED_LEVELS`) como "PENDIENTE". El 1-4 se desbloquea al extraer del 1-3.

**Pendiente de balance:** tiempo del duelo, cantidad de ladrones en las arenas mixtas y si el nivel se siente demasiado largo.

---

## 2.2d Fase A.5 — Nivel 5 (Sector 1-5): El Centinela con Escudo
*Estado:* Armado en `levels/chapter_1/level_1_05.tscn` (pendiente de validar en juego). Estrena el `ShieldedSentinel` (60 HP, 130 de escudo celeste que se recarga a 30/s si pasan 3 s sin recibir daño, 70 px/s, 14 de contacto).
*Objetivo:* Que el jugador aprenda a **sostener el fuego**: el escudo absorbe todo, pero si no se le da respiro cae y el Centinela muere rápido. Es la contracara del Bruto (que se resuelve con espacio y paciencia).

| # | Tramo | x | Qué pasa |
|---|---|---|---|
| 1 | Entrada | 0–1100 | Cartel del Centinela y checkpoint (x 560). |
| 2 | Arena 1: Duelo | 1300–2500 | **Un solo Centinela**, ronda `[1]`, una plataforma central. |
| 3 | Pasillo | 2650–4100 | Techo bajo: ladrón, Centinela y ladrón (x 3000, 3450, 3850). Checkpoints (x 2650 y 4250). |
| 4 | Arena 2: Mixta | 4400–5600 | **Rondas `[3, 5]`**, 1 Centinela en cada una. 3 plataformas. |
| 5 | Desvío opcional | 5750–6450 | Escalera de 3 plataformas a la **Runa de Perforación** (+1 enemigo atravesado). Checkpoint (x 5750). |
| 6 | Arena final | 6800–8150 | **Rondas `[4, 6, 6]`**, Centinelas `[1, 1, 2]`, descanso de 5 s. Checkpoint (x 6650). |
| 7 | Recompensa | 8450 | Pedestal con el **Subfusil MP5** (automático, 7 de daño a 12 tiros/s). |
| 8 | Extracción | 8800 | `ExitGate`. Desbloquea el Sector 1-6 (todavía esqueleto, sale como PENDIENTE). |

**Reglas y decisiones:**
- **Cómo se resuelve:** 190 de vida efectiva (130 + 60). La carabina (10 balas de 20) lo mata con un cargador si acierta todo; el revólver (6 de 18) necesita recargar, y su recarga (2.0 s) es menor que la espera del escudo (3.0 s): si se recarga y se sigue tirando, el escudo no vuelve.
- **Recompensa MP5:** el primer automático gratis, justo cuando el enemigo nuevo premia la cadencia. Sigue a la venta en el Mercader; con `allow_duplicates = false` el pedestal desaparece si ya se tiene.
- **Botín del Centinela** (`data/loot/shielded_sentinel_loot.tres`, nuevo): 4 a 7 monedas, munición 70%, vida 35%, equipo 12% (carabina, SMG, 9 mm, Colt, MP5, M4). Antes no soltaba nada.
- **`gear_loot_tier = 2`** y armas garantizadas: cuchillo, revólver oxidado y carabina.
- **Nunca más de 2 Centinelas vivos** y siempre con ladrones de distracción: la presión es de foco, no de cantidad.
- **Barra rápida:** las armas garantizadas, compradas o recogidas sin equipar ahora entran solas a los casilleros 1-3 libres (antes una partida con barra guardada no las mostraba y había que ir al inventario).

**Pendiente de balance:** si la arena final con 2 Centinelas es demasiado y si el MP5 llega tarde o temprano.

---

## 2.3 Economía — Mercader y Consumibles
*Estado:* Armado (pendiente de validación en juego). Da un destino a las monedas del loot y herramientas tácticas para las oleadas.

**Comercio (rework):** el Mercader y cualquier NPC comerciante usan una ventana grande de dos columnas (tus pertenencias / stock del comerciante) para **comprar y vender** arrastrando o con clic derecho, con filtros (categoría, rareza, búsqueda, orden), precios sobre cada casillero, lote de consumibles con Mayús, confirmación en operaciones caras o delicadas y una pestaña de **recompra**. Cada comerciante es un recurso `TraderData` (stock, límites, precios de compra y venta, qué categorías compra); la lógica vive en `TradeSession` y el estado (stock limitado, recompra) se guarda en el slot. Ver PROJECT_CONTEXT (`core/trade/`, `TradeWindow`).

**Consumibles (máximo 5 de cada uno, se compran en el Campamento Base):**

| Casillero | Consumible | Precio | Efecto |
|---|---|---|---|
| [4] / Mouse 4 | Poción de Vida | 15 | +50 de vida al instante (no se gasta con la vida completa) |
| [5] / Mouse 5 | Poción Sin Recarga | 25 | 15 s sin gastar munición ni recargar |
| [6] | Poción de Velocidad | 20 | +20 % de velocidad de movimiento por 20 s |

**Reglas y decisiones:**
- **Mercader:** NPC en el Campamento Base ([E]) y también en el hub del sandbox para probar con las 999 monedas. Vende al valor del objeto y compra al 40 %.
- **Persistencia:** las cantidades se guardan en el slot (`consumables`). La compra guarda la partida.
- **Efectos que no se apilan:** volver a usar una poción activa renueva su duración sin duplicar el bono.
- **Botones laterales del ratón:** M4 y M5 usan los consumibles 1 y 2 (antes M4 lanzaba el arrojadizo táctico; el arrojadizo conserva [G] y el gatillo izquierdo).
- **Indicador de recarga:** barra sobre el jugador (sección 2, punto 6).

**Pendiente:** balance de precios con el ingreso real de monedas por nivel (y del 40 % de compra, para que vender no sea una fuente de oro trivial); evaluar un casillero de consumible para el 1-3; ver si conviene un segundo comerciante (herrero con runas) usando `TraderData`.

---

## 2.5 Fase S — Sonido Básico (8-bit)
*Estado:* Armado (pendiente de validación en juego). Efectos con estética shooter clásico (tipo Doom: ruido filtrado, golpe grave, eco de sala y grano ~11 kHz / 7 bits). Módulo `core/sfx.gd` con unos 55 efectos sintetizados, enganchado en armas, combate, jugador, recolección, tienda, granadas y mundo. Ver PROJECT_CONTEXT (`sfx.gd` y `GameFeel`) para el catálogo. Quedan sin sonido a propósito: música, ambiente, pasos y voces.
*Objetivo:* Que cada disparo, golpe, recarga y daño tenga sonido, con efectos sintetizados por código (ondas cuadradas y ruido, estilo 8-bit) y una estructura que permita **reemplazarlos después por audio real sin tocar la lógica**.
* **Modelo recomendado:** Sonnet, esfuerzo **medium** (ya armado; los ajustes que falten se hacen de a un sistema por vez).
* **Alcance:**
  1. **Generador central** (helper estático con `preload`, sin `class_name`, como `GameFeel`): sintetiza `AudioStreamWAV` (onda cuadrada, triangular, ruido, barrido de frecuencia, envolvente), los cachea y los reproduce con un pool de `AudioStreamPlayer`. Variación de tono ±5% y límite de voces simultáneas para que las armas automáticas no saturen.
  2. **Buses de audio** `Master`, `SFX` y `Music` (volumen ajustable; el menú de opciones queda para después).
  3. **Disparo por familia de arma:** pistola/revólver, automática (corta), rifle/francotirador, escopeta, lanzallamas (ráfagas de ruido) y, cuando existan, arco/ballesta y bastones. El tono sale de datos del arma, no de un `match` por nombre.
  4. **Impacto:** golpe a enemigo, golpe a blindado (metálico, según armadura), crítico (más agudo), muerte (ya existe), choque contra pared y parry.
  5. **Melee:** tajo (silbido, más agudo cuanto más rápida el arma) e impacto del filo.
  6. **Recarga:** clic de cargador sacado y puesto, y aviso de recarga lista.
  7. **Jugador y mundo:** daño recibido, salto, aterrizaje, moneda, orbe de EXP, pickup de arma, subir de nivel y compra en la tienda.
  8. **Gancho de reemplazo:** `WeaponData` gana campos opcionales de sonido (`fire_stream`, `hit_stream`); si están asignados se usan en lugar del procedural. Así el audio real se cambia arma por arma, desde los `.tres`.
  9. **Música (hecha):** `core/music.gd` + `core/music_director.gd` con la banda sonora de `ost/`: menú, campamento, tienda (al abrir el Mercader), exploración de nivel, combate estándar y élite según los enemigos cercanos, derrota y victoria. La pista de jefe queda lista para el grupo `boss` (todavía no hay jefes).
* **Fuera de alcance por ahora:** ambientes, sonido posicional real, pasos y voces.
* **Criterio de cierre:** En `test_level.tscn` y en el 1-1, con F5, cada disparo, impacto, recarga, tajo y daño recibido suena; el SMG y el lanzallamas no saturan ni cortan el audio; y se puede reemplazar el sonido de un arma asignando un `AudioStream` en su `.tres`.

---

## 3. Fase B — Bucle Piñata (Oleadas, Loot y XP)
*Objetivo:* El núcleo del juego: muchos enemigos, muertes que sueltan recompensas.
* **Modelo recomendado:** Sonnet, esfuerzo **medium** (un sistema por tarea: primero armas, luego combate, luego jugador).
* **Alcance:**
  1. `WaveManager`: oleadas con cantidad creciente por ronda, y ráfagas además del mantener-uno-vivo actual.
  2. `EnemyBase`: al morir, dispersa monedas, loot y orbes de XP con `LootTable`.
  3. Tabla de loot de ejemplo para los 2 enemigos básicos.
* **Criterio de cierre:** Una oleada de 20 o más enemigos se puede reventar en el sandbox, y el loot cae, se recoge y suma sin errores ni caídas de rendimiento notorias.

**Estado:** Cumplido. Oleadas por rondas con elites (`WaveManager`), botín con `LootTable` y orbes de EXP en uso desde el 1-2. Medido en la Sala de Estrés (sección 6c): 100 enemigos muertos juntos cuestan un cuadro de ~19 ms y otro de ~52 ms, y el botín se funde para no llenar el escenario.

---

## 4. Fase C — Progresión (Nivel, Armadura y Armas)
*Objetivo:* Que tenga sentido seguir jugando: subir de nivel y equipar algo mejor.
* **Modelo recomendado:** Sonnet, esfuerzo **medium** (mayormente recursos y stats).
* **Alcance:**
  1. Nivel de personaje a partir de XP, con una mejora simple por nivel (por ejemplo, +vida).
  2. 3 o 4 tiers de armadura y de arma, definidos en `.tres` con stats simples.
  3. Mostrar el tier en el inventario y en el tooltip existente.
* **Criterio de cierre:** Subir de nivel cambia algo visible, y equipar un tier superior cambia las stats que se ven en el HUD.

**Estado:** Armado (pendiente de validar en juego). **Las armaduras se eliminaron** después de armar esta fase (no gustaron): no hay piezas de casco, pecho, guantes ni botas de armadura, ni tiers de armadura, ni sets. La mitigación por armadura del jugador sigue en el código (`StatsManager.get_armor()`) por si vuelven, pero hoy vale 0.

**Decisiones:**
- **Tier = rareza.** 4 tiers con la escala clásica: Normal (T1), Bueno (T2), Épico (T3), Legendario (T4). `Raro` sigue existiendo en el enum pero no se usa en el equipo por tiers.
- **Nivel:** máximo 10. Cada nivel sobre el 1 da +10 de vida máxima y +3% de daño, derivado de `level` (sobrevive al guardado). La EXP deja de acumularse en el nivel máximo.
- **Armadura del jugador:** mitigación `100 / (100 + armadura)` aplicada en `Player.take_damage()` (sin fuentes de armadura por ahora).

| Tier | Rareza | Arma de rango | Arma melee |
|---|---|---|---|
| T1 | Normal | Revólver Oxidado, Pistola 9 mm | Cuchillo de Combate |
| T2 | Bueno | Carabina de Chatarra, Colt .44, MP5 | Espada de Hierro |
| T3 | Épico | Subfusil SMG, AK-47, M4, Desert Eagle | Katana de Asalto |
| T4 | Legendario | Rifle de Precisión (130 de daño, 5 balas) | Martillo Pesado (100 de daño, 1.1/s) |

**Cómo se consiguen:** revólver, botas, carabina y MP5 son recompensas de los sectores 1-1, 1-2, 1-3 y 1-5. El resto se compra en el Mercader (sección EQUIPO, precio = `gold_value`: espada 80, SMG y katana 220, rifle y martillo 500, etc.) o cae como botín de equipo desde el 1-4.

**Inventario (mejora de UX):** nuevo sistema de ítem en mano (arrastrar y soltar, o clic y clic; clic derecho o ESC cancela), con resaltado de destinos válidos, acomodo en el casillero, vuelta animada al origen y sonidos. Hoja de equipamiento con silueta (paper doll). Arrastrar baúl a mochila y arma a mochila ahora funciona.

**Baúl y armas (campamento):** el Baúl guarda armas (con sus runas) y equipo directamente desde la barra rápida y el cuerpo, y el personaje puede quedarse **sin ninguna arma**. Lo equipado, el arma activa, la mochila y el baúl se guardan solos al moverlos y al cerrar el juego.

**Botín de equipo (enemigos):** además de monedas, munición y vida, los enemigos pueden soltar armas por tier (las armaduras del pool se quitaron junto con las armaduras).
- **Dónde se configura:** `LootTable` suma `gear_chance` y `gear_pool` (`ItemData` o `WeaponData`); el nivel aporta `LevelBase.gear_loot_tier` (0 = apagado, por defecto: los sectores 1-1 a 1-3 y el sandbox no cambian).
- **Probabilidad:** `gear_chance × (1 + 0.5 × (tier − 1))`, tope 50%. Ladrón 3%, Bruto 20% en tier 1.
- **Rareza por tier de nivel** (Normal / Bueno / Raro / Épico / Legendario): tier 1 `70/30/0/0/0`, tier 2 `50/35/0/15/0`, tier 3 `30/35/0/25/10`, tier 4+ `15/30/0/35/20`. El peso es sobre las piezas del pool.
- **Filtro:** no suelta lo que el jugador ya posee (equipado, arsenal, mochila o baúl) ni ítems de rareza igual o menor a lo equipado en su ranura.
- **Recogida:** `PickupItem` y `WeaponPickup` con `allow_duplicates = true`. Con la mochila llena el ítem se queda en el suelo (antes `PickupItem` lo perdía).
- **Sin sistema de venta:** el filtro evita llenar la mochila de chatarra.

**Personaje al doble de tamaño:** sprite, colisión, hurtbox, arma en mano y hitbox melee se duplicaron (ver PROJECT_CONTEXT, `Player`). La física no cambió (velocidad 240, salto 530), así que los niveles siguen siendo los mismos en píxeles. Los enemigos no se escalaron.

**Equipo visible en el personaje:** la granada táctica y el jetpack/alas se dibujan en el esqueleto del personaje (`CharacterRig`). Las piezas de armadura que se dibujaban antes ya no existen.

**Armas en mano:** el arma activa se dibuja con el mismo ícono pixel art del inventario (`ItemIcons.WEAPON_POSES`: agarre, punta, giro y escala por tipo). La boca del cañón (`Muzzle`) queda en la punta del arma. En melee el arma recorre el arco del tajo junto con el hitbox; al disparar da un golpe de retroceso; al recargar baja el cañón y mueve el cargador durante todo el `reload_time`. Los pickups del suelo (armas e ítems) también muestran el ícono y el nombre con el color de su rareza.

**Qué se ve:** HUD con línea `ARM x (-y%) | DMG z`, nombre del arma con su rareza y color, aviso central al subir de nivel, borde del casillero con el color de rareza y tooltip con rareza y stats con nombre legible.

**Pendiente (agregado 2026-10-11):**
- **Subida de nivel demasiado rápida:** el personaje llega al nivel alto muy pronto. Bajar la EXP que dan los enemigos o subir la curva (base 150, x1.5 por nivel) y revisar que el nivel 10 se alcance recién avanzada la campaña.
- **Drops de equipo generosos en los sectores tempranos:** en el 1-4 un mob soltó el arma del pedestal y otro una M4 (T3) antes de llegar al final. Revisar `gear_chance` y el peso de rareza por tier (sección "Botín de equipo") para que un nivel temprano no entregue armas de tier 3.
- **Enemigos levemente más duros:** con la Runa de Perforación y la de Afilado las oleadas caen con facilidad, y es muy temprano para eso. Subir un poco la vida o la armadura de ladrón, bruto y centinela (o escalarlas por sector) sin tocar la cantidad de enemigos.

---

## 5. Fase D — Movilidad Mínima
*Objetivo:* Una sola mejora de movimiento, sin tocar el resto de la FSM.
* **Modelo recomendado:** Sonnet, esfuerzo **medium** (la FSM del jugador es delicada: un cambio por tarea). Si solo se agrega un valor o un flag en `ItemData`, Haiku, esfuerzo **low**, alcanza.
* **Alcance:**
  1. Elegir una: doble salto, salto más alto o velocidad. **Elegida: velocidad**, como `Botas Ligeras` en la recompensa del Sector 1-2 (sección 2.2). Criterio de cierre validado en juego.
  2. Dejarla como mejora obtenible (pickup o desbloqueo por nivel).
* **Criterio de cierre:** Con la mejora equipada, el salto o la velocidad cambian; sin ella, el comportamiento actual no cambia.

**Ampliación (agregada 2026-10-11, pendiente):**
- **Agacharse:** disponible siempre, sin ítem. Achica la hitbox y baja el cuerpo; el arma sigue funcionando agachado.
- **Roll y dash:** no están desbloqueados. Se habilitan con ítems (una ranura de movilidad nueva o un ítem consumible de un solo uso según el caso), así que la FSM tiene que leer el flag del ítem y no hardcodearlo. Desbloqueables a futuro, sin fecha.
- **Modelo recomendado:** Sonnet, esfuerzo **medium** (toca la FSM del jugador). Agacharse, roll y dash son tareas separadas: una por vez.

**Prioridad alta (pedido 2026-10-11, lo antes posible):**
- **Botas de Súper Velocidad:** una mejora de movilidad por encima de las `Botas Ligeras` del Sector 1-2 (+60 de velocidad). Se vende en el **Mercader** (sección 2.3), así que el ítem tiene precio y aparece en su stock.
- **Por definir antes de empezar:** cuánta velocidad da (el valor de las Ligeras es referencia), precio de venta, si ocupa la ranura de pies que hoy usan las Ligeras (y si reemplaza a las Ligeras al equiparlas) y si tiene rareza propia.
- **Modelo recomendado:** Haiku, esfuerzo **low** si es solo un `ItemData` con un valor de velocidad y una entrada en el stock del `TraderData`; Sonnet, esfuerzo **medium** si hay que tocar la lógica de equipamiento de la ranura de pies.

---

## 6. Fase E — Menú de Niveles Operativo
*Objetivo:* Poder entrar a niveles reales desde el Campamento.
* **Modelo recomendado:** Haiku, esfuerzo **medium**.
* **Alcance:**
  1. `MapSelector` lista los niveles jugables y bloquea el resto como "pendiente".
  2. Entre 2 y 3 niveles reales conectados a `LevelRegistry` y a `level_base.gd`. El 1-1 ya está hecho (sección 2.1); los demás siguen sus principios de progresión (una mecánica nueva por tramo, pasillos largos, sin ítems avanzados al principio).
  3. Al terminar un nivel, vuelve el menú con el siguiente desbloqueado.
* **Criterio de cierre:** Se puede ir del Campamento a un nivel, completarlo y volver con el progreso guardado.

**Estado:** Cumplido. Sectores 1-1 a 1-5 jugables (`LevelRegistry.IMPLEMENTED_LEVELS`), el resto sale como PENDIENTE; extraer desbloquea el siguiente y la victoria ofrece SIGUIENTE SECTOR.

---

## 6b. Fase O — Opciones, Pulido de Personajes y Distribución
*Estado:* Primera y segunda tanda hechas (la segunda, pendiente de validar en juego). Queda solo lo que necesita arte a mano o una prueba física (ver "Pendiente").

**Hecho (primera tanda):**
- **Panel de opciones** (`core/settings.gd` + `ui/settings_window.gd`; menú principal y pausa, se guarda en `user://settings.cfg`): modo de pantalla (ventana, ventana sin bordes a pantalla completa, exclusiva), resolución, V-Sync (4 modos), FPS máximos, calidad gráfica (4 preajustes + personalizada: MSAA 2D y densidad de partículas), contador de FPS, volúmenes (general, música, efectos), silencio al perder el foco, intensidad del temblor de cámara, números de daño y reasignación de teclas.
- **Personaje:** cuerpo `hero` articulado (hombro/codo/muñeca y cadera/rodilla/tobillo), IK de brazos hacia el arma, agarre y animación propios por arma (`core/art/weapon_motion.gd`).
- **Enemigos:** ladrón, bruto y centinela con ciclo de marcha (torso y piernas partidos) y embestida al atacar; zombi, esqueleto y fantasma con zarpazo.
- **Balance:** XP más lenta (150 de base, x1.5 por nivel, 20 por enemigo), cuchillo con menos daño y más cadencia, bruto 25 % más grande, monedas apoyadas sobre el piso con sonido encadenado.

**Hecho (segunda tanda, pendiente de validar en juego):**
- **Opciones:** confirmación con cuenta regresiva de 15 s al cambiar modo, resolución o monitor (si no se confirma vuelve sola; ESC también revierte), **selección de monitor**, **reasignación de teclado, ratón y mando** (dos casilleros por acción, 21 acciones, botón ↺ por acción) con **detección de conflictos** (si otra acción usaba esa tecla, intercambian y se avisa), **dificultad** (Recluta / Soldado / Veterano / Pesadilla: daño enemigo x0.6 / 1 / 1.35 / 1.75 y vida enemiga x0.75 / 1 / 1.25 / 1.6) y una pestaña de **Accesibilidad**: escala de la interfaz y el texto (85-125 %, la cámara compensa para ver la misma porción del nivel), filtro para daltonismo (protanopia, deuteranopia, tritanopia, con intensidad), reducir destellos, apagar el hit stop y temblor de cámara. Las teclas guardadas con la versión anterior de `settings.cfg` se migran solas.
- **Calidad gráfica real:** posprocesado por pantalla (`core/post_fx.gd`) colgado del preajuste: Media = viñeta, Alta = viñeta + grano, Ultra = + resplandor (bloom). Cada efecto se puede tocar a mano (pasa a "Personalizada"). Solo tiñe el mundo: el HUD pasó a la capa 2 y el efecto vive en la 1. El MSAA 2D se oculta porque `gl_compatibility` no lo soporta (el motor lo avisaba en el log).
- **Recarga propia por arma y combos de las automáticas** (`RELOADS` y `PATTERNS` en `core/art/weapon_motion.gd`): los revólveres abren el tambor y meten bala por bala, la escopeta mete 4 cartuchos y bombea, el rifle de precisión acciona el cerrojo, fusiles y carabina tiran de la manija, las armas de energía cambian el bidón con un siseo. Sonidos nuevos `reload_shell`, `reload_rack`, `reload_vent`. Las automáticas suben el cañón y se mecen a medida que se sostiene la ráfaga y vuelven al soltar (solo visual, no cambia la dispersión).
- **Distribución:** ícono del `.exe` (`icon.ico`, generado por `art_source/icon/make_icon.py` desde la cabeza del héroe), versión y metadatos en el preset (`application/modify_resources = true`), **pantalla de carga** con barra de progreso y consejos (carga en segundo plano, `core/scene_loader.gd`; todos los cambios de escena pasan por `GameManager.change_scene()`), **registro de errores** en `user://logs/errors_<fecha>.log` (solo si hubo errores; versión, sistema y placa de video en el encabezado; guarda los últimos 10), lista de exclusiones afinada y `build_exe.bat` que importa, exporta y arma `build/WARMACHINE_<versión>.zip`.
- **Arreglo:** la tecla de recarga ya no está fija en R (respeta la reasignación).

**Pendiente:**
1. **Enemigos con arte por piezas:** el ladrón, el bruto y el centinela son una ilustración partida en cintura; para brazos que golpeen de verdad hay que separar brazos y arma como se hizo con el héroe (`assets/PSD`). Tarea de arte + `enemy_art.gd`. *Arte a mano, luego Sonnet.*
2. **Instalar las plantillas de exportación 4.7.2** (Editor > Administrar plantillas) y correr `build_exe.bat`; después **probar el `.zip` en una PC limpia** (sin Godot). No se puede hacer desde el código.
3. **Sombras 2D:** necesitan `LightOccluder2D` en las plataformas y luces por nivel; conviene hacerlo junto con un pase de iluminación de los niveles. Cuando estén, colgarlas del preajuste Ultra.
4. **Idioma y subtítulos:** quedan fuera mientras el juego tenga un solo idioma (español) y no haya voces. El paso previo sería pasar los textos a `tr()` con un archivo de traducción.

**Exportación a `.exe` único:** `export_presets.cfg` ya define el preset "Windows Desktop" con el `.pck` embebido (un solo archivo). Hace falta instalar una vez las plantillas de exportación de Godot 4.7.2 (Editor > Administrar plantillas de exportación) y correr `build_exe.bat`; sale `build/WARMACHINE.exe`.

---

## 6c. Fase P — Rendimiento y Optimización
*Objetivo:* Que el juego aguante pantallas llenas de enemigos, balas, gore y botín sin trabarse, midiendo en vez de adivinar.

**Hecho (2026-10-11, pendiente de validar en juego):**
- **Sala de Estrés** (puerta a la derecha del Campamento): generador infinito de enemigos (tipo, lote, ritmo, tope de vivos, cuántos por cuadro), fuego automático, congelar enemigos (separa el costo de dibujo del de IA y física), matar / herir / borrar, limpiar escombros, inmortal sin empujones. No guarda nada de lo que pasa adentro.
- **Monitor de rendimiento** (`core/debug/perf_monitor.gd`): fijo en la sala y con **F9** en cualquier nivel. Registra en `user://logs/rendimiento/` un `.csv` cada 0.5 s y un `.txt` con eventos, picos, censo de nodos y la tabla de FPS según enemigos vivos.
- **Botín:** monedas, munición, vida y orbes quietos se funden de a 10 en uno más grande que vale la suma (4 niveles). Quietos no calculan física y se juntan por distancia (antes sus áreas detectaban a los enemigos y llenaban la física de pares de colisión). La experiencia cae con gravedad.
- **Muertes masivas:** cola de efectos con presupuesto de 2.5 ms por cuadro (`combat/death_fx_queue.gd`): gore y botín se reparten en varios cuadros; el botín nunca se pierde. Se sacaron los `print()` por baja y por moneda (~15 ms cada uno con muchas bajas). 300 muertes juntas pasaron de 5.7 s congelado a ~0.2 s.

**Pendiente (no urgente; hacerlo cerca del cierre, sobre los enemigos definitivos):**
1. **Costo de los enemigos vivos:** con ~100 persiguiendo el juego baja a ~45-48 FPS; congelados vuelve a 60, así que es CPU (IA + física), no dibujo. Hay ~4 `Area2D` por enemigo y hasta 2000-2700 pares de colisión. Auditar sensores, capas y máscaras; IA y animación más baratas lejos o fuera de cámara; cachear búsquedas por cuadro.
2. **Instanciado:** cada enemigo cuesta 2-4 ms al aparecer (arte del rig y componentes). Evaluar pool de enemigos.
3. **Cuadro del golpe en masacres:** ~55 ms con 300 muertes (números de daño, señales) y ~148 ms el siguiente (liberar los enemigos). Pool o tope de números de daño y liberación repartida.
- **Cuándo adelantarlo:** si se diseñan niveles u hordas de más de 30-40 enemigos simultáneos, si el registro muestra caídas con pocos enemigos, o antes de probar el `.exe` en PCs más modestas.
- **Regla desde ya:** cada sistema pesado nuevo (explosiones, misiles, efectos de área) se prueba en la Sala de Estrés apenas está armado.
- **Modelo recomendado:** Sonnet, esfuerzo **medium**. Cada punto pendiente de abajo es una tarea aparte (sensores, pool de enemigos, liberación de números de daño).
- **Criterio de cierre:** 100 enemigos persiguiendo a 60 FPS estables y 200 jugables en la Sala de Estrés, comparando la tabla "FPS según enemigos vivos" antes y después.

---

## 6d. Fase W — Armas: Manos, Tipos y Animación
*Objetivo:* Que cada arma se sienta distinta en la mano, y que el personaje pueda llevar dos cosas a la vez. Es la base de varios puntos de abajo, así que el sistema de tipos va primero.
* **Modelo recomendado:** Sonnet, esfuerzo **medium**. Las verificaciones en F5 pendientes son tareas chicas, una por vez.

**Hecho (2026-10-11, pendiente de validar en juego con F5):**
- **Punto 1, tipos:** `WeaponData.family` (pistola, revólver, carabina, subfusil, escopeta, fusil, rifle de precisión, energía, lanzallamas, melee corto, espada, arma pesada) y `WeaponData.grip` (una mano, dos manos, escudo), asignados en los 19 `.tres` (incluyendo espada de hierro y katana a dos manos). `FAMILY_RULES` guarda por familia: nombre, qué suelta al recargar, techo de perforación y piso de penetración de armadura. El tooltip muestra familia y empuñadura. Sonido procedural (`weapon_fire_profile` en `core/sfx.gd`) resuelto por familia.
- **Punto 2, dos manos:** segundo `WeaponManager` hijo (`offhand`) que comparte pivote y cargadores. Acción nueva `attack_secondary` (clic derecho, R3). Casillero "M2" a la derecha de la barra (arrastrar mueve el arma; clic derecho lo libera; se guarda como 10.ª entrada de `hotbar`; arrastrar a la mochila desequipa). Un arma a dos manos bloquea la secundaria sin olvidar la elección. Con arma lista en la mano 2, el clic derecho dispara en vez de usar la herramienta (F y L1 siguen). R recarga las dos manos. El brazo de atrás agarra el arma secundaria (arte provisional: sprite desplazado).
- **Punto 3, casquillos y cargador:** `combat/reload_debris.gd`, según `get_reload_drop()` de la familia (tambor, cargador + casquillos, cartuchos, bidón). Solo visual; respeta la densidad de partículas.
- **Punto 4, balance:** Carabina de Chatarra daño 20→26, sin perforación, penetración 0.15 (regla de la familia carabina); cuchillo daño 15→12 y cadencia 4.6→5.2; revólver oxidado daño 18→15.
- **Punto 5, swing de espada y armas a dos manos:** `iron_sword.tres` y `katana.tres` pasaron a `grip = 1` (dos manos) y arco amplio (`swing_arc_degrees = 140.0` y `135.0`). Pose de apoyo (`support`) asignada en `core/art/weapon_motion.gd` para espada de hierro y katana, permitiendo que ambos brazos del rig sostengan el arma. Combo de 2 tajos con arcos amplios (-72° a +78° y +68° a -78°) con rotación (`lean` de -7° a +12°) y avance (`x` hasta 5 px) del torso. Además, los tajos melee ahora pasan `current_weapon.get_armor_penetration()` a `HitPayload`.

**Validado:**
- El sandbox y el Sector 1-1 cargan y corren sin errores de script ni advertencias en consola (`--quit-after`).
- Tipos de arma y familias asignados y leídos por datos en todos los `.tres`.
- La mano 2 dispara con clic derecho, no interfiere con herramientas si está activa y descuenta munición correctamente.
- Al recargar se generan los restos de munición correspondientes a la familia del arma.
- Las armas a dos manos bloquean la mano 2 con aviso "2 MANOS" y vuelven a activarla al volver a un arma de una mano.

**Sin verificar en runtime humano / pendiente:**
- Verificación visual directa en F5 del arco de swing de espada y la postura de dos manos del `CharacterRig`.
- Verificación en F5 de la sensación de juego del doble empuñe (ej. cuchillo + revólver) y la disposición del casillero M2 en pantalla.
- Escudos (la estructura de `Grip.SHIELD` está lista y funcional en código, pero todavía no hay un recurso ni arte de escudo en el juego).

---

## 6e. Fase V — Recompensas Visibles
*Objetivo:* Que el loot y la subida de nivel se vean a distancia, sin texto encima.
* **Modelo recomendado:** Sonnet, esfuerzo **medium** (efectos visuales, sin cambiar la lógica).

**Hecho (2026-10-11):**
- **Punto 2, Aura de subida de nivel:** implementado en `entities/player/level_up_aura.gd` y conectado a la señal `level_gained` de `StatsManager` en `Player`. Columna de luz ascendente dorada (estilo MU Online / WoW) con dibujo en dos capas aditivas (`z_index = -1` para resplandor y base de suelo, `z_index = 1` para halos ascendentes y núcleo frontal legible), y partículas de chispas doradas (`CPUParticles2D`) respetando la calidad gráfica (`SettingsScript.particle_scale()`) y accesibilidad (`SettingsScript.reduce_flashes()`). Se desvanece suavemente y se auto-elimina (`queue_free()`) tras 2.2s. Si se suben varios niveles seguidos, se reinicia de inmediato (`restart()`) sin acumular nodos colgados. Atajo `[U]` en Banco de Pruebas (`core/test_level.gd`) para pruebas de nivel instantáneo.

**Validado:**
- Verificación automatizada con `--quit-after` y `--test-aura` en `core/test_level.tscn`: creación de `LevelUpAura`, reinicio sin duplicación ante subidas consecutivas y eliminación completa sin nodos residuales.
- HUD central preservado intacto.
- Sin cambios en la progresión de vida o daño.

**Pendiente:**
1. **Objetos del piso (items y runas):** en vez de la caja actual, cada objeto flota con un leve movimiento de vaivén y un aura brillante que pulsa. El color del aura sale de la rareza.

---

## 6f. Fase T — Herramientas de Diseño desde el Editor
*Objetivo:* Que armar niveles y probar cosas sea rápido desde Godot, sin tocar código ni escribir a mano coordenadas o rutas.
* **Modelo recomendado:** Sonnet, esfuerzo **medium** (mayormente escenas, exports y un editor simple).

**Pendiente:**
1. **Colocar en el nivel sin código:** que un nivel se arme arrastrando escenas en el editor (plataformas, checkpoints, arenas, pedestales, puertas de salida), con los parámetros visibles en el Inspector.
2. ✅ **Spawnear enemigos desde el editor:** `entities/markers/enemy_spawn_marker.gd` — Marker2D con `@export` para `enemy_scene`, `count`, `round_index`, `aggro_on_spawn`. Como hijo de WaveManager se registra como punto de spawn; de forma independiente hace spawn directo con `auto_spawn`.
3. ✅ **Tirar armas e ítems al piso:** `entities/markers/item_floor_marker.gd` — Node2D con un único `@export var pickup_data: Resource`. Detecta automáticamente si es `WeaponData` → `WeaponPickup`, `RuneData` → `RunePickup`, `ItemData` → `PickupItem`. Escena de prueba: `levels/test_markers.tscn`.
4. **Probar desde el editor:** poder lanzar un nivel desde su escena y arrancar con un equipo de prueba (armas, consumibles, monedas) sin pasar por el Campamento.
5. **Regla desde ya:** cada sistema nuevo (armas, enemigos, ítems, runas) tiene que poder usarse desde el editor. Si para colocarlo hay que escribir código, no está terminado.


---

## 6g. Fase Q — Feedback de Pruebas (2026-10-11)
*Objetivo:* Dejar en limpio lo que apareció jugando (bugs, sensación de juego y balance) antes de sumar contenido nuevo. Cada punto dice qué pasa hoy y qué se pide. Pendiente de validar en F5 después de cada cambio.
* **Criterio de cierre:** cada punto se reproduce en el Sector 1-1 o en el Banco de Pruebas, y el cambio se ve y se siente como se pidió.

**Bugs:**
1. **Barra rápida después de la 3.ª arma (Sonnet, medium):** tras recoger la tercera arma, las nuevas dejan de acomodarse solo en los casilleros vacíos de la barra. Antes de tocar el código, confirmar qué se espera (¿sobrescribir un casillero, o ir a la mochila?). Archivo: `ui/hotbar.gd`. **HECHO (2026-10-11, opción a):** la causa estaba en `entities/items/weapon_pickup.gd` (tope de 3 armas en el arsenal; las siguientes iban a la mochila). El tope pasó a 9 (`ARSENAL_LIMIT`, igual que el inventario y el mercader); también el retorno de armas del yunque en `ui/blacksmith_window.gd`. Probado con script en el 1-1: se recogen 6 armas y el arsenal pasa de 2 a 8, todas en casilleros libres de la barra. **Sin verificar:** a mano en juego, y qué pasa al llegar a 9 (las siguientes van a la mochila).
2. **Armas que vuelven al salir del Herrero o del Mercader (Sonnet, medium):** vender todo en la base y entrar a un nivel devuelve el cuchillo, el revólver y la carabina. Causa probable: `levels/level_base.gd:63` agrega al arsenal las armas de `guaranteed_weapon_paths` que el jugador no posee, así que después de vender las vuelve a recibir. Corrección sugerida: entregarlas una sola vez por personaje (marca en el slot) y no más, o solo si no hay ninguna arma. **HECHO (2026-10-11):** confirmado en `levels/level_base.gd`. `_grant_guaranteed_weapons()` marca cada arma entregada con el flag de slot `weapon_granted:<ruta>` y no la vuelve a dar; si ya la tenía (partidas viejas) solo la marca. Probado con Godot: entrar al 1-2 marca los flags y no hay errores. **Sin verificar:** el ciclo completo en juego (vender todo en el Herrero/Mercader, guardar, entrar al nivel).
3. **Arrastrar desde la barra en el Herrero (Sonnet, medium):** hoy solo se puede arrastrar desde el inventario. Permitir arrastrar desde la barra en la ventana del herrero (y en el comercio, para vender). Archivos: `ui/hotbar_slot.gd`, `ui/inventory_window.gd`. **HECHO (2026-10-11):** `ui/blacksmith_window.gd` acepta armas de la barra y de la mano 2 en el yunque (la sacan del arsenal y de la mano 2); `ui/trade_window.gd` vende lo arrastrado desde la barra (armas y consumibles) con `_sell_entry_for`. Probado con script en el campamento: pistola de la barra al yunque (arsenal 4→3) y revólver de la barra a la columna del mercader (monedas +8, arma fuera del arsenal). **Sin verificar:** el arrastre con el mouse real y el cartel de confirmación de venta.
4. **Clic derecho con el arma secundaria (Sonnet, medium):** no funciona. Regla de prioridad: si el arma de la mano principal tiene función secundaria, esa se usa; si no tiene, dispara el arma de la mano 2. Archivos: `core/weapon_manager.gd`, `entities/player/player.gd`, `core/input_manager.gd`. Relacionado con la Fase W, punto 2. **HECHO (2026-10-11):** la causa era que el `ColorRect` de fondo de las escenas (filtro STOP, pantalla completa) se tragaba el clic derecho antes de `_unhandled_input`; ahora `levels/level_skin.gd` pone los controles del fondo en IGNORE. Además `WeaponData.has_secondary_function()` (hoy siempre false) y el chequeo en `WeaponManager._unhandled_input` dejan lista la prioridad: la función secundaria de la principal gana sobre la mano 2. Probado: con revólver en la principal y pistola en la mano 2, el clic derecho baja la munición 12→11 (antes 12→12). **Sin verificar:** la regla de prioridad (ningún arma tiene función secundaria todavía).

**Sensación de juego y HUD:**
5. **Pantalla roja con vida baja (Sonnet, medium):** a medida que baja la vida, un borde rojo o viñeta crece en pantalla. Reusar `core/post_fx.gd` y respetar "reducir destellos" de Accesibilidad. **HECHO (2026-10-11):** `core/post_fx.gd` tiene el uniforme `danger` y `set_danger()`; lo maneja `entities/player/low_health_feedback.gd` (nuevo, colgado del jugador). El borde rojo aparece por debajo del 60 % de vida y llega al máximo con 0, pulsa levemente y con "reducir destellos" queda fijo sin pulso. Funciona aunque la viñeta de Opciones esté apagada. Probado por script en el 1-1 (vida 100 %→45 %→10 %→100 %: danger 0 → 0.24 → 0.80 → 0). **Sin verificar:** cómo se ve y si la intensidad es la justa.
6. **Latido sin vida ni escudo (Sonnet, medium):** sonido de latido en bucle cuando la vida está en el tramo crítico y el escudo vacío. Ritmo más rápido cuanto menos vida. Definir el umbral: hoy vida 0 equivale a muerte, así que el latido empieza antes de ese punto. Archivos: `core/sfx.gd`, `entities/player/player.gd`. **HECHO (2026-10-11):** sonido `heartbeat` (lub-dub sintetizado en `core/sfx.gd`) que suena en bucle desde el componente de arriba cuando la vida está en el 30 % o menos y el escudo del jugador está vacío (`current_shield <= 0`; hoy el jugador casi nunca tiene escudo, así que en la práctica depende solo de la vida). El intervalo baja de 1.1 s a 0.45 s y el volumen sube con la vida. Umbral y tiempos son constantes al principio del script. Probado: con 10 % de vida el temporizador del latido corre; con 45 % no. **Sin verificar:** cómo suena y si el ritmo molesta.
7. **Texto flotante rojo al recibir daño (Sonnet, medium):** además del número de daño que se hace, el daño que recibe el jugador aparece como texto rojo intenso, más grande y con un leve temblor, que se nota como malo. Reusa el sistema de números de daño de la Fase O. **HECHO (2026-10-11):** `Player.take_damage()` genera un `DamageNumber` de tipo `PLAYER_HIT`: rojo intenso, fuente 26, contorno grueso, golpe de escala al aparecer y temblor 0.5 s (sin temblor con "reducir destellos"). Respeta la opción "números de daño". Probado: 10 de daño → texto "10" rojo, tamaño 26. **Sin verificar:** la lectura en pantalla en pleno combate.
8. **Escudo de energía como aura (dividido en tres tareas):**
   - **8a (Haiku, low):** ubicar el nodo que dibuja el rectángulo azul del escudo y reportar archivo y línea. No cambiar nada. **HECHO (2026-10-11):** era `ShieldOutline` en `entities/enemies/shielded_sentinel.tscn`.
   - **8b (Sonnet, medium):** reemplazar el rectángulo por una esfera de energía animada que envuelve al personaje (dibujo procedural, sin arte nuevo). **HECHO (2026-10-11, sin verificar a ojo):** elipse procedural en `entities/shield/energy_shield.gd`, que el jugador y el Centinela crean al empezar. Se ve solo cuando hay escudo (el jugador todavía no tiene). El `ShieldOutline` se quitó.
   - **8c (Sonnet, medium):** destello en el punto del golpe o del balazo que recibe el escudo. **HECHO (2026-10-11, sin verificar a ojo):** cada vez que el escudo absorbe daño, un anillo brillante se expande y se desvanece (0.35 s); al romperse, el escudo se desvanece (0.3 s). Con "reducir destellos" no hay anillo ni brillo. Es sobre la elipse, no sobre el punto exacto del impacto.
9. **Subfusil con más dispersión (Haiku, medium):** hoy se siente demasiado preciso. Subir la dispersión del subfusil en su `.tres` de `data/weapons/`. Es un cambio de valor (ver tarea 7 de la sección 8). **HECHO (2026-10-11):** `data/weapons/smg.tres` `spread_angle_degrees` 0 → 4. Cadencia y cargador sin tocar. **Sin verificar:** a mano en la Sala de Estrés.

**Movimiento y personaje:**
10. **Salto base más alto (Haiku, medium):** subir un poco la velocidad de salto por defecto (hoy 530) en `entities/player/player.gd`. Cambia la altura de los bloques y pozos de los niveles, así que después revisar que los sectores 1-1 y 1-2 sigan siendo alcanzables (ver tarea 8 de la sección 8). **HECHO (2026-10-11):** el valor real era `jump_force = 480` en `data/player_movement_data.gd` (no 530); pasó a 520 (~+17 % de altura). **Sin verificar:** recorrer 1-1 y 1-2 completos (techos bajos y plataformas) y buscar cabezazos contra techos.
11. **Brazos abiertos al saltar (dividido en dos tareas):** **11a/11b HECHO (2026-10-11), un solo cambio en `entities/player/character_rig.gd`:** en el aire los brazos libres se abren hacia afuera y arriba (`_jump_open`) y vuelven a la pose normal al aterrizar (más lento que la subida). Con arma en una mano solo abre el brazo libre; con arma a dos manos o mano 2 ocupada, no se abre ese brazo. Probado por script (en el aire 1.0, aterrizado 0.0). **Sin verificar:** cómo se ve.
   - **11a (Sonnet, medium):** al despegar, los brazos se abren hacia afuera y arriba como en un salto real. Archivo: `entities/player/character_rig.gd`.
   - **11b (Haiku, low):** que vuelvan a la pose normal al aterrizar, ajustando solo los tiempos o valores de interpolación.
12. **Manos sosteniendo el arma (dividido en dos tareas):** la imagen de referencia no quedó guardada en el repo; conviene ponerla en una carpeta de referencia antes de empezar. **PENDIENTE:** la imagen de referencia sigue sin estar en el repo; sin ella 12a/12b no se pueden hacer bien.
   - **12a (Sonnet, medium):** girar la mano delantera y la trasera en la pose de agarre de rifle, según la referencia. Archivos: `core/art/weapon_motion.gd`, `entities/player/character_rig.gd`.
   - **12b (Haiku, low):** ajustar `WEAPON_POSES` en `ui/item_icons.gd` para que el ícono del inventario coincida con la nueva pose.

**Enemigos:**
13. **Mobs al 1.5x (Sonnet, medium):** escalar a 1.5x a todos los enemigos (sprite, colisión, hurtbox y hitbox). Esto cambia lo que dice la Fase C ("los enemigos no se escalaron"). Riesgo: los pasillos de techo bajo de los sectores 1-2 a 1-5 y los fosos del 1-3 pueden quedar chicos para los enemigos; revisar cada nivel después del cambio.

**Balance y botín:**
14. **Botín del primer mundo (Sonnet, medium):** en los sectores 1-1 a 1-4 el equipo que cae se limita a cuchillo, revólver y pistola 9 mm. Las armas de tier 2 o más salen solo con alrededor de 0.05 % de chance, y ese es el "item groso" de vez en cuando. Esto absorbe la tarea 6 de la sección 8 y el punto pendiente de drops de la sección 4. Archivos: `LootTable`, `data/loot/`, `levels/level_base.gd`. **HECHO (2026-10-11):** `LootTable` ganó `early_gear_pool` y `jackpot_chance` (0.0005). Con tier de nivel <= 1 el equipo sale de la lista básica (cuchillo, revólver oxidado, pistola 9 mm) y la lista gruesa (`gear_pool`) solo cae con el golpe de suerte. Cargado en las 3 tablas de `data/loot/`. Probado con 200 000 tiradas por tabla: en tier 1 salen ~99.5 % básicas y ~0.04 % gruesas; en tier 2 (1-5) sigue el pool normal. Nota: los sectores 1-1 a 1-3 tienen `gear_loot_tier` 0 y no sueltan equipo; solo el 1-4 (tier 1) lo hace. **Sin verificar:** a mano.
15. **Mercader con stock infinito, modo prueba (Sonnet, medium):** todos los ítems que existen a la venta, sin límite de cantidad. Dejarlo como un interruptor en `TraderData` para poder volver a limitar el stock después. Archivos: `core/trade/`. **HECHO (2026-10-11):** `TraderData.sell_everything` (interruptor, activado en `data/traders/merchant.tres`): `TradeSession._build_full_stock()` ofrece todo `.tres` de `data/consumables`, `weapons`, `items`, `items/throwables` y `runes` sin límite. Apagarlo vuelve al stock normal. Verificado que el recurso lo trae activado; **sin verificar:** abrir la tienda en juego.

---

## 6h. Fase X — Lanzallamas de Combustible
*Objetivo:* Un lanzallamas que rocía combustible encendido: lo que cae al piso se prende y deja fuego en el suelo que quema a quien lo pisa. Hoy el lanzallamas que existe (`data/weapons/plasma_flamethrower.tres`) hace pulsos de fuego en el aire y no deja nada en el piso. **Prioridad alta:** se pidió agregarlo cuanto antes.
* **Modelo recomendado:** Sonnet, esfuerzo **medium**. Cada paso de abajo es una tarea aparte, una por vez.

**Comportamiento pedido:**
- Automático mientras se mantiene el clic, con cadencia alta y cargador de combustible.
- Cada gota sale encendida, vuela un poco, cae y forma un charco de fuego en el piso.
- El charco quema a quien lo pisa o está adentro (estado `burn` existente de `StatusReceiverComponent`) y hace daño por tick.
- El charco dura unos segundos y después se apaga solo. No se propaga a otros charcos en esta primera versión.
- Sin arte por ahora: las gotas y los charcos son cuadrados de color naranja/amarillo que parpadean.

**Pasos:**
1. **Arma:** nuevo `.tres` en `data/weapons/` con familia lanzallamas (ya existe en `FAMILY_RULES`), automática y con el fuego como efecto. Sin lógica nueva en este paso.
2. **Gota:** proyectil basado en `combat/projectile.tscn`, con gravedad leve. Al caer deja de moverse y crea el charco.
3. **Charco de fuego:** basado en `combat/throwables/acid_pool.gd` (charco persistente que hace ticks), pero aplica `burn` y tiene su duración propia. Visual: cuadrados que parpadean.
4. **Sonido:** usar el perfil de lanzallamas de `core/sfx.gd`. Un sonido de charco prendido queda opcional.
5. **Arte (cuando llegue la hoja de sprites):** reemplazar los cuadrados por sprites de gota, charco animado, boquilla del arma e ícono de inventario (`ui/item_icons.gd`). No bloquea la lógica: se puede hacer después de los pasos 1 a 4.

**Archivos:** `data/weapons/` (nuevo `.tres`), `combat/projectile.gd` o un script de gota nuevo, `combat/throwables/acid_pool.gd` como referencia, `core/status_receiver_component.gd` (burn), `core/sfx.gd`.

**Criterio de cierre:** en el Banco de Pruebas o en el 1-1, con F5: mantener el clic deja charcos naranjas en el piso; quien pisa un charco arde y recibe daño; el fuego se apaga solo; el arma se equipa, recarga y vende como cualquier otra; sin errores de script en el log.

---

## 6i. Fase Y — Espada Frostmourne (esqueletos aliados y congelado)
*Objetivo:* Una espada que congela a lo que golpea y que, al matar, recluta esqueletos aliados que pelean al lado del jugador. Cada aliado vivo le quita vida máxima al jugador, así que el arma se paga con riesgo.
* **Modelo recomendado:** Sonnet, esfuerzo **medium**. Cada paso de abajo es una tarea aparte, una por vez.

**Comportamiento pedido:**
- **Congelado:** cada golpe de la espada ralentiza al enemigo. Se reutiliza el efecto de hielo que ya existe (`ice_duration` e `ice_speed_multiplier` en `HitPayload`, aplicado por `apply_ice` en `StatusReceiverComponent`). Valores iniciales a ajustar en la Sala de Estrés.
- **Invocación:** cada enemigo que el jugador mata con la espada invoca un esqueleto aliado junto al cadáver.
- **Duración:** el esqueleto pelea con el jugador (ataca enemigos y lo sigue) hasta morir. No expira.
- **Tope:** como máximo **5 esqueletos a la vez**. Si hay 5 vivos, matar más no invoca nada.
- **Costo:** cada esqueleto vivo le quita **5 % de la vida máxima base** del jugador, de forma lineal (apilado sumando, no multiplicando). Con 5 vivos, 25 % menos.
- **Recuperación:** cuando un esqueleto muere, la vida máxima vuelve a subir.
- **Sin arte por ahora:** el esqueleto y el arma son placeholders (cuadrado de color del tamaño de un enemigo humano). Los sprites los pasa el usuario después.

**Supuesto a confirmar:** si la vida máxima baja por debajo de la vida actual, la vida actual se recorta al nuevo máximo.

**Pasos:**
1. **Arma:** nuevo `.tres` en `data/weapons/` de tipo espada, con `ice_duration` e `ice_speed_multiplier` en el payload de sus golpes. Sin lógica nueva en este paso.
2. **Congelado:** verificar que un golpe de la espada aplica el hielo al enemigo y que el enemigo se mueve más lento mientras dura. Ajustar duración y velocidad.
3. **Invocación:** al matar con la espada, crear el aliado en la posición del cadáver. Se engancha en la señal de muerte del enemigo y respeta el tope de 5.
4. **Aliado esqueleto:** basado en `entities/allies/ally_base.gd` (ya maneja grupos de aliados, vida y muerte). Revisar si `entities/allies/mercenary_skeleton.gd` sirve como base, aunque los mercenarios siguen en stand-by.
5. **Penalidad de vida máxima:** contar los esqueletos vivos y bajar la vida máxima del jugador en `StatsManager` (5 % de la base por aliado). Al morir un aliado, recalcular. No tocar la fórmula de subida de nivel.
6. **Arte (cuando el usuario pase la hoja de sprites):** reemplazar el cuadrado por el esqueleto animado e ícono de la espada.

**Archivos:** `data/weapons/` (nuevo `.tres`), `combat/hit_payload.gd` y `core/status_receiver_component.gd` (hielo, ya existen), `entities/allies/ally_base.gd`, `entities/allies/mercenary_skeleton.gd` (referencia), `StatsManager` (vida máxima), `core/health_component.gd` (señal de muerte).

**Criterio de cierre:** en el Banco de Pruebas, con F5: cada golpe de la espada ralentiza al enemigo; matar con la espada invoca un esqueleto que pelea; nunca hay más de 5 vivos a la vez; la vida máxima baja 5 % de la base por cada esqueleto vivo y vuelve al morir; sin errores de script en el log.

---

## 7. Después del Prototipo (no entra ahora)
- Los 50 niveles y los 5 capítulos (Fase 16 del plan anterior). Hechos: 1-1 a 1-5.
- Stand-by de la sección 0.
- Cierre y exportación a `.exe` (cuando el bucle esté validado): el pipeline ya está listo (sección 6b), falta instalar las plantillas y probar.

---

## 8. Tareas Menores (para IA liviana)
*Objetivo:* Cambios chicos, mayormente de valores en los `.tres` y las curvas, que se pueden hacer sin pensar en la arquitectura.
* **Modelo recomendado:** Haiku, esfuerzo **medium**.
* **Reglas para quien las haga:**
  - Cambiar solo los valores indicados. Si una tarea pide tocar la lógica de combate, la FSM o el sistema de armas, parar y reportar: no es una tarea menor.
  - No crear escenas ni scripts nuevos.
  - Verificar cada cambio con F5 en el Sector 1-1 o en el Banco de Pruebas. Anotar en la tarea qué se probó y qué se sintió.
  - No hacer commit ni push sin que lo pidan.

**Tareas:**
1. **Cuchillo de Combate:** bajar el daño un poco y subir la cadencia un poco. Archivo: el `.tres` del cuchillo en `data/weapons/`. Criterio: sigue matando a un ladrón de un golpe o dos, y se siente un poco más rápido.
2. **Revólver Oxidado:** bajar el daño un poco. Archivo: `data/weapons/rust_revolver.tres`. Criterio: el 1-1 sigue siendo posible con el revólver solo, sin que se sienta lento.
3. **Carabina de Chatarra:** subir el daño un poco y dejar la penetración de armadura en un valor chico. Archivo: `data/weapons/scrap_carbine.tres`. Criterio: el DPS sube sin cambiar la cadencia ni el cargador. No tocar el atravesar: eso es otra tarea (Fase W).
4. **Enemigos levemente más duros:** subir un poco la vida o la armadura de ladrón, bruto y centinela, sin cambiar cantidades ni rondas. Archivos: los `.tscn` o `.tres` de cada enemigo en `enemies/` (buscar los valores de vida y armadura). Criterio: las oleadas del 1-2 y del 1-3 se sienten con más presión, no más largas.
5. **Subida de nivel:** bajar un poco la EXP que da cada enemigo (`EXP por enemigo` en el código de experiencia). Criterio: llegar al nivel 5 toma más de la mitad del 1-2, no toda la campaña. No cambiar la curva de nivel (x1.5), solo la base o la ganancia por enemigo.
6. **Drops de equipo tempranos:** en los niveles 1-3 y 1-4, bajar `gear_chance` de los enemigos del nivel (o el `gear_loot_tier` si conviene). Criterio: un arma de tier 3 no aparece en los primeros cuatro sectores.
7. **Subfusil con más dispersión:** subir la dispersión del subfusil en su `.tres` de `data/weapons/`. No tocar cadencia ni cargador. Criterio: en la Sala de Estrés se nota que no es tan preciso, sin que sea inútil a distancia. (Fase Q, punto 9.)
8. **Salto base más alto:** subir un poco la velocidad de salto por defecto en `entities/player/player.gd`. Criterio: el personaje salta un poco más alto, y el 1-1 sigue siendo completo (todas las plataformas y pozos se alcanzan). (Fase Q, punto 10.)

---

## Reglas para Ahorrar Cuota
- Una sesión nueva por fase.
- Empezar siempre en Sonnet medium; para tareas mecánicas, Haiku low o medium.
- Haiku para tareas mecánicas (valores, recursos, textos).
- **Ninguna tarea se asigna a esfuerzo high ni a Opus.** Si una tarea parece pedir high, se parte en subtareas chicas hasta que cada una sea low o medium.
- Si una subtarea falla dos veces con Sonnet medium, se vuelve a dividir antes de subir de esfuerzo.
