extends Node2D

const TILE := 32
static var _shared_tileset: TileSet

var mapdef: Dictionary
var map_id: String
var player: SlimePlayer
var ground: TileMapLayer
var objects: TileMapLayer
var npcs: Array = []
var player_tiles := Vector2.ZERO
var busy := false
var hud: CanvasLayer
var toast_label: Label
var toast_timer := 0.0
var tracker: Label
var runner: DialogueRunner
var sage: SageMenu
var shop_panel: Control
var _encounter_acc := 0.0

func _ready() -> void:
	map_id = GameState.map_id
	mapdef = MapDef.get_map(map_id)
	if map_id == "tempest" and mapdef.has("dynamic_buildings"):
		for svc in mapdef["dynamic_buildings"]:
			if GameState.has_service(svc):
				var b: Dictionary = mapdef["dynamic_buildings"][svc]
				_stamp(b.x, b.y, b.w, b.h)
	_build_tileset()
	_build_layers()
	_spawn_player()
	_build_portals()
	_build_npcs()
	_build_hud()
	runner = DialogueRunner.new()
	add_child(runner)
	runner.request_battle.connect(_on_request_battle)
	runner.request_ending.connect(_on_request_ending)
	runner.request_map.connect(_on_request_map)
	runner.request_toast.connect(_toast)
	runner.request_shop.connect(_open_shop)
	runner.finished.connect(_on_dialogue_finished)
	sage = SageMenu.new()
	add_child(sage)
	if mapdef.get("rest", false):
		GameState.heal_full()
	_toast("Local: " + map_id.to_upper())
	_check_story()

func _stamp(x0: int, y0: int, w: int, h: int) -> void:
	var rows: Array = mapdef.layout
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			var ch := "W" if y > y0 else "R"
			rows[y] = rows[y].substr(0, x) + ch + rows[y].substr(x + 1)
	rows[y0 + h - 1] = rows[y0 + h - 1].substr(0, x0 + w / 2) + "D" + rows[y0 + h - 1].substr(x0 + w / 2 + 1)

func _build_tileset() -> void:
	if _shared_tileset != null:
		return
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/kenney_rpg/Spritesheet/roguelikeSheet_transparent.png")
	src.texture_region_size = Vector2i(16, 16)
	src.use_texture_padding = false
	ts.add_source(src, 0)
	for key in MapDef.TILES:
		var def: Dictionary = MapDef.TILES[key]
		var atlas: Array = def.atlas
		var coord := Vector2i(atlas[0], atlas[1])
		if not src.has_tile(coord):
			src.create_tile(coord)
		if def.get("solid", false):
			var poly := PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)])
			var td := src.get_tile_data(coord, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, poly)
	_shared_tileset = ts

func _tile_coords(atlas: Array) -> Vector2i:
	return Vector2i(atlas[0], atlas[1])

func _build_layers() -> void:
	ground = TileMapLayer.new()
	ground.tile_set = _shared_tileset
	ground.scale = Vector2(2, 2)
	add_child(ground)
	player = null
	objects = TileMapLayer.new()
	objects.tile_set = _shared_tileset
	objects.scale = Vector2(2, 2)
	add_child(objects)
	var rows: Array = mapdef.layout
	for y in rows.size():
		for x in rows[y].length():
			var ch: String = rows[y][x]
			var tname: String = MapDef.CHARS.get(ch, "grass")
			var def: Dictionary = MapDef.TILES[tname]
			var coord := _tile_coords(def.atlas)
			if tname in ["tree", "bush", "rock", "wall", "roof", "door"]:
				if tname == "tree":
					objects.set_cell(Vector2i(x, y - 1), 0, Vector2i(16, 9))
				objects.set_cell(Vector2i(x, y), 0, coord)
			else:
				ground.set_cell(Vector2i(x, y), 0, coord)

func _spawn_player() -> void:
	player = SlimePlayer.new()
	player.setup("res://assets/generated/rimuru.png")
	var px := int(GameState.pos.get("x", 10))
	var py := int(GameState.pos.get("y", 9))
	player.position = Vector2(px * TILE + TILE / 2.0, py * TILE + TILE / 2.0)
	var cam := Camera2D.new()
	var rows: Array = mapdef.layout
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = rows[0].length() * TILE
	cam.limit_bottom = rows.size() * TILE
	player.add_child(cam)
	add_child(player)
	player.z_index = 2
	objects.z_index = 3

func _build_portals() -> void:
	for p in mapdef.portals:
		var area := Area2D.new()
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		var w_tiles: int = p.get("w", 1)
		shape.size = Vector2(w_tiles * TILE, TILE)
		cs.shape = shape
		area.add_child(cs)
		area.position = Vector2(p.x * TILE + w_tiles * TILE / 2.0, p.y * TILE + TILE / 2.0)
		var meta: Dictionary = p.duplicate()
		area.set_meta("portal", meta)
		area.body_entered.connect(_on_portal.bind(meta))
		add_child(area)

