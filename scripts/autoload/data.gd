extends Node

var skills := {}
var enemies := {}
var items := {}
var synthesis: Array = []
var quests := {}
var dialogues := {}
var encounters := {}

const ALLIES := {
	"rigurumu": {"name": "Rigurimu", "sprite": "rigurumu", "level": 4, "hp": 60, "mp": 10, "atk": 12, "mag": 4, "def": 9, "res": 6, "agi": 11, "per": 8, "skills": ["rock_shot", "heal"], "desc": "Goblin leal, agora com nome e propósito."},
	"wolfo": {"name": "Lobo Alfa", "sprite": "wolf", "level": 6, "hp": 85, "mp": 0, "atk": 17, "mag": 0, "def": 10, "res": 6, "agi": 16, "per": 9, "skills": ["wind_gust"], "desc": "Alfa da matilha aliada. Caça ao seu lado."},
	"shun": {"name": "Shun", "sprite": "shun", "level": 7, "hp": 70, "mp": 60, "atk": 10, "mag": 18, "def": 8, "res": 14, "agi": 12, "per": 10, "skills": ["water_jet", "heal"], "desc": "Irmã goblin da pesquisa. Domina magia de água."},
}

func _ready() -> void:
	skills = _load_json("res://data/skills.json")
	enemies = _load_json("res://data/enemies.json")
	items = _load_json("res://data/items.json")
	synthesis = _load_json("res://data/synthesis.json")
	quests = _load_json("res://data/quests.json")
	dialogues = _load_json("res://data/dialogues.json")
	encounters = _load_json("res://data/encounters.json")
	print("[Data] carregado: %d skills, %d inimigos, %d itens" % [skills.size(), enemies.size(), items.size()])

func _load_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Falha ao carregar " + path)
		return {}
	return JSON.parse_string(text)
