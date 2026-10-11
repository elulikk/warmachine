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
* **Modelo recomendado:** Sonnet, esfuerzo **high** (toca arma, combate, jugador y pickups a la vez).
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
* **Modelo recomendado:** Sonnet, esfuerzo **high** (toca varios sistemas a la vez).
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

---

## 5. Fase D — Movilidad Mínima
*Objetivo:* Una sola mejora de movimiento, sin tocar el resto de la FSM.
* **Modelo recomendado:** Sonnet, esfuerzo **high** (la FSM del jugador es la parte más delicada). Si solo se agrega un valor o un flag en `ItemData`, medium alcanza.
* **Alcance:**
  1. Elegir una: doble salto, salto más alto o velocidad. **Elegida: velocidad**, como `Botas Ligeras` en la recompensa del Sector 1-2 (sección 2.2). Criterio de cierre validado en juego.
  2. Dejarla como mejora obtenible (pickup o desbloqueo por nivel).
* **Criterio de cierre:** Con la mejora equipada, el salto o la velocidad cambian; sin ella, el comportamiento actual no cambia.

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
- **Modelo recomendado:** Sonnet, esfuerzo **high** (toca enemigos, componentes y física).
- **Criterio de cierre:** 100 enemigos persiguiendo a 60 FPS estables y 200 jugables en la Sala de Estrés, comparando la tabla "FPS según enemigos vivos" antes y después.

---

## 7. Después del Prototipo (no entra ahora)
- Los 50 niveles y los 5 capítulos (Fase 16 del plan anterior). Hechos: 1-1 a 1-5.
- Stand-by de la sección 0.
- Cierre y exportación a `.exe` (cuando el bucle esté validado): el pipeline ya está listo (sección 6b), falta instalar las plantillas y probar.

---

## Reglas para Ahorrar Cuota
- Una sesión nueva por fase.
- Empezar siempre en Sonnet medium, subir a high solo si el cambio toca varios sistemas.
- Haiku para tareas mecánicas (valores, recursos, textos).
- Opus solo si Sonnet high falla dos veces en el mismo bug.