func _portal_ok(p: Dictionary) -> bool:
	var req: String = p.get("requires", "")
	if req == "":
		return true
	if req.begins_with("flag:"):
		var f := req.substr(5)
		if f.begins_with("!"):
			return not GameState.flags.get(f.substr(1), false)
		return GameState.flags.get(f, false)
	return true

func _on_portal(body: Node, meta: Dictionary) -> void:
	if body != player:
		return
	if busy:
		return
	if not _portal_ok(meta):
		var msg: String = meta.get("locked_msg", "Caminho bloqueado.")
		_toast(msg)
		return
	busy = true
	Flow.goto_map(meta["to"], int(meta["tx"]), int(meta["ty"]))

func _meets(req: String) -> bool:
	if req == "":
		return true
	if req.begins_with("flag:"):
		var f := req.trim_prefix("flag:")
		if f.begins_with("!"):
			return not GameState.flags.get(f.trim_prefix("!"), false)
		return GameState.flags.get(f, false)
	if req.begins_with("service:"):
		var s := req.trim_prefix("service:")
		if s.begins_with("!"):
			return not GameState.has_service(s.trim_prefix("!"))
		return GameState.has_service(s)
	return true

func _build_npcs() -> void:
	for nd in mapdef.npcs:
		if not _meets(nd.get("requires", "")):
			continue
		if nd.has("hide_if") and GameState.flags.get(nd["hide_if"], false):
			continue
		var node := Node2D.new()
		node.position = Vector2(nd.x * TILE + TILE / 2.0, nd.y * TILE + TILE / 2.0)
		if nd.get("sprite", "") != "":
			var spr := Sprite2D.new()
			spr.texture = load("res://assets/generated/%s.png" % nd.sprite)
			var sc: float = nd.get("scale", 1.0) * 0.5
			spr.scale = Vector2(sc, sc)
			spr.region_enabled = true
			spr.region_rect = Rect2(0, 0, 32, 32)
			spr.offset = Vector2(0, -6)
			if nd.has("tint"):
				spr.modulate = Color(nd.tint[0], nd.tint[1], nd.tint[2])
			node.add_child(spr)
			node.z_index = 2
			var mark := Label.new()
			mark.text = "!"
			mark.position = Vector2(-4, -34)
			mark.add_theme_font_size_override("font_size", 16)
			mark.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
			node.add_child(mark)
		var area := Area2D.new()
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(28, 28)
		cs.shape = sh
		area.add_child(cs)
		node.add_child(area)
		npcs.append({"node": node, "data": nd})
		add_child(node)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 40
	add_child(hud)
	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.offset_left = 0
	toast_label.offset_right = 0
	toast_label.offset_top = 6
	toast_label.offset_bottom = 46
	toast_label.add_theme_font_size_override("font_size", 12)
	toast_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1))
	toast_label.modulate.a = 0.0
	hud.add_child(toast_label)
	tracker = Label.new()
	tracker.position = Vector2(6, 6)
	tracker.add_theme_font_size_override("font_size", 11)
	tracker.add_theme_color_override("font_color", Color(0.8, 0.85, 0.6))
	var lines := []
	for qid in GameState.quests:
		if GameState.quest_state(qid) == "active":
			lines.append("► " + Data.quests[qid].name)
	if lines.size() == 0:
		lines.append("Tempest: Rise of Tempest")
	tracker.text = "\n".join(lines.slice(0, 3))
	hud.add_child(tracker)
	var gold_lbl := Label.new()
	gold_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gold_lbl.offset_left = -120
	gold_lbl.offset_right = -6
	gold_lbl.offset_top = 6
	gold_lbl.offset_bottom = 24
	gold_lbl.add_theme_font_size_override("font_size", 12)
	gold_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	gold_lbl.text = "Ouro: %d" % GameState.gold
	hud.add_child(gold_lbl)

func _toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	toast_timer = 3.0

func _check_story() -> void:
	if Flow.last_result == "win" and Flow.resume_dialogue != "":
		var node_id: String = Flow.resume_dialogue
		Flow.resume_dialogue = ""
		Flow.last_result = ""
		_open_dialogue(node_id)
		return
	if map_id == "cave" and not GameState.flags.get("prologue_started", false):
		GameState.flags["prologue_started"] = true
		_open_dialogue("prologue_wake")
		return
	if map_id == "tempest" and not GameState.flags.get("founding_done", false) and GameState.flags.get("boss_lobo_done", false):
		_open_dialogue("tempest_found")
		return

