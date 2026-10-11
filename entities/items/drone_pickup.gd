class_name DronePickup
extends Area2D
## Objeto recolectable en el escenario que despliega y vincula un Dron de Apoyo Orbital al Jugador.

@export var drone_scene: PackedScene = preload("res://entities/allies/support_drone.tscn")

@onready var visuals: Node2D = $Visuals
@onready var color_rect: ColorRect = $Visuals/ColorRect
@onready var name_label: Label = get_node_or_null("Visuals/NameLabel") as Label

var _time_accumulator: float = 0.0
var _collected: bool = false
var pickup_cooldown: float = 0.3


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if pickup_cooldown > 0.0:
		pickup_cooldown = maxf(0.0, pickup_cooldown - delta)
		if pickup_cooldown <= 0.0:
			for body in get_overlapping_bodies():
				if body is Player:
					_on_body_entered(body)
					break
	
	# Flotación vertical oscilatoria (bobbing)
	_time_accumulator += delta * 4.0
	if visuals != null:
		visuals.position.y = sin(_time_accumulator) * 4.0


func _on_body_entered(body: Node2D) -> void:
	if _collected or pickup_cooldown > 0.0:
		return
	
	if body is Player:
		_collected = true
		var player: Player = body as Player
		
		if drone_scene != null:
			var drone_instance: Node = drone_scene.instantiate()
			if drone_instance is SupportDrone:
				var drone: SupportDrone = drone_instance as SupportDrone
				drone.target_player = player
				drone.global_position = player.global_position + Vector2(-25.0, -35.0)
				
				var container: Node = get_tree().current_scene
				if container == null:
					container = owner if owner != null else get_parent()
				if container == null:
					container = get_tree().root
				
				container.add_child(drone)
				print("[DronePickup] ¡Módulo de Dron activado! Dron orbital desplegado y vinculado al Jugador.")
		
		GameFeel.sfx(self, &"pickup_gear", Vector2.INF, -3.0)
		# Animación de recogida
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 0.0, 0.15)
		tw.finished.connect(queue_free)
