extends Control
## DeepMine skill tree panel: a connected pixel-art honeycomb of skill hexes.
## Drag to pan, wheel/pinch/+/- to zoom, hover for the info card, click to upgrade.
## Data and rules come from SkillManager / ResourceDatabase; this file is presentation + input only.
## UIRoot contract: open(data) / close_requested. data may be {"focus": skill_id} for the tutorial.

signal close_requested

const SkillNodeScene := preload("res://scenes/ui/SkillNode.tscn")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const SkillNodeScript := preload("res://scripts/skills/skill_node.gd")

const HEX_R := 34.0
const SQRT3 := 1.7320508
const NODE_HALF := Vector2(26, 30)
const MIN_ZOOM := 0.32
const MAX_ZOOM := 2.2
const DRAG_THRESHOLD := 5.0
const PARTICLES := "res://assets/sprites/effects/particles.png"
const ARROW := "res://assets/ui/arrow_bounce.png"
const BAR_VARIATION := {"mining": &"ProgressOrange", "exploration": &"ProgressGreen", "equipment": &"", "engineering": &"ProgressPurple", "core": &"ProgressGold"}
## Where each branch's name is written on the tree (canvas px, around the core).
const BRANCH_LABEL_POS := {"mining": Vector2(150, -96), "exploration": Vector2(40, -116), "equipment": Vector2(-96, 40), "engineering": Vector2(126, 104)}

@onready var tree_viewport: Control = %TreeViewport
@onready var tree_canvas: Control = %TreeCanvas
@onready var connections: Control = %ConnectionLines
@onready var branch_labels: Control = %BranchLabels
@onready var nodes_root: Control = %SkillNodes
@onready var fx: Control = %Fx
@onready var bg_tile: TextureRect = %BgTile
@onready var vignette: TextureRect = %Vignette
@onready var level_label: Label = %LevelLabel
@onready var sp_label: Label = %AvailableSkillPoints
@onready var legend: HBoxContainer = %BranchFilters
@onready var minimap: PanelContainer = %Minimap
@onready var hint: Label = %Hint
@onready var details: PanelContainer = %SkillDetailsPanel
@onready var card_art: PanelContainer = %CardArt
@onready var card_icon: TextureRect = %SkillIcon
@onready var card_name: Label = %SkillName
@onready var card_branch: Label = %BranchName
@onready var card_rank: Label = %RankLabel
@onready var card_bar: ProgressBar = %RankBar
@onready var card_desc: Label = %Description
@onready var card_now: RichTextLabel = %NowLabel
@onready var card_next: RichTextLabel = %NextLabel
@onready var card_cost_row: HBoxContainer = %CostRow
@onready var card_cost: RichTextLabel = %CostLabel
@onready var card_needs: RichTextLabel = %NeedsLabel
@onready var unlock_button: Button = %UnlockButton
@onready var maxed_label: Label = %MaxedLabel
@onready var reason_label: Label = %ReasonLabel
@onready var toast: Label = %Toast
@onready var flash: ColorRect = %Flash
@onready var reset_confirm: Control = %ResetConfirmation
@onready var confirm_text: Label = %ConfirmText
@onready var confirm_list: Label = %ConfirmList
@onready var refund_label: Label = %RefundLabel

var nodes: Dictionary = {}      # skill id -> SkillNode
var centers: Dictionary = {}    # skill id -> Vector2 (canvas px)
var bounds := Rect2()
var zoom := 1.0
var target_zoom := 1.0
var pan := Vector2.ZERO
var target_pan := Vector2.ZERO
var selected_id := ""
var hovered_id := ""
var tutorial_focus := ""
var highlight_branch := ""

var _pressing := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _mouse_inside := false
var _opened_once := false
var _particles: Array = []
var _touches: Dictionary = {}
var _pinch_dist := 0.0
var _time := 0.0
var _toast_tween: Tween
var _arrow_frames: Array[Texture2D] = []
var _particle_tex: Texture2D
var _card_initials: Label

