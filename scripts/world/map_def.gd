class_name MapDef

# Atlas (col,row) do Kenney roguelikeSheet_transparent (tile 16px, spacing 1)
const TILES := {
	"grass":  {"atlas": [5, 1],  "solid": false},
	"grass2": {"atlas": [4, 1],  "solid": false},
	"water":  {"atlas": [0, 0],  "solid": true},
	"water2": {"atlas": [1, 0],  "solid": true},
	"dirt":   {"atlas": [5, 2],  "solid": false},
	"dirt2":  {"atlas": [6, 2],  "solid": false},
	"tree":   {"atlas": [16, 10], "solid": true},
	"bush":   {"atlas": [13, 2], "solid": false},
	"rock":   {"atlas": [12, 0], "solid": true},
	"cavefloor": {"atlas": [14, 12], "solid": false},
	"cavewall":  {"atlas": [21, 12], "solid": true},
	"wall":   {"atlas": [34, 12], "solid": true},
	"roof":   {"atlas": [34, 21], "solid": true},
	"door":   {"atlas": [20, 21], "solid": false},
	"wood":   {"atlas": [6, 2],  "solid": false},
}

const CHARS := {
	".": "grass", ",": "grass2", "~": "water", "%": "water2", "-": "dirt", "=": "dirt2",
	"T": "tree", "b": "bush", "r": "rock", "f": "cavefloor", "#": "cavewall",
	"W": "wall", "R": "roof", "D": "door", "u": "wood",
}

static func get_map(id: String) -> Dictionary:
	match id:
		"cave": return _cave()
		"forest": return _forest()
		"village": return _village()
		"tempest": return _tempest()
	return _cave()

static func _blank(w: int, h: int, ch: String) -> Array:
	var rows := []
	for y in h:
		rows.append(String(ch).repeat(w))
	return rows

static func _set(rows: Array, x: int, y: int, ch: String) -> void:
	rows[y] = rows[y].substr(0, x) + ch + rows[y].substr(x + 1)

static func _rect(rows: Array, x0: int, y0: int, x1: int, y1: int, ch: String) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_set(rows, x, y, ch)

static func _cave() -> Dictionary:
	var w := 20
	var h := 14
	var rows := _blank(w, h, "#")
	_rect(rows, 1, 1, w - 2, h - 2, "f")
	_rect(rows, 3, 3, 5, 4, "#")
	_rect(rows, 14, 2, 16, 4, "#")
	_rect(rows, 6, 9, 8, 10, "#")
	_set(rows, 9, 13, "f")
	_set(rows, 10, 13, "f")
	return {
		"layout": rows,
		"encounter": "cave",
		"zones": [],
		"portals": [{"x": 9, "y": 13, "w": 2, "to": "forest", "tx": 21, "ty": 32, "msg": ""}],
		"npcs": [
			{"id": "veldora", "x": 10, "y": 4, "sprite": "rimuru", "tint": [0.3, 0.9, 0.8], "dialogue": "veldora_meet", "requires": "flag:!met_veldora", "scale": 3},
			{"id": "sign_hint", "x": 12, "y": 11, "sprite": "", "dialogue": "cave_exit_hint", "requires": "flag:met_veldora", "hide": ""},
		],
		"rest": false,
	}

static func _forest() -> Dictionary:
	var w := 44
	var h := 34
	var rows := _blank(w, h, ".")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# bordas de árvore
	for x in w:
		for t in 2:
			_set(rows, x, t, "T")
			_set(rows, x, h - 1 - t, "T")
	for y in h:
		for t in 2:
			_set(rows, t, y, "T")
			_set(rows, w - 1 - t, y, "T")
	# árvores internas com ruído determinístico
	for y in range(3, h - 2):
		for x in range(3, w - 2):
			var v := rng.randf()
			if v < 0.14:
				_set(rows, x, y, "T")
			elif v < 0.18:
				_set(rows, x, y, "b")
			elif v < 0.195:
				_set(rows, x, y, "r")
	# clareiras
	_rect(rows, 18, 3, 26, 8, ".")     # area do chefe
	_rect(rows, 19, 10, 24, 14, ".")   # clareira central
	_rect(rows, 14, 16, 30, 20, ".")   # clareira goblins
	_rect(rows, 32, 22, 40, 29, ".")   # pantano SE
	_rect(rows, 2, 26, 6, 31, ".")     # clareira vila
	# caminho principal norte-sul
	_rect(rows, 20, 9, 22, 32, "-")
	_rect(rows, 2, 20, 40, 21, "=")
	# lago + pantano
	_rect(rows, 8, 6, 13, 9, "~")
	_rect(rows, 34, 24, 38, 27, "~")
	for i in 8:
		_set(rows, 32 + rng.randi() % 9, 22 + rng.randi() % 8, "%")
	# entradas/portais abertos
	_rect(rows, 20, 32, 22, 33, "-")   # saida sul -> caverna
	_rect(rows, 1, 28, 3, 30, "-")     # portal oeste -> vila
	_rect(rows, 40, 16, 42, 18, "-")   # portal leste -> tempest
	return {
		"layout": rows,
		"encounter": "forest",
		"zones": [{"x": 31, "y": 21, "w": 11, "h": 10, "pool": "swamp"}],
		"portals": [
			{"x": 20, "y": 33, "w": 3, "to": "cave", "tx": 10, "ty": 12, "msg": ""},
			{"x": 1, "y": 28, "w": 2, "to": "village", "tx": 27, "ty": 11, "msg": ""},
			{"x": 41, "y": 16, "w": 2, "to": "tempest", "tx": 13, "ty": 17, "msg": "", "requires": "flag:founding_done", "locked_msg": "Um desfiladeiro bloqueia o vale a leste. (Complete a fundação de Tempest)"},
		],
		"npcs": [
			{"id": "goblin", "x": 18, "y": 18, "sprite": "goblin", "dialogue": "goblin_survivor", "requires": "flag:!goblin_saved"},
			{"id": "wolfpack", "x": 28, "y": 12, "sprite": "wolf", "dialogue": "wolf_event", "requires": "flag:!wolves_ally", "hide_if": "wolves_hostile"},
			{"id": "boss_gate", "x": 21, "y": 5, "sprite": "wolfking", "dialogue": "boss_gate", "requires": "flag:!boss_lobo_done"},
			{"id": "ogre", "x": 38, "y": 19, "sprite": "ogre", "dialogue": "ogre_event", "requires": "flag:founding_done", "hide_if": "gido_done"},
		],
		"rest": false,
	}

