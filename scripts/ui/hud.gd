extends Control
## In-game HUD, laid out like the reference screenshot:
##   top-left:  coin chip "$12,450", skill-gem chip, level chip (Lv + green XP bar, "+" when points unspent)
##              then a compact "! Main Quest" box (click = Journal) and a small event chip
##   top-right: clock chip with a subtle depth/biome line under it, then 4 large icon buttons
##              Inventory (with backpack-fill badge) / Shop / Map / Settings
##   bottom-left heart health bar, bottom-centre numbered hotbar, right-middle pickup feed.
## Skills (level chip, K) and Journal (quest box, J) stay one click away.

const Kit = preload("res://scripts/ui/ui_kit.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const ItemSlot = preload("res://scripts/ui/components/item_slot.gd")

const FEED_COLOR := Color("fff1a8")
const XP_COLOR := Color("5ff2ff")
const CHIP_H := 24
const QUEST_W := 126

var ui: Node = null

var _coins_l: Label
var _coin_chip: PanelContainer
var _coin_shown: float = 0.0
var _coin_tw: Tween
var _sp_l: Label
var _sp_chip: PanelContainer
var _lvl_chip: PanelContainer
var _lvl_l: Label
var _xp_bar: ProgressBar
var _plus_badge: Label
var _clock_icon: TextureRect
var _clock_l: Label
var _quest_box: PanelContainer
var _quest_head: Label
var _quest_body: RichTextLabel
var _quest_prog: Label
var _bag_badge: PanelContainer
var _bag_l: Label
var _event_chip: PanelContainer
var _event_icon: TextureRect
var _event_l: Label
var _depth_l: Label
var _slots: Array = []
var _hp_bar: ProgressBar
var _hp_l: Label
var _feed: VBoxContainer
var _feed_entries: Dictionary = {}
var _levelup: VBoxContainer
var _vignette: TextureRect
var _full_warn: PanelContainer
var _full_cooldown: float = 0.0
var _override: Dictionary = {}
var _tick: float = 0.0
var _buttons: Dictionary = {}
var _t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Events.coins_changed.connect(_on_coins)
	Events.skill_points_changed.connect(func(_p): _refresh_sp())
	Events.xp_changed.connect(func(_a, _b, _c): _refresh_xp())
	Events.level_up.connect(_on_level_up)
	Events.inventory_changed.connect(_refresh_inventory)
	Events.equipment_changed.connect(_refresh_inventory)
	Events.hotbar_changed.connect(_refresh_hotbar)
	Events.depth_changed.connect(func(_d, _b): _refresh_depth())
	Events.player_health_changed.connect(func(_h, _m): _refresh_hp())
	Events.item_collected.connect(_on_item_collected)
	Events.xp_gained.connect(_on_xp_gained)
	Events.inventory_full.connect(_on_inventory_full)
	Events.quest_progress.connect(func(_q): _refresh_quest())
	Events.quest_completed.connect(func(_q, _t2): _refresh_quest())
	Events.tutorial_changed.connect(_refresh_quest)
	Events.world_event_started.connect(func(_e): _refresh_event())
	Events.world_event_ended.connect(func(_e, _c): _refresh_event())
	refresh_all()

# ================================================================ build helpers
func _chip(variation: String = "HudBox", min_w: float = 0.0) -> Array:
	var p := Kit.panel(variation)
	p.custom_minimum_size = Vector2(min_w, CHIP_H)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := Kit.hbox(3)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)
	return [p, h]

func _clickable(c: Control, tip: String, cb: Callable) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.tooltip_text = tip
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			AudioManager.play("ui_click", -4.0)
			cb.call())
	c.mouse_entered.connect(func(): c.modulate = Color(1.15, 1.15, 1.2))
	c.mouse_exited.connect(func(): c.modulate = Color.WHITE)

