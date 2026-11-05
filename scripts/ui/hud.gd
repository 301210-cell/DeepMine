extends Control
## In-game HUD (mirrors the reference HUD screenshots):
## top-left coin / skill-gem / level+XP chips, quest box with yellow "!", backpack + event chips;
## top-centre depth chip; top-right clock chip + labelled icon buttons; bottom-left heart health bar;
## bottom-centre numbered hotbar; right-side pickup feed; level-up banner; low-HP vignette; backpack-full warning.

const Kit = preload("res://scripts/ui/ui_kit.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const ItemSlot = preload("res://scripts/ui/components/item_slot.gd")

const FEED_COLOR := Color("fff1a8")
const XP_COLOR := Color("5ff2ff")

var ui: Node = null

var _coins_l: Label
var _coin_shown: float = 0.0
var _coin_tw: Tween
var _sp_l: Label
var _sp_chip: PanelContainer
var _lvl_l: Label
var _xp_bar: ProgressBar
var _xp_l: Label
var _clock_icon: TextureRect
var _clock_l: Label
var _quest_box: PanelContainer
var _quest_head: Label
var _quest_body: RichTextLabel
var _quest_prog: Label
var _bag_l: Label
var _bag_chip: PanelContainer
var _event_chip: PanelContainer
var _event_icon: TextureRect
var _event_l: Label
var _depth_l: Label
var _biome_l: Label
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
	Events.quest_completed.connect(func(_q, _t): _refresh_quest())
	Events.tutorial_changed.connect(_refresh_quest)
	Events.world_event_started.connect(func(_e): _refresh_event())
	Events.world_event_ended.connect(func(_e, _c): _refresh_event())
	refresh_all()

# ================================================================ build
func _chip(variation: String = "HudBox") -> Array:
	var p := Kit.panel(variation)
	var h := Kit.hbox(3)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)
	return [p, h]

