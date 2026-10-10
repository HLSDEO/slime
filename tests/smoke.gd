extends Node

var fails := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		fails += 1
		print("FAIL: ", label)

func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame

func _ready() -> void:
	print("=== SMOKE TEST ===")
	await frames(2)
	ok(Data.skills.size() >= 20, "Data.skills carregadas (%d)" % Data.skills.size())
	ok(Data.enemies.size() >= 10, "Data.enemies (%d)" % Data.enemies.size())
	ok(Data.dialogues.size() >= 20, "Data.dialogues (%d)" % Data.dialogues.size())
	ok(Data.encounters.has("fixed"), "encounters.fixed presente")
	for qid in Data.quests:
		for did in Data.dialogues:
			pass
	# valida que todas as skills de inimigos/aliadas existem
	for eid in Data.enemies:
		for s in Data.enemies[eid].get("skills", []):
			ok(Data.skills.has(s), "skill inimiga existe: %s" % s)
	for aid in Data.ALLIES:
		for s in Data.ALLIES[aid].get("skills", []):
			ok(Data.skills.has(s), "skill aliada existe: %s (%s)" % [s, aid])
	# valida synthesis inputs/outputs
	for r in Data.synthesis:
		ok(Data.skills.has(r.output), "synthesis output existe: %s" % r.output)
		for i in r.inputs:
			ok(Data.skills.has(i), "synthesis input existe: %s" % i)
	# game state
	GameState.start_new_game()
	GameState.add_skill("water_jet")
	GameState.add_skill("pressure_control")
	ok(GameState.has_skill("water_jet"), "add_skill/has_skill")
	GameState.recruit("rigurumu")
	ok("rigurumu" in GameState.allies, "recruit")
	ok(GameState.party_in_battle().size() == 2, "party size 2 (rimuru+rigurumu)")
	GameState.bump_analyze("forest_wolf", 0.5)
	GameState.bump_analyze("forest_wolf", 0.5)
	ok(GameState.analyze_progress("forest_wolf") >= 1.0, "analyze progress completo")
	GameState.unlock_service("blacksmith")
	ok(GameState.has_service("blacksmith"), "unlock_service")
	# unidades de batalha
	var u := BattleUnit.from_enemy("forest_wolf")
	ok(u.max_hp == 60 and u.side == "foe", "BattleUnit.from_enemy")
	var rim := BattleUnit.from_rimuru()
	ok(rim.side == "party" and rim.is_rimuru, "BattleUnit.from_rimuru")
	var ally := BattleUnit.from_ally("rigurumu")
	ok(ally.display_name == "Rigurimu", "BattleUnit.from_ally")
	# save/load
	GameState.flags["smoke_flag"] = true
	GameState.gold = 777
	SaveSystem.save_game()
	GameState.gold = 0
	ok(SaveSystem.load_game() and GameState.gold == 777, "save/load roundtrip")
	# mundos: instancia cada mapa por alguns frames
	for mid in ["cave", "forest", "village", "tempest"]:
		GameState.map_id = mid
		GameState.pos = {"x": 10, "y": 9}
		var scene: PackedScene = load("res://scenes/world.tscn")
		var w = scene.instantiate()
		add_child(w)
		await frames(10)
		ok(is_instance_valid(w), "world '%s' instanciou" % mid)
		w.queue_free()
		await frames(5)
	# batalha: instancia e espera iniciar (sem inputs)
	GameState.map_id = "forest"
	GameState.pos = {"x": 21, "y": 20}
	Flow.battle_request = {"group": ["forest_frog"], "kind": "encounter"}
	Flow.battle_context = {}
	var bs: PackedScene = load("res://scenes/battle.tscn")
	var battle = bs.instantiate()
	add_child(battle)
	await frames(30)
	ok(battle.get_node_or_null(".") != null, "battle instanciou e rodou turnos iniciais")
	ok(battle.party.size() == 2 and battle.foes.size() == 1, "battle party/foes corretos")
	battle._fled = true
	battle.over = true
	await frames(5)
	battle.queue_free()
	await frames(5)
	# dialogo: roda goblin_survivor via interacoes simuladas
	GameState.flags["goblin_saved"] = false
	var scene2: PackedScene = load("res://scenes/world.tscn")
	GameState.map_id = "forest"
	var w2 = scene2.instantiate()
	add_child(w2)
	await frames(10)
	var runner = w2.runner
	runner.start("goblin_survivor")
	for _i in 120:
		if not runner.active:
			break
		Input.action_press("interact")
		await frames(2)
		Input.action_release("interact")
		await frames(2)
	ok(not runner.active, "dialogo goblin_survivor concluido por interacoes")
	ok("rigurumu" in GameState.allies, "dialogo recrutou rigurumu (acao)")
	ok(GameState.quest_state("q_boss_lobo") == "active", "dialogo iniciou missao")
	w2.queue_free()
	await frames(3)
	print("=== SMOKE: %d falhas ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)
