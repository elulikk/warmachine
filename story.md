# STORY — La historia del juego

**Versión vigente: la simple (2026-10-19).** La historia es una **excusa liviana** para mostrar mapas, niveles, mundos y armas (estilo Metal Slug / Broforce): pocas palabras, ritmo rápido, cada mundo se justifica solo. Campaña lineal, no roguelite. Las reglas del universo (la Caja, el pasillo, los cristales) están en `lore.md`. Todo es borrador hasta que el usuario lo apruebe; los nombres son propuestas.

---

## 1. La historia en una página

**Gunther** es un detective sin miedo a ensuciarse las manos. La ciudad lo llama cuando nadie más se anima.

**El encargo.** La ciudad le pide recuperar algo que el **Sindicato** robó del puerto: una caja negra que nadie pudo abrir. Gunther va a hacer un trabajo más, aburrido y sucio, y lo que encuentra es una persecución.

**El presente (mundo 1).**
1. **La calle.** Gunther sigue a un mensajero del Sindicato. Lo ven, corren, empieza la persecución. Los maleantes del camino son gente del Sindicato. Al final, el mensajero se mete en las alcantarillas.
2. **Las alcantarillas.** El atajo del Sindicato. Las ratas están raras, demasiado grandes: algo de la caja se está "filtrando". Al fondo, la **Rata Gigante**. Gunther se lleva su flauta.
3. **La torre y los techos.** El edificio del Sindicato. Gunther sube piso por piso y salta de techo en techo hasta la azotea. Ahí está **la Caja**, y el jefe del Sindicato, **Víctor Valmont, el Patrón**, apoya una piedra brillante y la abre. Se mete adentro. Gunther lo sigue.

**El pasillo.** Adentro de la Caja hay un pasillo negro infinito lleno de puertas: cada puerta es un mundo, otra época. El Patrón entendió lo que tiene: **una forma de robar armas y tesoros de cualquier época y venderlos**. Salta de mundo en mundo y en cada uno se asocia con el poder local.

**El motor del juego.** Gunther lo persigue puerta por puerta. En cada mundo:
- el Patrón ya llegó, hizo un trato con alguien poderoso (el jefe del mundo) y se llevó algo;
- Gunther pelea hasta ese jefe, lo derrota y se queda con **el arma o el artefacto del mundo**;
- el Patrón se escapa por la siguiente puerta.

**Los Agentes del Tiempo.** Una organización que vigila el pasillo: **nadie viaja**. Aparecen cada tanto en los niveles para capturar a Gunther (helicópteros, naves, portales según la época). Llevan **cristales**, lo único que abre las puertas: los que te persiguen son tu combustible. No son el villano: son un estorbo que paga.

**El final.** Gunther acorrala al Patrón en el último mundo (el más profundo del pasillo), que pelea con todo lo que robó en el viaje. Gunther lo derrota y cierra el caso. Le devuelve a la ciudad lo que pidió... salvo la Caja, que se queda. Gancho para más mundos.

**Tono.** Gunther habla poco, seco e irónico. Una línea por escena alcanza. Nada de flashbacks largos ni monólogos.

## 2. Personajes

| Personaje | Qué es | Para qué sirve |
|---|---|---|
| **Gunther** | Detective, antihéroe, piloto largo, barba de días. Arranca con su 9 mm. | El jugador. |
| **Víctor Valmont, "el Patrón"** | Jefe del Sindicato, dueño de la torre. Elegante, cobarde, siempre un paso adelante. No pelea hasta el final: manda a otros. | El hilo de toda la campaña: es a quien se persigue. |
| **El mensajero** | Matón del Sindicato que Gunther persigue en el mundo 1. | Excusa para arrancar la persecución. Puede caer al final de la calle o en las alcantarillas. |
| **La Voz** | El contacto de la ciudad. Nunca se la ve ni se sabe su nombre: solo llama por teléfono. | Da el encargo y, de vez en cuando, un mensaje. Queda abierta para un giro al final (a definir). |
| **Jefes de cada mundo** | El socio local del Patrón (Loki, Zeus, Lucifer, el Rey Caído, etc.). | Un jefe por mundo con su arma o artefacto. |
| **Agentes del Tiempo** | Soldados de negro con visor. | Enemigos recurrentes que sueltan cristales. |

## 3. Plantilla de cada mundo

Todos los mundos siguen la misma receta para que hacer uno nuevo sea mecánico:

