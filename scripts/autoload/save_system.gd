extends Node

const SAVE_PATH := "user://save1.json"
const VERSION := 1

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var payload := {
		"version": VERSION,
		"p": GameState.p,
		"skills": GameState.skills,
		"allies": GameState.allies,
		"materials": GameState.materials,
		"consumables": GameState.consumables,
		"gold": GameState.gold,
		"analyzed": GameState.analyzed,
		"bestiary": GameState.bestiary,
		"flags": GameState.flags,
		"quests": GameState.quests,
		"resources": GameState.resources,
		"services": GameState.services,
		"synth_done": GameState.synth_done,
		"map_id": GameState.map_id,
		"pos": GameState.pos,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload))
		print("[Save] salvo em ", SAVE_PATH)

func load_game() -> bool:
	if not has_save():
		return false
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var d: Variant = JSON.parse_string(text)
	if typeof(d) != TYPE_DICTIONARY:
		return false
	GameState.p = d.get("p", {})
	GameState.skills = d.get("skills", [])
	GameState.allies = d.get("allies", [])
	GameState.materials = d.get("materials", {})
	GameState.consumables = d.get("consumables", {})
	GameState.gold = int(d.get("gold", 0))
	GameState.analyzed = d.get("analyzed", {})
	GameState.bestiary = d.get("bestiary", [])
	GameState.flags = d.get("flags", {})
	GameState.quests = d.get("quests", {})
	GameState.resources = d.get("resources", {"food": 5, "material": 5, "population": 5})
	GameState.services = d.get("services", [])
	GameState.synth_done = d.get("synth_done", [])
	GameState.map_id = d.get("map_id", "cave")
	GameState.pos = d.get("pos", {"x": 10, "y": 9})
	GameState.changed.emit()
	return true
