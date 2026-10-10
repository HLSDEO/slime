extends Node2D

signal acted(action: Dictionary)

var foes: Array = []
var party: Array = []
var queue: Array = []
var kind := "encounter"
var battle_context := {}
var over := false
var _fled := false

var log_label: Label
var menu_box: VBoxContainer
var order_label: Label
var enemy_nodes := {}
var party_nodes := {}
var _msg_time := 0.0
var _msg_queue: Array = []

func _ready() -> void:
	var req: Dictionary = Flow.battle_request
	kind = req.get("kind", "encounter")
	battle_context = Flow.battle_context
	var group: Array = req.get("group", [])
	_build_background()
	for eid in group:
		foes.append(BattleUnit.from_enemy(eid))
	for pid in GameState.party_in_battle():
		if pid == "rimuru":
			party.append(BattleUnit.from_rimuru())
		else:
			party.append(BattleUnit.from_ally(pid))
	_build_ui()
	for u in party + foes:
		GameState.seen(u.id)
	if _has_any_passive("advanced_detection"):
		for f in foes:
			GameState.bump_analyze(f.id, 1.0)
		_log("[Grande Sábio] Detecção Avançada: inimigos analisados automaticamente.")
	_run_battle()

func _has_any_passive(pid: String) -> bool:
	for u in party:
		if u.has_passive(pid):
			return true
	return false

func _build_background() -> void:
	var sky := ColorRect.new()
	sky.color = Color(0.42, 0.68, 0.82)
	sky.size = Vector2(640, 190)
	add_child(sky)
	var ground := ColorRect.new()
	ground.color = Color(0.33, 0.52, 0.3)
	ground.position = Vector2(0, 190)
	ground.size = Vector2(640, 170)
	add_child(ground)

func _sprite_node(unit: BattleUnit, sc: float, flip: bool) -> Sprite2D:
	var spr := Sprite2D.new()
	var tex: Texture2D = load("res://assets/generated/%s.png" % unit.sprite)
	spr.texture = tex
	spr.region_enabled = true
	var col := 2 if unit.side == "foe" else 3
	spr.region_rect = Rect2(col * 32, 0, 32, 32)
	spr.scale = Vector2(sc, sc)
	spr.flip_h = flip
	return spr

func _bar(w: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, 6)
	return b

func _build_ui() -> void:
	order_label = Label.new()
	order_label.position = Vector2(6, 2)
	order_label.add_theme_font_size_override("font_size", 11)
	order_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.8))
	add_child(order_label)
	foes.sort_custom(func(a, b): return a.max_hp < b.max_hp)
	for i in foes.size():
		var u: BattleUnit = foes[i]
		var node := Node2D.new()
		node.position = Vector2(90 + i * 120, 120)
		var spr := _sprite_node(u, 3.0, false)
		node.add_child(spr)
		var name_lbl := Label.new()
		name_lbl.text = u.display_name + (" ★" if u.is_boss else "")
		name_lbl.position = Vector2(-45, 34)
		name_lbl.add_theme_font_size_override("font_size", 10)
		node.add_child(name_lbl)
		var hb := _bar(80)
		hb.position = Vector2(-40, 46)
		node.add_child(hb)
		add_child(node)
		enemy_nodes[u] = {"node": node, "bar": hb, "spr": spr}
	for i in party.size():
		var u: BattleUnit = party[i]
		var node := Node2D.new()
		node.position = Vector2(90 + i * 70, 260)
		var spr := _sprite_node(u, 2.2, true)
		node.add_child(spr)
		add_child(node)
		var panel := PanelContainer.new()
		panel.position = Vector2(470, 30 + i * 52)
		panel.custom_minimum_size = Vector2(160, 46)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.12, 0.18, 0.9)
		style.set_content_margin_all(4)
		panel.add_theme_stylebox_override("panel", style)
		var v := VBoxContainer.new()
		panel.add_child(v)
		var nl := Label.new()
		nl.text = u.display_name
		nl.add_theme_font_size_override("font_size", 10)
		v.add_child(nl)
		var hb := _bar(140)
		v.add_child(hb)
		var mb := _bar(140)
		mb.self_modulate = Color(0.45, 0.6, 1.0)
		v.add_child(mb)
		add_child(panel)
		party_nodes[u] = {"bar": hb, "mbar": mb, "spr": spr, "panel": panel}
	menu_box = VBoxContainer.new()
	menu_box.position = Vector2(250, 140)
	menu_box.custom_minimum_size = Vector2(200, 0)
	add_child(menu_box)
	log_label = Label.new()
	log_label.position = Vector2(6, 330)
	log_label.size = Vector2(628, 28)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_font_size_override("font_size", 11)
	log_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1))
	add_child(log_label)
	_refresh_bars()

