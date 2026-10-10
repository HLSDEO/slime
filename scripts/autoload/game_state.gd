extends Node

signal changed

var p := {}          # Rimuru stats
var skills := []     # ids de habilidades do jogador
var allies := []     # ids de aliados recrutados
var materials := {}  # id -> qty
var consumables := {}
var gold := 0
var analyzed := {}   # enemy_id -> 0.0..1.0
var bestiary := []   # enemy ids vistos
var flags := {}
var quests := {}     # quest_id -> "active" | "done"
var resources := {"food": 5, "material": 5, "population": 5}
var services := []   # blacksmith/kitchen/lab
var synth_done := []
var map_id := "cave"
var pos := {"x": 10, "y": 9}
var step_since_battle := 0.0

func start_new_game() -> void:
	p = {"hp": 60, "max_hp": 60, "mp": 30, "max_mp": 30, "atk": 10, "mag": 8, "def": 6, "res": 6, "agi": 9, "per": 8, "level": 1, "xp": 0}
	skills = []
	allies = []
	materials = {}
	consumables = {"potion_s": 3}
	gold = 20
	analyzed = {}
	bestiary = []
	flags = {}
	quests = {}
	resources = {"food": 5, "material": 5, "population": 5}
	services = []
	synth_done = []
	map_id = "cave"
	pos = {"x": 10, "y": 9}
	step_since_battle = 0.0
	changed.emit()

func has_skill(id: String) -> bool:
	return id in skills

func add_skill(id: String) -> String:
	if id in skills:
		gain_xp(12)
		return "dupe"
	skills.append(id)
	changed.emit()
	return "new"

func active_skills() -> Array:
	var out := []
	for s in skills:
		if Data.skills.get(s, {}).get("type", "") in ["active"]:
			out.append(s)
	return out

func passive_skills() -> Array:
	var out := []
	for s in skills:
		if Data.skills.get(s, {}).get("type", "") == "passive":
			out.append(s)
	return out

func heal_full() -> void:
	p.hp = p.max_hp
	p.mp = p.max_mp
	changed.emit()

func xp_needed() -> int:
	return 20 + p.level * p.level * 10

func gain_xp(amount: int) -> void:
	p.xp += amount
	while p.xp >= xp_needed():
		p.xp -= xp_needed()
		p.level += 1
		p.max_hp += 12
		p.max_mp += 6
		p.atk += 2
		p.mag += 2
		p.def += 1
		p.res += 1
		p.agi += 1
		if p.level % 2 == 0:
			p.per += 1
		p.hp = p.max_hp
		p.mp = p.max_mp
	changed.emit()

func add_material(id: String, qty: int) -> void:
	materials[id] = materials.get(id, 0) + qty
	changed.emit()

func add_consumable(id: String, qty: int) -> void:
	consumables[id] = consumables.get(id, 0) + qty
	if consumables[id] <= 0:
		consumables.erase(id)
	changed.emit()

func has_items(req: Dictionary) -> bool:
	for k in req:
		if materials.get(k, 0) < int(req[k]):
			return false
	return true

func consume_items(req: Dictionary) -> void:
	for k in req:
		materials[k] = materials.get(k, 0) - int(req[k])
		if materials[k] <= 0:
			materials.erase(k)
	changed.emit()

func analyze_progress(enemy_id: String) -> float:
	return analyzed.get(enemy_id, 0.0)

func bump_analyze(enemy_id: String, amount: float) -> void:
	analyzed[enemy_id] = minf(1.0, analyze_progress(enemy_id) + amount)
	if not enemy_id in bestiary:
		bestiary.append(enemy_id)
	changed.emit()

func seen(enemy_id: String) -> void:
	if not enemy_id in bestiary:
		bestiary.append(enemy_id)
		changed.emit()

func recruit(id: String) -> void:
	if not id in allies and Data.ALLIES.has(id):
		allies.append(id)
		bestiary.append(id)
		changed.emit()

func party_in_battle() -> Array:
	var out := ["rimuru"]
	for a in allies:
		if out.size() >= 3:
			break
		out.append(a)
	return out

func set_quest(id: String, state: String) -> void:
	quests[id] = state
	changed.emit()

func quest_state(id: String) -> String:
	return quests.get(id, "")

func add_resource(key: String, qty: int) -> void:
	resources[key] = int(resources.get(key, 0)) + qty
	changed.emit()

func unlock_service(id: String) -> void:
	if not id in services:
		services.append(id)
		if id == "lab":
			recruit("shun")
		changed.emit()

func has_service(id: String) -> bool:
	return id in services
