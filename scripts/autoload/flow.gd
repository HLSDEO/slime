extends Node

var battle_request := {}      # {"group": [...], "kind": "encounter|fixed", "context": {...}}
var battle_context := {}      # retornado ao mundo após batalha
var last_result := ""         # win / flee / lose
var resume_dialogue := ""     # nó de diálogo a continuar pós-batalha
var pending_ending := ""

var _fade_rect: ColorRect

func _ready() -> void:
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.modulate.a = 0.0
	_fade_rect.z_index = 100
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.add_child(_fade_rect)
	add_child(layer)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := get_tree().root
	root.size_changed.connect(func():
		_fade_rect.size = root.get_visible_rect().size)
	_fade_rect.size = Vector2(1280, 720)
	_fade_rect.position = Vector2.ZERO
	_fade_rect.anchors_preset = Control.PRESET_FULL_RECT

func goto_map(map_id: String, tile_x: int, tile_y: int, autosave := true) -> void:
	GameState.map_id = map_id
	GameState.pos = {"x": tile_x, "y": tile_y}
	GameState.step_since_battle = 0.0
	if autosave and GameState.flags.size() > 0:
		SaveSystem.save_game()
	await _fade(true)
	get_tree().change_scene_to_file("res://scenes/world.tscn")
	await _fade(false)

func launch_battle(group: Array, kind: String, context := {}) -> void:
	battle_request = {"group": group, "kind": kind}
	battle_context = context
	await _fade(true)
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

func finish_battle(result: String) -> void:
	last_result = result
	battle_request = {}

func return_to_world() -> void:
	await _fade(true)
	get_tree().change_scene_to_file("res://scenes/world.tscn")
	await _fade(false)

func show_ending(kind: String) -> void:
	pending_ending = kind
	await _fade(true)
	get_tree().change_scene_to_file("res://scenes/ending.tscn")
	await _fade(false)

func to_menu() -> void:
	await _fade(true)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	await _fade(false)

func _fade(in_dir: bool) -> void:
	var tw := create_tween()
	tw.tween_property(_fade_rect.modulate, "a", 1.0 if in_dir else 0.0, 0.25)
	await tw.finished
