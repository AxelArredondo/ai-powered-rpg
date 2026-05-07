extends Node
# Autoload singleton. Owns all persistent game state and is the ONLY code
# allowed to write save files. The AI returns deltas; this code applies them
# after validation, so the model can never freely overwrite saves.

const SAVE_PATH := "user://save_state.json"
const STATE_VERSION := 1

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
	"met_farmer2",
	"met_princess2",
	"met_villager",
	"met_skeleton",
	"farmer_gave_info",
	"princess_told_about_blob",
	"princess_knows_mr_henry",
	"villager_gave_rumor",
	"skeleton_released_mr_henry",
]

const ALLOWED_QUEST_STATES: Array[String] = [
	"none",
	"seeking_mr_henry",
	"found_mr_henry_alive",
	"found_mr_henry_dead",
	"skeleton_quest_active",
	"quest_completed",
]

const ALLOWED_FARMER_QUEST_STATES: Array[String] = [
	"none", "offered_info", "player_helped", "quest_complete",
]

const ALLOWED_PRINCESS_QUEST_STATES: Array[String] = [
	"none", "searching_for_blob", "player_told_about_blob", "reunited", "told_about_mr_henry",
]

const ALLOWED_VILLAGER_QUEST_STATES: Array[String] = [
	"none", "shared_rumor", "directed_to_ruins", "directed_to_castle",
]

const ALLOWED_SKELETON_QUEST_STATES: Array[String] = [
	"none", "hostile_standoff", "negotiating", "mr_henry_freed",
]

const MAX_OPINION_LENGTH := 150
const MAX_MEMORY_LENGTH  := 120
const MAX_MEMORIES       := 10

var player := {
	"version": STATE_VERSION,
	"inventory": [],
	"location": "starting_area",
	"reputation": 0.0,
	"quest_progress": {},
	"flags": [],
	"recent_action": "",
}

var blob := {
	"version": STATE_VERSION,
	"npc_id": "blob",
	"alive": true,
	"relationship": 0.0,
	"trust": 0.0,
	"opinion": "A stranger I just met.",
	"memories": [],
	"quest_involvement": "none",
}

var farmer2 := {
	"version": STATE_VERSION,
	"npc_id": "farmer2",
	"alive": true,
	"relationship": 0.0,
	"trust": 0.0,
	"opinion": "A stranger who wandered onto my property.",
	"memories": [],
	"quest_involvement": "none",
}

var princess2 := {
	"version": STATE_VERSION,
	"npc_id": "princess2",
	"alive": true,
	"relationship": 0.0,
	"trust": 0.0,
	"opinion": "A traveler I have not yet met.",
	"memories": [],
	"quest_involvement": "none",
}

var villager := {
	"version": STATE_VERSION,
	"npc_id": "villager",
	"alive": true,
	"relationship": 0.0,
	"trust": 0.0,
	"opinion": "A newcomer to the village.",
	"memories": [],
	"quest_involvement": "none",
}

var skeleton := {
	"version": STATE_VERSION,
	"npc_id": "skeleton",
	"alive": true,
	"relationship": -0.5,
	"trust": 0.0,
	"opinion": "An intruder who must be stopped.",
	"memories": [],
	"quest_involvement": "none",
}

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

	farmer2["alive"] = true
	farmer2["relationship"] = 0.0
	farmer2["trust"] = 0.0
	farmer2["opinion"] = "A stranger who wandered onto my property."
	farmer2["memories"] = []
	farmer2["quest_involvement"] = "none"

	princess2["alive"] = true
	princess2["relationship"] = 0.0
	princess2["trust"] = 0.0
	princess2["opinion"] = "A traveler I have not yet met."
	princess2["memories"] = []
	princess2["quest_involvement"] = "none"

	villager["alive"] = true
	villager["relationship"] = 0.0
	villager["trust"] = 0.0
	villager["opinion"] = "A newcomer to the village."
	villager["memories"] = []
	villager["quest_involvement"] = "none"

	skeleton["alive"] = true
	skeleton["relationship"] = -0.5
	skeleton["trust"] = 0.0
	skeleton["opinion"] = "An intruder who must be stopped."
	skeleton["memories"] = []
	skeleton["quest_involvement"] = "none"

	world["active_quests"] = []
	world["completed_quests"] = []
	world["global_flags"] = []
	save_state()

func load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_state()
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
		_sanitize_npc(blob)
	if parsed.has("farmer2"):
		_merge_into(farmer2, parsed["farmer2"])
		_sanitize_npc(farmer2)
	if parsed.has("princess2"):
		_merge_into(princess2, parsed["princess2"])
		_sanitize_npc(princess2)
	if parsed.has("villager"):
		_merge_into(villager, parsed["villager"])
		_sanitize_npc(villager)
	if parsed.has("skeleton"):
		_merge_into(skeleton, parsed["skeleton"])
		_sanitize_npc(skeleton)
	if parsed.has("world"):
		_merge_into(world, parsed["world"])