func _log(text: String) -> void:
	log_label.text = text

func _refresh_bars() -> void:
	for u in foes:
		if enemy_nodes.has(u):
			enemy_nodes[u]["bar"].max_value = u.max_hp
			enemy_nodes[u]["bar"].value = maxf(0, u.hp)
			enemy_nodes[u]["node"].visible = u.alive
	for u in party:
		if party_nodes.has(u):
			party_nodes[u]["bar"].max_value = u.max_hp
			party_nodes[u]["bar"].value = maxf(0, u.hp)
			party_nodes[u]["mbar"].max_value = maxf(1, u.max_mp)
			party_nodes[u]["mbar"].value = maxf(0, u.mp)
			party_nodes[u]["panel"].modulate.a = 1.0 if u.alive else 0.35
			party_nodes[u]["spr"].modulate.a = 1.0 if u.alive else 0.25

# ---------- loop principal ----------

func _run_battle() -> void:
	await get_tree().create_timer(0.6).timeout
	while not over:
		queue = party.filter(func(u): return u.alive) + foes.filter(func(u): return u.alive)
		queue.sort_custom(func(a, b): return a.eff_agi() > b.eff_agi())
		var names := []
		for u in queue:
			names.append(u.display_name.left(3).to_upper())
		order_label.text = "Ordem: " + " > ".join(names)
		for u in queue:
			if over:
				break
			if not u.alive:
				continue
			u.defending = false
			var tick := _tick_statuses(u)
			if not tick.alive:
				continue
			if tick.skip:
				await get_tree().create_timer(0.5).timeout
				continue
			if _check_end():
				break
			if u.side == "party":
				await _player_turn(u)
			else:
				await _enemy_turn(u)
			if _check_end():
				break
		if _check_end():
			break
	await _finish()

func _tick_statuses(u: BattleUnit) -> Dictionary:
	var skip := false
	if u.statuses.has("stun"):
		skip = true
		_log("%s está atordoado!" % u.display_name)
	elif u.statuses.has("fear") and randf() < 0.6:
		skip = true
		_log("%s está paralisado de medo!" % u.display_name)
	if u.has_passive("purification") and u.statuses.size() > 0:
		u.statuses.erase(u.statuses.keys()[0])
		_log("%s purifica um efeito negativo." % u.display_name)
	for s in ["poison", "bleed", "regen"]:
		if u.statuses.has(s):
			if s == "regen":
				var heal := int(u.max_hp * 0.08)
				u.hp = mini(u.hp + heal, u.max_hp)
			elif s == "poison":
				var dmg := int(u.max_hp * 0.06)
				if u.has_passive("resist_poison"):
					dmg = int(dmg / 2.0)
				u.hp -= dmg
				_log("%s sofre %d de veneno." % [u.display_name, dmg])
			elif s == "bleed":
				var dmg2 := int(u.max_hp * 0.05)
				u.hp -= dmg2
				_log("%s sangra e perde %d PV." % [u.display_name, dmg2])
	for s in u.statuses.keys():
		u.statuses[s] -= 1
		if u.statuses[s] <= 0:
			u.statuses.erase(s)
	if u.has_passive("mp_regen"):
		u.mp = mini(u.mp + 3, u.max_mp)
	_refresh_bars()
	if u.hp <= 0:
		_kill(u, null)
		return {"alive": false, "skip": false}
	return {"alive": true, "skip": skip}

func _check_end() -> bool:
	var party_alive := party.any(func(u): return u.alive)
	var foes_alive := foes.any(func(u): return u.alive)
	if not party_alive or not foes_alive:
		over = true
		return true
	return false

# ---------- turno do jogador ----------

func _player_turn(u: BattleUnit) -> void:
	_show_menu(u)
	var action: Dictionary = await acted
	_clear_menu()
	await _do_action(u, action)

