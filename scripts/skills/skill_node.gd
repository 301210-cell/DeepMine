extends Control
## One hexagonal skill socket in the DeepMine skill tree.
## Pure presentation: the SkillTreePanel owns input (hover/click/drag) and calls refresh()/set_* here.
## Draws: additive glow (child "Glow"), tinted hex fill + frame, 2x icon, rank pips, lock, MAX badge,
## selection ring, "???" fog for hidden branches, pulse when affordable, pop on unlock.

const HEX_W := 52.0
const HEX_H := 60.0
const CENTER := Vector2(26, 30)

const P_FRAME := "res://assets/ui/hex_frame.png"
const P_FILL := "res://assets/ui/hex_fill.png"
const P_GLOW := "res://assets/ui/hex_glow.png"
const P_SELECT := "res://assets/ui/hex_select.png"
const P_CORE := "res://assets/ui/hex_core.png"
const P_LOCK := "res://assets/ui/hex_lock.png"
const P_MAX := "res://assets/ui/hex_max.png"
const P_FONT := "res://assets/fonts/pixel.fnt"
const P_FONT_BIG := "res://assets/fonts/pixel_big.fnt"

const GOLD := Color(1.0, 0.83, 0.32)
const GOLD_LIGHT := Color(1.0, 0.95, 0.66)

var skill_id := ""
var branch_id := ""
var branch_color := Color.WHITE
var glow_color := Color.WHITE
var is_core := false
var is_capstone := false
var state := 0              # SkillManager.State
var rank := 0
var max_rank := 1
var selected := false
var hovered := false
var dimmed := false         # tutorial spotlight: everything except the focus is dimmed
var reveal_level := 1

var _time := 0.0
var _hover_amt := 0.0
var _pop_tween: Tween
var _icon: Texture2D
var _initials := ""

static var _tex: Dictionary = {}

@onready var _glow: Control = $Glow