# ================================================================== setup
func _ready() -> void:
	if _needs_theme():
		theme = UiTheme.get_theme()
	var have_ui_icons := ResourceLoader.exists(ResourceDatabase.PATH_UI_ICONS)
	%TitleIcon.texture = ResourceDatabase.ui_icon(12) if have_ui_icons else _gem_texture(Color(0.35, 0.85, 1.0))
	%GemIcon.texture = ResourceDatabase.ui_icon(1) if have_ui_icons else _gem_texture(Color(0.72, 0.42, 1.0))
	%CostIcon.texture = %GemIcon.texture
	_card_initials = Label.new()
	_card_initials.theme_type_variation = &"LabelTitle"
	_card_initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_art.add_child(_card_initials)
	vignette.texture = _make_vignette()
	if ResourceLoader.exists(PARTICLES):
		_particle_tex = load(PARTICLES)
	if ResourceLoader.exists(ARROW):
		var at: Texture2D = load(ARROW)
		for i in 4:
			var a := AtlasTexture.new()
			a.atlas = at
			a.region = Rect2(i * 16, 0, 16, 16)
			_arrow_frames.append(a)
	if ResourceDatabase.skill_order.is_empty():
		ResourceDatabase.load_all()
	_build_tree()
	_build_legend()
	tree_viewport.gui_input.connect(_on_viewport_input)
	tree_viewport.mouse_entered.connect(func(): _mouse_inside = true)
	tree_viewport.mouse_exited.connect(func(): _mouse_inside = false; _set_hovered(""))
	minimap.gui_input.connect(_on_minimap_input)
	minimap.draw.connect(_draw_minimap)
	fx.draw.connect(_draw_fx)
	branch_labels.draw.connect(_draw_branch_labels)
	%CloseButton.pressed.connect(func(): AudioManager.play("ui_close"); close_requested.emit())
	%ZoomIn.pressed.connect(func(): _zoom_at(tree_viewport.size * 0.5, 1.25))
	%ZoomOut.pressed.connect(func(): _zoom_at(tree_viewport.size * 0.5, 1.0 / 1.25))
	%FitTree.pressed.connect(fit_tree)
	%CenterProgress.pressed.connect(center_on_progress)
	%ResetButton.pressed.connect(_ask_reset)
	%ConfirmResetButton.pressed.connect(_confirm_reset)
	%CancelResetButton.pressed.connect(_cancel_reset)
	unlock_button.pressed.connect(func(): if selected_id != "": _try_unlock(selected_id))
	for b in [%ZoomIn, %ZoomOut, %FitTree, %CenterProgress, %ResetButton]:
		b.mouse_entered.connect(func(): AudioManager.play("ui_hover", -8.0))
	Events.skill_points_changed.connect(func(_p): refresh())
	Events.skill_ranked.connect(func(_a, _b): refresh())
	Events.skills_reset.connect(func(_r): refresh())
	Events.level_up.connect(func(_l): refresh())
	resized.connect(_on_resized)
	refresh()

func _needs_theme() -> bool:
	if String(ProjectSettings.get_setting("gui/theme/custom", "")) != "":
		return false
	var n: Node = get_parent()
	while n:
		if (n is Control and n.theme) or (n is Window and n.theme):
			return false
		n = n.get_parent()
	return true

static func hex_to_px(q: float, r: float) -> Vector2:
	return Vector2(HEX_R * SQRT3 * (q + r * 0.5), HEX_R * 1.5 * r)

func _build_tree() -> void:
	for c in nodes_root.get_children():
		c.queue_free()
	nodes.clear()
	centers.clear()
	var edges: Array = []
	var first := true
	for id in ResourceDatabase.skill_order:
		var s := ResourceDatabase.skill(id)
		var p: Array = s.get("pos", [0, 0])
		var c := hex_to_px(float(p[0]), float(p[1])).round()
		centers[id] = c
		var n: Control = SkillNodeScene.instantiate()
		nodes_root.add_child(n)
		n.position = c - NODE_HALF
		n.setup(id)
		nodes[id] = n
		if first:
			bounds = Rect2(c, Vector2.ZERO)
			first = false
		else:
			bounds = bounds.expand(c)
	var i := 0
	for id in ResourceDatabase.skill_order:
		var s2 := ResourceDatabase.skill(id)
		var br := ResourceDatabase.branch(s2.branch)
		for req in s2.get("requires", []):
			if not centers.has(req[0]):
				continue
			edges.append({"from": req[0], "to": id, "a": centers[req[0]], "b": centers[id],
				"color": Color(br.get("color", "ffffff")), "glow": Color(br.get("glow", "ffffff")), "seed": fposmod(i * 0.37, 1.0)})
			i += 1
	connections.set_edges(edges)
	bounds = bounds.grow(44)

