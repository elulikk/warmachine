class_name State
extends Node
## Clase base abstracta para todos los estados de la Máquina de Estados Finita (FSM).
## Cada nodo que herede de State encapsula la lógica exclusiva de ese estado
## y decide cuándo y hacia dónde transicionar emitiendo la señal `transitioned`.

## Señal emitida para solicitar una transición a un nuevo estado por nombre.
signal transitioned(from_state: State, to_state_name: StringName)

## Referencia a la máquina de estados a la que pertenece este nodo.
var state_machine: StateMachine = null


## Se ejecuta una única vez al entrar en este estado.
func enter() -> void:
	pass


## Se ejecuta una única vez al salir de este estado (limpieza de timers, tweens, etc.).
func exit() -> void:
	pass


## Se ejecuta en cada frame de renderizado (_process del StateMachine).
func update(_delta: float) -> void:
	pass


## Se ejecuta en cada tick de física (_physics_process del StateMachine).
func physics_update(_delta: float) -> void:
	pass


## Se ejecuta cuando hay eventos de entrada sin procesar (_unhandled_input).
func handle_input(_event: InputEvent) -> void:
	pass