static func tex(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex[path] = t
	return t

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = CENTER
	_glow.draw.connect(_draw_glow)

func setup(id: String) -> void:
	skill_id = id
	var s := ResourceDatabase.skill(id)
	branch_id = s.get("branch", "core")
	var br := ResourceDatabase.branch(branch_id)
	branch_color = Color(br.get("color", "ffffff"))
	glow_color = Color(br.get("glow", "ffffff"))
	reveal_level = int(br.get("reveal_level", 1))
	is_core = branch_id == "core"
	is_capstone = s.get("capstone", false)
	max_rank = int(s.get("max_rank", 1))
	_icon = ResourceDatabase.skill_icon(id) if ResourceLoader.exists(ResourceDatabase.PATH_SKILLS) else null
	_initials = initials_for(String(s.get("name", "?")))
	refresh()

func refresh() -> void:
	state = SkillManager.state(skill_id)
	rank = SkillManager.rank(skill_id)
	queue_redraw()
	if is_instance_valid(_glow):
		_glow.queue_redraw()

func set_selected(v: bool) -> void:
	if selected != v:
		selected = v
		queue_redraw()

func set_hovered(v: bool) -> void:
	hovered = v

func set_dimmed(v: bool) -> void:
	dimmed = v
	modulate = Color(0.32, 0.33, 0.42) if v else Color.WHITE

## Bouncy pop used when a rank is bought.
func pop() -> void:
	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()
	scale = Vector2.ONE * 1.32
	_pop_tween = create_tween()
	_pop_tween.tween_property(self, "scale", Vector2.ONE * (1.08 if hovered else 1.0), 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## Hexagon hit test in local coordinates (pointy-top, slightly inset).
func hit(local: Vector2) -> bool:
	var p := (local - CENTER).abs()
	var hw := HEX_W * 0.5 - 1.0
	var hh := HEX_H * 0.5 - 1.0
	if p.x > hw or p.y > hh:
		return false
	# pointy-top: top/bottom edges slope from the side corners (y = hh/2) to the tip (y = hh)
	return p.y <= hh - (hh * 0.5) * (p.x / hw)

func _process(delta: float) -> void:
	_time += delta
	var target := 1.0 if hovered else 0.0
	var prev := _hover_amt
	_hover_amt = move_toward(_hover_amt, target, delta * 8.0)
	if not (_pop_tween and _pop_tween.is_running()):
		scale = Vector2.ONE * (1.0 + 0.08 * _ease(_hover_amt))
	var animating := state == SkillManager.State.AFFORDABLE or selected or state == SkillManager.State.MAXED or is_core
	if animating or prev != _hover_amt:
		queue_redraw()
		_glow.queue_redraw()

func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

func _pulse(speed: float = 3.2) -> float:
	return 0.5 + 0.5 * sin(_time * speed)

# ------------------------------------------------------------------ drawing
func _draw_glow() -> void:
	var g := tex(P_GLOW)
	if g == null:
		return
	var col := glow_color
	var a := 0.0
	match state:
		SkillManager.State.AFFORDABLE:
			a = 0.28 + 0.32 * _pulse()
		SkillManager.State.AVAILABLE:
			a = 0.12
		SkillManager.State.UNLOCKED:
			a = 0.5
		SkillManager.State.MAXED:
			col = GOLD
			a = 0.55 + 0.12 * _pulse(2.0)
	if is_core:
		col = Color(0.55, 0.95, 1.0)
		a = 0.55 + 0.15 * _pulse(1.6)
	if selected:
		a = maxf(a, 0.6) + 0.15 * _pulse(5.0)
	a += 0.18 * _hover_amt
	if a <= 0.01:
		return
	col.a = clampf(a, 0.0, 1.0)
	var gs := g.get_size()
	var scale_g := 1.25 if is_core else 1.0
	_glow.draw_texture_rect(g, Rect2(CENTER - gs * 0.5 * scale_g, gs * scale_g), false, col)

func _draw() -> void:
	var font: Font = tex_font(P_FONT)
	if is_core:
		_draw_core()
		return
	var fill := tex(P_FILL)
	var frame := tex(P_FRAME)
	var fill_col := Color(0.13, 0.14, 0.21)
	var frame_col := Color(0.34, 0.37, 0.48)
	var icon_col := Color(0.42, 0.44, 0.54, 0.85)
	match state:
		SkillManager.State.HIDDEN:
			fill_col = Color(0.06, 0.07, 0.12)
			frame_col = Color(0.19, 0.21, 0.29)
		SkillManager.State.LOCKED:
			pass
		SkillManager.State.AVAILABLE:
			fill_col = branch_color.darkened(0.68)
			frame_col = branch_color.darkened(0.2)
			icon_col = Color(0.85, 0.87, 0.92, 0.9)
		SkillManager.State.AFFORDABLE:
			fill_col = branch_color.darkened(0.62 - 0.1 * _pulse())
			frame_col = glow_color.lerp(Color.WHITE, 0.25 * _pulse())
			icon_col = Color.WHITE
		SkillManager.State.UNLOCKED:
			fill_col = branch_color.darkened(0.08)
			frame_col = branch_color.lerp(Color.WHITE, 0.4)
			icon_col = Color.WHITE
		SkillManager.State.MAXED:
			fill_col = branch_color.lerp(Color.WHITE, 0.08)
			frame_col = GOLD.lerp(GOLD_LIGHT, 0.3 * _pulse(2.0))
			icon_col = Color.WHITE
	if is_capstone and state != SkillManager.State.HIDDEN:
		var sel := tex(P_SELECT)
		if sel:
			var cap_col := GOLD.darkened(0.35) if state != SkillManager.State.MAXED else GOLD
			cap_col.a = 0.85
			draw_texture(sel, CENTER - sel.get_size() * 0.5, cap_col)
	if fill:
		draw_texture(fill, Vector2.ZERO, fill_col)
	if frame:
		draw_texture(frame, Vector2.ZERO, frame_col)

	if state == SkillManager.State.HIDDEN:
		var big: Font = tex_font(P_FONT_BIG)
		if big:
			_draw_centered_text(big, "?", CENTER + Vector2(0, 6), 16, Color(0.36, 0.4, 0.55))
		return

	if _icon == null:
		_draw_centered_text(tex_font(P_FONT_BIG), _initials, CENTER + Vector2(0, 3), 16, icon_col)
	# Icon at 2x (16 -> 32), nudged up to leave room for rank pips.
	if _icon:
		var icon_rect := Rect2(CENTER + Vector2(-16, -19), Vector2(32, 32))
		# soft drop shadow for readability on bright fills
		draw_texture_rect(_icon, Rect2(icon_rect.position + Vector2(1, 1), icon_rect.size), false, Color(0, 0, 0, 0.45 * icon_col.a))
		draw_texture_rect(_icon, icon_rect, false, icon_col)

	if state == SkillManager.State.LOCKED:
		var lock := tex(P_LOCK)
		if lock:
			draw_texture(lock, CENTER + Vector2(-8, 2))

	_draw_pips()

	if state == SkillManager.State.MAXED:
		var mx := tex(P_MAX)
		if mx:
			draw_texture(mx, Vector2(CENTER.x - mx.get_width() * 0.5, HEX_H - mx.get_height() - 1))

	if selected:
		var sel2 := tex(P_SELECT)
		if sel2:
			var c := Color(1, 1, 1, 0.75 + 0.25 * _pulse(5.0))
			draw_texture(sel2, CENTER - sel2.get_size() * 0.5, c)

func _draw_core() -> void:
	var core := tex(P_CORE)
	if core:
		draw_texture(core, CENTER - core.get_size() * 0.5)
	if _icon == null:
		_draw_centered_text(tex_font(P_FONT_BIG), "MC", CENTER + Vector2(0, 5), 16, Color.WHITE)
	if _icon:
		var r := Rect2(CENTER + Vector2(-16, -17), Vector2(32, 32))
		draw_texture_rect(_icon, Rect2(r.position + Vector2(1, 1), r.size), false, Color(0, 0, 0, 0.5))
		draw_texture_rect(_icon, r, false, Color.WHITE)
	if selected:
		var sel := tex(P_SELECT)
		if sel:
			var s := sel.get_size() * 1.2
			draw_texture_rect(sel, Rect2(CENTER - s * 0.5, s), false, Color(1, 1, 1, 0.75 + 0.25 * _pulse(5.0)))

func _draw_pips() -> void:
	if max_rank <= 1:
		return
	var pip_w := 4.0
	var gap := 2.0
	var total := max_rank * pip_w + (max_rank - 1) * gap
	var x0 := roundf(CENTER.x - total * 0.5)
	var y := 45.0
	for i in max_rank:
		var r := Rect2(x0 + i * (pip_w + gap), y, pip_w, 3)
		draw_rect(r.grow(1), Color(0.03, 0.04, 0.08, 0.9))
		var on := i < rank
		var c := Color(0.2, 0.22, 0.3)
		if on:
			c = GOLD if state == SkillManager.State.MAXED else Color.WHITE
		draw_rect(r, c)
		if on:
			draw_rect(Rect2(r.position, Vector2(pip_w, 1)), c.lightened(0.5))

func _draw_centered_text(font: Font, text: String, baseline_center: Vector2, size: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(roundf(baseline_center.x - w * 0.5), roundf(baseline_center.y))
	draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.7))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

static func tex_font(path: String) -> Font:
	if _tex.has(path):
		return _tex[path]
	var f: Font = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	_tex[path] = f
	return f

static func initials_for(name: String) -> String:
	var words := name.replace("'", "").split(" ", false)
	if words.size() >= 2:
		return (words[0].substr(0, 1) + words[1].substr(0, 1)).to_upper()
	return name.substr(0, 2).to_upper()
