class_name SlimePlayer
extends CharacterBody2D

const SPEED := 96.0
const DASH_SPEED := 168.0
const TILE := 32

var disabled := false
var facing := "down"
var anim_time := 0.0
var sprite: Sprite2D
var _sheets := {}

func setup(tex_path: String) -> void:
	var tex := load(tex_path)
	for i in 6:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 32, 0, 32, 32)
		_sheets[i] = at
	sprite = Sprite2D.new()
	sprite.texture = _sheets[0]
	sprite.offset = Vector2(0, -8)
	add_child(sprite)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 10)
	cs.shape = shape
	cs.position = Vector2(0, 10)
	add_child(cs)

func _physics_process(delta: float) -> void:
	if disabled:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := DASH_SPEED if Input.is_action_pressed("dash") else SPEED
	velocity = dir * speed
	move_and_slide()
	if dir != Vector2.ZERO:
		anim_time += delta
		if absf(dir.x) >= absf(dir.y):
			facing = "right" if dir.x > 0 else "left"
		else:
			facing = "down" if dir.y > 0 else "up"
	var base := 0
	if facing == "down":
		base = 0
	elif facing == "up":
		base = 4
	else:
		base = 2
	var fi := base + (1 if fmod(anim_time, 0.3) < 0.15 and dir != Vector2.ZERO else 0)
	sprite.texture = _frame(fi)
	sprite.flip_h = facing == "left"

func _frame(i: int) -> AtlasTexture:
	return _sheets[i]
