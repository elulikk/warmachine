class_name StateMachine
extends Node
## Gestor jerárquico de estados finitos (FSM) modular y desacoplado.
## Descubre automáticamente los nodos hijos que hereden de State,
## controla el ciclo de vida y delega las actualizaciones de física, lógica e input.

## Emitida cuando ocurre una transición exitosa entre estados.
signal state_changed(previous_state: State, new_state: State)

## Estado con el que iniciará la máquina al estar lista la escena.
@export var initial_state: State

## Referencia al estado que se encuentra activo en el tick actual.
var current_state: State = null

## Registro indexado de estados hijos por nombre en minúsculas para robustez.
var states: Dictionary[StringName, State] = {}


func _ready() -> void:
	_register_child_states()
	
	if initial_state != null:
		change_state(initial_state.name.to_lower())
	elif get_child_count() > 0 and get_child(0) is State:
		change_state(get_child(0).name.to_lower())
	else:
		push_warning("[StateMachine] No se definió initial_state y no hay hijos de tipo State.")


func _process(delta: float) -> void:
	if current_state != null:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_state != null:
		current_state.handle_input(event)


## Solicita cambiar al estado con el nombre especificado.
func change_state(target_state_name: StringName) -> void:
	var normalized_key: StringName = StringName(target_state_name.to_lower())
	
	if not states.has(normalized_key):
		push_error("[StateMachine] El estado '%s' no existe en el registro." % target_state_name)
		return
	
	var next_state: State = states[normalized_key]
	if next_state == current_state:
		return
	
	var previous_state: State = current_state
	
	if current_state != null:
		current_state.exit()
	
	current_state = next_state
	current_state.enter()
	
	state_changed.emit(previous_state, current_state)


## Devuelve el nombre del estado actual o StringName vacío si no hay ninguno activo.
func get_current_state_name() -> StringName:
	return current_state.name if current_state != null else &""


## Registra todos los nodos hijos de tipo State y conecta sus señales.
func _register_child_states() -> void:
	for child in get_children():
		if child is State:
			var state_node: State = child as State
			var key: StringName = StringName(state_node.name.to_lower())
			
			states[key] = state_node
			state_node.state_machine = self
			
			if not state_node.transitioned.is_connected(_on_state_transitioned):
				state_node.transitioned.connect(_on_state_transitioned)


## Callback receptor de la señal `transitioned` emitida por los estados.
func _on_state_transitioned(from_state: State, to_state_name: StringName) -> void:
	if from_state != current_state:
		return
	change_state(to_state_name)