func _on_dialogue_finished() -> void:
	busy = false
	if player != null:
		player.disabled = sage.open if sage != null else false
	SaveSystem.save_game()
	if map_id == "forest":
		for n in npcs:
			if not _meets(n.data.get("requires", "")):
				n.node.queue_free()
		npcs = npcs.filter(func(n): return _meets(n.data.get("requires", "")))

func _open_dialogue(node_id: String) -> void:
	busy = true
	player.disabled = true
	runner.start(node_id)

func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_label.modulate.a = 0.0
	if Input.is_action_just_pressed("sage_menu") and not busy and not runner.active:
		sage.toggle()
		player.disabled = sage.open
	if Input.is_action_just_pressed("interact") and not busy and not runner.active and not sage.open:
		_try_interact()
	if Input.is_action_just_pressed("cancel"):
		if shop_panel != null and shop_panel.visible:
			_close_shop()
		elif sage.open:
			sage.close()
			player.disabled = false

func _physics_process(delta: float) -> void:
	if player == null or busy:
		return
	GameState.pos = {"x": int(player.position.x / TILE), "y": int(player.position.y / TILE)}
	if player.velocity.length() > 1.0:
		_encounter_acc += player.velocity.length() * delta / TILE
		while _encounter_acc >= 1.0:
			_encounter_acc -= 1.0
			_roll_encounter()

func _current_pool() -> String:
	for z in mapdef.zones:
		var px := int(GameState.pos.x)
		var py := int(GameState.pos.y)
		if px >= z.x and px < z.x + z.w and py >= z.y and py < z.y + z.h:
			return z.pool
	var pool: String = mapdef.encounter
	if pool == "":
		return ""
	if map_id == "cave" and not GameState.flags.get("prologue_started", false):
		return ""
	return pool

func _roll_encounter() -> void:
	if busy:
		return
	var pool := _current_pool()
	if pool == "":
		return
	var pdata: Dictionary = Data.encounters.pools.get(pool, {})
	if pdata.is_empty():
		return
	GameState.step_since_battle += 1.0
	var rate: float = pdata.get("rate", 0.08)
	if randf() < rate:
		var groups: Array = pdata.groups
		var group: Array = groups[randi() % groups.size()]
		busy = true
		player.disabled = true
		Flow.launch_battle(group, "encounter", {})

func _try_interact() -> void:
	var best: Variant = null
	var best_d := 48.0
	for n in npcs:
		var d: float = player.position.distance_to(n.node.position)
		if d < best_d:
			best_d = d
			best = n
	if best != null:
		_open_dialogue(best.data.dialogue)

func _on_request_battle(group: Array, after_goto: String) -> void:
	Flow.launch_battle(group, "fixed", {"dialogue_after": after_goto})

func _on_request_ending(kind: String) -> void:
	SaveSystem.save_game()
	Flow.show_ending(kind)

func _on_request_map(map_to: String, x: int, y: int) -> void:
	busy = true
	Flow.goto_map(map_to, x, y)

func _open_shop() -> void:
	busy = true
	player.disabled = true
	shop_panel = PanelContainer.new()
	shop_panel.set_anchors_preset(Control.PRESET_CENTER)
	shop_panel.position = Vector2(200, 60)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.14, 0.95)
	style.border_color = Color(0.4, 0.8, 0.9)
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	shop_panel.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	shop_panel.add_child(vbox)
	var title := Label.new()
	title.text = "Loja da Vila Jura"
	title.add_theme_color_override("font_color", Color(0.5, 0.9, 1))
	vbox.add_child(title)
	var items := [["potion_s", 15], ["potion_l", 40], ["ether_s", 20], ["antidote", 10], ["smoke_ball", 25], ["rice_cracker", 10]]
	for entry in items:
		var id: String = entry[0]
		var price: int = entry[1]
		if id == "rice_cracker" and not GameState.has_service("kitchen"):
			continue
		var b := Button.new()
		b.text = "%s — %d ouro" % [Data.items[id].name, price]
		b.pressed.connect(_buy.bind(id, price))
		vbox.add_child(b)
	var close_b := Button.new()
	close_b.text = "Sair [X]"
	close_b.pressed.connect(_close_shop)
	vbox.add_child(close_b)
	hud.add_child(shop_panel)

func _buy(id: String, price: int) -> void:
	if GameState.gold >= price:
		GameState.gold -= price
		GameState.add_consumable(id, 1)
		_toast("Comprou " + Data.items[id].name)
	else:
		_toast("Ouro insuficiente!")

func _close_shop() -> void:
	if shop_panel != null:
		shop_panel.queue_free()
		shop_panel = null
	busy = false
	player.disabled = false