1. **3 niveles + jefe** (el largo puede variar si el mundo lo pide).
2. **Una mecánica del lugar** que no esté en otro mundo (ejemplos ya hechos: agua y ratas en las alcantarillas, vacío entre techos, lava que quema).
3. **2 o 3 armas de la época** como premio por avanzar, y **el arma o artefacto del jefe** al final.
4. **Tres escenas cortas**, cada una con 1 imagen o un plano y 1 o 2 líneas:
   - **Llegada:** Gunther sale de la Caja local y ve dónde cayó.
   - **Mitad:** una pista de qué vino a buscar el Patrón acá.
   - **Jefe:** el jefe se presenta; al ganar, el Patrón se escapa por la puerta siguiente.
5. **Agentes del Tiempo** cada tanto, adaptados a la época.

## 4. Los mundos y qué fue a buscar el Patrón

Solo los mundos que ya están confirmados en `ROADMAP.md` 3.4; el orden es una propuesta.

| Orden | Mundo | Qué vino a buscar el Patrón | Arma o artefacto del jefe |
|---|---|---|---|
| 1 | **Presente** (calle, alcantarillas, torre) | Vende lo que robó; la Caja es su mercadería. | Flauta de Hamelin (Rata Gigante). |
| 2 | **Periferia Subterránea** (steampunk) | Máquinas de vapor y armas industriales para vender. | Arma de vapor (a definir). |
| 3 | **Valle Esmeralda** (medieval) | La corona y la armería del Rey Caído. | Arma del Rey Caído (a definir). |
| 4 | **Abismo Ígneo** (infierno) | Le ofrece a Lucifer una salida por la Caja a cambio de armas demoníacas. | Arma de Lucifer (a definir). |
| 5 | **Asgard** (nórdico) | El martillo de Thor. Loki lo ayuda y después lo traiciona. | **Mjolnir** (ya existe en el juego). |
| 6 | **Olimpo** (griego) | El rayo de Zeus. | **Rayo de Zeus**. |
| 7 | **Páramo Radiactivo** | Un reactor portátil para alimentar sus armas. | **Reactor portátil**. |
| 8 | **Futuro** (final) | La tecnología para controlar el pasillo. Acá se lo enfrenta. | Arma del futuro / teletransporte. |

## 5. Escenas del mundo 1

Cortas; se arman con el motor de `core/cinematics/` cuando toque (primero mapas y mecánicas).

- **Apertura:** negro, lluvia. **LA VOZ** (por teléfono): *"El Sindicato se llevó algo del puerto. Recuperalo. Como sea."* **GUNTHER:** *"Como sea es mi especialidad."*
- **Calle, al ver al mensajero:** el mensajero lo ve y sale corriendo. **GUNTHER:** *"Siempre corren."*
- **Entrada a las alcantarillas:** **GUNTHER:** *"Claro. Las ratas siempre van para abajo."*
- **Rata Gigante:** **GUNTHER:** *"...Eso no es una rata de acá."*
- **Torre:** cartel del Sindicato en la entrada. **GUNTHER:** *"Piso por piso, entonces."*
- **Azotea:** el Patrón abre la Caja con una piedra que brilla. **VALMONT:** *"Llegás tarde, detective. Esto vale más que tu ciudad entera."* Entra. **GUNTHER:** *"Nunca me gustó dejar un caso a medias."* Lo sigue.
- **El pasillo:** puertas infinitas, una entreabierta con luz. **GUNTHER:** *"...Esto no estaba en el encargo."*

## 6. Pendiente

- Qué mundo va segundo (propuesta: Periferia Subterránea).
- Armas de los jefes que dicen "a definir".
- Si La Voz aparece más allá de la apertura y si tiene un giro al final.

---

## Apéndice — material viejo (descartado salvo que se rescate algo)

Lo de abajo es la versión anterior (2026-10-17 y antes): el robo del compañero, el monólogo del P-1, el Agente fugitivo y el giro. **No está vigente.** Queda por si se quiere rescatar alguna idea.

### 1. Protagonista: Gunther

- **Ex policía, hoy detective privado.** Sabe investigar, seguir pistas y pelear. Arranca con su **pistola 9 mm** equipada: es su arma de siempre.
- **Aspecto:** piloto largo, camisa arremangada, corbata floja, barba de días. Noir moderno.
- **Su herida:** años atrás, siendo policía, a su compañero lo mataron durante un robo. Los "ladrones" eran en realidad **Agentes del Tiempo**. Gunther nunca lo supo.
- **Cómo lo lleva:** ya lo superó, más o menos, pero lo tiene ahí. No vive para vengarse; sigue con su trabajo y ese recuerdo le pesa de fondo.
- **Tono:** seco, irónico, de pocas palabras. Habla consigo mismo como un narrador de cine negro.