static func _flat(bg: Color, border: Color, radius: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 2
	s.content_margin_right = 2
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	return s

func _text_w(t: String) -> float:
	var f := UiTheme.font()
	if f == null:
		return t.length() * 5.0
	return f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x

# ================================================================ build
func _build() -> void:
	# ---------------- top-left chips: coins, skill gem, level + XP
	var top_left := Kit.hbox(3)
	top_left.position = Vector2(4, 4)
	add_child(top_left)

	var c := _chip("HudBox", 70)
	_coin_chip = c[0]
	c[0].tooltip_text = "Coins"
	c[1].add_child(Kit.ui_icon(0))
	_coins_l = Kit.label("$0")
	_coins_l.custom_minimum_size.x = 44
	c[1].add_child(_coins_l)
	top_left.add_child(c[0])

	var g := _chip("HudBox", 42)
	_sp_chip = g[0]
	g[1].add_child(Kit.ui_icon(1))
	_sp_l = Kit.label("0")
	_sp_l.custom_minimum_size.x = 14
	g[1].add_child(_sp_l)
	_clickable(g[0], "Skill Points: spend them in the Skill Tree (%s)" % SaveManager.binding_text("skill_tree"), func(): _open_skills())
	top_left.add_child(g[0])

	var l := _chip("HudBox", 78)
	_lvl_chip = l[0]
	l[1].add_child(Kit.ui_icon(2))
	var lv := Kit.vbox(0)
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	l[1].add_child(lv)
	_lvl_l = Kit.label("Lv. 1")
	lv.add_child(_lvl_l)
	var xrow := Kit.hbox(2)
	var xl := Kit.label("XP", "LabelSmall", Color("7dff8a"))
	xl.add_theme_font_size_override("font_size", 10)
	xrow.add_child(xl)
	_xp_bar = Kit.progress("ProgressGreen", 40, 5)
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xrow.add_child(_xp_bar)
	lv.add_child(xrow)
	_clickable(l[0], "Level and experience. Click to open the Skill Tree (%s)" % SaveManager.binding_text("skill_tree"), func(): _open_skills())
	top_left.add_child(l[0])
	# "+" badge: unspent skill points
	_plus_badge = Kit.label("+", "", Color("2a1800"))
	_plus_badge.add_theme_stylebox_override("normal", _flat(Color("ffc93c"), Color("7a4a00"), 4))
	_plus_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_plus_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plus_badge.custom_minimum_size = Vector2(9, 9)
	_plus_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plus_badge)  # HUD root (not inside the chip container); positioned in _place_plus()

	# ---------------- left column: quest box + event chip
	var left := Kit.vbox(3)
	left.position = Vector2(4, 4 + CHIP_H + 3)
	add_child(left)
	_quest_box = Kit.panel("PanelDark")
	_quest_box.custom_minimum_size = Vector2(QUEST_W, 0)
	_quest_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var qv := Kit.vbox(1)
	_quest_box.add_child(qv)
	var qh := Kit.hbox(3)
	var qi := Kit.ui_icon(27)
	qh.add_child(qi)
	_quest_head = Kit.label("Main Quest", "LabelGold")
	_quest_head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_quest_head.clip_text = true
	_quest_head.custom_minimum_size.x = QUEST_W - 32
	qh.add_child(_quest_head)
	qv.add_child(qh)
	_quest_body = Kit.rich("", QUEST_W - 12)
	qv.add_child(_quest_body)
	_quest_prog = Kit.label("", "LabelSmall")
	qv.add_child(_quest_prog)
	_clickable(_quest_box, "Quests and challenges (%s)" % SaveManager.binding_text("journal"), func():
		if ui: ui.toggle_panel("journal"))
	left.add_child(_quest_box)

	var e := _chip("PanelPurple")
	_event_chip = e[0]
	e[0].custom_minimum_size = Vector2(0, 20)
	e[0].size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	e[0].add_theme_stylebox_override("panel", UiTheme.sb("panel_purple.png", 12, 12, 12, 12, 5, 2, 6, 2))
	_event_icon = Kit.icon(null)
	_event_icon.custom_minimum_size = Vector2(16, 16)
	e[1].add_child(_event_icon)
	_event_l = Kit.label("")
	e[1].add_child(_event_l)
	_event_chip.visible = false
	_clickable(_event_chip, "", func():
		if ui: ui.toggle_panel("journal"))
	left.add_child(e[0])

	# ---------------- top-right: clock (+ depth line) and 4 icon buttons
	var top_right := Kit.hbox(3)
	top_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_right.alignment = BoxContainer.ALIGNMENT_END
	add_child(top_right)
	var clock_col := Kit.vbox(1)
	top_right.add_child(clock_col)
	var ck := _chip("HudBox", 104)
	ck[0].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_clock_icon = Kit.ui_icon(6)
	ck[1].add_child(_clock_icon)
	_clock_l = Kit.label("Day 1 - 6:00 AM")
	ck[1].add_child(_clock_l)
	clock_col.add_child(ck[0])
	_depth_l = Kit.label("", "LabelSmall")
	_depth_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_depth_l.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.06, 1))
	clock_col.add_child(_depth_l)

	var specs := [["inventory", "Inventory", 8], ["shop", "Shop", 13], ["map", "Map", 10], ["settings", "Settings", 9]]
	var bw := 40.0
	for spec in specs:
		bw = maxf(bw, _text_w(spec[1]) + 8.0)
	for spec in specs:
		var btn := Button.new()
		btn.theme_type_variation = "IconButton"
		btn.text = spec[1]
		btn.icon = ResourceDatabase.ui_icon(spec[2])
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(bw, 38)
		btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.tooltip_text = _button_tip(spec[0])
		Kit.sfx(btn)
		var pname: String = spec[0]
		btn.pressed.connect(func(): _on_hud_button(pname))
		top_right.add_child(btn)
		_buttons[pname] = btn
	# backpack-fill badge on the Inventory button
	_bag_badge = PanelContainer.new()
	_bag_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bag_l = Kit.label("0/20")
	_bag_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_bag_badge.add_child(_bag_l)
	_buttons["inventory"].add_child(_bag_badge)
	_place(top_right, Control.PRESET_TOP_RIGHT, 4)

	# ---------------- bottom-left health
	var hp := _chip("HudBox", 0)
	hp[0].grow_vertical = Control.GROW_DIRECTION_BEGIN
	hp[1].add_child(Kit.ui_icon(4))
	var hb: Array = Kit.text_bar("ProgressRed", 96, 12)
	_hp_bar = hb[0]
	_hp_l = hb[1]
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp[1].add_child(_hp_bar)
	add_child(hp[0])
	_place(hp[0], Control.PRESET_BOTTOM_LEFT, 4)

	# ---------------- bottom-centre hotbar
	var hot := Kit.hbox(2)
	hot.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(hot)
	var sb_n := UiTheme.sb("hotbar_slot.png", 7, 7, 7, 7, 2, 2, 2, 2)
	var sb_s := UiTheme.sb("hotbar_selected.png", 7, 7, 7, 7, 2, 2, 2, 2)
	for i in GameState.HOTBAR.size():
		var s = ItemSlot.new(26)
		s.add_theme_stylebox_override("normal", sb_n)
		s.add_theme_stylebox_override("hover", sb_n)
		s.add_theme_stylebox_override("pressed", sb_s)
		s.add_theme_stylebox_override("hover_pressed", sb_s)
		s.set_number(i + 1)
		var idx := i
		s.pressed.connect(func(): _select_hotbar(idx))
		hot.add_child(s)
		_slots.append(s)
	_place(hot, Control.PRESET_CENTER_BOTTOM, 4)

	# ---------------- right-middle pickup feed
	_feed = Kit.vbox(1)
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_feed.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_feed.alignment = BoxContainer.ALIGNMENT_END
	add_child(_feed)
	_place(_feed, Control.PRESET_CENTER_RIGHT, 8, 0, 64)

	# ---------------- level-up banner (centre, under the top bar)
	_levelup = Kit.vbox(0)
	_levelup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_levelup.alignment = BoxContainer.ALIGNMENT_CENTER
	var lt := Kit.label("LEVEL UP!", "LabelTitle")
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lt.name = "Title"
	_levelup.add_child(lt)
	var ls := Kit.label("", "")
	ls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ls.name = "Sub"
	_levelup.add_child(ls)
	_levelup.visible = false
	add_child(_levelup)
	_place(_levelup, Control.PRESET_CENTER_TOP, 4, 0, 58)

	# ---------------- backpack full warning (above the hotbar)
	_full_warn = Kit.panel("PanelDark")
	_full_warn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_full_warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fv := Kit.vbox(0)
	_full_warn.add_child(fv)
	var fh := Kit.hbox(3)
	fh.alignment = BoxContainer.ALIGNMENT_CENTER
	fh.add_child(Kit.ui_icon(42))
	fh.add_child(Kit.label("Backpack full!", "", Color("ff9a3a")))
	fv.add_child(fh)
	var fs := Kit.label("Store or sell at the surface, or drop items [I].", "LabelSmall")
	fs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fv.add_child(fs)
	_full_warn.visible = false
	add_child(_full_warn)
	_full_warn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_place(_full_warn, Control.PRESET_CENTER_BOTTOM, 4, 0, -38)

	# ---------------- low HP vignette (behind everything else in the HUD)
	_vignette = TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.8, 0.05, 0.05, 0.0))
	grad.set_color(1, Color(0.7, 0.0, 0.0, 0.55))
	grad.add_point(0.6, Color(0.8, 0.05, 0.05, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 128
	gt.height = 72
	_vignette.texture = gt
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	add_child(_vignette)
	move_child(_vignette, 0)

func _button_tip(p: String) -> String:
	match p:
		"inventory": return "Inventory (%s)" % SaveManager.binding_text("inventory")
		"map": return "Map (%s)" % SaveManager.binding_text("map")
		"settings": return "Settings (Esc for the pause menu)"
		"shop": return "Shop (at the mining camp)"
	return ""

func _on_hud_button(p: String) -> void:
	if ui == null:
		return
	if p == "shop" and not GameState.at_surface:
		Events.notify.emit("The Shop is back at the mining camp.", "info")
		AudioManager.play("ui_error")
		return
	ui.toggle_panel(p)

func _open_skills() -> void:
	if ui == null:
		return
	if ui.has_method("skills_allowed") and not ui.skills_allowed():
		Events.notify.emit("Mara will show you the Skill Tree soon!", "info")
		return
	ui.toggle_panel("skills")

# ================================================================ positions for UI effects
func get_button(name: String) -> Control:
	return _buttons.get(name)

func button_center(name: String) -> Vector2:
	var b: Control = _buttons.get(name)
	return b.get_global_rect().get_center() if b else Vector2(600, 20)

func get_coin_chip() -> Control:
	return _coin_chip

func coin_center() -> Vector2:
	return _coin_chip.get_global_rect().get_center() if _coin_chip else Vector2(30, 14)

func event_chip_center() -> Vector2:
	if _event_chip and _event_chip.is_visible_in_tree():
		return _event_chip.get_global_rect().get_center()
	return _quest_box.get_global_rect().end if _quest_box else Vector2(60, 80)

# ================================================================ refresh
func refresh_all() -> void:
	_coin_shown = GameState.coins
	_coins_l.text = "$" + ResourceDatabase.fmt_num(GameState.coins)
	_refresh_sp()
	_refresh_xp()
	_refresh_inventory()
	_refresh_depth()
	_refresh_hp()
	_refresh_quest()
	_refresh_event()
	_refresh_clock()

func _on_coins(total: int, delta: int) -> void:
	if _coin_tw and _coin_tw.is_valid():
		_coin_tw.kill()
	_coin_tw = create_tween()
	_coin_tw.tween_method(func(v: float):
		_coin_shown = v
		_coins_l.text = "$" + ResourceDatabase.fmt_num(int(v)), _coin_shown, float(total), 0.6)
	if delta > 0:
		_coin_chip.pivot_offset = _coin_chip.size / 2.0
		var tw := create_tween()
		tw.tween_property(_coin_chip, "scale", Vector2(1.1, 1.1), 0.07)
		tw.tween_property(_coin_chip, "scale", Vector2.ONE, 0.14)

func _refresh_sp() -> void:
	_sp_l.text = str(GameState.skill_points)
	_plus_badge.visible = GameState.skill_points > 0
	_place_plus()

func _place_plus() -> void:
	if _lvl_chip and _plus_badge:
		_plus_badge.reset_size()
		_plus_badge.position = _lvl_chip.global_position - global_position + Vector2(_lvl_chip.size.x - _plus_badge.size.x + 2, -3)

func _refresh_xp() -> void:
	_lvl_l.text = "Lv. %d" % GameState.level
	var need := GameState.xp_needed()
	_xp_bar.value = float(GameState.xp) / maxf(1.0, need)
	_lvl_chip.tooltip_text = "Level %d  •  %s / %s XP\nClick to open the Skill Tree (%s)" % [GameState.level, ResourceDatabase.fmt_num(GameState.xp), ResourceDatabase.fmt_num(need), SaveManager.binding_text("skill_tree")]

func _refresh_inventory() -> void:
	var used := GameState.used_slots()
	var cap := GameState.inventory_capacity()
	_bag_l.text = "%d/%d" % [used, cap]
	var fill := float(used) / maxf(1.0, cap)
	var bg := Color("1e2650")
	var border := Color("5a6378")
	var fg := Color("c3cad8")
	if used >= cap:
		bg = Color("8a1e1e")
		border = Color("ff6a6a")
		fg = Color.WHITE
	elif fill >= 0.8:
		bg = Color("6a3a10")
		border = Color("ff9a3a")
		fg = Color("ffe0b0")
	_bag_badge.add_theme_stylebox_override("panel", _flat(bg, border, 3))
	_bag_l.add_theme_color_override("font_color", fg)
	_buttons["inventory"].tooltip_text = "Inventory (%s)  •  Backpack %d/%d" % [SaveManager.binding_text("inventory"), used, cap]
	call_deferred("_place_badge")
	_refresh_hotbar()

func _place_badge() -> void:
	var b: Control = _buttons.get("inventory")
	if b == null:
		return
	_bag_badge.reset_size()
	# inside the button's top-right corner (never clipped by the screen edge)
	_bag_badge.position = Vector2(b.size.x - _bag_badge.size.x - 2, 2)

func _refresh_hotbar() -> void:
	for i in _slots.size():
		var s = _slots[i]
		var key: String = GameState.HOTBAR[i]
		match key:
			"pickaxe":
				var pid: String = GameState.equipped.get("pickaxe", "basic_pickaxe")
				s.set_texture(ResourceDatabase.equip_icon(pid), 0, Color.WHITE, ResourceDatabase.equip(pid).get("name", "Pickaxe"))
			"drill":
				var did: String = GameState.equipped.get("drill", "")
				if did == "":
					did = GameState.best_owned("drill")
				if did != "":
					s.set_texture(ResourceDatabase.equip_icon(did), 0, Color.WHITE, ResourceDatabase.equip(did).get("name", "Drill"))
				else:
					s.set_texture(ResourceDatabase.equip_icon("portable_drill"), 0, Color(1, 1, 1, 0.22), "Portable Drill (buy at the Shop)")
			_:
				var n := GameState.count_item(key)
				s.set_texture(ResourceDatabase.item_icon(key), n, Color.WHITE if n > 0 else Color(1, 1, 1, 0.3), "%s (%d)" % [ResourceDatabase.item_name(key), n])
				if n == 0:
					s.set_count_text("0")
		s.set_pressed_no_signal(i == GameState.hotbar_index)

func _select_hotbar(i: int) -> void:
	GameState.hotbar_index = i
	AudioManager.play("ui_click", -8.0)
	Events.hotbar_changed.emit()
	if i < _slots.size():
		var s: Control = _slots[i]
		s.pivot_offset = s.size / 2.0
		var tw := s.create_tween()
		tw.tween_property(s, "scale", Vector2(1.12, 1.12), 0.06)
		tw.tween_property(s, "scale", Vector2.ONE, 0.12)

func _refresh_depth() -> void:
	var d := GameState.current_depth
	var b := GameState.current_biome
	if GameState.at_surface or d <= 0:
		_depth_l.text = "Surface  •  Mining Camp"
		_depth_l.add_theme_color_override("font_color", Color("9fe0a8"))
	else:
		var bd := ResourceDatabase.biome(b)
		_depth_l.text = "%dm  •  %s" % [d, bd.get("name", "")]
		_depth_l.add_theme_color_override("font_color", Color(bd.get("color", "8a93a8")).lightened(0.3))

func _refresh_hp() -> void:
	var r := GameState.hp / GameState.MAX_HP
	_hp_bar.value = r
	_hp_l.text = "%d / %d" % [ceili(GameState.hp), int(GameState.MAX_HP)]

func set_objective_override(title: String, text: String, progress: String) -> void:
	if title == "":
		_override = {}
	else:
		_override = {"title": title, "text": text, "progress": progress}
	_refresh_quest()

func _refresh_quest() -> void:
	## Compact box: title ("Main Quest" / "Tutorial 4/12"), short objective, progress.
	## The long description lives in the Journal.
	var hud: Dictionary = GameState.quest_state.get("hud", {})
	var head := String(hud.get("title", ""))
	var text := String(hud.get("short", ""))
	var prog := String(hud.get("progress", ""))
	if text == "" and not _override.is_empty():
		text = String(_override.title)
		prog = String(_override.progress)
		head = "Tutorial"
	if text == "":
		text = String(hud.get("text", ""))
	if head == "" or head == "Main Quest:":
		head = "Main Quest"
	var hint := String(hud.get("hint", ""))
	if hint != "" and not GameState.tutorial.get("done", false):
		text += "  [%s]" % hint
	_quest_box.visible = text != ""
	_quest_head.text = head
	_quest_body.text = Kit.key_bbcode(text)
	_quest_prog.text = ("(%s)" % prog) if prog != "" else ""
	_quest_prog.visible = prog != ""

func _refresh_event() -> void:
	var st: Dictionary = GameState.event_state
	var id: String = st.get("id", "")
	var was := _event_chip.visible
	_event_chip.visible = id != ""
	if id == "":
		return
	for ev in ResourceDatabase.events:
		if ev.id == id:
			_event_icon.texture = ResourceDatabase.event_icon(int(ev.icon))
			_event_chip.tooltip_text = "%s\n%s\n%s" % [ev.name, ev.desc, st.get("quest_text", "")]
	_update_event_text()
	if not was:
		_event_chip.modulate.a = 0.0
		create_tween().tween_property(_event_chip, "modulate:a", 1.0, 0.3).set_delay(0.2)

func _update_event_text() -> void:
	var st: Dictionary = GameState.event_state
	var id: String = st.get("id", "")
	if id == "":
		return
	var nm := id
	for ev in ResourceDatabase.events:
		if ev.id == id:
			nm = ev.name
	var cnt := int(st.get("count", 0))
	var extra := ("  %d/%d" % [int(st.get("progress", 0)), cnt]) if cnt > 0 else ""
	_event_l.text = "%s  %s%s" % [nm, ResourceDatabase.fmt_time(float(st.get("time_left", 0.0))), extra]

func _refresh_clock() -> void:
	var t := fposmod(GameState.day_time, 1.0) * 24.0
	var h := int(t)
	var m := int((t - h) * 60.0)
	var ampm := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	_clock_l.text = "Day %d - %d:%02d %s" % [GameState.day_count, h12, m, ampm]
	_clock_icon.texture = ResourceDatabase.ui_icon(6 if h >= 6 and h < 19 else 7)

# ================================================================ feed / banners
func _on_item_collected(id: String, n: int) -> void:
	if n <= 0:
		return
	_feed_push("i:" + id, n, ResourceDatabase.item_name(id), ResourceDatabase.item_icon(id), FEED_COLOR.lerp(ResourceDatabase.rarity_color(ResourceDatabase.item_rarity(id)), 0.35))

func _on_xp_gained(a: int) -> void:
	_feed_push("xp", a, "XP", null, XP_COLOR)

func _feed_push(key: String, n: int, name_text: String, tex: Texture2D, col: Color) -> void:
	var e: Dictionary = _feed_entries.get(key, {})
	if e.is_empty() or not is_instance_valid(e.node):
		var row := Kit.hbox(3)
		row.alignment = BoxContainer.ALIGNMENT_END
		if tex:
			row.add_child(Kit.icon(tex))
		var l := Kit.label("", "", col)
		row.add_child(l)
		_feed.add_child(row)
		if key != "xp":
			# keep XP lines at the bottom like the reference
			for k in _feed_entries:
				if k == "xp" and is_instance_valid(_feed_entries[k].node):
					_feed.move_child(_feed_entries[k].node, _feed.get_child_count() - 1)
		e = {"node": row, "label": l, "n": 0, "t": 0.0, "name": name_text}
		_feed_entries[key] = e
		row.modulate.a = 0.0
		var tw := row.create_tween()
		tw.tween_property(row, "modulate:a", 1.0, 0.12)
	e.n = int(e.n) + n
	e.t = 2.6
	e.label.text = "+%s %s" % [ResourceDatabase.fmt_num(e.n), e.name]
	e.node.modulate.a = 1.0
	var lab: Label = e.label
	lab.pivot_offset = lab.size / 2.0
	var tw2 := lab.create_tween()
	tw2.tween_property(lab, "scale", Vector2(1.15, 1.15), 0.05)
	tw2.tween_property(lab, "scale", Vector2.ONE, 0.1)
	while _feed.get_child_count() > 6:
		var first := _feed.get_child(0)
		_feed.remove_child(first)
		first.queue_free()

func _on_level_up(lvl: int) -> void:
	AudioManager.play("level_up")
	var sub: Label = _levelup.get_node("Sub")
	sub.text = "Level %d  •  +1 Skill Point  •  +$%s" % [lvl, ResourceDatabase.fmt_num(25 * lvl)]
	_levelup.visible = true
	_levelup.modulate.a = 0.0
	await get_tree().process_frame
	_levelup.reset_size()
	_place(_levelup, Control.PRESET_CENTER_TOP, 4, 0, 58)
	_levelup.pivot_offset = _levelup.size / 2.0
	_levelup.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_levelup, "modulate:a", 1.0, 0.2)
	tw.tween_property(_levelup, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(2.4)
	tw.chain().tween_property(_levelup, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(func(): _levelup.visible = false)
	if ui and ui.get("fx"):
		ui.fx.burst(_lvl_chip.get_global_rect().get_center(), "star", 14, Color("ffd35a"))

func _on_inventory_full(_id: String) -> void:
	if _full_cooldown > 0.0:
		return
	_full_cooldown = 4.0
	AudioManager.play("ui_error", -4.0)
	_full_warn.visible = true
	_full_warn.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(_full_warn, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): _full_warn.visible = false)
	if _bag_badge:
		_bag_badge.pivot_offset = _bag_badge.size / 2.0
		var tb := _bag_badge.create_tween()
		for i in 2:
			tb.tween_property(_bag_badge, "scale", Vector2(1.3, 1.3), 0.08)
			tb.tween_property(_bag_badge, "scale", Vector2.ONE, 0.12)

func _unhandled_input(event: InputEvent) -> void:
	if GameState.ui_blocking:
		return
	for i in GameState.HOTBAR.size():
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			_select_hotbar(i)
			get_viewport().set_input_as_handled()
			return

func _process(delta: float) -> void:
	_t += delta
	_full_cooldown = maxf(0.0, _full_cooldown - delta)
	# "+" badge gentle pulse
	if _plus_badge.visible:
		_place_plus()
		var k := 1.0 + 0.12 * sin(_t * 5.0)
		_plus_badge.pivot_offset = _plus_badge.size / 2.0
		_plus_badge.scale = Vector2(k, k)
	# pickup feed fade
	for k2 in _feed_entries.keys():
		var e: Dictionary = _feed_entries[k2]
		if not is_instance_valid(e.node):
			_feed_entries.erase(k2)
			continue
		e.t = float(e.t) - delta
		if float(e.t) < 0.6:
			e.node.modulate.a = clampf(float(e.t) / 0.6, 0.0, 1.0)
		if float(e.t) <= 0.0:
			e.node.queue_free()
			_feed_entries.erase(k2)
	# low HP vignette pulse
	var r := GameState.hp / GameState.MAX_HP
	var target := 0.0
	if r < 0.3 and GameState.hp > 0.0:
		target = (0.55 + 0.35 * sin(Time.get_ticks_msec() / 180.0)) * (1.0 - r / 0.3)
	_vignette.modulate.a = lerpf(_vignette.modulate.a, target, minf(1.0, delta * 6.0))
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.25
		_refresh_clock()
		if _event_chip.visible:
			_update_event_text()
		if _event_chip.visible != (String(GameState.event_state.get("id", "")) != ""):
			_refresh_event()
		_refresh_depth()
		_refresh_sp()

func _place(c: Control, preset: int, margin: int, dx: float = 0.0, dy: float = 0.0) -> void:
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)
	c.offset_left += dx
	c.offset_right += dx
	c.offset_top += dy
	c.offset_bottom += dy
