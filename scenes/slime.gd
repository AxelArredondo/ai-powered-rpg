extends CharacterBody2D

# ── Follow speeds ─────────────────────────────────────────────────────────────
const STOP_DISTANCE  := 36.0   # idle zone – stop when within this radius
const NEAR_DISTANCE  := 80.0   # start accelerating past this distance
const FAR_DISTANCE   := 300.0  # reach MAX_SPEED at this distance
const BASE_SPEED     := 55.0   # normal follow speed
const MAX_SPEED      := 200.0  # catch-up speed when very far

# ── Stuck / too-far detection ─────────────────────────────────────────────────
const STUCK_CHECK_INTERVAL := 1.0   # sample position every N seconds
const STUCK_THRESHOLD      := 10.0  # must have moved at least this many pixels per sample
const STUCK_MIN_DIST       := 80.0  # only flag as stuck when farther than this
const STUCK_TRIGGER_COUNT  := 2     # consecutive stuck samples before reposition (~2 s)
const MAX_FAR_DISTANCE     := 500.0 # "too far" threshold that starts the far-timer
const MAX_FAR_TIME         := 3.0   # seconds beyond MAX_FAR_DISTANCE before forced reposition

# ── Teleport fallback ─────────────────────────────────────────────────────────
const TELEPORT_RADIUS   := 56.0  # distance from player for candidate positions
const TELEPORT_COOLDOWN := 2.5   # minimum seconds between repositions

var is_companion := false
var player: Node2D = null

# ── Internal state ────────────────────────────────────────────────────────────
var _stuck_timer                 := 0.0
var _stuck_count                 := 0
var _last_sampled_pos            := Vector2.ZERO
var _far_timer                   := 0.0
var _teleport_cooldown_remaining := 0.0

@onready var sprite:          AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

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
	_last_sampled_pos = global_position

func _physics_process(delta: float) -> void:
	if not is_companion or player == null:
		return

	var diff := player.global_position - global_position
	var dist := diff.length()

	# ── Movement with distance-based speed ────────────────────────────────────
	if dist > STOP_DISTANCE:
		var speed     := _get_speed(dist)   # smooth speed curve (see below)
		var direction := diff.normalized()
		velocity = direction * speed
		move_and_slide()
		_update_walk_animation(direction)
	else:
		velocity = Vector2.ZERO
		_transition_to_idle()

	# ── Teleport cooldown countdown ───────────────────────────────────────────
	if _teleport_cooldown_remaining > 0.0:
		_teleport_cooldown_remaining -= delta

	# ── Far-timer: accumulate time spent beyond MAX_FAR_DISTANCE ─────────────
	if dist > MAX_FAR_DISTANCE:
		_far_timer += delta
	else:
		_far_timer = 0.0

	# ── Stuck detection: compare sampled positions every STUCK_CHECK_INTERVAL ─
	_stuck_timer += delta
	if _stuck_timer >= STUCK_CHECK_INTERVAL:
		_stuck_timer = 0.0
		var moved := global_position.distance_to(_last_sampled_pos)
		# Only flag stuck when far enough that we *should* be moving
		if dist > STUCK_MIN_DIST and moved < STUCK_THRESHOLD:
			_stuck_count += 1
		else:
			_stuck_count = 0
		_last_sampled_pos = global_position

	# ── Trigger safe reposition when stuck or too far for too long ────────────
	if _teleport_cooldown_remaining <= 0.0:
		if _stuck_count >= STUCK_TRIGGER_COUNT or _far_timer >= MAX_FAR_TIME:
			_try_reposition()

# Smoothly scales speed based on distance:
#   dead zone → 0, ramp-in → BASE_SPEED, far → lerp to MAX_SPEED, beyond → MAX_SPEED
func _get_speed(dist: float) -> float:
	if dist <= STOP_DISTANCE:
		return 0.0
	elif dist <= NEAR_DISTANCE:
		var t := (dist - STOP_DISTANCE) / (NEAR_DISTANCE - STOP_DISTANCE)
		return lerpf(0.0, BASE_SPEED, t)
	elif dist <= FAR_DISTANCE:
		var t := (dist - NEAR_DISTANCE) / (FAR_DISTANCE - NEAR_DISTANCE)
		return lerpf(BASE_SPEED, MAX_SPEED, t)
	else:
		return MAX_SPEED

# Tries 8 evenly-spaced positions around the player and teleports to the first
# one that passes a physics collision check. Does nothing if all are blocked.
func _try_reposition() -> void:
	for i in range(8):
		var angle     := i * TAU / 8.0
		var candidate := player.global_position + Vector2(cos(angle), sin(angle)) * TELEPORT_RADIUS

		if _is_position_safe(candidate):
			global_position = candidate
			velocity        = Vector2.ZERO
			_stuck_count    = 0
			_far_timer      = 0.0
			_teleport_cooldown_remaining = TELEPORT_COOLDOWN
			# [OPTIONAL] Uncomment to trigger a visual effect here:
			# $TeleportParticles.restart()
			return
	# All candidates were blocked – do nothing; will retry after cooldown

# Physics check: returns true when placing the slime's shape at `pos` would
# not intersect any collidable body (uses the slime's own collision shape).
func _is_position_safe(pos: Vector2) -> bool:
	var space_state := get_world_2d().direct_space_state
	var params      := PhysicsShapeQueryParameters2D.new()
	params.shape          = collision_shape.shape
	params.transform      = Transform2D(0.0, pos)
	params.collision_mask = collision_mask   # same layers the slime blocks against
	params.exclude        = [get_rid()]      # don't collide with self
	return space_state.intersect_shape(params, 1).is_empty()

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
