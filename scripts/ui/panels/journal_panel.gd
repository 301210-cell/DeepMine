extends Control
## Journal: Quests (main / tutorial / challenges / event), Mineral Collection, Discoveries, Achievements.
## open(data): data = "quests" | "collection" | "discoveries" | "achievements".

signal close_requested

const SettingsPanel = preload("res://scripts/ui/panels/settings_panel.gd")
const TABS := ["quests", "collection", "discoveries", "achievements"]
const TAB_TITLES := ["Quests", "Collection", "Discoveries", "Achievements"]
const MILESTONES := [[25, "$2,000"], [50, "Aurora Lantern Glow"], [75, "Gem Charm"], [100, "Crown + Golden Finish + $50,000"]]
const GRID_COLS := 12

@onready var window: Control = %Window
@onready var close_button: BaseButton = %CloseButton
@onready var tab_row: HBoxContainer = %TabRow
@onready var pages: Control = %Pages
@onready var title_icon: TextureRect = %TitleIcon

var current_tab := "quests"
var selected_item := ""
var _tab_buttons: Dictionary = {}
var _detail: Dictionary = {}

func _ready() -> void:
	title_icon.texture = ResourceDatabase.ui_icon(11)
	close_button.pressed.connect(func(): AudioManager.play("ui_close"); close_requested.emit())
	var group := ButtonGroup.new()
	for i in TABS.size():
		var b := Button.new()
		b.text = TAB_TITLES[i]
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = &"TabButton"
		b.custom_minimum_size = Vector2(92, 22)
		b.focus_mode = Control.FOCUS_NONE
		var tab: String = TABS[i]
		b.pressed.connect(func(): AudioManager.play("ui_click"); _show_tab(tab))
		b.mouse_entered.connect(func(): AudioManager.play("ui_hover", -10.0))
		tab_row.add_child(b)
		_tab_buttons[tab] = b
	for sig in [Events.quest_progress, Events.quest_completed, Events.collection_changed, Events.achievement_unlocked, Events.tutorial_changed]:
		sig.connect(_on_data_changed)

func _on_data_changed(_a = null, _b = null) -> void:
	if is_visible_in_tree():
		_show_tab(current_tab)

func open(data = null) -> void:
	var tab := String(data) if data != null and String(data) in TABS else "quests"
	_show_tab(tab)
	window.pivot_offset = window.size * 0.5
	window.scale = Vector2(0.94, 0.94)
	window.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(window, "scale", Vector2.ONE, 0.18)
	tw.tween_property(window, "modulate:a", 1.0, 0.12)

func _show_tab(tab: String) -> void:
	current_tab = tab
	_tab_buttons[tab].button_pressed = true
	for c in pages.get_children():
		c.queue_free()
	match tab:
		"quests": _build_quests()
		"collection": _build_collection()
		"discoveries": _build_discoveries()
		"achievements": _build_achievements()