static func _village() -> Dictionary:
	var w := 30
	var h := 22
	var rows := _blank(w, h, ".")
	for x in w:
		for t in 1:
			_set(rows, x, t, "T")
			_set(rows, x, h - 1 - t, "T")
	for y in h:
		_set(rows, 0, y, "T")
		_set(rows, w - 1, y, "T")
	# praça central e ruas
	_rect(rows, 8, 8, 21, 13, "=")
	_rect(rows, 14, 2, 15, 21, "-")
	# casas
	_rect(rows, 4, 4, 8, 7, "W"); _rect(rows, 4, 4, 8, 4, "R"); _set(rows, 6, 7, "D")
	_rect(rows, 21, 4, 25, 7, "W"); _rect(rows, 21, 4, 25, 4, "R"); _set(rows, 23, 7, "D")
	_rect(rows, 5, 15, 10, 18, "W"); _rect(rows, 5, 15, 10, 15, "R"); _set(rows, 7, 18, "D")
	_rect(rows, 18, 15, 24, 19, "W"); _rect(rows, 18, 15, 24, 15, "R"); _set(rows, 21, 19, "D")
	# guilda maior
	_rect(rows, 12, 3, 17, 6, "W"); _rect(rows, 12, 3, 17, 3, "R"); _set(rows, 14, 6, "D")
	return {
		"layout": rows,
		"encounter": "",
		"zones": [],
		"portals": [{"x": 28, "y": 10, "w": 1, "to": "forest", "tx": 3, "ty": 29, "msg": ""}],
		"npcs": [
			{"id": "guide", "x": 15, "y": 9, "sprite": "villager", "dialogue": "village_guide"},
			{"id": "dwarf", "x": 9, "y": 6, "sprite": "dwarf", "dialogue": "dwarf_artisan", "requires": "service:!blacksmith"},
			{"id": "merchant", "x": 20, "y": 6, "sprite": "merchant", "dialogue": "merchant_guild", "requires": "service:!kitchen"},
			{"id": "shop", "x": 13, "y": 10, "sprite": "merchant", "dialogue": "shop_keeper", "shop": true},
			{"id": "guild", "x": 14, "y": 8, "sprite": "messenger", "dialogue": "guild_ogre_quest", "requires": "flag:founding_done", "hide_if": "gido_done"},
		],
		"rest": true,
	}

static func _tempest() -> Dictionary:
	var w := 28
	var h := 20
	var rows := _blank(w, h, ".")
	for x in w:
		_set(rows, x, 0, "T")
		_set(rows, x, h - 1, "T")
	for y in h:
		_set(rows, 0, y, "T")
		_set(rows, w - 1, y, "T")
	for i in range(1, w - 1):
		if rows[1][i] != "T":
			pass
	# praça central
	_rect(rows, 11, 8, 16, 12, "=")
	_rect(rows, 13, 13, 14, 19, "-")
	# casa principal (sempre presente apos fundacao)
	_rect(rows, 11, 4, 16, 7, "W"); _rect(rows, 11, 4, 16, 4, "R"); _set(rows, 13, 7, "D")
	return {
		"layout": rows,
		"encounter": "",
		"zones": [],
		"portals": [{"x": 13, "y": 19, "w": 2, "to": "forest", "tx": 41, "ty": 17, "msg": ""}],
		"npcs": [
			{"id": "riguru_npc", "x": 10, "y": 10, "sprite": "rigurumu", "dialogue": "npc_riguru", "requires": "flag:founding_done"},
			{"id": "bs_npc", "x": 8, "y": 6, "sprite": "dwarf", "dialogue": "npc_blacksmith", "requires": "service:blacksmith"},
			{"id": "cook_npc", "x": 19, "y": 6, "sprite": "merchant", "dialogue": "npc_cook", "requires": "service:kitchen"},
			{"id": "lab_npc", "x": 19, "y": 13, "sprite": "shun", "dialogue": "npc_lab", "requires": "service:lab"},
		],
		"rest": true,
		"dynamic_buildings": {
			"blacksmith": {"x": 5, "y": 4, "w": 4, "h": 3},
			"kitchen": {"x": 18, "y": 4, "w": 4, "h": 3},
			"lab": {"x": 18, "y": 12, "w": 4, "h": 3},
		},
	}
