extends "res://scripts/ui/panels/panel_base.gd"
## Machine panel (data = machine id): animated machine, level + upgrade, recipes (input -> output,
## have-counts, time), quantity 1/5/Max + Start, queue progress + Cancel, output + Collect.
## Drills pick a discovered biome; the Ore Sorter shows the rocks it pulls from Storage.

const MachineLogic = preload("res://scripts/machines/machine_logic.gd")

var _mid := ""
var _recipe := -1
var _qty := 1
var _anim: TextureRect
var _frames: Array[Texture2D] = []
var _anim_t := 0.0
var _lvl_l: Label
var _desc_l: Label
var _status_l: Label
var _upgrade_b: Button
var _list: VBoxContainer
var _qty_l: Label
var _start_b: Button
var _qty_row: HBoxContainer
var _bar: ProgressBar
var _bar_l: Label
var _queue_l: Label
var _cancel_b: Button
var _out_row: HBoxContainer
var _collect_b: Button
var _cap_l: Label

func build() -> void:
	win = Kit.window(self, "Machine", Vector2(440, 296), request_close)
	var body := Kit.hbox(6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	win.body.add_child(body)

	# ---------------- left: machine card
	var card := Kit.panel("PanelDark")
	card.custom_minimum_size = Vector2(140, 0)
	body.add_child(card)
	var cv := Kit.vbox(4)
	card.add_child(cv)
	var frame := Kit.panel("HudBox")
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_anim = Kit.icon(null)
	_anim.custom_minimum_size = Vector2(64, 64)
	frame.add_child(_anim)
	cv.add_child(frame)
	_lvl_l = Kit.label("Level 1 / 5", "LabelGold")
	_lvl_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(_lvl_l)
	_desc_l = Kit.wrap_label("", 128, "LabelSmall")
	cv.add_child(_desc_l)
	_status_l = Kit.wrap_label("", 128)
	cv.add_child(_status_l)
	cv.add_child(Kit.spacer(false))
	_upgrade_b = Kit.button("Upgrade", "ButtonGreen", _upgrade, 128, "buy")
	cv.add_child(_upgrade_b)

	# ---------------- right: recipes / production
	var right := Kit.vbox(4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 118)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sc)
	_list = Kit.vbox(2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	_qty_row = Kit.hbox(3)
	_qty_row.add_child(Kit.label("Amount:", "LabelDim"))
	for spec in [["1", 1], ["5", 5], ["Max", -1]]:
		var q: int = spec[1]
		_qty_row.add_child(Kit.button(spec[0], "ButtonDark", func(): _set_qty(q), 26))
	_qty_l = Kit.label("x1")
	_qty_l.custom_minimum_size.x = 28
	_qty_row.add_child(_qty_l)
	_qty_row.add_child(Kit.spacer())
	_start_b = Kit.button("Start", "", _start, 64)
	_qty_row.add_child(_start_b)
	right.add_child(_qty_row)

	var qp := Kit.panel("PanelDark")
	right.add_child(qp)
	var qv := Kit.vbox(2)
	qp.add_child(qv)
	var qh := Kit.hbox(4)
	_queue_l = Kit.label("Idle", "LabelSmall")
	_queue_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qh.add_child(_queue_l)
	_cancel_b = Kit.button("Cancel", "ButtonRed", _cancel)
	qh.add_child(_cancel_b)
	qv.add_child(qh)
	var pb: Array = Kit.text_bar("ProgressOrange", 260, 10)
	_bar = pb[0]
	_bar_l = pb[1]
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qv.add_child(_bar)

	var op := Kit.panel("PanelDark")
	right.add_child(op)
	var oh := Kit.hbox(4)
	op.add_child(oh)
	oh.add_child(Kit.label("Output", "LabelGold"))
	_out_row = Kit.hbox(2)
	_out_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oh.add_child(_out_row)
	_cap_l = Kit.label("", "LabelDim")
	oh.add_child(_cap_l)
	_collect_b = Kit.button("Collect", "ButtonGreen", _collect, 60, "pickup")
	oh.add_child(_collect_b)
	Events.machine_changed.connect(func(m):
		if is_inside_tree() and m == _mid:
			_refresh_dynamic())
	Events.inventory_changed.connect(func():
		if is_inside_tree():
			_refresh_list())

func open(data: Variant = null) -> void:
	_mid = String(data) if data != null else "smelter"
	_recipe = -1
	_qty = 1
	var m := ResourceDatabase.machine(_mid)
	win.title.text = m.get("name", "Machine")
	_frames.clear()
	var path := "res://assets/sprites/machines/%s.png" % _mid
	if ResourceLoader.exists(path):
		var base: Texture2D = load(path)
		for i in int(base.get_width() / 64):
			var at := AtlasTexture.new()
			at.atlas = base
			at.region = Rect2(i * 64, 0, 64, 64)
			_frames.append(at)
	else:
		_frames.append(ResourceDatabase.machine_icon(_mid))
	refresh()

func refresh() -> void:
	if _mid == "":
		return
	var m := ResourceDatabase.machine(_mid)
	_desc_l.text = m.get("desc", "")
	_refresh_list()
	_refresh_dynamic()

func _kind() -> String:
	return MachineLogic.kind(_mid)

func _refresh_list() -> void:
	if _mid == "":
		return
	Kit.clear(_list)
	var st := GameState.machine_state(_mid)
	match _kind():
		"processor":
			_qty_row.visible = true
			var recs := MachineLogic.recipes(_mid)
			for r in recs.size():
				_recipe_row(r, recs[r])
			if _recipe < 0:
				for r in recs.size():
					if MachineLogic.max_batches(_mid, r) > 0:
						_recipe = r
						break
			_highlight()
		"drill":
			_qty_row.visible = false
			var m := ResourceDatabase.machine(_mid)
			var biomes: Array = m.get("biomes", [0])
			if biomes != [-1]:
				var bh := Kit.hbox(2)
				bh.add_child(Kit.label("Drill site:", "LabelDim"))
				var group := ButtonGroup.new()
				for b in biomes:
					var bi := int(b)
					var bd := ResourceDatabase.biome(bi)
					var btn := Kit.button(bd.get("name", "?"), "TabButton")
					btn.toggle_mode = true
					btn.button_group = group
					var found: bool = bi < GameState.biomes_found.size() and GameState.biomes_found[bi]
					btn.disabled = not found
					btn.tooltip_text = "" if found else "Discover this biome first"
					btn.button_pressed = int(st.biome) == bi
					btn.pressed.connect(func(): MachineLogic.set_biome(_mid, bi); _refresh_list())
					bh.add_child(btn)
				_list.add_child(bh)
			var tables: Dictionary = m.get("tables", {})
			var key := str(int(st.biome))
			if not tables.has(key):
				key = tables.keys()[0]
			var total := 0.0
			for p in tables[key]:
				total += float(p[1])
			_list.add_child(Kit.label("Produces one item every %.1fs:" % MachineLogic.interval(_mid), "LabelSmall"))
			var g := GridContainer.new()
			g.columns = 3
			g.add_theme_constant_override("h_separation", 8)
			for p in tables[key]:
				var h := Kit.hbox(2)
				h.add_child(Kit.icon(ResourceDatabase.item_icon(p[0])))
				h.add_child(Kit.label("%s %d%%" % [ResourceDatabase.item_name(p[0]), int(round(float(p[1]) / total * 100.0))], "LabelSmall"))
				g.add_child(h)
			_list.add_child(g)
		"auto":
			_qty_row.visible = false
			var m2 := ResourceDatabase.machine(_mid)
			_list.add_child(Kit.wrap_label("Automatically takes %d rocks from Storage every %.1fs and sorts out gravel and trace ores:" % [int(m2.get("batch", 4)), MachineLogic.interval(_mid)], 250, "LabelSmall"))
			var g2 := GridContainer.new()
			g2.columns = 3
			g2.add_theme_constant_override("h_separation", 8)
			for id in m2.get("inputs", []):
				var h2 := Kit.hbox(2)
				h2.add_child(Kit.icon(ResourceDatabase.item_icon(id)))
				h2.add_child(Kit.label("%s: %d" % [ResourceDatabase.item_name(id), GameState.storage_count(id)], "LabelSmall"))
				g2.add_child(h2)
			_list.add_child(g2)

func _recipe_row(r: int, rec: Dictionary) -> void:
	var b := Button.new()
	b.theme_type_variation = "SlotButton"
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 26)
	b.name = "R%d" % r
	Kit.sfx(b)
	var h := Kit.hbox(3)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 4
	h.offset_right = -4
	b.add_child(h)
	h.add_child(Kit.icon(ResourceDatabase.item_icon(rec["in"])))
	h.add_child(Kit.label("x%d" % int(rec.in_n), "LabelSmall"))
	h.add_child(Kit.ui_icon(17))
	h.add_child(Kit.icon(ResourceDatabase.item_icon(rec.out)))
	var nm := Kit.label("%s x%d" % [ResourceDatabase.item_name(rec.out), int(rec.out_n)])
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	h.add_child(nm)
	var have := GameState.count_available(rec["in"])
	var batches := MachineLogic.max_batches(_mid, r)
	var hl := Kit.label("Have %d" % have, "LabelSmall" if batches > 0 else "LabelDim")
	h.add_child(hl)
	var tl := Kit.label("%.1fs" % MachineLogic.recipe_time(_mid, r), "LabelGold")
	tl.custom_minimum_size.x = 30
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(tl)
	b.tooltip_text = "%s -> %s\nUses backpack first, then Storage." % [ResourceDatabase.item_name(rec["in"]), ResourceDatabase.item_name(rec.out)]
	if batches <= 0:
		b.modulate = Color(1, 1, 1, 0.55)
	b.pressed.connect(func(): _recipe = r; _qty = clampi(_qty, 1, maxi(1, MachineLogic.max_batches(_mid, r))); _highlight())
	_list.add_child(b)