func _show_menu(u: BattleUnit) -> void:
	_clear_menu()
	_add_menu_button("Atacar", {"kind": "attack"})
	_add_menu_button("Habilidade", {"kind": "skills"})
	_add_menu_button("Analisar", {"kind": "analyze"})
	_add_menu_button("Defender", {"kind": "defend"})
	_add_menu_button("Item", {"kind": "items"})
	_add_menu_button("Absorver", {"kind": "absorb"})
	if kind == "encounter":
		_add_menu_button("Fugir", {"kind": "flee"})
	_log("Vez de %s. O que fazer? (PM %d/%d)" % [u.display_name, u.mp, u.max_mp])

func _clear_menu() -> void:
	for c in menu_box.get_children():
		c.queue_free()

func _add_menu_button(text: String, action: Dictionary) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(200, 0)
	b.pressed.connect(func(): acted.emit(action))
	menu_box.add_child(b)

func _show_targets(u: BattleUnit, action: Dictionary, targets: Array, label: String) -> void:
	_clear_menu()
	_log(label)
	for t in targets:
		var tt: BattleUnit = t
		var b := Button.new()
		b.text = "%s (PV %d/%d)" % [tt.display_name, maxi(0, tt.hp), tt.max_hp]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(200, 0)
		b.pressed.connect(func(): acted.emit({"kind": action.kind, "target": tt}))
		menu_box.add_child(b)
	var cb := Button.new()
	cb.text = "Cancelar"
	cb.pressed.connect(func(): acted.emit({"kind": "cancel"}))
	menu_box.add_child(cb)

func _do_action(u: BattleUnit, action: Dictionary) -> void:
	match action.get("kind", ""):
		"attack":
			var alive_foes := foes.filter(func(f): return f.alive)
			_show_targets(u, action, alive_foes, "Atacar quem?")
			var t1: Dictionary = await acted
			if t1.kind == "cancel":
				await _player_turn(u)
			return
			await _act_attack(u, t1.target, 40)
		"skills":
			var usable := []
			for sid in u.skills:
				var s: Dictionary = Data.skills[sid]
				if u.mp >= int(s.cost):
					usable.append(s)
			if usable.is_empty():
				_log("Sem habilidades utilizáveis (PM insuficiente).")
				await get_tree().create_timer(0.6).timeout
				await _player_turn(u)
			return
			_clear_menu()
			for s in usable:
				var b := Button.new()
				b.text = "%s (%d PM)" % [s.name, s.cost]
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
				b.custom_minimum_size = Vector2(200, 0)
				b.pressed.connect(func(): acted.emit({"kind": "use_skill", "skill": s}))
				menu_box.add_child(b)
			var cb := Button.new()
			cb.text = "Cancelar"
			cb.pressed.connect(func(): acted.emit({"kind": "cancel"}))
			menu_box.add_child(cb)
			var sel: Dictionary = await acted
			if sel.kind == "cancel":
				await _player_turn(u)
			return
			await _cast_skill(u, sel.skill)
		"analyze":
			var alive_foes2 := foes.filter(func(f): return f.alive)
			_show_targets(u, action, alive_foes2, "Analisar quem?")
			var t2: Dictionary = await acted
			if t2.kind == "cancel":
				await _player_turn(u)
			return
			_act_analyze(u, t2.target)
		"defend":
			u.defending = true
			_log("%s assume postura defensiva." % u.display_name)
			await get_tree().create_timer(0.5).timeout
		"items":
			var owned := []
			for k in GameState.consumables:
				if int(GameState.consumables[k]) > 0:
					owned.append(k)
			if owned.is_empty():
				_log("Mochila vazia.")
				await get_tree().create_timer(0.5).timeout
				await _player_turn(u)
			return
			_clear_menu()
			for k in owned:
				var b3 := Button.new()
				b3.text = "%s x%d" % [Data.items[k].name, int(GameState.consumables[k])]
				b3.alignment = HORIZONTAL_ALIGNMENT_LEFT
				b3.custom_minimum_size = Vector2(200, 0)
				b3.pressed.connect(func(): acted.emit({"kind": "use_item", "item": k}))
				menu_box.add_child(b3)
			var cb2 := Button.new()
			cb2.text = "Cancelar"
			cb2.pressed.connect(func(): acted.emit({"kind": "cancel"}))
			menu_box.add_child(cb2)
			var it: Dictionary = await acted
			if it.kind == "cancel":
				await _player_turn(u)
			return
			await _use_item(u, it.item)
		"absorb":
			_clear_menu()
			var options := foes.filter(func(f): return f.alive)
			if options.is_empty():
				return
			for f in options:
				var b4 := Button.new()
				var reason := _absorb_reason(f)
				b4.text = f.display_name + (" — " + reason if reason != "OK" else " — devorar!")
				b4.disabled = reason != "OK"
				b4.alignment = HORIZONTAL_ALIGNMENT_LEFT
				b4.custom_minimum_size = Vector2(200, 0)
				b4.pressed.connect(func(): acted.emit({"kind": "do_absorb", "target": f}))
				menu_box.add_child(b4)
			var cb3 := Button.new()
			cb3.text = "Cancelar"
			cb3.pressed.connect(func(): acted.emit({"kind": "cancel"}))
			menu_box.add_child(cb3)
			var ab: Dictionary = await acted
			if ab.kind == "cancel":
				await _player_turn(u)
			return
			await _act_absorb(ab.target)
		"flee":
			var avg_pa := _avg_agi(party)
			var avg_fa := _avg_agi(foes)
			var chance := clampf(0.5 + (avg_pa - avg_fa) * 0.04, 0.15, 0.9)
			if randf() < chance:
				_log("Fuga bem-sucedida!")
				over = true
				_fled = true
				return
			_log("Não conseguiu fugir!")
			await get_tree().create_timer(0.6).timeout

