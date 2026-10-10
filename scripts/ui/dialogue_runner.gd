class_name DialogueRunner
extends CanvasLayer

signal finished
signal request_battle(group: Array, after_goto: String)
signal request_ending(kind: String)
signal request_map(map_id: String, x: int, y: int)
signal request_toast(text: String)
signal request_shop

const PORTRAITS := {
	"Rimuru": ["rimuru", Color(1, 1, 1)],
	"Grande Sábio": ["rimuru", Color(0.4, 0.95, 0.9)],
	"Veldora": ["rimuru", Color(0.3, 0.9, 0.85)],
	"Rimuru?": ["rimuru", Color(1, 1, 1)],
	"Goblin": ["goblin", Color(1, 1, 1)],
	"Rigurimu": ["rigurumu", Color(1, 1, 1)],
	"Lobo Alfa": ["wolf", Color(1, 1, 1)],
	"Rei Lobo Borboleta": ["wolfking", Color(1, 1, 1)],
	"Dwarin": ["dwarf", Color(1, 1, 1)],
	"Ferreiro Dwarin": ["dwarf", Color(1, 1, 1)],
	"Serei": ["merchant", Color(1, 1, 1)],
	"Guilda Mercante Serei": ["merchant", Color(1, 1, 1)],
	"Cozinheiro Germes": ["merchant", Color(1, 1, 1)],
	"Presta": ["villager", Color(1, 1, 1)],
	"Mestre da Guilda": ["messenger", Color(1, 1, 1)],
	"Mensageiro": ["messenger", Color(1, 1, 1)],
	"Ogro Arauto": ["ogre", Color(1, 1, 1)],
	"Rei Ogro Gido": ["ogre", Color(1, 1, 1)],
	"Shun": ["shun", Color(1, 1, 1)],
}

var active := false
var node: Dictionary = {}
var lines: Array = []
var line_i := 0
var typing := false
var typed_chars := 0
var full_text := ""
var choices_node: VBoxContainer
var panel: PanelContainer
var name_label: Label
var text_label: Label
var portrait: TextureRect
var _node_id := ""

func _ready() -> void:
	layer = 50
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_top = -118
	panel.offset_bottom = -8
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.14, 0.92)
	style.border_color = Color(0.4, 0.8, 0.9)
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var hbox := HBoxContainer.new()
	panel.add_child(hbox)
	var vport := VBoxContainer.new()
	hbox.add_child(vport)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vport.add_child(portrait)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	name_label = Label.new()
	name_label.add_theme_color_override("font_color", Color(0.5, 0.9, 1))
	name_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(name_label)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(0, 72)
	text_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(text_label)
	panel.visible = false
	choices_node = VBoxContainer.new()
	choices_node.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	choices_node.offset_left = -240
	choices_node.offset_right = -20
	choices_node.offset_top = -250
	choices_node.offset_bottom = -130
	choices_node.visible = false
	add_child(choices_node)

func start(node_id: String) -> void:
	if not Data.dialogues.has(node_id):
		push_error("dialogue ausente: " + node_id)
		finished.emit()
		return
	_node_id = node_id
	node = Data.dialogues[node_id]
	active = true
	for c in choices_node.get_children():
		c.queue_free()
	choices_node.visible = false
	panel.visible = true
	lines = node.get("lines", [])
	line_i = -1
	# acoes imediatas executam ja; battle/mapa/ending ficam para o fim do no
	_deferred = []
	var now := []
	for a in node.get("actions", []):
		if a.has("battle") or a.has("map") or a.has("ending"):
			_deferred.append(a)
		else:
			now.append(a)
	_exec(now)
	_next_line()

var _deferred: Array = []

func _takeover() -> void:
	panel.visible = false
	active = false
	if _pending_battle.size() > 0:
		var b := _pending_battle
		var g := _pending_goto
		_pending_battle = []
		request_battle.emit(b, g)

func _exec(actions: Array) -> bool:  # true = houve takeover (batalha/mapa/fim)
	for a in actions:
		if a.has("set"):
			GameState.flags[a["set"]] = a.get("val", true)
		elif a.has("skill"):
			var r := GameState.add_skill(a["skill"])
			var sname: String = Data.skills[a["skill"]]["name"]
			request_toast.emit(("[Grande Sábio] Nova habilidade: %s" % sname) if r == "new" else ("[Grande Sábio] Habilidade duplicada: +%d XP" % 12))
		elif a.has("recruit"):
			GameState.recruit(a["recruit"])
			request_toast.emit("[Aliado] " + Data.ALLIES[a["recruit"]]["name"] + " entrou para o grupo!")
		elif a.has("item"):
			GameState.add_consumable(a["item"], int(a.get("qty", 1)))
			request_toast.emit("[Item] " + Data.items[a["item"]]["name"] + " x" + str(a.get("qty", 1)))
		elif a.has("gold"):
			GameState.gold += int(a["gold"])
			request_toast.emit("[Ouro] " + ("+" if a["gold"] > 0 else "") + str(a["gold"]))
		elif a.has("quest"):
			GameState.set_quest(a["quest"], a["state"] if a["state"] != "check" else "active")
			var qname: String = Data.quests[a["quest"]]["name"]
			if a["state"] == "start":
				request_toast.emit("[Missão] " + qname)
		elif a.has("consume"):
			GameState.consume_items(a["consume"])
		elif a.has("resource"):
			for k in a["resource"]:
				GameState.add_resource(k, int(a["resource"][k]))
			request_toast.emit("[Tempest] Recursos atualizados")
		elif a.has("unlock_service"):
			GameState.unlock_service(a["unlock_service"])
			request_toast.emit("[Tempest] Novo serviço disponível!")
		elif a.has("battle"):
			var groups: Dictionary = Data.encounters["fixed"]
			_exec_later_battle(groups[a["battle"]], a.get("goto", ""))
			return true
		elif a.has("map"):
			request_map.emit(a["map"], int(a.get("x", 0)), int(a.get("y", 0)))
			return true
		elif a.has("ending"):
			request_ending.emit(a["ending"])
			return true
	return false