func _highlight() -> void:
	for c in _list.get_children():
		if c is Button and c.name.begins_with("R"):
			c.set_pressed_no_signal(int(c.name.substr(1)) == _recipe)
	_set_qty(_qty)

func _set_qty(q: int) -> void:
	if _recipe < 0:
		_qty_l.text = "-"
		_start_b.disabled = true
		return
	var mx := MachineLogic.max_batches(_mid, _recipe)
	var room := MachineLogic.queue_limit(_mid) - MachineLogic.queued_total(_mid)
	mx = mini(mx, room)
	_qty = mx if q < 0 else clampi(q, 1, maxi(1, mx))
	_qty_l.text = "x%d" % _qty
	_start_b.disabled = mx <= 0
	_start_b.tooltip_text = "" if mx > 0 else ("Queue is full" if room <= 0 else "Not enough materials")

func _refresh_dynamic() -> void:
	if _mid == "":
		return
	var st := GameState.machine_state(_mid)
	var maxl := int(ResourceDatabase.machine_upgrade.get("max_level", 5))
	_lvl_l.text = "Level %d / %d" % [int(st.level), maxl]
	if int(st.level) >= maxl:
		_upgrade_b.text = "MAX LEVEL"
		_upgrade_b.disabled = true
	else:
		var cost := GameState.machine_upgrade_cost(_mid)
		_upgrade_b.text = "Upgrade $%s" % ResourceDatabase.fmt_short(cost)
		_upgrade_b.disabled = GameState.coins < cost
		_upgrade_b.tooltip_text = "+25% speed and +20% output per level"
	var working := MachineLogic.is_working(_mid)
	match _kind():
		"processor":
			var qt := MachineLogic.queued_total(_mid)
			_queue_l.text = ("Processing  •  %d in queue (max %d)" % [qt, MachineLogic.queue_limit(_mid)]) if qt > 0 else "Idle  •  choose a recipe and press Start"
			_cancel_b.visible = qt > 0
			_status_l.text = "Working..." if working else "Idle"
		"drill", "auto":
			_cancel_b.visible = false
			var full := MachineLogic.output_total(_mid) >= MachineLogic.capacity(_mid)
			_queue_l.text = "Output full! Collect to keep it running." if full else ("Working..." if working else "Waiting for rocks in Storage")
			_status_l.text = "Full" if full else ("Working..." if working else "Idle")
	_status_l.add_theme_color_override("font_color", Color("7dff8a") if working else Color("c3cad8"))
	Kit.clear(_out_row)
	var out: Dictionary = st.output
	var shown := 0
	for id in out:
		if shown >= 6:
			break
		var s = ItemSlot.new(22)
		s.toggle_mode = false
		s.mouse_filter = Control.MOUSE_FILTER_PASS
		s.set_item(id, int(out[id]))
		_out_row.add_child(s)
		shown += 1
	if shown == 0:
		_out_row.add_child(Kit.label("empty", "LabelDim"))
	_cap_l.text = "%d/%d" % [MachineLogic.output_total(_mid), MachineLogic.capacity(_mid)] if _kind() != "processor" else ""
	_collect_b.disabled = out.is_empty()
	if _recipe >= 0:
		_set_qty(_qty)