func _build_legend() -> void:
	for c in legend.get_children():
		c.queue_free()
	for bid in ResourceDatabase.branch_order:
		if bid == "core":
			continue
		var br := ResourceDatabase.branch(bid)
		var b := Button.new()
		b.theme_type_variation = &"ButtonDark"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 18)
		b.icon = _swatch(Color(br.color))
		b.set_meta("branch", bid)
		b.pressed.connect(_on_legend_pressed.bind(bid))
		legend.add_child(b)
	_update_legend()

func _swatch(c: Color) -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.03, 0.04, 0.09))
	img.fill_rect(Rect2i(1, 1, 6, 6), c)
	img.fill_rect(Rect2i(1, 1, 6, 1), c.lightened(0.45))
	return ImageTexture.create_from_image(img)

func _make_vignette() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.01, 0.01, 0.04, 0.78))
	g.add_point(0.55, Color(0, 0, 0, 0.05))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 128
	gt.height = 72
	return gt

# ================================================================== UIRoot API
func open(data = null) -> void:
	refresh()
	_cancel_reset()
	var focus := ""
	if typeof(data) == TYPE_DICTIONARY:
		focus = String(data.get("focus", ""))
	if focus == "" and not GameState.tutorial.get("done", false) and SkillManager.rank("strong_swing") == 0:
		focus = "strong_swing"
	if not _opened_once:
		_opened_once = true
		await get_tree().process_frame
		center_on_progress(true)
	set_tutorial_focus(focus)
	AudioManager.play("ui_open")

## Spotlight one skill (and the core) for the tutorial; "" clears the spotlight.
func set_tutorial_focus(skill_id: String) -> void:
	tutorial_focus = skill_id
	if skill_id != "" and nodes.has(skill_id):
		_select(skill_id, false)
		_focus_point((centers["miners_core"] + centers[skill_id]) * 0.5, maxf(target_zoom, 1.2))
	_apply_dimming()

func _apply_dimming() -> void:
	for id in nodes:
		var dim := false
		if tutorial_focus != "":
			dim = not (id == tutorial_focus or id == "miners_core")
		elif highlight_branch != "":
			var b: String = ResourceDatabase.skill(id).branch
			dim = b != highlight_branch and b != "core"
		nodes[id].set_dimmed(dim)
	branch_labels.queue_redraw()

func refresh() -> void:
	for id in nodes:
		nodes[id].refresh()
	level_label.text = "LEVEL %d" % GameState.level
	sp_label.text = "AVAILABLE SKILL POINTS: %d" % GameState.skill_points
	_update_legend()
	_update_card()
	minimap.queue_redraw()
	branch_labels.queue_redraw()
	if tutorial_focus != "" and SkillManager.rank(tutorial_focus) > 0:
		set_tutorial_focus("")

func _update_legend() -> void:
	for b in legend.get_children():
		if not b.has_meta("branch"):
			continue
		var bid: String = b.get_meta("branch")
		var br := ResourceDatabase.branch(bid)
		var revealed := SkillManager.is_branch_revealed(bid)
		var prog := SkillManager.branch_progress(bid)
		if revealed:
			b.text = String(br.name).to_upper()
			b.tooltip_text = "%s: %d / %d ranks learned. Click to focus this branch." % [br.name, prog.x, prog.y]
			b.modulate = Color.WHITE if highlight_branch == "" or highlight_branch == bid else Color(0.6, 0.6, 0.7)
		else:
			b.text = "??? LV %d" % int(br.get("reveal_level", 1))
			b.tooltip_text = "This branch is revealed at level %d." % int(br.get("reveal_level", 1))
			b.modulate = Color(0.55, 0.55, 0.65)

func _on_legend_pressed(bid: String) -> void:
	AudioManager.play("ui_click")
	if highlight_branch == bid:
		highlight_branch = ""
	else:
		highlight_branch = bid
		var r := Rect2()
		var first := true
		for id in centers:
			if ResourceDatabase.skill(id).branch == bid:
				if first:
					r = Rect2(centers[id], Vector2.ZERO)
					first = false
				else:
					r = r.expand(centers[id])
		r = r.grow(50)
		var vp := tree_viewport.size
		_focus_point(r.get_center(), clampf(minf(vp.x / r.size.x, vp.y / r.size.y), MIN_ZOOM, 1.4))
	_update_legend()
	_apply_dimming()

