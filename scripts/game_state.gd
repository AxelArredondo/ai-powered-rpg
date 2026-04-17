extends Node
# Autoload singleton. Owns all persistent game state and is the ONLY code
# allowed to write save files. The AI returns deltas; this code applies them
# after validation, so the model can never freely overwrite saves.

const SAVE_PATH := "user://save_state.json"
const STATE_VERSION := 1

# Approved flag names. The AI may only set flags from this list.
const ALLOWED_FLAGS: Array[String] = [
	"met_blob",
	"accepted_blob_quest",
	"blob_helping_player",
	"found_mr_henry",
	"mr_henry_dead",
	"skeleton_defeated",
	"skeleton_redeemed",
	"skeleton_stopped",
	"blob_learned_truth",
]

# Approved quest states for blob.quest_involvement.
const ALLOWED_QUEST_STATES: Array[String] = [
	"none",
	"seeking_mr_henry",
	"found_mr_henry_alive",
	"found_mr_henry_dead",
	"skeleton_quest_active",
	"quest_completed",
]

# ---- Player state ----
var player := {
	"version": STATE_VERSION,
	"inventory": [],
	"location": "starting_area",
	"reputation": 0.0,
	"quest_progress": {},
	"flags": [],
	"recent_action": "",
}

# ---- Blob NPC state ----
var blob := {
	"version": STATE_VERSION,
	"npc_id": "blob",
	"alive": true,
	"relationship": 0.0,   # -1.0 (hate) to 1.0 (love)
	"trust": 0.0,           # 0.0 (no trust) to 1.0 (full trust)
	"opinion": "A stranger I just met.",
	"memories": [],         # capped at 10 short strings
	"quest_involvement": "none",
}

# ---- World / quest state ----
var world := {
	"version": STATE_VERSION,
	"active_quests": [],
	"completed_quests": [],
	"global_flags": [],
}

func _ready() -> void:
	reset_to_defaults()

func reset_to_defaults() -> void:
	player["inventory"] = []
	player["location"] = "starting_area"
	player["reputation"] = 0.0
	player["quest_progress"] = {}
	player["flags"] = []
	player["recent_action"] = ""
	blob["alive"] = true
	blob["relationship"] = 0.0
	blob["trust"] = 0.0
	blob["opinion"] = "A stranger I just met."
	blob["memories"] = []
	blob["quest_involvement"] = "none"
	world["active_quests"] = []
	world["completed_quests"] = []
	world["global_flags"] = []
	save_state()

# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_state()  # Create default save on first run
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("GameState: Could not open save file. Using defaults.")
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("GameState: Save file is malformed. Using defaults.")
		return
	if parsed.has("player"):
		_merge_into(player, parsed["player"])
	if parsed.has("blob"):
		_merge_into(blob, parsed["blob"])
	if parsed.has("world"):
		_merge_into(world, parsed["world"])

func save_state() -> void:
	var data := {"player": player, "blob": blob, "world": world}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameState: Could not write save file.")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

# Merges known keys from src into dst. Unknown keys are ignored so old
# save files never crash on schema changes.
func _merge_into(dst: Dictionary, src: Dictionary) -> void:
	for key in src:
		if dst.has(key):
			dst[key] = src[key]

# ---------------------------------------------------------------------------
# Validated state application (called by BlobDialogue after parsing AI output)
# ---------------------------------------------------------------------------

func apply_blob_changes(changes: Dictionary) -> void:
	# relationship_delta: clamped per-turn and to total range
	var rel_delta := clampf(float(changes.get("relationship_delta", 0.0)), -0.15, 0.15)
	blob["relationship"] = clampf(blob["relationship"] + rel_delta, -1.0, 1.0)

	# trust_delta: clamped per-turn and to total range
	var trust_delta := clampf(float(changes.get("trust_delta", 0.0)), -0.15, 0.15)
	blob["trust"] = clampf(blob["trust"] + trust_delta, 0.0, 1.0)

	# opinion_update: non-empty string only
	var opinion := str(changes.get("opinion_update", "")).strip_edges()
	if opinion != "":
		blob["opinion"] = opinion

	# memories_to_add: deduplicated, capped at 10
	var new_mems = changes.get("memories_to_add", [])
	if new_mems is Array:
		for m in new_mems:
			var ms := str(m).strip_edges()
			if ms != "" and not (ms in blob["memories"]):
				blob["memories"].append(ms)
		while blob["memories"].size() > 10:
			blob["memories"].pop_front()

	# flags_to_set: only approved flags, written to both player and world
	var new_flags = changes.get("flags_to_set", [])
	if new_flags is Array:
		for f in new_flags:
			var fs := str(f).strip_edges()
			if fs in ALLOWED_FLAGS:
				if not (fs in player["flags"]):
					player["flags"].append(fs)
				if not (fs in world["global_flags"]):
					world["global_flags"].append(fs)

	# quest_update: only approved quest states
	var quest := str(changes.get("quest_update", "")).strip_edges()
	if quest != "" and quest in ALLOWED_QUEST_STATES:
		blob["quest_involvement"] = quest

	save_state()

# ---------------------------------------------------------------------------
# Query helpers used by BlobDialogue and aichat
# ---------------------------------------------------------------------------

func has_flag(flag: String) -> bool:
	return (flag in player["flags"]) or (flag in world["global_flags"])

# Hatred threshold: deeply negative relationship
func is_hatred_active() -> bool:
	return blob["relationship"] <= -0.7

# Grief threshold: Blob only grieves when he knows Mr Henry is dead
func is_grief_active() -> bool:
	return has_flag("mr_henry_dead") and has_flag("blob_learned_truth")

func get_memories_string() -> String:
	var mems: Array = blob.get("memories", [])
	return "none" if mems.is_empty() else ", ".join(mems)

func get_player_flags_string() -> String:
	var flags: Array = player.get("flags", [])
	return "none" if flags.is_empty() else ", ".join(flags)