func _process(delta: float) -> void:
	if _mid == "" or not is_visible_in_tree():
		return
	var p := MachineLogic.current_progress(_mid)
	_bar.value = p
	var st := GameState.machine_state(_mid)
	if _kind() == "processor" and not st.queue.is_empty():
		var rec: Dictionary = MachineLogic.recipes(_mid)[int(st.queue[0].r)]
		var t := MachineLogic.recipe_time(_mid, int(st.queue[0].r))
		_bar_l.text = "%s  %.1fs" % [ResourceDatabase.item_name(rec.out), maxf(0.0, t - float(st.progress))]
	elif _kind() != "processor":
		_bar_l.text = "Next item %.1fs" % maxf(0.0, MachineLogic.interval(_mid) - float(st.timer))
	else:
		_bar_l.text = ""
	if _frames.size() > 1 and MachineLogic.is_working(_mid):
		_anim_t += delta * 8.0
		_anim.texture = _frames[1 + int(_anim_t) % (_frames.size() - 1)]
	else:
		_anim.texture = _frames[0] if _frames.size() > 0 else null

func _start() -> void:
	var why := MachineLogic.queue_recipe(_mid, _recipe, _qty)
	if why != "":
		error(why)
		return
	AudioManager.play(String(ResourceDatabase.machine(_mid).get("sound", "smelter")), -6.0)
	_refresh_list()
	_refresh_dynamic()

func _cancel() -> void:
	confirm("Cancel Queue?", "Stop processing and return all unprocessed materials?", func():
		MachineLogic.cancel_queue(_mid)
		_refresh_list(), "Cancel Queue")

func _collect() -> void:
	var n := MachineLogic.collect(_mid)
	if n > 0:
		AudioManager.play("pickup_rare", -3.0)

func _upgrade() -> void:
	var why := GameState.upgrade_machine(_mid)
	if why != "":
		error(why)
	else:
		AudioManager.play("skill_unlock", -4.0)
		fx_upgrade("Level %d!" % int(GameState.machine_state(_mid).level))
		toast("%s upgraded to level %d!" % [ResourceDatabase.machine(_mid).name, int(GameState.machine_state(_mid).level)], "good")
		_refresh_list()
		_refresh_dynamic()