func _avg_agi(units: Array) -> float:
	var s := 0.0
	var n := 0
	for u in units:
		if u.alive:
			s += u.eff_agi()
			n += 1
	return s / maxf(1.0, n)

# ---------- ações ----------

func _act_attack(att: BattleUnit, tgt: BattleUnit, power: int) -> void:
	await _cast_core(att, tgt, power, "phys", false, [], 0.0)

func _cast_skill(att: BattleUnit, s: Dictionary) -> void:
	att.mp -= int(s.cost)
	_refresh_bars()
	var target := _auto_target(s, att)
	if s.get("heal", false):
		var amount := _heal_amount(att, s)
		target.hp = mini(target.hp + amount, target.max_hp)
		_log("%s usa %s: %s recupera %d PV." % [att.display_name, s.name, target.display_name, amount])
		_refresh_bars()
		await get_tree().create_timer(0.6).timeout
		return
	if s.target == "all_enemies":
		for f in foes.filter(func(x): return x.alive):
			await _cast_core(att, f, int(s.power), s.element, s.power > 0 and _is_magic(s), s.get("effects", []), float(s.get("effect_chance", 0.0)), true)
		return
	if s.target == "self":
		for e in s.get("effects", []):
			att.statuses[e] = 3
		_log("%s usa %s." % [att.display_name, s.name])
		_refresh_bars()
		await get_tree().create_timer(0.5).timeout
		return
	if target == null:
		return
	await _cast_core(att, target, int(s.power), s.element, _is_magic(s), s.get("effects", []), float(s.get("effect_chance", 0.0)))

func _is_magic(s: Dictionary) -> bool:
	return s.element != "phys"

func _heal_amount(att: BattleUnit, s: Dictionary) -> int:
	return int(att.mag * int(s.power) / 40.0 * randf_range(0.9, 1.1)) + 10

func _auto_target(s: Dictionary, att: BattleUnit) -> BattleUnit:
	var own_side: Array = party if att.side == "party" else foes
	var other_side: Array = foes if att.side == "party" else party
	if s.target == "self":
		return att
	if s.target == "single_ally":
		var hurt: Array = own_side.filter(func(x): return x.alive)
		if s.get("heal", false):
			hurt.sort_custom(func(a, b): return float(a.hp) / a.max_hp < float(b.hp) / b.max_hp)
		return hurt[0] if hurt.size() > 0 else att
	var enemies := other_side.filter(func(f): return f.alive)
	return enemies[0] if enemies.size() > 0 else null

