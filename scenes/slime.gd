extends CharacterBody2D

func _ready() -> void:
	$AnimatedSprite2D.play("walking-front")

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
			