# ================================================================ widgets
func _label(text: String, variation: String = "", wrap := false, color := Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = StringName(variation)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 40
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	return l

func _icon(tex: Texture2D, size := 16, tint := Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.modulate = tint
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t

func _bar(value: float, maxv: float, variation: String = "", text := "") -> Control:
	var pb := ProgressBar.new()
	pb.max_value = maxf(maxv, 1.0)
	pb.value = clampf(value, 0.0, pb.max_value)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(60, 10)
	if variation != "":
		pb.theme_type_variation = StringName(variation)
	if text != "":
		var l := _label(text, "LabelSmall")
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.offset_top = -1
		pb.add_child(l)
	return pb

func _card(variation := "PanelDark") -> Array:
	var pc := PanelContainer.new()
	pc.theme_type_variation = StringName(variation)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	pc.add_child(vb)
	return [pc, vb]

func _hbox(sep := 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

func _button(text: String, variation: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = StringName(variation)
	b.custom_minimum_size = Vector2(70, 20)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): AudioManager.play("ui_click"); cb.call())
	b.mouse_entered.connect(func(): AudioManager.play("ui_hover", -10.0))
	return b

func _reward_text(q: Dictionary) -> String:
	var parts: Array[String] = []
	if int(q.get("reward_coins", 0)) > 0:
		parts.append("$" + ResourceDatabase.fmt_num(int(q.reward_coins)))
	if int(q.get("reward_xp", 0)) > 0:
		parts.append("%s XP" % ResourceDatabase.fmt_num(int(q.reward_xp)))
	if int(q.get("reward_sp", 0)) > 0:
		parts.append("+%d Skill Point%s" % [int(q.reward_sp), "" if int(q.reward_sp) == 1 else "s"])
	return "  •  ".join(parts)

func _scroll(content: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	return sc

# ================================================================ quests
func _build_quests() -> void:
	var root := _hbox(8)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pages.add_child(root)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.15
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	root.add_child(right)

	var qs: Dictionary = GameState.quest_state
	var qdefs: Dictionary = ResourceDatabase.quests
	var tut: Dictionary = GameState.tutorial
	var tut_steps: Array = qdefs.get("tutorial", [])
	var tut_active := not bool(tut.get("done", false)) and not bool(tut.get("skipped", false))

	# --- main quest (or current tutorial step)
	left.add_child(_label("MAIN QUEST", "LabelGold"))
	var main_card := _card("PanelDark")
	left.add_child(main_card[0])
	var mv: VBoxContainer = main_card[1]
	if tut_active and int(tut.get("step", 0)) < tut_steps.size():
		var step: Dictionary = tut_steps[int(tut.get("step", 0))]
		var head := _hbox()
		head.add_child(_icon(ResourceDatabase.ui_icon(27)))
		head.add_child(_label("Tutorial: " + String(step.get("title", "")), "LabelHeader"))
		mv.add_child(head)
		mv.add_child(_label(String(step.get("text", "")), "", true))
		var cnt := int(step.get("count", 1))
		var prog := int(qs.get("tutorial_progress", 0))
		mv.add_child(_bar(prog, cnt, "", "%d / %d" % [mini(prog, cnt), cnt]))
		mv.add_child(_label("Step %d of %d with Mara" % [int(tut.get("step", 0)) + 1, tut_steps.size()], "LabelDim"))
	else:
		var mains: Array = qdefs.get("main", [])
		var mi := int(qs.get("main_index", 0))
		if mi < mains.size():
			var q: Dictionary = mains[mi]
			var head2 := _hbox()
			head2.add_child(_icon(ResourceDatabase.ui_icon(27)))
			head2.add_child(_label(String(q.get("title", "")), "LabelHeader"))
			mv.add_child(head2)
			mv.add_child(_label(String(q.get("text", "")), "", true))
			var cnt2 := int(q.get("count", 1))
			var prog2 := int(qs.get("main_progress", 0))
			var txt := ("%sm / %sm" % [ResourceDatabase.fmt_num(mini(prog2, cnt2)), ResourceDatabase.fmt_num(cnt2)]) if q.get("type", "") == "reach_depth" else "%s / %s" % [ResourceDatabase.fmt_num(mini(prog2, cnt2)), ResourceDatabase.fmt_num(cnt2)]
			mv.add_child(_bar(prog2, cnt2, "ProgressGold", txt))
			var rw := _hbox()
			rw.add_child(_icon(ResourceDatabase.ui_icon(0)))
			rw.add_child(_label("Reward: " + _reward_text(q), "LabelSmall"))
			mv.add_child(rw)
			mv.add_child(_label("Main quest %d of %d" % [mi + 1, mains.size()], "LabelDim"))
		else:
			mv.add_child(_label("All main quests complete!", "LabelHeader"))
			mv.add_child(_label("You conquered the mountain. Keep hunting for legendary finds!", "", true))

	# --- tutorial controls
	var tcard := _card("PanelDark")
	left.add_child(tcard[0])
	var tv: VBoxContainer = tcard[1]
	var trow := _hbox(6)
	tv.add_child(trow)
	var status := "In progress" if tut_active else ("Skipped" if bool(tut.get("skipped", false)) else "Completed")
	var tl := _label("Tutorial with Mara: " + status, "LabelSmall")
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(tl)
	if tut_active:
		trow.add_child(_button("Skip", "ButtonDark", func(): _confirm("Skip Tutorial?", "Mara's tips will stop. You can replay the tutorial any time from the Journal.", func(): _set_tutorial(true))))
	trow.add_child(_button("Replay", "Button", func(): _confirm("Replay Tutorial?", "Mara will walk you through the basics again. Your progress is kept.", func(): _set_tutorial(false))))

	# --- event challenge
	var ev: Dictionary = GameState.event_state
	if String(ev.get("id", "")) != "":
		var edef: Dictionary = {}
		for e in ResourceDatabase.events:
			if e.id == ev.id:
				edef = e
		var ecard := _card("PanelPurple")
		left.add_child(ecard[0])
		var evb: VBoxContainer = ecard[1]
		var eh := _hbox()
		eh.add_child(_icon(ResourceDatabase.event_icon(int(edef.get("icon", 0))), 24))
		var en := VBoxContainer.new()
		en.add_theme_constant_override("separation", 0)
		en.add_child(_label("EVENT!", "LabelGold"))
		en.add_child(_label(String(edef.get("name", ev.id)), "", false, Color("ff6b8a")))
		en.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eh.add_child(en)
		eh.add_child(_icon(ResourceDatabase.ui_icon(34)))
		eh.add_child(_label(ResourceDatabase.fmt_time(float(ev.get("time_left", 0.0))), "LabelGold"))
		evb.add_child(eh)
		var qtext := String(ev.get("quest_text", ""))
		if qtext != "":
			evb.add_child(_label(qtext, "", true))
			evb.add_child(_bar(int(ev.get("progress", 0)), int(ev.get("count", 1)), "ProgressPurple", "%d / %d" % [int(ev.get("progress", 0)), int(ev.get("count", 1))]))

	# --- optional challenges
	right.add_child(_label("OPTIONAL CHALLENGES", "LabelGold"))
	var defs: Dictionary = {}
	for c in qdefs.get("challenges", []):
		defs[c.id] = c
	var active: Array = qs.get("challenges", [])
	if active.is_empty():
		var empty_card := _card("PanelDark")
		right.add_child(empty_card[0])
		empty_card[1].add_child(_label("New challenges appear on the Mining Board after the tutorial.", "LabelDim", true))
	for ch in active:
		if typeof(ch) != TYPE_DICTIONARY or not defs.has(ch.get("id", "")):
			continue
		var d: Dictionary = defs[ch.id]
		var cc := _card("PanelDark")
		right.add_child(cc[0])
		var cv: VBoxContainer = cc[1]
		var ch_head := _hbox()
		ch_head.add_child(_icon(ResourceDatabase.ui_icon(26)))
		var ct := _label(String(d.get("title", "")), "", false, Color("ffd890"))
		ct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ch_head.add_child(ct)
		cv.add_child(ch_head)
		cv.add_child(_label(String(d.get("text", "")), "LabelSmall", true))
		var n := int(d.get("count", 1))
		var p := int(ch.get("progress", 0))
		var done := p >= n
		cv.add_child(_bar(p, n, "ProgressGreen" if done else "", "COMPLETE!" if done else "%s / %s" % [ResourceDatabase.fmt_num(p), ResourceDatabase.fmt_num(n)]))
		cv.add_child(_label("Reward: " + _reward_text(d), "LabelDim"))

func _set_tutorial(skip: bool) -> void:
	if skip:
		GameState.tutorial["skipped"] = true
		GameState.tutorial["done"] = true
	else:
		GameState.tutorial = {"step": 0, "done": false, "skipped": false}
		GameState.quest_state["tutorial_progress"] = 0
	Events.tutorial_changed.emit()
	_show_tab("quests")

# ================================================================ collection
func _build_collection() -> void:
	var root := _hbox(8)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pages.add_child(root)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	root.add_child(left)

	var ids: Array = ResourceDatabase.collectibles
	var found := 0
	for id in ids:
		if GameState.collection.has(id):
			found += 1
	var pct := int(floor(100.0 * found / maxf(1.0, ids.size())))
	var head := _hbox()
	head.add_child(_label("MINERAL COLLECTION", "LabelGold"))
	var cnt := _label("%d / %d  (%d%%)" % [found, ids.size(), pct], "LabelSmall")
	cnt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(cnt)
	left.add_child(head)
	var bar := _bar(found, ids.size(), "ProgressGold")
	bar.custom_minimum_size.y = 10
	left.add_child(bar)
	bar.draw.connect(func():
		for m in MILESTONES:
			var x: float = bar.size.x * float(m[0]) / 100.0
			bar.draw_line(Vector2(x, 0), Vector2(x, bar.size.y), Color(1, 1, 1, 0.5), 1.0))
	var ms := _hbox(3)
	left.add_child(ms)
	for m in MILESTONES:
		var claimed: bool = GameState.collection_rewards.get(str(m[0]), false)
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"HudBox"
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.tooltip_text = "%d%%: %s" % [m[0], m[1]]
		var hb := _hbox(2)
		chip.add_child(hb)
		hb.add_child(_icon(ResourceDatabase.ui_icon(15 if claimed else 14), 12, Color("5fdc6a") if claimed else Color(0.7, 0.7, 0.8)))
		hb.add_child(_label("%d%%" % m[0], "LabelGold" if claimed else "LabelDim"))
		ms.add_child(chip)

	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	var first_found := ""
	for id in ids:
		var have: bool = GameState.collection.has(id)
		if have and first_found == "":
			first_found = id
		var slot := Button.new()
		slot.theme_type_variation = &"SlotButton"
		slot.custom_minimum_size = Vector2(24, 24)
		slot.toggle_mode = true
		slot.focus_mode = Control.FOCUS_NONE
		var ic := _icon(ResourceDatabase.item_icon(id), 16, Color.WHITE if have else Color(0.02, 0.03, 0.08, 0.92))
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 4
		ic.offset_top = 4
		ic.offset_right = -4
		ic.offset_bottom = -4
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(ic)
		if have:
			var frame := NinePatchRect.new()
			frame.texture = ResourceDatabase.tex("res://assets/ui/slot_rarity.png")
			frame.patch_margin_left = 6
			frame.patch_margin_right = 6
			frame.patch_margin_top = 6
			frame.patch_margin_bottom = 6
			frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			frame.modulate = Color(ResourceDatabase.rarity_color(ResourceDatabase.item_rarity(id)), 0.9)
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(frame)
		var iid: String = id
		slot.pressed.connect(func(): AudioManager.play("ui_click"); _select_item(iid))
		slot.mouse_entered.connect(func(): AudioManager.play("ui_hover", -12.0))
		slot.set_meta("item", id)
		grid.add_child(slot)
	left.add_child(_scroll(grid))

	# --- detail card
	var dc := _card("PanelDark")
	var dpanel: PanelContainer = dc[0]
	dpanel.custom_minimum_size = Vector2(172, 0)
	root.add_child(dpanel)
	var dv: VBoxContainer = dc[1]
	var top := _hbox(6)
	dv.add_child(top)
	var big := _icon(null, 32)
	top.add_child(big)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 1)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	var nm := _label("", "", true)
	names.add_child(nm)
	var rar := _label("", "LabelSmall")
	names.add_child(rar)
	dv.add_child(HSeparator.new())
	var desc := _label("", "", true)
	dv.add_child(desc)
	var stats := _label("", "LabelSmall", true)
	dv.add_child(stats)
	_detail = {"icon": big, "name": nm, "rarity": rar, "desc": desc, "stats": stats, "grid": grid}
	if selected_item == "" or not selected_item in ids:
		selected_item = first_found if first_found != "" else String(ids[0])
	_select_item(selected_item)

func _select_item(id: String) -> void:
	selected_item = id
	if _detail.is_empty():
		return
	for s in _detail.grid.get_children():
		s.set_pressed_no_signal(s.get_meta("item", "") == id)
	var it := ResourceDatabase.item(id)
	var have: bool = GameState.collection.has(id)
	var r := ResourceDatabase.item_rarity(id)
	_detail.icon.texture = ResourceDatabase.item_icon(id)
	_detail.icon.modulate = Color.WHITE if have else Color(0.02, 0.03, 0.08, 0.92)
	if have:
		var rec: Dictionary = GameState.collection[id]
		_detail.name.text = String(it.get("name", id))
		_detail.name.add_theme_color_override("font_color", ResourceDatabase.rarity_color(r))
		_detail.rarity.text = "%s %s" % [ResourceDatabase.rarity_name(r), ResourceDatabase.CATEGORY_NAMES.get(it.get("category", ""), "")]
		_detail.desc.text = String(it.get("desc", ""))
		_detail.stats.text = "Collected: %s\nBest depth: %sm\nValue: $%s" % [ResourceDatabase.fmt_num(int(rec.get("count", 0))), ResourceDatabase.fmt_num(int(rec.get("best", 0))), ResourceDatabase.fmt_num(ResourceDatabase.item_value(id))]
	else:
		_detail.name.text = "???"
		_detail.name.add_theme_color_override("font_color", Color("8a93a8"))
		_detail.rarity.text = "Undiscovered"
		var dr: Array = it.get("depth", [0, 0])
		var where := "the depths"
		var bi := ResourceDatabase.biome_for_depth(float(dr[0]))
		if bi >= 0 and bi < GameState.biomes_found.size() and GameState.biomes_found[bi]:
			where = String(ResourceDatabase.biome(bi).get("name", "the depths"))
		_detail.desc.text = "Keep exploring. Rumour says it can be found in %s." % where
		_detail.stats.text = "Depth: %sm - %sm" % [ResourceDatabase.fmt_num(int(dr[0])), ResourceDatabase.fmt_num(int(dr[1]))]

# ================================================================ discoveries
func _build_discoveries() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	var sc := _scroll(vb)
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pages.add_child(sc)
	vb.add_child(_label("BIOMES", "LabelGold"))
	for b in ResourceDatabase.biomes:
		var i := int(b.index)
		var found: bool = i < GameState.biomes_found.size() and bool(GameState.biomes_found[i])
		var card := _card("PanelDark")
		vb.add_child(card[0])
		var row := _hbox(6)
		card[1].add_child(row)
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(6, 22)
		sw.color = Color(b.get("color", "888888")) if found else Color("2a3150")
		row.add_child(sw)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var h := _hbox()
		h.add_child(_label(String(b.name) if found else "??? Undiscovered Biome", "", false, Color(b.get("color", "ffffff")).lightened(0.35) if found else Color("6a7090")))
		var dep := _label("%dm - %dm" % [int(b.depth[0]), int(b.depth[1])], "LabelDim")
		dep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dep.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(dep)
		col.add_child(h)
		col.add_child(_label(String(b.get("desc", "")) if found else "Dig deeper to discover what lies below.", "LabelSmall", true))

	vb.add_child(_label("SPECIAL CHAMBERS", "LabelGold"))
	var cc := _card("PanelDark")
	vb.add_child(cc[0])
	if GameState.chambers.is_empty():
		cc[1].add_child(_label("No hidden chambers found yet. Watch for strange glows and cracked walls.", "LabelDim", true))
	else:
		for nm in GameState.chambers.keys():
			var r := _hbox()
			r.add_child(_icon(ResourceDatabase.item_icon("amethyst")))
			r.add_child(_label(String(nm)))
			cc[1].add_child(r)

	vb.add_child(_label("FOSSILS & ARTIFACTS", "LabelGold"))
	var fc := _card("PanelDark")
	vb.add_child(fc[0])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	fc[1].add_child(grid)
	for id in ResourceDatabase.item_order:
		var cat := ResourceDatabase.item_category(id)
		if cat != "fossil" and cat != "artifact":
			continue
		var have: bool = GameState.collection.has(id)
		var r2 := _hbox()
		r2.custom_minimum_size.x = 230
		r2.add_child(_icon(ResourceDatabase.item_icon(id), 16, Color.WHITE if have else Color(0.02, 0.03, 0.08, 0.92)))
		r2.add_child(_label(ResourceDatabase.item_name(id) if have else "???", "", false, ResourceDatabase.rarity_color(ResourceDatabase.item_rarity(id)) if have else Color("6a7090")))
		if have:
			r2.add_child(_label("x%d" % int(GameState.collection[id].get("count", 0)), "LabelDim"))
		grid.add_child(r2)

# ================================================================ achievements
## Maps an achievement/quest objective to its GameState.counters key.
static func counter_key(type: String, target: String) -> String:
	if type == "collect":
		if target.begins_with("@"):
			return "collect_cat:" + target.substr(1)
		return "collect:" + target
	return type

func _build_achievements() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	var list: Array = ResourceDatabase.achievements
	var unlocked := 0
	for a in list:
		if GameState.achievements.has(a.id):
			unlocked += 1
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 4)
	pages.add_child(outer)
	var head := _hbox()
	head.add_child(_label("ACHIEVEMENTS", "LabelGold"))
	var cnt := _label("%d / %d unlocked" % [unlocked, list.size()], "LabelSmall")
	cnt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(cnt)
	outer.add_child(head)
	outer.add_child(_bar(unlocked, list.size(), "ProgressGold"))
	outer.add_child(_scroll(vb))
	# unlocked first, then by progress
	var sorted := list.duplicate()
	sorted.sort_custom(func(a, b):
		var ua: bool = GameState.achievements.has(a.id)
		var ub: bool = GameState.achievements.has(b.id)
		if ua != ub:
			return ua
		return _ach_ratio(a) > _ach_ratio(b))
	for a in sorted:
		var done: bool = GameState.achievements.has(a.id)
		var card := _card("HudBox" if done else "PanelDark")
		vb.add_child(card[0])
		var row := _hbox(6)
		card[1].add_child(row)
		row.add_child(_icon(ResourceDatabase.ui_icon(int(a.get("icon", 26))), 16, Color.WHITE if done else Color(0.55, 0.58, 0.7)))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(_label(String(a.name), "LabelGold" if done else ""))
		col.add_child(_label(String(a.get("desc", "")), "LabelSmall"))
		var right := VBoxContainer.new()
		right.add_theme_constant_override("separation", 1)
		right.custom_minimum_size.x = 120
		row.add_child(right)
		var n := int(a.get("count", 1))
		var p := mini(GameState.counter(counter_key(String(a.get("type", "")), String(a.get("target", "")))), n)
		if done:
			p = n
		right.add_child(_bar(p, n, "ProgressGold" if done else "", "UNLOCKED" if done else "%s / %s" % [ResourceDatabase.fmt_num(p), ResourceDatabase.fmt_num(n)]))
		var rw := _reward_text(a)
		right.add_child(_label(rw if rw != "" else " ", "LabelDim"))

func _ach_ratio(a: Dictionary) -> float:
	var n := maxf(1.0, float(a.get("count", 1)))
	return GameState.counter(counter_key(String(a.get("type", "")), String(a.get("target", "")))) / n

# ================================================================ helpers
func _confirm(title: String, text: String, on_yes: Callable) -> void:
	var n := get_parent()
	while n:
		if n.has_method("show_confirm"):
			n.show_confirm(title, text, on_yes)
			return
		n = n.get_parent()
	SettingsPanel.make_confirm(self, title, text, on_yes)

func _capture_setup(args: Array) -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	theme = load("res://scripts/ui/ui_theme.gd").get_theme()
	GameState.new_game(3)
	for id in ["stone", "coal", "copper_ore", "quartz", "geode_small", "iron_ore", "silver_ore", "amethyst", "sapphire", "fossil_fern", "gold_ore", "crystal_shard", "ruby", "diamond"]:
		GameState.collection[id] = {"count": randi_range(3, 140), "best": randi_range(20, 900)}
	GameState.collection_rewards["25"] = true
	GameState.biomes_found[1] = true
	GameState.biomes_found[2] = true
	GameState.chambers["Old Miner's Camp"] = true
	GameState.tutorial = {"step": 12, "done": true, "skipped": false}
	GameState.quest_state = {"main_index": 1, "main_progress": 4, "challenges": [{"id": "c_stone", "progress": 12}, {"id": "c_geodes", "progress": 3}, {"id": "c_cart", "progress": 0}]}
	GameState.event_state = {"id": "crystal_surge", "time_left": 263.0, "progress": 3, "count": 8, "quest_text": "Mine 8 crystal or gem deposits"}
	GameState.counters = {"mine_any": 420, "mine_ore": 61, "open_geodes": 3, "level": 5, "earned": 4200}
	GameState.achievements = {"a_first_block": true, "a_geode_1": true, "a_depth_iron": true}
	open(args[0] if args.size() > 0 else "quests")
