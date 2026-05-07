extends CharacterBody2D

@onready var path2d: Path2D =$Path2D
@onready var path_follow: PathFollow2D = $Path2D/PathFollow2D

@export var move_speed: float = 10	
@export var loop_path: bool = true

var	 last_position: Vector2

func _ready() -> void:
	position = path_follow.global_position
	last_position = position
	
func _physics_process(delta: float) -> void:
	path_follow.progress += move_speed * delta