# ================================================================== camera
func _process(delta: float) -> void:
	_time += delta
	var k := 1.0 - exp(-delta * 12.0)
	zoom = lerpf(zoom, target_zoom, k)
	if not _dragging:
		pan = pan.lerp(target_pan, k)
	_apply_camera()
	if _mouse_inside and not _dragging:
		_set_hovered(_node_at(tree_viewport.get_local_mouse_position()))
	_update_particles(delta)
	if not _particles.is_empty():
		fx.queue_redraw()
	if tutorial_focus != "":
		branch_labels.queue_redraw()

func _apply_camera() -> void:
	tree_canvas.position = pan.round()
	tree_canvas.scale = Vector2(zoom, zoom)
	bg_tile.position = Vector2(-128.0 + fposmod(pan.x * 0.35, 128.0), -128.0 + fposmod(pan.y * 0.35, 128.0))
	minimap.queue_redraw()

func _clamp_pan(p: Vector2, z: float) -> Vector2:
	var vp := tree_viewport.size
	var center_canvas := (vp * 0.5 - p) / z
	var b := bounds.grow(30)
	center_canvas.x = clampf(center_canvas.x, b.position.x, b.end.x)
	center_canvas.y = clampf(center_canvas.y, b.position.y, b.end.y)
	return vp * 0.5 - center_canvas * z

func _zoom_at(screen_pt: Vector2, factor: float) -> void:
	var new_zoom := clampf(target_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	var anchor := (screen_pt - target_pan) / target_zoom
	target_zoom = new_zoom
	target_pan = _clamp_pan(screen_pt - anchor * new_zoom, new_zoom)

func _focus_point(canvas_pt: Vector2, z: float, snap: bool = false) -> void:
	target_zoom = clampf(z, MIN_ZOOM, MAX_ZOOM)
	target_pan = _clamp_pan(_view_center() - canvas_pt * target_zoom, target_zoom)
	if snap:
		zoom = target_zoom
		pan = target_pan
		_apply_camera()

## Fit Entire Tree.
func fit_tree() -> void:
	AudioManager.play("ui_click")
	var vp := tree_viewport.size
	var z := minf(vp.x / bounds.size.x, vp.y / bounds.size.y)
	_focus_point(bounds.get_center(), z)

## Center on Current Progress: frames everything learned plus the next reachable skills.
func center_on_progress(snap: bool = false) -> void:
	var r := Rect2()
	var first := true
	for id in nodes:
		var st: int = SkillManager.state(id)
		if st in [SkillManager.State.UNLOCKED, SkillManager.State.MAXED, SkillManager.State.AFFORDABLE, SkillManager.State.AVAILABLE] or id == "miners_core":
			if first:
				r = Rect2(centers[id], Vector2.ZERO)
				first = false
			else:
				r = r.expand(centers[id])
	r = r.grow(70)
	var vp := tree_viewport.size
	var z := clampf(minf(vp.x / r.size.x, vp.y / r.size.y), 0.7, 1.35)
	if not snap:
		AudioManager.play("ui_click")
	_focus_point(r.get_center(), z, snap)

## Screen point that should hold the focus: left of the info card while a node is selected.
func _view_center() -> Vector2:
	var vp := tree_viewport.size
	if selected_id != "" and vp.x > 420.0:
		return Vector2((vp.x - details.size.x - 16.0) * 0.5, vp.y * 0.5)
	return vp * 0.5

func _on_resized() -> void:
	if is_node_ready():
		target_pan = _clamp_pan(target_pan, target_zoom)

# ================================================================== input
func _on_viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_dragging = false
				_press_pos = mb.position
			else:
				if _pressing and not _dragging:
					_on_click(_node_at(mb.position))
				_pressing = false
				_dragging = false
				target_pan = _clamp_pan(pan, zoom)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(mb.position, 1.15)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mb.position, 1.0 / 1.15)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_select("", false)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _pressing and not _dragging and mm.position.distance_to(_press_pos) > DRAG_THRESHOLD:
			_dragging = true
			_set_hovered("")
		if _dragging:
			pan += mm.relative
			target_pan = pan
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		_zoom_at(mg.position, mg.factor)
	elif event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		target_pan = _clamp_pan(target_pan - pg.delta * 12.0, target_zoom)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		_pinch_dist = _touch_spread()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var d := _touch_spread()
			if _pinch_dist > 0.0 and d > 0.0:
				_zoom_at(_touch_mid(), d / _pinch_dist)
			_pinch_dist = d

