# LEVEL DESIGN — Lo que aprendimos armando el nivel 1

Plantilla de diseño sacada del sector 1-01 (la calle, `levels/chapter_1/level_1_01.tscn`). Sirve para armar el resto de los niveles. Es borrador: se corrige a medida que se prueba a mano.

## 1. Estructura y ritmo

- **Largo:** el nivel principal es largo (1-01: 34.000 px, unas 5 veces lo que era). Un tramo de calma entre encuentros, no un pasillo de enemigos continuo.
- **Ciclo de enemigos:** crece un tipo antes de introducir el siguiente (ratas de a 1, 2, 3 → asaltante → más ratas → más asaltantes) y se repite con grupos más grandes. Ver `enemy-wave-progression-cycle`.
- **Tutorial sin decirlo:** se empieza sin armas, el cuchillo es la primera, las ratas llegan de a pocas, y recién al final del primer tramo hay un enemigo armado.
- **Checkpoints:** uno cada 4.000–6.000 px y siempre antes de un grupo fuerte. Al cargar la partida se vuelve al último checkpoint (no al campamento).
- **Armas:** la primera arma que aparece es floja (revólver oxidado); la mejor (9 mm) llega mucho después, con su cartel. Cada arma nueva se siente como una mejora.

## 2. Enemigos y combate

- Las ratas y los asaltantes sueltan poca sangre y pocos trozos (`gore_amount` por enemigo). Humanos y brutos, más.
- El disparo del asaltante sale de la boca de la pistola (65 px sobre los pies, 28 hacia adelante), no del cuerpo.
- Las ratas saltan poco (`hop_speed` 400, unos 82 px): pasan tachos y barriles, no cajas altas ni contenedores.
- Un enemigo **pierde el aggro** al alejarte más de 1,8 veces su rango (no los de arena ni los de oleadas).
- Los enemigos nacen en la escena desde el principio; los lejanos duermen (animación y física a menor frecuencia).
- La munición tiene reserva de 6 cargadores que se rellena sola (10 s por cargador); al subir de nivel se recarga todo.

## 3. Props, plataformas y obstáculos

- Obstáculos sólidos (`WorldProp`): tachos, barriles, cajas, bolsas, contenedores, de a 1 a 3 pegados y de menor a mayor altura, para subirlos como escalones.
- **Plataformas elevadas** (150–190 px sobre el piso) solo con escalones al lado; el salto del jugador llega a ~138 px. Una plataforma sin escalones cerca es inalcanzable: no se pone.
- Colisión un poco más chica que el dibujo (14 % de ancho, 7 % de alto), para no pisar aire al costado.
- Los obstáculos sacan solos a lo que quede metido adentro (cada 1,5 s), pero no a quien se pega al costado ni a quien camina encima.
- **No poner un obstáculo delante de un edificio**: los grupos se acomodan en tramos sin edificio detrás.
- Mantener libres: el arranque, la salida, los checkpoints, las armas del suelo y la zona de aparición de cada enemigo (±80 px).

## 4. Piso, sangre y línea de pies

- Todo (colisión, pies, sangre, trozos, objetos) se apoya en **una sola línea: el borde superior del sprite del piso**. No subir ni bajar la acera para "arreglar" la vista: rompe esa línea.
- En pisos pintados vistos de frente (la acera del 1-01) la sangre es una mancha plana en esa línea, no un charco que gotea.
- El piso está a y = 556 en los niveles de la ciudad.

## 5. Fondo y estética

- Menos edificios en el frente (la mitad que antes) y el parallax del fondo se ve entre ellos.
- Los faroles del parallax son luz suave y translúcida, no conos opacos.
- Cada nivel largo lleva su música (`base_music`) y sus carteles de ayuda provisorios.

## 6. Cómo se arma

- Los tramos prearmados (`levels/chunks/`) se arrastran dentro del nivel en el editor; la geometría se pasa sola a `Environment` y toma el tileset del mundo.
- `build_levels.py` regenera niveles desde cero y **borra lo hecho a mano** (edificios, props) del 1-01: no usarlo en niveles ya editados a mano.
- Pruebas: arrancar el nivel con `smoke.sh` (sin sonido) y mirar una captura de la zona tocada.

## 7. Pendiente de diseño

- Nivel 2 (alcantarillas) y nivel 3 (torre y techos): ver `ROADMAP.md` sección 1b.
- Arenas y tramos con plataformas entre techos para el nivel 3.
- Enemigos nuevos para la subida del edificio.
- Cinemáticas y carteles definitivos (después de la historia).
