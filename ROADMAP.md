# ROADMAP — Lo que falta hacer

Solo figura lo pendiente. Lo ya construido se documenta en `PROJECT_CONTEXT.md` (mapa técnico) y en el historial de git. Cuando algo se termina y se valida, se **borra de acá**.

**Estado en una línea:** el primer mundo está completo (sectores 1-1 a 1-10 con jefe), con armas, runas, escudos, invocaciones, comercio, opciones y herramientas de editor. Falta validarlo a mano, balancearlo, darle arte y sonido finales, y construir el Capítulo 2.

---

## 1. Validar a mano (armado, sin verificar en F5)

Marcar y borrar cada punto al comprobarlo. Si algo falla, pasa a la sección 3 o 6.

- [ ] **Sectores 1-5 a 1-10:** recorrerlos completos; que ningún enemigo quede trabado y que las arenas de 12 a 18 enemigos sean jugables.
- [ ] **Rework de oleadas 1-2 a 1-6:** bruto solo en el 1-4, 10 ladrones en el 1-3, ritmo general.
- [ ] **Jefe del 1-10 (Coloso del Núcleo):** si 1200 de vida es mucho o poco, y si la franja roja de la onda de choque se lee a tiempo.
- [ ] **Escudo de madera y Escudo espejo:** sensación del clic derecho mantenido, tamaño de la zona de reflejo, rebote contra plataformas reflectantes.
- [ ] **Red arraigadora, Boomerang, Casco láser, Capa de invisibilidad:** que se compren, se usen desde la barra y se sientan bien (en especial el robo de la capa y el 70 dps del láser).
- [ ] **Invocaciones separadas (Fase J):** seis esqueletos en la Sala de Estrés; que 70 px de distancia sea buena.
- [ ] **Opciones (segunda tanda):** cuenta regresiva de 15 s al cambiar resolución, selección de monitor, reasignación de mando, dificultades, accesibilidad, posprocesado por calidad.
- [ ] **Animaciones de arma:** recarga propia por arma, ráfaga sostenida de las automáticas, tajo de espada y katana a dos manos, doble empuñe y casillero M2.
- [ ] **Pulido visual:** aura de los objetos del piso, pose agachado, brazos abiertos al saltar, borde rojo y latido con poca vida, llama sobre enemigos que arden.
- [ ] **Progresión:** con 15 de EXP por enemigo, en qué punto del 1-2 se llega al nivel 5; presión de enemigos con la vida subida (ladrón 70, bruto 250, centinela 70).
- [ ] **Piezas de editor:** armar una arena y una plataforma desde `platform.tscn` / `arena.tscn`, y correr un nivel con F6 y el equipo de prueba activo.
- [ ] **Sonido:** `fire_ignite`, `net_deploy`, `laser_beam`, `cloak_on/off`, `heartbeat`.

---

## 2. Contenido nuevo

1. **Capítulo 2.** La victoria del 1-10 ya apunta a él y no existe. Definir antes de armar:
   - Tema del capítulo, enemigos nuevos y jefe (el ciclo es: crecen las oleadas de un tipo, entra uno nuevo de a uno por sector).
   - **Aquí empiezan las runas** (se quitaron del primer mundo) y la movilidad avanzada.
   - Qué armas llegan (pistola criogénica y escopeta quedaron para más adelante).
   - Crear `levels/chapter_2/`, registrar en `LevelRegistry.IMPLEMENTED_LEVELS` y nombrar el capítulo.
2. **Capítulos 3 a 5** y el total de 50 niveles. Sin fecha.
3. **Reintegrar mecánicas en stand-by** (ya existen en código, fuera de la campaña): jetpack, alas, vuelo mágico, gancho de anclaje, baliza de translocación, runas avanzadas, mercenarios y drones, contratos de zona. Decidir en qué capítulo entra cada una.

---

## 3. Balance pendiente

- **Oleadas del 1-7 al 1-10:** cantidades sin revisar; las arenas de 16 a 18 pueden ser injustas. Los élites no tienen tope de vivos (corregir con `elite_per_round` o `round_sizes`).
- **Jefe del 1-10:** vida y armadura según el equipo real que llega; efecto del escudo de madera y del espejo.
- **Arena final del 1-5:** si 2 Centinelas a la vez es demasiado; si el MP5 llega tarde o temprano.
- **Casco láser:** 70 dps sostenido es alto; limitar con la barra de energía.
- **Dash:** distancia y tiempo de recarga.
- **Economía:** precios contra el ingreso real de monedas por nivel; el 40 % de compra para que vender no sea oro trivial; un casillero de consumible para el 1-3; segundo comerciante (herrero con runas) con `TraderData`.
- **Mercader en modo prueba:** `sell_everything = true` en `data/traders/merchant.tres`. Apagarlo y definir el stock real antes de una versión jugable.
- **Sockets de runas en armas del primer mundo:** sin runas hasta el Capítulo 2, ¿conviene quitárselos?

