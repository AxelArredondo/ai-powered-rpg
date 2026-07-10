# AI-Powered RPG

A 2D pixel-art RPG built in Godot where non-player characters hold real-time conversations powered by a locally-run large language model, instead of scripted dialogue trees.

## About

This project explores what happens when NPCs are no longer limited to pre-written dialogue. Each character in the game is backed by a local LLM that generates its responses on the fly, in character, based on the current state of the game world.

Rather than relying on branching dialogue trees, every conversation is generated live. The model is given the NPC's personality, its relationship with the player, and relevant world knowledge, then produces a response along with a set of proposed changes to the game state — such as shifts in trust or new memories. Those changes are validated before being applied, so the world stays consistent even though the dialogue itself is generated dynamically.

The result is a small RPG where talking to a character feels less like selecting dialogue options and more like an actual conversation, while the underlying game logic remains fully deterministic and save-safe.

## Gameplay

The player explores a small top-down world divided into distinct areas — a village, a farm, a castle, and a set of ruins — connected by directional transitions.

Walking up to an NPC and starting a conversation is the core interaction. What the player says, and how a conversation unfolds, can shift an NPC's trust and opinion of the player, unlock new dialogue context, and move quest-related flags forward. These effects persist between sessions, so earlier conversations continue to shape how NPCs react later in the game.

## Features

### Gameplay Features

- Top-down exploration across multiple connected areas (village, farm, castle, ruins)
- Real-time, freeform conversations with multiple distinct NPCs, each with their own personality and knowledge of the world
- A companion slime that begins following the player after their first conversation with it
- NPC relationships (trust and opinion) that evolve based on conversation and persist across play sessions
- Quest progress tracked per NPC and reflected in how they speak to the player
- Pause menu and main menu flow

### Technical Highlights

- Local LLM inference running entirely on-device, with no external API calls
- Per-NPC persistent memory, opinion, trust, and relationship values
- Structured JSON output from the model, parsed and validated before use
- A validation layer that constrains AI-proposed state changes to an explicit allow-list of flags and quest states
- A single authoritative game-state system that is the only code permitted to write save data
- Scene-based architecture with autoload singletons for game state and dialogue logic

## How the AI Dialogue Works

Every conversation follows the same pipeline, regardless of which NPC the player is talking to:

1. **Player input** — the player walks up to an NPC and types a message in the dialogue box.
2. **Prompt construction** — the NPC's system prompt (personality, voice, world knowledge) is combined with a compact snapshot of the current game state: relationship, trust, opinion, memories, quest progress, and relevant player flags.
3. **Local model inference** — the combined prompt is sent to a local LLM running through the NobodyWho GDExtension. No data leaves the machine.
4. **Structured output** — the model is instructed to reply with a fixed JSON shape containing both the spoken response and a proposed set of state changes.
5. **Validation layer** — the raw JSON is parsed defensively. Unknown fields are discarded, numeric deltas are clamped to safe ranges, and flags or quest states are checked against an explicit allow-list before anything is accepted.
6. **Persistent game state updates** — only validated changes are applied to the NPC's relationship, trust, opinion, memories, and quest progress, after which the game state is saved to disk.

Because validation happens outside the model, the AI can be creative in how it speaks without ever being able to corrupt the save file or set state that the game doesn't recognize.

## Technical Challenges

- **Running inference entirely locally.** The game loads a GGUF model through a native GDExtension and runs inference on-device, with no network dependency at runtime.
- **Keeping AI output structured and safe.** Language models don't reliably produce valid JSON. The dialogue pipeline strips code fences, locates the JSON payload defensively, and falls back to an in-character response if parsing fails.
- **Preventing invalid game state.** Because the model proposes state changes as free-form output, every proposed change is validated against allow-lists and numeric clamps before it can touch the actual game state.
- **Giving each NPC a consistent voice and world knowledge.** Every NPC has its own system prompt defining tone, known locations, and awareness of other characters, so conversations stay internally consistent with the wider story.
- **Making persistent memory usable in a short prompt.** NPC memories and opinions are summarized into a compact state block on every message, so the model has continuity without needing the full conversation history.

## Architecture Overview

Dialogue pipeline:

```
Player
  |
  v
Dialogue System (proximity trigger + chat UI)
  |
  v
Prompt Construction (system prompt + game state snapshot)
  |
  v
Local LLM (NobodyWho / GGUF model)
  |
  v
Structured JSON Output
  |
  v
Validation Layer (allow-lists, clamps, sanitization)
  |
  v
Persistent Game State (autoload singleton)
  |
  v
NPC Memory / Save File
```

Overall structure:

```
World Scene
  |
  +-- Player (movement, camera, dialogue trigger)
  |
  +-- NPCs (Blob, Farmer, Princess, Villager, Skeleton)
  |     each backed by a NobodyWhoChat node
  |
  +-- Autoloads
        +-- GameState     (save data, validation entry points)
        +-- BlobDialogue  (Blob prompt + validation)
        +-- NpcDialogue   (shared prompt + validation for other NPCs)
        +-- Global        (screen/area tracking)
```

## Tech Stack

- **Engine:** Godot 4.6
- **Language:** GDScript
- **AI runtime:** NobodyWho GDExtension (local LLM inference)
- **Model format:** GGUF (quantized language models)
- **Architecture:** Autoload singletons for game state and dialogue logic, scene-based NPCs and world areas

## Project Structure

```
scenes/     Game scenes and their scripts (world, player, NPCs, dialogue UI, menus)
scripts/    Autoload singletons and shared logic (game state, dialogue pipelines, movement, area transitions)
addons/     NobodyWho GDExtension (local LLM inference addon)
assets/     Sprites, tilesets, backgrounds, and other visual assets
fonts/      Game UI font
music/      Background music
```

## Requirements

To run this project locally you will need:

- Godot 4.6
- The NobodyWho GDExtension addon (not bundled in this repository — it must be installed into `addons/nobodywho/`)
- A local GGUF language model compatible with NobodyWho, placed in the project root and referenced by the dialogue scenes
- A machine capable of running local LLM inference at a reasonable speed; performance will vary significantly depending on CPU/GPU and the chosen model size

## Future Improvements

- Additional NPCs and areas to expand the world
- Expanded quest content built on the existing flag and quest-state system
- Further tuning of prompt design and response validation for more consistent AI behavior
- Performance improvements for local inference on lower-end hardware