func _touch_spread() -> float:
	if _touches.size() < 2:
		return 0.0
	var v: Array = _touches.values()
	return (v[0] as Vector2).distance_to(v[1])

func _touch_mid() -> Vector2:
	var v: Array = _touches.values()
	return ((v[0] as Vector2) + (v[1] as Vector2)) * 0.5

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if reset_confirm.visible and event.is_action_pressed("pause"):
		_cancel_reset()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and not reset_confirm.visible:
		match (event as InputEventKey).keycode:
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				_zoom_at(tree_viewport.size * 0.5, 1.25)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom_at(tree_viewport.size * 0.5, 1.0 / 1.25)
			KEY_F:
				fit_tree()
			KEY_C:
				center_on_progress()
			KEY_ENTER, KEY_KP_ENTER:
				if selected_id != "":
					_try_unlock(selected_id)
			_:
				return
		get_viewport().set_input_as_handled()

func _node_at(view_pt: Vector2) -> String:
	var cp := (view_pt - tree_canvas.position) / zoom
	for id in nodes:
		var n: Control = nodes[id]
		if n.hit(cp - n.position):
			return id
	return ""

func _set_hovered(id: String) -> void:
	if id == hovered_id:
		return
	if hovered_id != "" and nodes.has(hovered_id):
		nodes[hovered_id].set_hovered(false)
	hovered_id = id
	if id != "":
		nodes[id].set_hovered(true)
		AudioManager.play("ui_hover", -10.0)
	_update_card()

func _select(id: String, sound: bool = true) -> void:
	if selected_id != "" and nodes.has(selected_id):
		nodes[selected_id].set_selected(false)
	selected_id = id
	if id != "":
		nodes[id].set_selected(true)
		if sound:
			AudioManager.play("ui_click")
	_update_card()

func _on_click(id: String) -> void:
	if id == "":
		_select("", false)
		if highlight_branch != "":
			highlight_branch = ""
			_update_legend()
			_apply_dimming()
		return
	_select(id)
	var why := SkillManager.can_rank_up(id)
	if why == "":
		_try_unlock(id)
	elif SkillManager.state(id) != SkillManager.State.MAXED and id != "miners_core":
		AudioManager.play("ui_error", -4.0)
		_show_toast(why.to_upper(), Color(1, 0.5, 0.5))

# ================================================================== unlocking
func _try_unlock(id: String) -> void:
	var why := SkillManager.can_rank_up(id)
	if why != "":
		AudioManager.play("ui_error", -4.0)
		_show_toast(why.to_upper(), Color(1, 0.5, 0.5))
		return
	if not SkillManager.rank_up(id):
		return
	var n: Control = nodes[id]
	var s := ResourceDatabase.skill(id)
	var br := ResourceDatabase.branch(s.branch)
	var maxed := SkillManager.rank(id) >= SkillManager.max_rank(id)
	n.pop()
	connections.burst_into(id)
	_spawn_burst(centers[id], Color(br.glow) if not maxed else Color(1, 0.86, 0.4), 34 if maxed else 22)
	_flash(0.22 if maxed else 0.12)
	AudioManager.play("skill_max" if maxed else "skill_unlock")
	if maxed:
		_show_toast("%s MAXED OUT!" % String(s.name).to_upper(), Color(1, 0.86, 0.4))
	else:
		_show_toast("%s  RANK %d" % [String(s.name).to_upper(), SkillManager.rank(id)], Color(br.glow))
	refresh()

func _flash(a: float) -> void:
	var tw := create_tween()
	flash.color.a = a
	tw.tween_property(flash, "color:a", 0.0, 0.35)

func _show_toast(text: String, col: Color) -> void:
	toast.text = text
	toast.add_theme_color_override("font_color", col)
	toast.visible = true
	toast.modulate.a = 1.0
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func(): toast.visible = false)

