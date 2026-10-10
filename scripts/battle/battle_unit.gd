class_name BattleUnit
extends RefCounted

var id := ""
var display_name := ""
var side := "party"   # party | foe
var sprite := "rimuru"
var is_rimuru := false
var is_boss := false
var enemy_def := {}

var max_hp := 10
var hp := 10
var max_mp := 0
var mp := 0
var atk := 5
var mag := 5
var defense := 5
var res := 5
var agi := 5
var per := 8

var skills: Array = []
var statuses := {}    # id -> turns remaining
var defending := false
var alive := true

func is_deadly() -> bool:
	return not alive

static func from_enemy(eid: String) -> BattleUnit:
	var u := BattleUnit.new()
	var d: Dictionary = Data.enemies[eid]
	u.id = eid
	u.display_name = d.name
	u.side = "foe"
	u.sprite = d.sprite
	u.is_boss = d.get("boss", false)
	u.enemy_def = d
	u.max_hp = int(d.hp)
	u.hp = u.max_hp
	u.max_mp = int(d.mp)
	u.mp = u.max_mp
	u.atk = int(d.atk)
	u.mag = int(d.mag)
	u.defense = int(d.def)
	u.res = int(d.res)
	u.agi = int(d.agi)
	u.per = int(d.per)
	for s in d.get("skills", []):
		u.skills.append(s)
	return u

static func from_rimuru() -> BattleUnit:
	var u := BattleUnit.new()
	var p: Dictionary = GameState.p
	u.id = "rimuru"
	u.display_name = "Rimuru"
	u.side = "party"
	u.is_rimuru = true
	u.sprite = "rimuru"
	u.max_hp = int(p.max_hp)
	u.hp = int(p.hp)
	u.max_mp = int(p.max_mp)
	u.mp = int(p.mp)
	u.atk = int(p.atk)
	u.mag = int(p.mag)
	u.defense = int(p.def)
	u.res = int(p.res)
	u.agi = int(p.agi)
	u.per = int(p.per)
	u.skills = GameState.active_skills()
	return u

static func from_ally(aid: String) -> BattleUnit:
	var u := BattleUnit.new()
	var d: Dictionary = Data.ALLIES[aid]
	u.id = aid
	u.display_name = d.name
	u.side = "party"
	u.sprite = d.sprite
	u.max_hp = int(d.hp)
	u.hp = u.max_hp
	u.max_mp = int(d.mp)
	u.mp = u.max_mp
	u.atk = int(d.atk)
	u.mag = int(d.mag)
	u.defense = int(d.def)
	u.res = int(d.res)
	u.agi = int(d.agi)
	u.per = int(d.per)
	u.skills = d.get("skills", [])
	return u

func has_passive(id2: String) -> bool:
	if side == "party" and is_rimuru:
		return GameState.has_skill(id2)
	return false

func eff_agi() -> int:
	var a := agi
	if statuses.has("slow"):
		a = int(a / 2.0)
	if has_passive("swift"):
		a = int(a * 1.2)
	return a