func _cast_core(att: BattleUnit, tgt: BattleUnit, power: int, element: String, use_mag: bool, effects: Array, chance: float, silent_log := false) -> void:
	if att.side == "foe":
		_flash(enemy_nodes.get(att, {}).get("spr", null))
	else:
		_flash(party_nodes.get(att, {}).get("spr", null))
	if not silent_log:
		_log("%s usa %s em %s!" % [att.display_name, _move_name(att, power, element), tgt.display_name])
	if element == "phys" and tgt.has_passive("flexible_body") and randf() < 0.15:
		_log("%s esquiva com o Corpo Maleável!" % tgt.display_name)
		await get_tree().create_timer(0.5).timeout
		return
	var base := float(att.mag if use_mag else att.atk) * power / 40.0
	base *= randf_range(0.9, 1.1)
	var defense_part := float(tgt.res if use_mag else tgt.defense) * 0.55
	var dmg := maxf(1.0, base - defense_part)
	dmg *= _elem_mult(tgt, element)
	if tgt.defending:
		dmg *= 0.5
	var final := maxi(1, int(dmg))
	tgt.hp -= final
	_log("  → %d de dano%s." % [final, " (eficaz!)" if _elem_mult(tgt, element) > 1.5 else (" (resistido)" if _elem_mult(tgt, element) < 1.0 else "")])
	if effects.size() > 0 and tgt.alive:
		var real_chance := chance
		if att.side == "party":
			real_chance *= (1.0 + (att.per - 8) * 0.05)
		for e in effects:
			if randf() < real_chance:
				if tgt.has_passive("resist_poison") and e == "poison":
					continue
				tgt.statuses[e] = 3 if e != "stun" else 1
				_log("  → %s sofre %s!" % [tgt.display_name, _status_name(e)])
	_refresh_bars()
	if tgt.hp <= 0:
		_kill(tgt, att)
	await get_tree().create_timer(0.65).timeout

func _move_name(att: BattleUnit, power: int, element: String) -> String:
	if power == 40 and element == "phys":
		return "ataque"
	return "uma habilidade"

func _status_name(e: String) -> String:
	return {"poison": "envenenamento", "bleed": "sangramento", "stun": "atordoamento", "slow": "lentidão", "fear": "medo", "regen": "regeneração"}.get(e, e)

func _elem_mult(tgt: BattleUnit, element: String) -> float:
	var m := 1.0
	if tgt.side == "foe":
		if element in tgt.enemy_def.get("weak", []):
			m = 2.0
		elif element in tgt.enemy_def.get("resist", []):
			m = 0.5
	if tgt.has_passive("resist_thermal") and element in ["fire", "water"]:
		m *= 0.75
	return m

func _act_analyze(att: BattleUnit, tgt: BattleUnit) -> void:
	var amount := 0.5
	var extra := ""
	if att.has_passive("magic_perception"):
		amount = 1.0
	GameState.bump_analyze(tgt.id, amount)
	var p := GameState.analyze_progress(tgt.id)
	var e: Dictionary = tgt.enemy_def
	if p >= 1.0:
		_log("[Grande Sábio] Análise completa de %s: PV %d, fraquezas %s, resistências %s." % [e.name, e.hp, ", ".join(e.weak) if e.weak.size() else "nenhuma", ", ".join(e.resist) if e.resist.size() else "nenhuma"])
	else:
		_log("[Grande Sábio] Análise de %s em %d%%. Dados parciais: PV %d." % [e.name, int(p * 100), e.hp])
	_refresh_bars()
	await get_tree().create_timer(0.9).timeout

func _absorb_reason(f: BattleUnit) -> String:
	if f.is_boss or f.enemy_def.get("absorb", "none") == "none":
		return "não pode ser devorado"
	if float(f.hp) / f.max_hp > 0.35:
		return "resiste (PV baixos necessários)"
	return "OK"

func _act_absorb(f: BattleUnit) -> void:
	var reason := _absorb_reason(f)
	if reason != "OK":
		_log("Predador falha: %s." % reason)
		await get_tree().create_timer(0.6).timeout
		return
	var e: Dictionary = f.enemy_def
	var prog := GameState.analyze_progress(f.id)
	_log("PREDADOR devora %s..." % f.display_name)
	await get_tree().create_timer(0.9).timeout
	var grants: Dictionary = e.get("grants", {})
	var got_something := false
	if grants.has("skill") and prog >= 1.0:
		var r := GameState.add_skill(grants.skill)
		var sname: String = Data.skills[grants.skill].name
		_log("[Predador] %s" % ("Nova habilidade: %s!" % sname if r == "new" else "Habilidade repetida → +12 XP."))
		got_something = true
	elif grants.has("skill"):
		_log("[Predador] Análise incompleta: absorveu apenas matéria-prima.")
	if grants.has("materials"):
		for k in grants.materials:
			GameState.add_material(k, int(grants.materials[k]))
			_log("[Predador] Material obtido: %s x%d" % [Data.items[k].name, int(grants.materials[k])])
		got_something = true
	if not got_something:
		_log("[Predador] Nada de valor... mas a informação foi arquivada.")
	GameState.bump_analyze(f.id, 0.2)
	_kill(f, null)
	await get_tree().create_timer(0.7).timeout

