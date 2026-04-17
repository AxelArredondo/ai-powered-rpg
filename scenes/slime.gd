extends CharacterBody2D

const FOLLOW_SPEED := 55.0
const STOP_DISTANCE := 36.0

var is_companion := false
var player: Node2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	sprite.play("idle-front")
	call_deferred("_connect_to_blob")

func _connect_to_blob() -> void:
	var blob = get_node_or_null("../Player/AIChat/Blob")
	if blob and blob.has_signal("response_finished"):
		blob.response_finished.connect(_on_first_conversation, CONNECT_ONE_SHOT)

func _on_first_conversation(_response: String) -> void:
	is_companion = true
	player = get_tree().get_first_node_in_group("player")

func _physics_process(_delta: float) -> void:
	if not is_companion or player == null:
		return

	var diff := player.global_position - global_position
	var dist := diff.length()

	if dist > STOP_DISTANCE:
		var direction := diff.normalized()
		velocity = direction * FOLLOW_SPEED
		move_and_slide()
		_update_walk_animation(direction)
	else:
		velocity = Vector2.ZERO
		_transition_to_idle()

func _update_walk_animation(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		sprite.flip_h = dir.x < 0
		sprite.play("walking-side")
	elif dir.y < 0:
		sprite.flip_h = false
		sprite.play("walking-back")
	else:
		sprite.flip_h = false
		sprite.play("walking-front")

func _transition_to_idle() -> void:
	match sprite.animation:
		"walking-front": sprite.play("idle-front")
		"walking-back":  sprite.play("idle-back")
		"walking-side":  sprite.play("idle-side")

func _on_area_2d_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		var dialogue_ui = get_tree().get_first_node_in_group("dialogue_ui")
		if dialogue_ui != null:
			dialogue_ui.set_player_near(true)

func _on_area_2d_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		var dialogue_ui = get_tree().get_first_node_in_group("dialogue_ui")
		if dialogue_ui != null:
			dialogue_ui.set_player_near(false)
