class_name PlayerMovementData
extends Resource
## Recurso de datos configurable para parametrizar la física y mecánicas de movimiento del jugador.
## Permite a los diseñadores iterar valores desde el Inspector sin modificar código fuente.

@export_group("Movimiento Horizontal")
## Velocidad horizontal máxima que puede alcanzar el jugador en el suelo o aire (píxeles/segundo).
@export var move_speed: float = 140.0

## Tasa de aceleración horizontal sobre el suelo (píxeles/segundo^2).
@export var acceleration: float = 900.0

## Tasa de frenado (fricción) horizontal sobre el suelo al soltar controles (píxeles/segundo^2).
@export var friction: float = 1100.0

## Tasa de aceleración cuando el jugador se desplaza en el aire (control aéreo).
@export var air_acceleration: float = 600.0

## Tasa de resistencia o arrastre en el aire al no presionar controles horizontales.
@export var air_friction: float = 250.0

@export_group("Mecánicas de Salto")
## Impulso vertical aplicado hacia arriba al saltar (velocidad en píxeles/segundo).
@export var jump_force: float = 480.0

## Multiplicador de corte de velocidad vertical al soltar la tecla de salto en pleno ascenso (0.5 = 50%).
@export var jump_cut_multiplier: float = 0.5

## Tiempo de tolerancia (en segundos) para saltar tras haber dejado una plataforma sin haber saltado.
@export var coyote_time: float = 0.15

## Tiempo de almacenamiento en buffer (en segundos) de la pulsación de salto previa al aterrizaje.
@export var jump_buffer_time: float = 0.10

@export_group("Gravedad y Caída")
## Gravedad base aplicada al personaje (píxeles/segundo^2).
@export var gravity: float = 980.0

## Multiplicador aplicado a la gravedad durante la caída para mayor peso y sensación "snappy".
@export var fall_gravity_multiplier: float = 1.35

## Velocidad terminal máxima de caída permitida (píxeles/segundo).
@export var max_fall_speed: float = 650.0
