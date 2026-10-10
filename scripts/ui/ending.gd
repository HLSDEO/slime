extends Control

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.07, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var deco := Sprite2D.new()
	deco.texture = load("res://assets/generated/rimuru.png")
	deco.region_enabled = true
	deco.region_rect = Rect2(0, 0, 32, 32)
	deco.scale = Vector2(5, 5)
	deco.position = Vector2(320, 80)
	add_child(deco)
	var v := VBoxContainer.new()
	v.position = Vector2(60, 160)
	v.custom_minimum_size = Vector2(520, 0)
	add_child(v)
	var t := Label.new()
	t.text = "TEMPEST — VILA FUNDADA"
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Color(0.5, 0.9, 1))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var r: Dictionary = GameState.resources
	var stats := Label.new()
	stats.text = "População: %d   Comida: %d   Material: %d   Ouro: %d" % [r.get("population", 0), r.get("food", 0), r.get("material", 0), GameState.gold]
	stats.add_theme_font_size_override("font_size", 14)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stats)
	var skills_lbl := Label.new()
	skills_lbl.text = "Habilidades dominadas: %d   Aliados: %d   Serviços: %d" % [GameState.skills.size(), GameState.allies.size(), GameState.services.size()]
	skills_lbl.add_theme_font_size_override("font_size", 13)
	skills_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	skills_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(skills_lbl)
	var next_lbl := Label.new()
	next_lbl.text = "\nCapítulos futuros: diplomacia com Dwargon, a Academia das Almas,\ne o despertar do Lorde Demônio do oeste..."
	next_lbl.add_theme_font_size_override("font_size", 12)
	next_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(next_lbl)
	var b := Button.new()
	b.text = "Voltar ao menu"
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): Flow.to_menu())
	v.add_child(b)
