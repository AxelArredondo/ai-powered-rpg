extends Node

# ─── Position (existing) ───────────────────────────────────────────────────
var position = 0

# ─── Reputation ────────────────────────────────────────────────────────────
# Global reputation: -1.0 (villain) to 1.0 (hero)
var reputation: float = 0.0

# Per-faction reputation, keyed by faction identifier
var faction_reputation: Dictionary = {
	"village": 0.0,
	"forest_spirits": 0.0,
	"hunters_guild": 0.0
}

# ─── NPC Attitude Cache ────────────────────────────────────────────────────
# Stores each NPC's current attitude toward the player
# attitude range: -1.0 (hostile) to 1.0 (friendly)
var npc_attitudes: Dictionary = {}

# ─── Modify Reputation ─────────────────────────────────────────────────────
# Call this whenever the player does something that affects reputation.
# faction is optional — pass "" to only affect global reputation.
func modify_reputation(amount: float, faction: String = "") -> void:
	# Update global reputation and clamp to [-1.0, 1.0]
	reputation = clamp(reputation + amount, -1.0, 1.0)

	# Update faction reputation if a valid faction was given
	if faction != "" and faction_reputation.has(faction):
		faction_reputation[faction] = clamp(faction_reputation[faction] + amount, -1.0, 1.0)

	# Build log message: always show global, only show faction if it is known
	var log_message := "[Global] Reputation updated → global: %.2f" % reputation

	if faction != "":
		if faction_reputation.has(faction):
			log_message += " | faction '%s': %.2f" % [faction, faction_reputation[faction]]
		else:
			push_warning("[Global] modify_reputation called with unknown faction '%s'; only global reputation was updated." % faction)

	print_debug(log_message)

# ─── Modify NPC Attitude ───────────────────────────────────────────────────
# Call this after a conversation or event to update how an NPC feels.
# npc_id should be the NPC's stable identifier used throughout the game (e.g. "blacksmith_01").
func modify_attitude(npc_id: String, amount: float) -> void:
	if not npc_attitudes.has(npc_id):
		npc_attitudes[npc_id] = 0.0

	npc_attitudes[npc_id] = clamp(npc_attitudes[npc_id] + amount, -1.0, 1.0)

	print_debug("[Global] Attitude updated → NPC '%s': %.2f" % [
		npc_id,
		npc_attitudes[npc_id]
	])

# ─── Helper: Get NPC Attitude ──────────────────────────────────────────────
# Returns current attitude for an NPC (defaults to 0.0 if never set).
func get_attitude(npc_id: String) -> float:
	return npc_attitudes.get(npc_id, 0.0)
