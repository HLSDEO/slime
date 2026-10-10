class_name SageMenu
extends CanvasLayer

var root_panel: PanelContainer
var content: VBoxContainer
var tabs := {}
var open := false

func _ready() -> void:
	layer = 60
	root_panel = PanelContainer.new()
	root_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_panel.offset_left = 30
	root_panel.offset_top = 16
	root_panel.offset_right = -30
	root_panel.offset_bottom = -16
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.13, 0.97)
	style.border_color = Color(0.4, 0.8, 0.9)
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	root_panel.add_theme_stylebox_override("panel", style)
	add_child(root_panel)
	var hbox := HBoxContainer.new()
	root_panel.add_child(hbox)
	var tabs_box := VBoxContainer.new()
	hbox.add_child(tabs_box)
	tabs_box.add_child(_label("GRANDE SÁBIO", 16, Color(0.5, 0.9, 1)))
	for tab_name in ["Equipe", "Habilidades", "Síntese", "Bestiário", "Missões"]:
		var b := Button.new()
		b.text = tab_name
		b.custom_minimum_size = Vector2(120, 0)
		b.pressed.connect(_show_tab.bind(tab_name))
		tabs_box.add_child(b)
	var close_b := Button.new()
	close_b.text = "Fechar [Q]"
	close_b.pressed.connect(close)
	tabs_box.add_child(close_b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	root_panel.visible = false

func _label(text: String, size := 13, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func toggle() -> void:
	if open:
		close()
	else:
		open_menu()

func open_menu() -> void:
	open = true
	root_panel.visible = true
	_show_tab("Equipe")

func close() -> void:
	open = false
	root_panel.visible = false

func _clear() -> void:
	for c in content.get_children():
		c.queue_free()

func _show_tab(tab: String) -> void:
	_clear()
	match tab:
		"Equipe": _tab_equipe()
		"Habilidades": _tab_skills()
		"Síntese": _tab_synth()
		"Bestiário": _tab_bestiary()
		"Missões": _tab_quests()

func _tab_equipe() -> void:
	content.add_child(_label("— EQUIPE —", 15, Color(0.5, 0.9, 1)))
	var p := GameState.p
	content.add_child(_label("Rimuru (Nv %d)  PV %d/%d  PM %d/%d" % [p.level, p.hp, p.max_hp, p.mp, p.max_mp], 14, Color(0.6, 1, 0.8)))
	content.add_child(_label("FOR %d  MAG %d  DEF %d  RES %d  AGI %d  PER %d  XP %d/%d" % [p.atk, p.mag, p.def, p.res, p.agi, p.per, p.xp, GameState.xp_needed()]))
	for a in GameState.allies:
		var d: Dictionary = Data.ALLIES[a]
		content.add_child(_label("%s (Nv %d)  PV %d  FOR %d  MAG %d  DEF %d  AGI %d" % [d.name, d.level, d.hp, d.atk, d.mag, d.def, d.agi], 14, Color(0.8, 0.9, 0.6)))
		content.add_child(_label(d.desc, 12, Color(0.7, 0.7, 0.75)))
	content.add_child(_label("", 8))
	content.add_child(_label("— TEMPEST —", 15, Color(0.5, 0.9, 1)))
	var r: Dictionary = GameState.resources
	content.add_child(_label("Comida %d | Material %d | População %d | Ouro %d" % [r.get("food", 0), r.get("material", 0), r.get("population", 0), GameState.gold]))
	var svc := []
	for s in GameState.services:
		svc.append(s)
	content.add_child(_label("Serviços: " + (", ".join(svc) if svc.size() > 0 else "nenhum"), 12))

func _tab_skills() -> void:
	content.add_child(_label("— BIBLIOTECA DE HABILIDADES —", 15, Color(0.5, 0.9, 1)))
	for id in GameState.skills:
		var s: Dictionary = Data.skills[id]
		var tag := {"active": "Ativa", "passive": "Passiva", "unique": "Única"}.get(s.type, s.type)
		var extra := ""
		if s.type == "active":
			extra = "  [%s, poder %s, %s PM]" % [s.element, str(s.power), str(s.cost)]
		content.add_child(_label("%s (%s)%s" % [s.name, tag, extra], 14, Color(0.6, 1, 0.8)))
		content.add_child(_label(s.desc, 12, Color(0.7, 0.7, 0.75)))

func _tab_synth() -> void:
	content.add_child(_label("— SÍNTESE —", 15, Color(0.5, 0.9, 1)))
	if not GameState.has_service("lab"):
		content.add_child(_label("Bloqueado: construa o Laboratório (recrute Shun na Vila Jura e entregue 3 Líquidos Mágicos).", 13, Color(1, 0.6, 0.5)))
	for r in Data.synthesis:
		var out_name: String = Data.skills[r.output].name
		var ins := []
		for i in r.inputs:
			ins.append(Data.skills[i].name)
		var line := "%s  =  %s" % [" + ".join(ins), out_name]
		if r.output in GameState.synth_done:
			content.add_child(_label("✓ " + line, 13, Color(0.5, 1, 0.6)))
		else:
			var have := true
			for i in r.inputs:
				if not GameState.has_skill(i):
					have = false
			content.add_child(_label(line, 13, Color(0.9, 0.9, 0.7) if have else Color(0.5, 0.5, 0.55)))
			content.add_child(_label(r.desc, 12, Color(0.7, 0.7, 0.75)))
			if have:
				var b := Button.new()
				b.text = "Sintetizar: " + out_name
				b.disabled = not GameState.has_service("lab")
				b.pressed.connect(_do_synth.bind(r))
				content.add_child(b)

func _do_synth(r: Dictionary) -> void:
	GameState.add_skill(r.output)
	GameState.synth_done.append(r.output)
	GameState.changed.emit()
	_show_tab("Síntese")

func _tab_bestiary() -> void:
	content.add_child(_label("— BESTIÁRIO —", 15, Color(0.5, 0.9, 1)))
	var seen_any := false
	for id in Data.enemies:
		if not id in GameState.bestiary:
			continue
		seen_any = true
		var e: Dictionary = Data.enemies[id]
		var prog := GameState.analyze_progress(id)
		var color := Color(0.6, 1, 0.8) if prog >= 1.0 else Color(0.9, 0.9, 0.6)
		var line := "%s  —  análise %d%%" % [e.name, int(prog * 100)]
		content.add_child(_label(line, 13, color))
		if prog >= 1.0:
			content.add_child(_label("PV %d FRAC: %s  RES: %s" % [e.hp, ", ".join(e.weak) if e.weak.size() else "-", ", ".join(e.resist) if e.resist.size() else "-"], 12, Color(0.7, 0.7, 0.75)))
			content.add_child(_label(e.desc, 12, Color(0.7, 0.7, 0.75)))
		else:
			content.add_child(_label("Use [Analisar] em batalha para revelar fraquezas e liberar recompensas de absorção.", 11, Color(0.55, 0.55, 0.6)))
	if not seen_any:
		content.add_child(_label("Nenhuma criatura registrada. Use [Analisar] em batalha.", 13))

func _tab_quests() -> void:
	content.add_child(_label("— MISSÕES —", 15, Color(0.5, 0.9, 1)))
	for qid in Data.quests:
		var st := GameState.quest_state(qid)
		if st == "":
			continue
		var q: Dictionary = Data.quests[qid]
		var state := "✓ Concluída" if st == "done" else "Em andamento"
		content.add_child(_label("%s — %s" % [q.name, state], 14, Color(0.5, 1, 0.6) if st == "done" else Color(0.9, 0.9, 0.6)))
		content.add_child(_label(q.desc, 12, Color(0.7, 0.7, 0.75)))