# ================================================================== info card
func _update_card() -> void:
	var id := hovered_id if hovered_id != "" else selected_id
	if id == "" or not nodes.has(id):
		details.visible = false
		return
	details.visible = true
	var s := ResourceDatabase.skill(id)
	var br := ResourceDatabase.branch(s.branch)
	var bcol := Color(br.get("color", "ffffff"))
	var st := SkillManager.state(id)
	var r := SkillManager.rank(id)
	var mr := SkillManager.max_rank(id)
	card_art.self_modulate = bcol.lerp(Color.WHITE, 0.55)
	var have_icons := ResourceLoader.exists(ResourceDatabase.PATH_SKILLS)
	card_icon.texture = ResourceDatabase.skill_icon(id) if have_icons else null
	_card_initials.visible = not have_icons
	_card_initials.text = SkillNodeScript.initials_for(String(s.get("name", "?")))
	card_branch.text = String(br.name).to_upper()
	card_branch.add_theme_color_override("font_color", Color(br.get("glow", "ffffff")))
	if st == SkillManager.State.HIDDEN:
		card_icon.modulate = Color(0.2, 0.22, 0.3)
		card_name.text = "???"
		card_desc.text = "This branch is revealed at level %d. Keep mining!" % int(br.get("reveal_level", 1))
		card_rank.text = "RANK ? / ?"
		card_bar.value = 0
		for c in [card_now, card_next, card_cost_row, card_needs, unlock_button, maxed_label, reason_label]:
			c.visible = false
		return
	card_icon.modulate = Color.WHITE if st != SkillManager.State.LOCKED else Color(0.55, 0.57, 0.66)
	card_name.text = String(s.name).to_upper()
	card_desc.text = String(s.desc)
	card_rank.text = "RANK %d / %d" % [r, mr]
	card_bar.max_value = mr
	card_bar.value = r
	card_bar.theme_type_variation = &"ProgressGold" if r >= mr else BAR_VARIATION.get(s.branch, &"")
	card_now.visible = true
	card_now.text = "[color=#8a93a8]NOW:[/color] " + (SkillManager.effect_text(id, r) if r > 0 else "[color=#8a93a8]Not learned yet[/color]")
	var maxed := r >= mr
	card_next.visible = not maxed
	card_cost_row.visible = not maxed
	if not maxed:
		card_next.text = "[color=#8a93a8]NEXT:[/color] [color=#9cf0a8]%s[/color]" % SkillManager.effect_text(id, r + 1)
		var cost := SkillManager.cost_for_next(id)
		var afford := GameState.skill_points >= cost
		card_cost.text = "[color=#8a93a8]COST:[/color] [color=%s]%d SKILL POINT%s[/color]" % ["#ffc93c" if afford else "#ff6b6b", cost, "" if cost == 1 else "S"]
	# Requirements (level + prerequisite skills), green when met, red when not.
	var parts: Array[String] = []
	var lvl := int(s.get("level", 1))
	if lvl > 1:
		parts.append("[color=%s]LEVEL %d[/color]" % ["#9cf0a8" if GameState.level >= lvl else "#ff6b6b", lvl])
	var reqs: Array = s.get("requires", [])
	var req_parts: Array[String] = []
	for req in reqs:
		var rs := ResourceDatabase.skill(req[0])
		var met := SkillManager.rank(req[0]) >= int(req[1])
		req_parts.append("[color=%s]%s RANK %d[/color]" % ["#9cf0a8" if met else "#ff6b6b", String(rs.get("name", req[0])).to_upper(), int(req[1])])
	if not req_parts.is_empty():
		parts.append((" OR " if s.get("req_any", false) else " + ").join(req_parts))
	card_needs.visible = id != "miners_core"
	card_needs.text = "[color=#8a93a8]NEEDS:[/color] " + (" • ".join(parts) if not parts.is_empty() else "NOTHING")
	maxed_label.visible = maxed
	unlock_button.visible = not maxed
	var why := SkillManager.can_rank_up(id)
	unlock_button.text = "UNLOCK" if r == 0 else "UPGRADE TO RANK %d" % (r + 1)
	unlock_button.disabled = why != ""
	reason_label.visible = not maxed and why != ""
	reason_label.text = why
	if id == "miners_core":
		maxed_label.text = "ALWAYS ACTIVE"
	else:
		maxed_label.text = "MAXED OUT!"

