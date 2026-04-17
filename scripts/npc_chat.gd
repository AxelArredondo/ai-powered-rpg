extends Node

@export var chat_node_name: String = "Blob"

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var dialogue_ui = get_tree().get_first_node_in_group("dialogue_ui")
		if dialogue_ui != null:
			dialogue_ui.set_active_chat(chat_node_name)
			dialogue_ui.set_player_near(true)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		var dialogue_ui = get_tree().get_first_node_in_group("dialogue_ui")
		if dialogue_ui != null:
			dialogue_ui.set_player_near(false)