### 2. Personajes clave

- **El compañero** (nombre a definir): el policía muerto en el robo. Ver el giro (sección 7).
- **El viajero** (nombre a definir): la persona de otro mundo a la que el Agente estaba por arrestar. Gunther lo salva sin querer. Aliado, guía del pasillo o alguien con su propia agenda.
- **El Agente fugitivo** (nombre a definir): el que huye de Gunther en el mundo del presente y lo lleva hasta la Caja.
- **El jefe del Sindicato** (nombre a definir): dueño del hotel y de la discoteca. Custodia la Caja para el comprador. No pelea: manda a los suyos.
- **Personajes por mundo:** Loki, Zeus, Poseidón, Eolo, Caronte, Lucifer, el Rey Caído, etc.

### 3. Antagonistas

| Antagonista | Quién es | Por qué es su enemigo |
|---|---|---|
| **El Agente fugitivo** | Agente del Tiempo sorprendido por Gunther en pleno arresto. | Gunther lo vio y eso no puede pasar. Huye en vez de pelear porque un testigo del presente es un problema que debe reportar. |
| **El Sindicato y su jefe** | La mafia que controla la noche de la ciudad. | Gunther entra a sus calles, su muelle, su hotel y su discoteca persiguiendo a alguien, y se acerca a la Caja que están vendiendo. |
| **Los Agentes del Tiempo** | La organización que vigila el pasillo (ver `lore.md`). | Gunther vio lo que no debía y después usa la Caja. Para ellos es un viajero ilegal más. |
| **El líder de los Agentes** | **(a definir según el giro, sección 7)** | Fue quien dio la orden aquella noche del robo. |
| **El comprador** (posible dueño de Núcleo) | Viajero que junta Cajas y artefactos para controlar la red. | Gunther le arruina la compra de la Caja del presente y después compite con él por los artefactos legendarios. Rival recurrente. |
| **Loki** | El embaucador de Asgard. | Primero ayuda a Gunther y después lo traiciona: quiere los cristales para escapar del Ragnarok. |
| **Zeus** | Rey del Olimpo. | Gunther le roba el rayo, como Prometeo robó el fuego. |
| **Lucifer** | Señor del Infierno; custodia su Caja sin poder usarla. | Gunther llega con cristales: es su llave de salida. |

Patrón general: cada jefe de mundo quiere algo que Gunther tiene (cristales, la Caja, un artefacto) o se ofende por algo que hace. Ningún jefe es "malo porque sí".

---

### 4. Prólogo — el robo (flashback)

Cinemática corta, años atrás. Misma ciudad, misma lluvia.

1. Un patrullero frena frente a una joyería con la vidriera rota. Gunther, más joven y de uniforme, y su compañero bajan con las linternas.
2. Adentro, figuras de negro con visores. No se llevan joyas: rodean a alguien.
3. Destello blanco, disparos. El compañero cae. Las figuras ya no están.
4. Corte a negro. Texto: *"El caso nunca se cerró."*

Diálogo:
- **COMPAÑERO:** Dejá que hablo yo. Siempre te ponés nervioso.
- **GUNTHER:** Yo no me pongo nervioso.
- **COMPAÑERO:** *(viendo a las figuras)* ...Eso no es una banda.

### 5. Acto 1 — el presente (8 sectores)

Ciudad moderna, siempre de noche y con lluvia. El mundo del presente es el **primero del juego**; la Periferia Subterránea (steampunk) queda tal cual y pasa a ser un mundo tier 1.

| Sector | Lugar | Enemigos | Momento de historia |
|---|---|---|---|
| P-1 | **La calle** (veredas, faroles, autos pasando) | Ratas, ladrones | Tutorial. Paseo con monólogo de Gunther que revela el pasado de a poco. Sin viajero ni arresto; solo un visor en el callejón. |
| P-2 | **Los callejones** | Ratas, ladrones, matones | Persecución por los callejones; el Agente se le escapa por una alcantarilla. |
| P-3 | **Las alcantarillas** | Ratas en masa, ladrones escondidos | Gunther encuentra la primera filtración: algo de otro mundo tirado en el agua. |
| P-4 | **El barrio de casitas** | Ladrones, matones, asaltantes | Un vecino vio "a un tipo de negro" correr hacia el puerto. |
| P-5 | **El muelle** | Asaltantes, matones | Primera aparición del **helicóptero de los Agentes** y primeros cristales. Gunther se entera de que el Sindicato descargó una caja negra y la llevó al hotel. |
| P-6 | **El hotel** (lobby, pasillos, ascensores) | Patovicas, asaltantes, matones | El hotel es del Sindicato. Gunther sube piso por piso. |
| P-7 | **La discoteca electrónica** (en el hotel) | Patovicas, asaltantes, todo junto | Música fuerte, luces, láseres. El jefe del Sindicato lo ve desde la cabina del DJ y ordena subir la seguridad de la azotea. |
| P-8 | **La azotea** | Oleadas de sicarios y lo peor del Sindicato | **Final del mundo.** Sin jefe único: oleadas cada vez más duras protegiendo la Caja. Al terminar, la Caja. |