# ================================================================== reset
func _ask_reset() -> void:
	AudioManager.play("ui_click")
	var ranked := SkillManager.ranked_skills()
	if ranked.is_empty():
		_show_toast("NO SKILLS TO RESET", Color(0.8, 0.85, 1))
		return
	var lines: Array[String] = []
	for id in ranked:
		lines.append("• %s  (Rank %d)" % [ResourceDatabase.skill(id).name, SkillManager.rank(id)])
	confirm_text.text = "These %d skills will return to rank 0:" % ranked.size()
	confirm_list.text = "\n".join(lines)
	refund_label.text = "REFUND: %d OF %d SKILL POINTS (90%%)" % [SkillManager.refund_amount(), SkillManager.total_spent()]
	reset_confirm.visible = true

func _confirm_reset() -> void:
	var refund := SkillManager.reset_all()
	reset_confirm.visible = false
	AudioManager.play("ui_close")
	_flash(0.18)
	_show_toast("SKILLS RESET: +%d SKILL POINTS" % refund, Color(1, 0.86, 0.4))
	_select("", false)
	refresh()

func _cancel_reset() -> void:
	if reset_confirm and reset_confirm.visible:
		AudioManager.play("ui_close", -4.0)
		reset_confirm.visible = false

# ================================================================== minimap
func _minimap_rect() -> Rect2:
	return Rect2(Vector2(5, 5), minimap.size - Vector2(10, 10))

func _minimap_xform() -> Array:
	var r := _minimap_rect()
	var s := minf(r.size.x / bounds.size.x, r.size.y / bounds.size.y)
	var off := r.position + (r.size - bounds.size * s) * 0.5
	return [s, off]

func _draw_minimap() -> void:
	var xf := _minimap_xform()
	var s: float = xf[0]
	var off: Vector2 = xf[1]
	for id in nodes:
		var p: Vector2 = off + (centers[id] - bounds.position) * s
		var st: int = SkillManager.state(id)
		var br := ResourceDatabase.branch(ResourceDatabase.skill(id).branch)
		var c := Color(0.25, 0.27, 0.36)
		match st:
			SkillManager.State.HIDDEN: c = Color(0.12, 0.13, 0.2)
			SkillManager.State.AVAILABLE, SkillManager.State.AFFORDABLE: c = Color(br.color).darkened(0.35)
			SkillManager.State.UNLOCKED: c = Color(br.color)
			SkillManager.State.MAXED: c = Color(1, 0.83, 0.32)
		if id == "miners_core":
			c = Color(0.55, 0.95, 1.0)
		minimap.draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(3, 3)), c)
	var vp := tree_viewport.size
	var view := Rect2(-tree_canvas.position / zoom, vp / zoom)
	var vr := Rect2(off + (view.position - bounds.position) * s, view.size * s)
	vr = vr.intersection(_minimap_rect().grow(1))
	if vr.size.x > 0 and vr.size.y > 0:
		minimap.draw_rect(vr, Color(1, 1, 1, 0.85), false, 1.0)

func _on_minimap_input(event: InputEvent) -> void:
	var press: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var drag: bool = event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if press or drag:
		var xf := _minimap_xform()
		var pt: Vector2 = (event.position - xf[1]) / float(xf[0]) + bounds.position
		_focus_point(pt, target_zoom)
		minimap.accept_event()

# ================================================================== branch labels / fx
func _draw_branch_labels() -> void:
	var font: Font = UiTheme.font()
	# Tutorial: bouncing gold arrow above the spotlighted node (normal blend, full opacity).
	if tutorial_focus != "" and centers.has(tutorial_focus) and not _arrow_frames.is_empty():
		var c2: Vector2 = centers[tutorial_focus]
		var bob := roundf(sin(_time * 6.0) * 3.0)
		var fr: Texture2D = _arrow_frames[int(_time * 8.0) % _arrow_frames.size()]
		branch_labels.draw_texture_rect(fr, Rect2(c2 + Vector2(-8, -54 + bob), Vector2(16, 16)), false)
	for bid in BRANCH_LABEL_POS:
		var br := ResourceDatabase.branch(bid)
		var revealed := SkillManager.is_branch_revealed(bid)
		var txt: String = String(br.name).to_upper() if revealed else "??? LV %d" % int(br.get("reveal_level", 1))
		var col := Color(br.glow) if revealed else Color(0.35, 0.38, 0.5)
		var dim: bool = tutorial_focus != "" and bid != "mining" or (highlight_branch != "" and highlight_branch != bid)
		if dim:
			col = col.darkened(0.55)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var p: Vector2 = (BRANCH_LABEL_POS[bid] - Vector2(w * 0.5, -3)).round()
		var bg := Rect2(p + Vector2(-4, -9), Vector2(w + 8, 13))
		branch_labels.draw_rect(bg, Color(0.03, 0.04, 0.1, 0.82))
		branch_labels.draw_rect(Rect2(bg.position.x, bg.end.y - 1, bg.size.x, 1), col.darkened(0.2))
		branch_labels.draw_string(font, p + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0, 0.8))
		branch_labels.draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)