var _pending_battle := []
var _pending_goto := ""

func _exec_later_battle(group: Array, goto_after: String) -> void:
	_pending_battle = group
	_pending_goto = goto_after

func _next_line() -> void:
	line_i += 1
	if line_i >= lines.size():
		_finish_node()
		return
	var pair: Array = lines[line_i]
	var speaker: String = pair[0]
	name_label.text = speaker
	full_text = pair[1]
	typed_chars = 0
	typing = true
	var p := PORTRAITS.get(speaker, ["", Color.WHITE])
	if p[0] == "":
		portrait.visible = false
	else:
		portrait.visible = true
		portrait.texture = load("res://assets/generated/%s.png" % p[0])
		portrait.modulate = p[1]

func _finish_node() -> void:
	if node.has("choices"):
		_show_choices(node["choices"])
		return
	if node.get("shop", false):
		request_shop.emit()
		active = false
		panel.visible = false
		return
	if _deferred.size() > 0:
		var took := _exec(_deferred)
		_deferred = []
		if took or _pending_battle.size() > 0:
			_takeover()
			return
	var goto := node.get("goto", "")
	if goto != "":
		start(goto)
		return
	_close()

func _show_choices(choices: Array) -> void:
	typing = false
	text_label.text = full_text
	for c in choices_node.get_children():
		c.queue_free()
	for c in choices:
		var btn := Button.new()
		btn.text = c["text"]
		var ok := _req_ok(c.get("requires", {}))
		btn.disabled = not ok
		if not ok:
			btn.text += "  [bloqueado]"
		btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		btn.pressed.connect(_on_choice.bind(c))
		choices_node.add_child(btn)
	choices_node.visible = true

func _on_choice(c: Dictionary) -> void:
	choices_node.visible = false
	choices_node.reset_size()
	var goto: String = c.get("goto", "")
	var deferred := []
	var now := []
	for a in c.get("actions", []):
		if a.has("battle") or a.has("map") or a.has("ending"):
			deferred.append(a)
		else:
			now.append(a)
	_exec(now)
	if deferred.size() > 0:
		var took := _exec(deferred)
		if took or _pending_battle.size() > 0:
			_takeover()
			return
	if goto != "":
		start(goto)
	else:
		_close()

func _req_ok(req: Dictionary) -> bool:
	if req.is_empty():
		return true
	if req.has("flag"):
		var f: String = req["flag"]
		var want_neg := f.begins_with("!")
		var key := f.trim_prefix("!")
		var v: bool = GameState.flags.get(key, false)
		if want_neg and v:
			return false
		if not want_neg and not v:
			return false
	if req.has("service"):
		var s: String = req["service"]
		var want_neg2 := s.begins_with("!")
		var key2 := s.trim_prefix("!")
		if want_neg2 == GameState.has_service(key2):
			return false
	if req.has("ally"):
		if not req["ally"] in GameState.allies:
			return false
	if req.has("skill"):
		if not GameState.has_skill(req["skill"]):
			return false
	if req.has("item"):
		if not GameState.has_items(req["item"]):
			return false
	if req.has("gold"):
		if GameState.gold < int(req["gold"]):
			return false
	return true

func _close() -> void:
	active = false
	panel.visible = false
	choices_node.visible = false
	if _pending_battle.size() > 0:
		var b := _pending_battle
		var g := _pending_goto
		_pending_battle = []
		request_battle.emit(b, g)
		return
	if _node_id == "q_craftsmen_check":
		pass
	_check_craftsmen()
	finished.emit()

func _check_craftsmen() -> void:
	if GameState.quest_state("q_craftsmen") == "active" and GameState.has_service("blacksmith") and GameState.has_service("kitchen"):
		GameState.set_quest("q_craftsmen", "done")
		GameState.set_quest("q_lab", "start")
		request_toast.emit("[Missão] Laboratório de Pesquisa")

func _process(delta: float) -> void:
	if not active:
		return
	if typing:
		typed_chars += 40.0 * delta * 60.0
		var n := int(typed_chars)
		text_label.text = full_text.substr(0, mini(n, full_text.length()))
		if n >= full_text.length():
			typing = false
			text_label.text = full_text
		if Input.is_action_just_pressed("interact"):
			typing = false
			text_label.text = full_text
	elif not choices_node.visible:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
			_next_line()