(Los nombres "P-1…P-8" son de trabajo; el código decide la numeración.)

#### P-1 — el paseo (monólogo mientras camina)

Sin cinemática ni encuentros. Gunther camina por la calle bajo la lluvia y el control queda libre todo el tiempo. Cada vez que cruza un punto de la calle dispara una línea de voz en off, una sola vez por punto. Las líneas van de a poco revelando la historia; no explican nada de golpe.

- **GUNTHER** *(al arrancar, bajo el toldo)*: "Todavía recuerdo aquella noche despejada, con estrellas."
- **GUNTHER** *(al pasar el primer farol)*: "Intenté escapar del pasado. Pero el pasado siempre tiene mejores armas."
- **GUNTHER** *(al pasar un auto que frena en el charco)*: "Doce años y la lluvia sigue igual. Como si el cielo también se hubiera quedado esa noche."
- **GUNTHER** *(al cruzar la esquina)*: "Dejá que hablo yo, me decía. Siempre se adelantaba. Y yo siempre lo dejaba."
- **GUNTHER** *(al mirar su reflejo en un vidrio)*: "Dicen que uno no sale nunca del uniforme. Yo creo que es al revés: el uniforme nunca sale de uno."
- **GUNTHER** *(al llegar a la boca de un callejón oscuro)*: "Otra noche de lluvia. Otro caso que no es un caso."
- **GUNTHER** *(al ver, al fondo del callejón, un visor que brilla un segundo y se apaga)*: "...Ese equipo. Lo vi una sola vez en mi vida."
- Fin del tramo: Gunther se queda mirando el callejón vacío. Corte, sin persecución.

Notas:
- El contraste "noche despejada con estrellas" (recuerdo) contra "siempre lluvia" (presente) es intencional: el juego empieza con el recuerdo y el presente lo tapa.
- Las líneas se pueden leer como subtítulos, con voz en off o como monólogo; decidir cuál después.
- Pendiente: el visor del callejón es lo único que queda del Agente en P-1. Si no se quiere ni eso, se borra y P-2 arranca directo en la persecución.

#### P-3 — la filtración
- **GUNTHER** *(levanta un objeto imposible del agua: una moneda de un país que no existe)*: Esto no lo fabricó nadie de acá.

#### P-5 — el muelle y el helicóptero
- Un helicóptero negro sin luces aparece sobre los contenedores y barre el muelle con el reflector. Bajan Agentes.
- **GUNTHER:** Bueno. Ahora vinieron a buscarme a mí.
- Al matar al primero, suelta un **cristal** en vez de monedas.
- **GUNTHER** *(mirando el cristal)*: Ni plata, ni documentos. Una piedra que brilla. ¿Qué son ustedes?
- Un estibador herido: *"Bajaron una caja negra del barco... se la llevaron al hotel. Nadie pudo abrirla."*

#### P-7 — la discoteca
- **JEFE DEL SINDICATO** *(por los parlantes, desde la cabina)*: Un detective. En mi club. Que alguien suba a la azotea y no deje que nadie toque la mercadería.
- **GUNTHER:** Mercadería. Así que la venden.

#### P-8 — la azotea y la Caja
- Antes de las oleadas: la Caja bajo una lona, rodeada de sicarios, la lluvia golpeando el metal.
- **GUNTHER:** Una caja negra en una azotea. Doce años para esto.
- Oleadas. Al terminar, aparece el **Agente fugitivo**, apoya un cristal en la Caja y la Caja se abre sola.
- **AGENTE:** No tendrías que haber visto nada. Igual que tu compañero.
- Entra. La Caja empieza a cerrarse. Gunther corre y se mete.

