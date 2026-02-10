extends Area2D

# Distance teleported
@export var screen_height: int = 256

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		# Stop immediate re-trigger
		monitoring = false
		
		# Teleport UP (negative Y)
		body.global_position += Vector2(0, screen_height)
		
		# Snap to pixel grid (optional but good for 8-bit)
		body.global_position = body.global_position.round()
		
		# Re-enable after physics frame
		await get_tree().physics_frame
		monitoring = true