func _spawn_burst(at: Vector2, col: Color, count: int) -> void:
	for i in count:
		var ang := randf() * TAU
		var spd := randf_range(40.0, 130.0)
		var life := randf_range(0.45, 0.9)
		_particles.append({"p": at, "v": Vector2(cos(ang), sin(ang)) * spd, "life": life, "max": life,
			"col": col.lerp(Color.WHITE, randf() * 0.5), "kind": randi() % 2})
	# expanding ring
	_particles.append({"p": at, "v": Vector2.ZERO, "life": 0.5, "max": 0.5, "col": col, "kind": 9})

func _update_particles(delta: float) -> void:
	for p in _particles:
		p.life -= delta
		p.p += p.v * delta
		p.v *= 1.0 - delta * 3.0
	_particles = _particles.filter(func(p): return p.life > 0.0)

func _draw_fx() -> void:
	for p in _particles:
		var t: float = 1.0 - p.life / p.max
		var c: Color = p.col
		if int(p.kind) == 9:
			c.a = 1.0 - t
			fx.draw_arc(p.p, 20.0 + 40.0 * t, 0.0, TAU, 24, c, 3.0)
			continue
		c.a = 1.0 - t * t
		if _particle_tex and int(p.kind) == 0:
			var frame := int(t * 4.0) % 4
			fx.draw_texture_rect_region(_particle_tex, Rect2((p.p as Vector2).round() - Vector2(4, 4), Vector2(8, 8)), Rect2(frame * 8, 16, 8, 8), c)
		else:
			var sz := 3.0 if t < 0.5 else 2.0
			fx.draw_rect(Rect2((p.p as Vector2).round() - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), c)

# ================================================================== screenshot harness
func _capture_setup(args: Array) -> void:
	await Engine.get_main_loop().process_frame
	GameState.new_game(7)
	GameState.level = 12
	GameState.skill_points = 9
	GameState.skills = {"miners_core": 1, "strong_swing": 5, "quick_swing": 2, "efficient_extraction": 1,
		"fleet_footed": 1, "bigger_backpack": 2, "faster_smelting": 1}
	GameState.tutorial.done = true
	SkillManager.invalidate()
	refresh()
	if "tutorial" in args:
		GameState.tutorial.done = false
		GameState.level = 2
		GameState.skill_points = 1
		GameState.skills = {"miners_core": 1}
		SkillManager.invalidate()
	await open(null)
	if "fit" in args:
		fit_tree()
		zoom = target_zoom
		pan = target_pan
	_set_hovered("")
	if "reset" in args:
		_ask_reset()
	elif not "tutorial" in args:
		_select("efficient_extraction", false)
		_spawn_burst(centers["quick_swing"], Color(1, 0.7, 0.4), 22)
		connections.burst_into("quick_swing")

## Small faceted gem glyph used when ui_icons.png is not available yet.
func _gem_texture(c: Color) -> Texture2D:
	var rows := ["....oooo....", "...ohhllo...", "..ohhlllmo..", ".ohllllmmdo.", "oooooooooooo", ".odllmmmddo.", "..odlmmddo..", "...odmmdo...", "....oddo....", ".....oo....."]
	var pal := {"o": Color(0.05, 0.04, 0.12), "h": c.lightened(0.7), "l": c.lightened(0.3), "m": c, "d": c.darkened(0.45)}
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			var ch: String = rows[y][x]
			if pal.has(ch):
				img.set_pixel(x + 2, y + 3, pal[ch])
	return ImageTexture.create_from_image(img)
