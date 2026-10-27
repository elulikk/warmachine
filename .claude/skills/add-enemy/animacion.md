# Arte animado de un enemigo (hojas de Flow → cuadros)

Sustituye la ilustración fija de `MOBS` por cuadros dibujados: caminar, ataque, golpe y muerte. **Estado (actualizar siempre que se procese uno nuevo):** hechos rata, ladrón y pistolero (ataque de 2 cuadros); faltan matón, patovica, sicario escopeta (`hitman_elite`), sicario SMG (`hitman_smg`) y agente (`time_agent`) (ROADMAP 5). **Sin animación de muerte:** el cuerpo desaparece y las tripas hacen de cuerpo universal; pedir solo base, walk, attack (y hit de 2 cuadros opcional). **Los prompts los genera el usuario** (política: no usar el navegador). Tu parte: dar los prompts, procesar, conectar.

## 1. Prompts (4 hojas por enemigo, 16:9, croma verde #00FF00)

Verde y no negro: los personajes oscuros se pierden. Decir siempre "sin nada verde en <enemigo>". Una variante por prompt y **la hoja 1 como imagen de referencia de las otras tres** (mantiene el diseño). Reemplazar `<E>` por la descripción corta (ej. "ladrón encapuchado, buzo gris, pantalón militar, máscara"). Dar los 4 bloques listos para copiar, con el nombre de archivo de cada uno.

Reglas que ya costaron una repetición: **máximo 5 cuadros**, **UNA SOLA FILA**, cada cuadro en su propia celda con margen vacío, **nada toca ni se superpone con otro** (colas, brazos y armas incluidos), misma línea de suelo y mismo tamaño, vista lateral pura mirando a la derecha. Sin eso Flow apila los cuadros en dos filas con "cuerpos fantasma" y la hoja no sirve.

**Hoja 1, `base.jpg` (diseño de referencia, 3 poses):**
```
Hoja de sprites 16:9 para videojuego 2D de plataformas, estilo noir urbano de noche, <E>, de cuerpo entero, VISTA LATERAL PURA mirando a la derecha. Dibujado 3 veces con mucho espacio entre sí: 1) parado en guardia, 2) agazapado listo para atacar, 3) atacando. Fondo verde croma liso #00FF00 uniforme, sin degradé ni sombras. Bordes nítidos, contorno oscuro, colores apagados con un reflejo sutil de neón cian y magenta, sin texto, sin sombra en el suelo, sin nada verde en el personaje.
```

**Hoja 2, `walk.jpg` (5 cuadros):**
```
Hoja de sprites de animación 16:9, el MISMO personaje de la imagen de referencia, ciclo de correr de exactamente 5 cuadros en UNA SOLA FILA horizontal, cada uno en su propia celda de un quinto del ancho con margen vacío: NINGÚN cuadro toca, tapa ni se superpone con otro. Misma línea de suelo y mismo tamaño. Vista lateral pura mirando a la derecha. Secuencia: 1) paso largo adelante, 2) apoyo con el cuerpo bajo, 3) en el aire, 4) paso largo atrás, 5) apoyo otra vez. Fondo verde croma #00FF00 liso, sin degradé ni sombras. Bordes nítidos, contorno oscuro, sin texto, sin sombra, sin nada verde.
```

**Hoja 3, `attack.jpg` (5 cuadros):** igual que la 2, con la secuencia `1) preparación (cuerpo hacia atrás), 2) arranque, 3) golpe en el punto más extendido (con <arma / puño / mordida>), 4) continuación, 5) recuperación`. Armados a distancia: `3) dispara el arma con fogonazo`. Animales: salto y mordida.

**Hoja 4, `hitdeath.jpg` (5 cuadros):** igual que la 2, con la secuencia `1-2) recibe un golpe (cabeza atrás, cuerpo encogido, gesto de dolor), 3-5) cae y termina inmóvil en el suelo, boca arriba`. Sin sangre explícita (la pone el juego por partículas).

## 2. Procesar

Guardar las hojas como `art_source/world<N>/<kind>/{base,walk,attack,hitdeath}.jpg` (`python art_source/flow_tools.py ingest --since 30 --dest art_source/world<N>/<kind> --prefix x_` y renombrar mirando el contenido). Después:

```bash
python art_source/process_anim.py <kind> --world <N> --ref-h <ALTO_TEXTURA> [--ref-w ANCHO] [--hit 2]
```

`--ref-h` = alto en px de textura (3x el juego) del primer cuadro de caminar: humanos ≈ 3x el `size.y` de `MOBS` en `armor_art.gd` (ladrón 46 → ~138); animales por ancho con `--ref-w` (rata 105). El script recorta (`--holes --gap 2 --min-area 0.004`; sin `--holes` queda verde atrapado entre cola y cuerpo), escala todo con un mismo factor, ancla los pies por centro de masa y escribe `assets/art/world<N>/<kind>/`. Mirar **una sola vez** `_cut/` con `flow_tools.py contact`; si faltan o sobran piezas la hoja salió mal: pedir otra, no parchear.

## 3. Conectar

Pegar la línea que imprime el script en `MOB_FRAMES` de `entities/enemies/enemy_art.gd` (clave = `art_kind` de la escena). `enemy_art.gd` anima solo: caminar según la velocidad, ataque cuando salta `contact_cooldown` (los armados también), cuadro 3 del ataque en el aire, golpe al perder vida y un **cadáver** (cuadros de muerte, queda 1.2 s y se desvanece) al morir. Con `MOB_FRAMES` ya no cuentan `MOB_SPLIT` ni la marcha partida. Probar con `smoke.sh` y que el usuario mire tamaño y velocidad (perillas: `--ref-h` del script; `7.0 + …` y `0.4` en `_animate_frames`).

**Arreglos de hoja sin repetirla:** si dos cuadros se tocan (pies, arma) quedan fusionados en una pieza: pintar con el color del fondo un rectángulo fino **solo en la zona de contacto** con PIL (no una línea vertical entera: se lleva la cara o el arma del cuadro vecino). Si sobra una pieza fantasma, pintarla entera de fondo. Editar la copia de `art_source/world<N>/<kind>/`, no la de Descargas. Mirar las hojas originales solo si el contacto muestra algo raro.