#### Dentro de la Caja (cinemática clave)
- Silencio total. La lluvia desaparece. Un **pasillo negro infinito** lleno de puertas, a los dos lados, hasta perderse de vista.
- Al fondo, el Agente atraviesa una puerta. Esa puerta queda entreabierta, con luz en el marco: **el primer viaje es gratis** porque el Agente la dejó abierta.
- Las demás puertas están apagadas.
- **GUNTHER:** ...Dijo "igual que tu compañero".
- **GUNTHER:** Muy bien. Sigamos el rastro.
- Cruza la puerta. La primera puerta lleva a la **Periferia Subterránea** (mundo steampunk) **(a confirmar)**.

### 6. Acto 2 — el multiverso

#### Motivaciones que se apilan
1. **Al principio:** atrapar al Agente fugitivo y entender qué pasó con su compañero.
2. **A mitad del juego:** descubre que las armas de un solo mundo no pueden matar a los altos mandos de los Agentes. Solo los dañan **artefactos legendarios de distintos mundos** (Martillo de Thor, Rayo de Zeus, tecnología del año 5000). Tiene que juntarlos, compitiendo con el comprador, que busca lo mismo.
3. **El giro** (sección 7).

#### Ritmo por mundo
- Salida por la Caja local (cinemática corta).
- Niveles del mundo (cantidad variable), con una pista del caso en alguno, como un detective que arma el expediente.
- Jefe del mundo y su artefacto legendario.
- Los Agentes aparecen cada tanto durante los niveles; sus cristales abren la puerta siguiente.

### 7. El giro (a decidir)

Opciones, de la preferida a la menos:

- **1) El compañero está vivo y es Agente (recomendada):** aquella noche no murió; los Agentes se lo llevaron porque vio demasiado y lo convirtieron en uno de ellos. Hoy es el alto mando que persigue a Gunther de mundo en mundo, con máscara. La frase del Agente en la azotea ("igual que tu compañero") es la primera pista.
- **2) El líder de los Agentes es Gunther del futuro:** el Gunther que ya hizo todo este viaje y vio que cada salto rompe la realidad. Fundó a los Agentes con la regla "nadie viaja" y aquella noche dio la orden. Persigue a su yo joven para que no repita su error.
- **3) Los Agentes tienen razón a medias:** cada viaje daña la realidad y las filtraciones son culpa de los viajeros. Se suma bien a cualquiera de las dos anteriores para que el final sea un dilema.

Combinación propuesta: **1 + 3**, con la 2 de reserva para un giro más grande al final.

#### Cómo se revela (para la opción 1)
1. **Pistas tempranas:** el Agente enmascarado conoce el apodo que el compañero le decía a Gunther, pelea con su estilo, usa una frase suya ("dejá que hablo yo").
2. **Mitad del juego:** Gunther encuentra el expediente de los Agentes sobre la noche del robo: no figura un muerto, figura un "reclutado".
3. **Revelación:** cinemática en la que se saca la máscara (en un mundo tier 2, por ejemplo el Futuro).

### 8. Acto 3 — el final

- En lo más profundo del pasillo está la sede de los Agentes, un lugar fuera del tiempo.
- Jefe final: el líder de los Agentes (según el giro).
- **Dilema final (a definir si el jugador elige o hay un solo final):**
  - **Cerrar el pasillo:** no hay más filtraciones ni viajes.
  - **Tomar el pasillo:** Gunther lo controla, arriesgando convertirse en lo que combatía.
  - **Tercera vía (final "bueno"):** con todos los artefactos, Gunther repara el pasillo en vez de cerrarlo o dominarlo, y cierra el caso de su compañero.

### 9. Cinemáticas previstas

Usan el motor de cinemáticas (`ROADMAP.md`, sección 3.6).

1. Prólogo: el robo (flashback).
2. P-1: el paseo (líneas de voz en off, sin cinemática).
3. P-5: el helicóptero y el primer cristal.
4. P-7: el jefe del Sindicato en la discoteca.
5. P-8: la Caja en la azotea.
6. Dentro de la Caja: el pasillo de puertas.
7. Salida por la Caja en cada mundo.
8. Presentación de cada jefe de mundo.
9. Revelación del giro.
10. Final.

### 10. Pendiente

- Nombres: compañero, viajero, Agente fugitivo, jefe del Sindicato, comprador, líder de los Agentes.
- Elegir el giro (1, 2, 3 o combinación) y si el final es elegible.
- Qué papel tiene el viajero que Gunther salvó (ya no aparece en P-1; decidir si vuelve después o se descarta).
- A qué mundo lleva la primera puerta (propuesta: Periferia Subterránea).
- Qué pista del caso hay en cada mundo.