func save_state() -> void:
	var data := {
		"player": player,
		"blob": blob,
		"farmer2": farmer2,
		"princess2": princess2,
		"villager": villager,
		"skeleton": skeleton,
		"world": world,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameState: Could not write save file.")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func _merge_into(dst: Dictionary, src: Dictionary) -> void:
	for key in src:
		if dst.has(key):
			dst[key] = src[key]

func apply_blob_changes(changes: Dictionary) -> void:
	var rel_delta := clampf(float(changes.get("relationship_delta", 0.0)), -0.15, 0.15)
	blob["relationship"] = clampf(blob["relationship"] + rel_delta, -1.0, 1.0)

	var trust_delta := clampf(float(changes.get("trust_delta", 0.0)), -0.15, 0.15)
	blob["trust"] = clampf(blob["trust"] + trust_delta, 0.0, 1.0)

	var opinion := str(changes.get("opinion_update", "")).strip_edges().left(MAX_OPINION_LENGTH)
	opinion = opinion.replace("[", "").replace("]", "")
	if opinion != "":
		blob["opinion"] = opinion

	var new_mems = changes.get("memories_to_add", [])
	if new_mems is Array:
		for m in new_mems:
			var ms := str(m).strip_edges().left(MAX_MEMORY_LENGTH)
			ms = ms.replace("[", "").replace("]", "")
			if ms != "" and not (ms in blob["memories"]):
				blob["memories"].append(ms)
		while blob["memories"].size() > MAX_MEMORIES:
			blob["memories"].pop_front()

	var new_flags = changes.get("flags_to_set", [])
	if new_flags is Array:
		for f in new_flags:
			var fs := str(f).strip_edges()
			if fs in ALLOWED_FLAGS:
				if not (fs in player["flags"]):
					player["flags"].append(fs)
				if not (fs in world["global_flags"]):
					world["global_flags"].append(fs)

	var quest := str(changes.get("quest_update", "")).strip_edges()
	if quest != "" and quest in ALLOWED_QUEST_STATES:
		blob["quest_involvement"] = quest

	save_state()

func apply_npc_changes(npc_id: String, changes: Dictionary) -> void:
	var npc: Dictionary
	var allowed_quest_states: Array[String]

	match npc_id:
		"farmer2":
			npc = farmer2
			allowed_quest_states = ALLOWED_FARMER_QUEST_STATES
		"princess2":
			npc = princess2
			allowed_quest_states = ALLOWED_PRINCESS_QUEST_STATES
		"villager":
			npc = villager
			allowed_quest_states = ALLOWED_VILLAGER_QUEST_STATES
		"skeleton":
			npc = skeleton
			allowed_quest_states = ALLOWED_SKELETON_QUEST_STATES
		_:
			push_warning("GameState.apply_npc_changes: unknown npc_id '%s'" % npc_id)
			return

	var rel_delta := clampf(float(changes.get("relationship_delta", 0.0)), -0.15, 0.15)
	npc["relationship"] = clampf(npc["relationship"] + rel_delta, -1.0, 1.0)

	var trust_delta := clampf(float(changes.get("trust_delta", 0.0)), -0.15, 0.15)
	npc["trust"] = clampf(npc["trust"] + trust_delta, 0.0, 1.0)

	var opinion := str(changes.get("opinion_update", "")).strip_edges().left(MAX_OPINION_LENGTH)
	opinion = opinion.replace("[", "").replace("]", "")
	if opinion != "":
		npc["opinion"] = opinion

	var new_mems = changes.get("memories_to_add", [])
	if new_mems is Array:
		for m in new_mems:
			var ms := str(m).strip_edges().left(MAX_MEMORY_LENGTH)
			ms = ms.replace("[", "").replace("]", "")
			if ms != "" and not (ms in npc["memories"]):
				npc["memories"].append(ms)
		while npc["memories"].size() > MAX_MEMORIES:
			npc["memories"].pop_front()

	var new_flags = changes.get("flags_to_set", [])
	if new_flags is Array:
		for f in new_flags:
			var fs := str(f).strip_edges()
			if fs in ALLOWED_FLAGS:
				if not (fs in player["flags"]):
					player["flags"].append(fs)
				if not (fs in world["global_flags"]):
					world["global_flags"].append(fs)

	var quest := str(changes.get("quest_update", "")).strip_edges()
	if quest != "" and quest in allowed_quest_states:
		npc["quest_involvement"] = quest

	save_state()

func _sanitize_npc(npc: Dictionary) -> void:
	if not (npc.get("relationship") is float or npc.get("relationship") is int):
		npc["relationship"] = 0.0
	npc["relationship"] = clampf(float(npc["relationship"]), -1.0, 1.0)

	if not (npc.get("trust") is float or npc.get("trust") is int):
		npc["trust"] = 0.0
	npc["trust"] = clampf(float(npc["trust"]), 0.0, 1.0)

	if not (npc.get("opinion") is String):
		npc["opinion"] = ""
	else:
		var op: String = npc["opinion"]
		npc["opinion"] = op.replace("[", "").replace("]", "").left(MAX_OPINION_LENGTH)

	if not (npc.get("memories") is Array):
		npc["memories"] = []
	else:
		var clean: Array = []
		for m in npc["memories"]:
			if m is String:
				var ms: String = (m as String).strip_edges().replace("[", "").replace("]", "").left(MAX_MEMORY_LENGTH)
				if ms != "":
					clean.append(ms)
		while clean.size() > MAX_MEMORIES:
			clean.pop_front()
		npc["memories"] = clean

func has_flag(flag: String) -> bool:
	return (flag in player["flags"]) or (flag in world["global_flags"])

func is_hatred_active() -> bool:
	return blob["relationship"] <= -0.7

func is_grief_active() -> bool:
	return has_flag("mr_henry_dead") and has_flag("blob_learned_truth")

func get_memories_string() -> String:
	var mems: Array = blob.get("memories", [])
	return "none" if mems.is_empty() else ", ".join(mems)

func get_player_flags_string() -> String:
	var flags: Array = player.get("flags", [])
	return "none" if flags.is_empty() else ", ".join(flags)