func _build() -> void:
	# ---------------- top-left chips
	var top_left := Kit.hbox(3)
	top_left.position = Vector2(5, 5)
	add_child(top_left)

	var c := _chip()
	c[0].custom_minimum_size = Vector2(66, 20)
	c[0].tooltip_text = "Coins"
	c[1].add_child(Kit.ui_icon(0))
	_coins_l = Kit.label("0")
	_coins_l.custom_minimum_size.x = 40
	_coins_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c[1].add_child(_coins_l)
	top_left.add_child(c[0])

	var g := _chip()
	_sp_chip = g[0]
	g[0].custom_minimum_size = Vector2(42, 20)
	g[0].tooltip_text = "Skill Points (press K)"
	g[1].add_child(Kit.ui_icon(1))
	_sp_l = Kit.label("0")
	_sp_l.custom_minimum_size.x = 14
	_sp_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g[1].add_child(_sp_l)
	g[0].gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and ui:
			ui.toggle_panel("skills"))
	top_left.add_child(g[0])

	var l := _chip()
	l[0].tooltip_text = "Level and experience"
	l[1].add_child(Kit.ui_icon(2))
	_lvl_l = Kit.label("Lv. 1")
	_lvl_l.custom_minimum_size.x = 30
	l[1].add_child(_lvl_l)
	var xb: Array = Kit.text_bar("", 84, 10)
	_xp_bar = xb[0]
	_xp_l = xb[1]
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l[1].add_child(_xp_bar)
	top_left.add_child(l[0])

	# ---------------- left column: quest box, backpack chip, event chip
	var left := Kit.vbox(3)
	left.position = Vector2(5, 28)
	add_child(left)
	_quest_box = Kit.panel("PanelDark")
	_quest_box.custom_minimum_size = Vector2(150, 0)
	_quest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var qh := Kit.hbox(4)
	_quest_box.add_child(qh)
	var qi := Kit.ui_icon(27)
	qi.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	qh.add_child(qi)
	var qv := Kit.vbox(0)
	qv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qh.add_child(qv)
	_quest_head = Kit.label("Main Quest:", "LabelGold")
	qv.add_child(_quest_head)
	_quest_body = Kit.rich("", 124)
	qv.add_child(_quest_body)
	_quest_prog = Kit.label("", "LabelSmall")
	qv.add_child(_quest_prog)
	left.add_child(_quest_box)

	var row := Kit.hbox(3)
	left.add_child(row)
	var b := _chip()
	_bag_chip = b[0]
	b[0].tooltip_text = "Backpack slots used (I)"
	b[1].add_child(Kit.ui_icon(8))
	_bag_l = Kit.label("0/20")
	b[1].add_child(_bag_l)
	row.add_child(b[0])
	var e := _chip("PanelPurple")
	_event_chip = e[0]
	e[0].add_theme_stylebox_override("panel", UiTheme.sb("panel_purple.png", 12, 12, 12, 12, 6, 3, 6, 3))
	_event_icon = Kit.icon(null)
	_event_icon.custom_minimum_size = Vector2(16, 16)
	e[1].add_child(_event_icon)
	_event_l = Kit.label("")
	e[1].add_child(_event_l)
	_event_chip.visible = false
	row.add_child(e[0])

	# ---------------- top-centre depth chip
	var depth := _chip()
	depth[0].grow_horizontal = Control.GROW_DIRECTION_BOTH
	depth[0].custom_minimum_size = Vector2(120, 20)
	depth[0].mouse_filter = Control.MOUSE_FILTER_IGNORE
	depth[1].add_child(Kit.ui_icon(32))
	_depth_l = Kit.label("Depth: 0m")
	depth[1].add_child(_depth_l)
	_biome_l = Kit.label("", "LabelDim")
	depth[1].add_child(_biome_l)
	add_child(depth[0])
	_place(depth[0], Control.PRESET_CENTER_TOP, 5, 0, 23)

	# ---------------- top-right: clock + buttons
	var top_right := Kit.hbox(3)
	top_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_right.alignment = BoxContainer.ALIGNMENT_END
	add_child(top_right)
	var ck := _chip()
	ck[0].custom_minimum_size = Vector2(98, 20)
	ck[0].size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_clock_icon = Kit.ui_icon(6)
	ck[1].add_child(_clock_icon)
	_clock_l = Kit.label("Day 1 - 6:00 AM")
	ck[1].add_child(_clock_l)
	top_right.add_child(ck[0])
	for spec in [["inventory", "Inventory", 8], ["shop", "Shop", 13], ["skills", "Skills", 12], ["map", "Map", 10], ["journal", "Journal", 11], ["settings", "Settings", 9]]:
		var btn := Button.new()
		btn.theme_type_variation = "IconButton"
		btn.text = spec[1]
		btn.icon = ResourceDatabase.ui_icon(spec[2])
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 32)
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.tooltip_text = _button_tip(spec[0])
		Kit.sfx(btn)
		var pname: String = spec[0]
		btn.pressed.connect(func(): _on_hud_button(pname))
		top_right.add_child(btn)
		_buttons[pname] = btn
	_place(top_right, Control.PRESET_TOP_RIGHT, 5)

	# ---------------- bottom-left health
	var hp := _chip()
	hp[0].grow_vertical = Control.GROW_DIRECTION_BEGIN
	hp[0].mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp[1].add_child(Kit.ui_icon(4))
	var hb: Array = Kit.text_bar("ProgressRed", 92, 10)
	_hp_bar = hb[0]
	_hp_l = hb[1]
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp[1].add_child(_hp_bar)
	add_child(hp[0])
	_place(hp[0], Control.PRESET_BOTTOM_LEFT, 5, 0, -3)

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
	_place(hot, Control.PRESET_CENTER_BOTTOM, 5)

	# ---------------- right-side pickup feed
	_feed = Kit.vbox(1)
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_feed.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_feed.alignment = BoxContainer.ALIGNMENT_END
	add_child(_feed)
	_place(_feed, Control.PRESET_CENTER_RIGHT, 10, 0, 70)

	# ---------------- level-up banner
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
	_place(_levelup, Control.PRESET_CENTER_TOP, 5, 0, 60)

	# ---------------- backpack full warning
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
	var fs := Kit.label("Return to the surface to store or sell, or drop items [I].", "LabelSmall")
	fs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fv.add_child(fs)
	_full_warn.visible = false
	add_child(_full_warn)
	_full_warn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_place(_full_warn, Control.PRESET_CENTER_BOTTOM, 5, 0, -62)

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
		"skills": return "Skill Tree (%s)" % SaveManager.binding_text("skill_tree")
		"map": return "Map (%s)" % SaveManager.binding_text("map")
		"journal": return "Journal (%s)" % SaveManager.binding_text("journal")
		"settings": return "Settings"
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

# ================================================================ refresh
func refresh_all() -> void:
	_coin_shown = GameState.coins
	_coins_l.text = ResourceDatabase.fmt_num(GameState.coins)
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
		_coins_l.text = ResourceDatabase.fmt_num(int(v)), _coin_shown, float(total), 0.45)
	if delta > 0:
		var p := _coins_l.get_parent().get_parent() as Control
		p.pivot_offset = p.size / 2.0
		var tw := create_tween()
		tw.tween_property(p, "scale", Vector2(1.12, 1.12), 0.07)
		tw.tween_property(p, "scale", Vector2.ONE, 0.12)