---

## 4. Arte pendiente

- **Enemigos por piezas** (ladrón, bruto, centinela): hoy son una ilustración partida en la cintura. Separar brazos y arma como el héroe (`assets/PSD`) para que golpeen de verdad. Arte a mano, luego `enemy_art.gd`.
- **Jefe del 1-10:** usa el arte del bruto agrandado; necesita el suyo.
- **Escudos en mano:** madera y espejo usan arte de respaldo.
- **Lanzallamas de combustible:** sprites de gota, charco animado, boquilla del arma e ícono de inventario (`ui/components/item_icons.gd`).
- **Frostmourne:** el último cuadro de la hoja de armado (`frostmoon_spawn_sheet.png`) es un caballero y el esqueleto que camina es más simple; regenerar la hoja.
- **Íconos propios:** Botas de Súper Velocidad y los ítems nuevos que hoy usan el ícono de respaldo.
- **Haz del casco láser y boomerang:** dibujo procedural, con arte propio opcional.
- **Sombras 2D:** necesitan `LightOccluder2D` en plataformas y luces por nivel; hacerlo junto con un pase de iluminación y colgarlas del preajuste Ultra.

---

## 5. Sonido

- **Reemplazar el 8-bit provisorio por sonido de calidad** (tarea aparte, no bloquea nada): crear o importar los efectos y asignarlos arma por arma con `fire_stream` / `hit_stream`, o con `Sfx.register_override()`.
- Sin sonido a propósito: ambientes, pasos y voces.

---

## 6. Decisiones abiertas y cabos sueltos

- **Escudo:** ¿el bloqueo del escudo de madera debe ser direccional (solo de frente)? Hoy protege de todo mientras está levantado.
- **Función secundaria de arma** (p. ej. zoom del rifle de precisión): `has_secondary_function()` está listo pero ninguna arma lo usa; mientras tanto el clic derecho dispara la mano 2.
- **Nivel antiguo:** `levels/level_01.tscn` / `.gd` está sin conectar al registro; borrarlo o dejarlo.
- **Tests históricos:** `tests/test_phase4..8.gd` ya no se usan; borrarlos o dejarlos.

---

## 7. Técnico y distribución

- **Exportación a `.exe` (diferido hasta tener una versión final cercana):** instalar las plantillas de exportación 4.7.2 (Editor > Administrar plantillas), correr `build_exe.bat` y **probar el `.zip` en una PC limpia**, sin Godot. No se puede hacer desde el código.
- **Idioma y subtítulos:** hoy solo español y sin voces. Si hace falta, pasar los textos a `tr()` con un archivo de traducción.
- **Rendimiento (reabrir solo si el registro muestra caídas):**
  1. Costo de enemigos vivos: con ~100 persiguiendo bajan a 45-48 FPS (CPU: IA y física, ~4 `Area2D` por enemigo). Auditar sensores, capas y máscaras; IA y animación más baratas fuera de cámara.
  2. Instanciado: 2 a 4 ms por enemigo al aparecer; evaluar pool de enemigos.
  3. Liberación repartida de enemigos tras una masacre (el cuadro del golpe ronda 55 ms con 300 muertes).
  - **Criterio:** 100 enemigos persiguiendo a 60 FPS estables y 200 jugables en la Sala de Estrés (tabla "FPS según enemigos vivos" del monitor, F9).

---

## 8. Cómo trabajar las tareas de acá

- Una tarea por sesión, chica y verificable. Si una tarea parece pedir esfuerzo alto, partirla.
- Sonnet con esfuerzo medio por defecto; Haiku para cambios de valores en `.tres`.
- Cambios de valores: tocar solo los valores indicados, sin escenas ni scripts nuevos.
- No hacer commit ni push sin que el usuario lo pida.
- Al cerrar una tarea: actualizar `PROJECT_CONTEXT.md` solo si cambió un archivo de entrada o una regla, y borrar la tarea de este archivo.
