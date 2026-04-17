extends Control

@onready var ai_text: RichTextLabel = $PanelContainer/VBoxContainer/RichTextLabel
@onready var text_edit: TextEdit = $PanelContainer/VBoxContainer/TextEdit

var player_near := false
var chat_open := false
var waiting_for_response := false
var active_chat: Node = null
var _active_chat_name := ""

func _ready() -> void:
	hide()
	# Push the static Blob system prompt onto the NobodyWhoChat node before
	# any say() calls so the scene-file placeholder prompt is replaced.
	var blob_node := get_node_or_null("Blob")
	if blob_node != null:
		blob_node.system_prompt = BlobDialogue.BLOB_SYSTEM_PROMPT
	set_active_chat("Blob")

# ---------------------------------------------------------------------------
# Chat management
# ---------------------------------------------------------------------------

func set_active_chat(node_name: String) -> void:
	if active_chat != null:
		if active_chat.response_updated.is_connected(_on_nobody_who_chat_response_updated):
			active_chat.response_updated.disconnect(_on_nobody_who_chat_response_updated)
		if active_chat.response_finished.is_connected(_on_nobody_who_chat_response_finished):
			active_chat.response_finished.disconnect(_on_nobody_who_chat_response_finished)
	active_chat = get_node_or_null(node_name)
	_active_chat_name = node_name
	if active_chat != null:
		active_chat.response_updated.connect(_on_nobody_who_chat_response_updated)
		active_chat.response_finished.connect(_on_nobody_who_chat_response_finished)

func set_player_near(value: bool) -> void:
	player_near = value
	if not player_near and chat_open:
		close_chat()

func open_chat() -> void:
	show()
	chat_open = true
	text_edit.editable = true
	text_edit.grab_focus()
	set_player_movement_enabled(false)
	# Record first contact with Blob
	if _active_chat_name == "Blob" and not GameState.has_flag("met_blob"):
		GameState.player["flags"].append("met_blob")
		GameState.save_state()

func close_chat() -> void:
	hide()
	chat_open = false
	waiting_for_response = false
	text_edit.text = ""
	ai_text.text = ""
	set_player_movement_enabled(true)

# ---------------------------------------------------------------------------
# Sending messages
# ---------------------------------------------------------------------------

func send_text_to_ai() -> void:
	var message := text_edit.text.strip_edges()
	if message == "":
		return

	waiting_for_response = true
	text_edit.editable = false
	ai_text.text = ""

	if active_chat != null:
		var payload := message
		if _active_chat_name == "Blob":
			GameState.player["recent_action"] = message
			payload = BlobDialogue.build_message(message)
			ai_text.text = "..."
		active_chat.say(payload)

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if chat_open:
			close_chat()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_text_newline"):
		if player_near and not chat_open:
			open_chat()
			get_viewport().set_input_as_handled()
		elif player_near and chat_open and not waiting_for_response:
			send_text_to_ai()
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# NobodyWho signals
# ---------------------------------------------------------------------------

# Blob produces raw JSON while streaming — suppress it from the UI.
# Other NPCs stream naturally.
func _on_nobody_who_chat_response_updated(new_token: String) -> void:
	if _active_chat_name != "Blob":
		ai_text.text += new_token

func _on_nobody_who_chat_response_finished(response: String) -> void:
	waiting_for_response = false
	text_edit.editable = true
	text_edit.text = ""
	text_edit.grab_focus()

	if _active_chat_name == "Blob":
		# Parse JSON, validate, apply state changes, show only spoken_response
		ai_text.text = BlobDialogue.validate_and_apply(response)
	# For other NPCs the text is already displayed via streaming

# ---------------------------------------------------------------------------
# Player movement lock
# ---------------------------------------------------------------------------

func set_player_movement_enabled(enabled: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_can_move"):
		player.set_can_move(enabled)