func _refresh_sp() -> void:
	_sp_l.text = str(GameState.skill_points)
	_sp_chip.modulate = Color(1.15, 1.0, 1.25) if GameState.skill_points > 0 else Color.WHITE

func _refresh_xp() -> void:
	_lvl_l.text = "Lv. %d" % GameState.level
	var need := GameState.xp_needed()
	_xp_bar.value = float(GameState.xp) / maxf(1.0, need)
	_xp_l.text = "%s / %s XP" % [ResourceDatabase.fmt_short(GameState.xp), ResourceDatabase.fmt_short(need)]

func _refresh_inventory() -> void:
	var used := GameState.used_slots()
	var cap := GameState.inventory_capacity()
	_bag_l.text = "%d/%d" % [used, cap]
	_bag_l.add_theme_color_override("font_color", Color("ff9a3a") if used >= cap else (Color("ffe08a") if used >= cap * 0.8 else UiTheme.COL_TEXT))
	_refresh_hotbar()

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

func _refresh_depth() -> void:
	var d := GameState.current_depth
	var b := GameState.current_biome
	if GameState.at_surface or d <= 0:
		_depth_l.text = "Surface"
		_biome_l.text = "Mining Camp"
		_biome_l.add_theme_color_override("font_color", Color("9fe0a8"))
	else:
		_depth_l.text = "Depth: %dm" % d
		var bd := ResourceDatabase.biome(b)
		_biome_l.text = bd.get("name", "")
		_biome_l.add_theme_color_override("font_color", Color(bd.get("color", "8a93a8")).lightened(0.25))

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
	var title := ""
	var text := ""
	var prog := ""
	if not _override.is_empty():
		_quest_head.text = "Tutorial: " + String(_override.title)
		text = _override.text
		prog = _override.progress
		title = "t"
	else:
		var hud: Dictionary = GameState.quest_state.get("hud", {})
		title = hud.get("title", "")
		text = hud.get("text", "")
		prog = hud.get("progress", "")
		_quest_head.text = "Main Quest:"
		if title != "" and text == "":
			text = title
	_quest_box.visible = title != "" or text != ""
	_quest_body.text = Kit.key_bbcode(text)
	_quest_prog.text = ("(%s)" % prog) if prog != "" else ""
	_quest_prog.visible = prog != ""

func _refresh_event() -> void:
	var st: Dictionary = GameState.event_state
	var id: String = st.get("id", "")
	_event_chip.visible = id != ""
	if id == "":
		return
	for ev in ResourceDatabase.events:
		if ev.id == id:
			_event_icon.texture = ResourceDatabase.event_icon(int(ev.icon))
			_event_chip.tooltip_text = "%s\n%s\n%s" % [ev.name, ev.desc, st.get("quest_text", "")]
	_update_event_text()

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
	while _feed.get_child_count() > 7:
		var first := _feed.get_child(0)
		_feed.remove_child(first)
		first.queue_free()

func _on_level_up(lvl: int) -> void:
	AudioManager.play("level_up")
	var sub: Label = _levelup.get_node("Sub")
	sub.text = "Level %d   •   +1 Skill Point   •   +$%s" % [lvl, ResourceDatabase.fmt_num(25 * lvl)]
	_levelup.visible = true
	_levelup.modulate.a = 0.0
	await get_tree().process_frame
	_levelup.pivot_offset = _levelup.size / 2.0
	_levelup.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_levelup, "modulate:a", 1.0, 0.2)
	tw.tween_property(_levelup, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(2.4)
	tw.chain().tween_property(_levelup, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(func(): _levelup.visible = false)

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

func _unhandled_input(event: InputEvent) -> void:
	if GameState.ui_blocking:
		return
	for i in GameState.HOTBAR.size():
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			_select_hotbar(i)
			get_viewport().set_input_as_handled()
			return

func _process(delta: float) -> void:
	_full_cooldown = maxf(0.0, _full_cooldown - delta)
	# pickup feed fade
	for k in _feed_entries.keys():
		var e: Dictionary = _feed_entries[k]
		if not is_instance_valid(e.node):
			_feed_entries.erase(k)
			continue
		e.t = float(e.t) - delta
		if float(e.t) < 0.6:
			e.node.modulate.a = clampf(float(e.t) / 0.6, 0.0, 1.0)
		if float(e.t) <= 0.0:
			e.node.queue_free()
			_feed_entries.erase(k)
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

func _place(c: Control, preset: int, margin: int, dx: float = 0.0, dy: float = 0.0) -> void:
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)
	c.offset_left += dx
	c.offset_right += dx
	c.offset_top += dy
	c.offset_bottom += dy
