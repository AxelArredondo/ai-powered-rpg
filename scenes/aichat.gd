extends Control

@onready var ai_text: RichTextLabel = $PanelContainer/VBoxContainer/RichTextLabel
@onready var text_edit: TextEdit = $PanelContainer/VBoxContainer/TextEdit

var player_near := false
var chat_open := false
var waiting_for_response := false
var active_chat: Node = null
var _active_chat_name := ""
var _system_prompts: Dictionary = {}
var _first_turn_injected: Dictionary = {}
var _worker_started: Dictionary = {}

# Maps NobodyWhoChat node name → npc_id used by NpcDialogue / GameState.
const NPC_ID_MAP := {
	"Farmer2":  "farmer2",
	"Princess2": "princess2",
	"Villager": "villager",
	"Skeleton": "skeleton",
}

# Maps node name → the met_X flag written on first contact.
const MET_FLAG_MAP := {
	"Blob":      "met_blob",
	"Farmer2":   "met_farmer2",
	"Princess2": "met_princess2",
	"Villager":  "met_villager",
	"Skeleton":  "met_skeleton",
}

func _ready() -> void:
	hide()
	# Gemma has no system role in its chat template — NobodyWho would just
	# concatenate system_prompt into the first user turn, confusing the model.
	# We capture each node's system_prompt, clear it, then prepend it manually
	# to the first user message sent to that node.
	for child in get_children():
		if child.get_class() == "NobodyWhoChat":
			var prompt: String
			if child.name == "Blob":
				prompt = BlobDialogue.BLOB_SYSTEM_PROMPT
			elif NPC_ID_MAP.has(child.name):
				prompt = NpcDialogue.get_system_prompt(NPC_ID_MAP[child.name])
			else:
				prompt = child.system_prompt
			_system_prompts[child.name] = prompt
			_first_turn_injected[child.name] = false
			child.system_prompt = ""
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
		if not _worker_started.get(node_name, false):
			active_chat.start_worker()
			_worker_started[node_name] = true
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

	var met_flag: String = MET_FLAG_MAP.get(_active_chat_name, "")
	if met_flag != "" and not GameState.has_flag(met_flag):
		GameState.player["flags"].append(met_flag)
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
	ai_text.text = "..."

	if active_chat != null:
		GameState.player["recent_action"] = message
		var payload := message

		if _active_chat_name == "Blob":
			payload = BlobDialogue.build_message(message)
		elif NPC_ID_MAP.has(_active_chat_name):
			payload = NpcDialogue.build_message(NPC_ID_MAP[_active_chat_name], message)

		if not _first_turn_injected.get(_active_chat_name, true):
			var sys: String = _system_prompts.get(_active_chat_name, "")
			if sys != "":
				payload = sys + "\n\n" + payload
			_first_turn_injected[_active_chat_name] = true

		active_chat.ask(payload)

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

# All NPCs return JSON — suppress streaming tokens and show "..." until done.
func _on_nobody_who_chat_response_updated(_new_token: String) -> void:
	pass

func _on_nobody_who_chat_response_finished(response: String) -> void:
	waiting_for_response = false
	text_edit.editable = true
	text_edit.text = ""
	text_edit.grab_focus()

	if _active_chat_name == "Blob":
		ai_text.text = BlobDialogue.validate_and_apply(response)
	elif NPC_ID_MAP.has(_active_chat_name):
		ai_text.text = NpcDialogue.validate_and_apply(NPC_ID_MAP[_active_chat_name], response)
	else:
		ai_text.text = response.strip_edges()
	_debug_print_state()

func _debug_print_state() -> void:
	var gs := GameState
	var npc: Dictionary
	if _active_chat_name == "Blob":
		npc = gs.blob
	elif NPC_ID_MAP.has(_active_chat_name):
		npc = gs.get(NPC_ID_MAP[_active_chat_name])
	else:
		return
	print("[DEBUG %s] rel=%.2f  trust=%.2f  quest=%s  flags=%s" % [
		_active_chat_name,
		npc.get("relationship", 0.0),
		npc.get("trust", 0.0),
		npc.get("quest_involvement", "none"),
		str(gs.player.get("flags", [])),
	])

# ---------------------------------------------------------------------------
# Player movement lock
# ---------------------------------------------------------------------------

func set_player_movement_enabled(enabled: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_can_move"):
		player.set_can_move(enabled)