func _use_item(u: BattleUnit, item_id: String) -> void:
	var item: Dictionary = Data.items[item_id]
	GameState.add_consumable(item_id, -1)
	var eff: Dictionary = item.get("effect", {})
	if eff.has("escape"):
		if kind == "encounter":
			_log("Bomba de fumaça! Fuga garantida!")
			over = true
			_fled = true
			return
		_log("Inútil aqui...")
		return
	if eff.has("hp"):
		u.hp = mini(u.hp + int(eff.hp), u.max_hp)
		_log("%s usa %s: +%d PV." % [u.display_name, item.name, int(eff.hp)])
	if eff.has("mp"):
		u.mp = mini(u.mp + int(eff.mp), u.max_mp)
		_log("%s usa %s: +%d PM." % [u.display_name, item.name, int(eff.mp)])
	if eff.has("cure"):
		u.statuses.erase(eff.cure)
		_log("%s usa %s: status curado." % [u.display_name, item.name])
	_refresh_bars()
	await get_tree().create_timer(0.6).timeout

# ---------- IA inimiga ----------

func _enemy_turn(u: BattleUnit) -> void:
	await get_tree().create_timer(0.4).timeout
	var targets := party.filter(func(p): return p.alive)
	if targets.is_empty():
		return
	var target: BattleUnit = targets[randi() % targets.size()]
	if randf() < 0.3:
		var hurt := targets.duplicate()
		hurt.sort_custom(func(a, b): return float(a.hp) / a.max_hp < float(b.hp) / b.max_hp)
		target = hurt[0]
	var usable := []
	for sid in u.skills:
		var s: Dictionary = Data.skills[sid]
		if u.mp >= int(s.cost):
			usable.append(s)
	if usable.size() > 0 and randf() < 0.4:
		var s: Dictionary = usable[randi() % usable.size()]
		await _cast_skill(u, s)
	else:
		await _cast_core(u, target, 40, "phys", false, [], 0.0)

# ---------- fim ----------

func _kill(u: BattleUnit, _attacker) -> void:
	if not u.alive:
		return
	u.alive = false
	u.hp = 0
	if u.side == "foe":
		_log("%s foi derrotado!" % u.display_name)
		var e: Dictionary = u.enemy_def
		GameState.gain_xp(int(e.get("xp", 5)))
		if randf() < 0.4 and e.get("grants", {}).has("materials"):
			var mats: Dictionary = e.grants.materials
			var k: String = mats.keys()[randi() % mats.keys().size()]
			GameState.add_material(k, 1)
			_log("  → Material: %s x1" % Data.items[k].name)
	_refresh_bars()

func _finish() -> void:
	_clear_menu()
	if _fled:
		Flow.finish_battle("flee")
		await Flow.return_to_world()
		return
	var rim: BattleUnit = party[0]
	if not party.any(func(u): return u.alive):
		_log("Você foi derrotado... mas uma força antiga te envolve em sombras. Veldora te salva de novo.")
		GameState.p.hp = int(GameState.p.max_hp * 0.5)
		GameState.p.mp = int(GameState.p.max_mp * 0.5)
		GameState.gold = int(GameState.gold * 0.9)
		await get_tree().create_timer(2.4).timeout
		Flow.finish_battle("lose")
		SaveSystem.save_game()
		await Flow.return_to_world()
		return
	var win_gold := randi_range(4, 14) * (2 if kind == "fixed" else 1)
	GameState.gold += win_gold
	_log("Vitória! +%d ouro. (PV/PM persistem; descanse na Vila ou em Tempest)" % win_gold)
	if party.any(func(u): return u.is_rimuru):
		GameState.p.hp = maxi(1, rim.hp)
		GameState.p.mp = maxi(0, rim.mp)
	await get_tree().create_timer(1.6).timeout
	var after: String = battle_context.get("dialogue_after", "")
	Flow.finish_battle("win")
	if after != "":
		Flow.resume_dialogue = after
	SaveSystem.save_game()
	await Flow.return_to_world()

func _flash(spr: Sprite2D) -> void:
	if spr == null:
		return
	spr.modulate = Color(1, 0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(spr, "modulate", Color.WHITE, 0.35)
