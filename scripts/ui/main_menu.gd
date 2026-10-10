extends Control

var bg: ColorRect
var title_label: Label
var subtitle_label: Label
var buttons_box: VBoxContainer

func _ready() -> void:
	bg = ColorRect.new()
	bg.color = Color(0.05, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var deco := Sprite2D.new()
	deco.texture = load("res://assets/generated/rimuru.png")
	deco.region_enabled = true
	deco.region_rect = Rect2(0, 0, 32, 32)
	deco.scale = Vector2(4, 4)
	deco.position = Vector2(320, 120)
	add_child(deco)
	title_label = Label.new()
	title_label.text = "SLIME: RISE OF TEMPEST"
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(0.5, 0.9, 1))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0, 180)
	title_label.size = Vector2(640, 40)
	add_child(title_label)
	subtitle_label = Label.new()
	subtitle_label.text = "Demonstração — Prólogo + Capítulos 1 e 2"
	subtitle_label.add_theme_font_size_override("font_size", 12)
	subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.position = Vector2(0, 218)
	subtitle_label.size = Vector2(640, 20)
	add_child(subtitle_label)
	buttons_box = VBoxContainer.new()
	buttons_box.position = Vector2(250, 260)
	buttons_box.custom_minimum_size = Vector2(140, 0)
	add_child(buttons_box)
	var new_b := Button.new()
	new_b.text = "Novo Jogo"
	new_b.pressed.connect(_new_game)
	buttons_box.add_child(new_b)
	var cont_b := Button.new()
	cont_b.text = "Continuar"
	cont_b.disabled = not SaveSystem.has_save()
	cont_b.pressed.connect(_continue)
	buttons_box.add_child(cont_b)
	var help_b := Button.new()
	help_b.text = "Controles"
	help_b.pressed.connect(_show_help)
	buttons_box.add_child(help_b)
	var quit_b := Button.new()
	quit_b.text = "Sair"
	quit_b.pressed.connect(func(): get_tree().quit())
	buttons_box.add_child(quit_b)

func _new_game() -> void:
	GameState.start_new_game()
	GameState.map_id = "cave"
	GameState.pos = {"x": 10, "y": 9}
	Flow.goto_map("cave", 10, 9, false)

func _continue() -> void:
	if SaveSystem.load_game():
		Flow.goto_map(GameState.map_id, int(GameState.pos.x), int(GameState.pos.y), false)

func _show_help() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(150, 60)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.14, 0.97)
	style.border_color = Color(0.4, 0.8, 0.9)
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var l := Label.new()
	l.text = "WASD/Setas — mover    Shift — correr\nE/Z/Enter — interagir/confirmar\nX/Esc — cancelar    Q — Grande Sábio\nGamepad: D-pad, A=confirmar, B=cancelar, LB=menu"
	l.add_theme_font_size_override("font_size", 13)
	panel.add_child(l)
	add_child(panel)
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_callback(panel.queue_free)
