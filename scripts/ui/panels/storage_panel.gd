extends "res://scripts/ui/panels/panel_base.gd"
## Camp Storage: backpack grid (left) <-> storage grid (right), selected-item strip with
## Deposit / Withdraw / Sell. Resource Organizer (skill) unlocks Quick Stack and Smart Sort.

const COLS := 7

var _bag: GridContainer
var _store: GridContainer
var _cap_bar: ProgressBar
var _cap_l: Label
var _sel_id := ""
var _sel_from := "bag"
var _amount := 1
var _s_icon
var _s_name: Label
var _s_counts: Label
var _s_amount: Label
var _btn_dep: Button
var _btn_wd: Button
var _btn_sell: Button
var _btn_quick: Button
var _btn_sort: Button
var _smart := true

func build() -> void:
	win = Kit.window(self, "Storage", Vector2(470, 296), request_close)
	var cb: Array = Kit.text_bar("ProgressGreen", 110, 10)
	_cap_bar = cb[0]
	_cap_l = cb[1]
	_cap_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	win.extra.add_child(Kit.ui_icon(47))
	win.extra.add_child(_cap_bar)

	var tools := Kit.hbox(3)
	tools.add_child(Kit.button("Deposit All", "ButtonGreen", _deposit_all))
	_btn_quick = Kit.button("Quick Stack", "", _quick_stack)
	tools.add_child(_btn_quick)
	_btn_sort = Kit.button("Smart Sort", "ButtonDark", func(): _smart = not _smart; refresh())
	tools.add_child(_btn_sort)
	tools.add_child(Kit.spacer())
	tools.add_child(Kit.button("Sort Backpack", "ButtonDark", func(): GameState.sort_inventory("rarity"); refresh()))
	win.body.add_child(tools)

	var cols := Kit.hbox(6)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	win.body.add_child(cols)
	_bag = _grid_column(cols, "Backpack", 8)
	_store = _grid_column(cols, "Storage", 47)

	var strip := Kit.panel("PanelDark")
	win.body.add_child(strip)
	var h := Kit.hbox(5)
	strip.add_child(h)
	_s_icon = ItemSlot.new(26)
	_s_icon.toggle_mode = false
	_s_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_s_icon)
	var v := Kit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_s_name = Kit.label("Select an item")
	_s_name.clip_text = true
	_s_name.custom_minimum_size.x = 150
	_s_counts = Kit.label("", "LabelDim")
	_s_counts.clip_text = true
	_s_counts.custom_minimum_size.x = 150
	v.add_child(_s_name)
	v.add_child(_s_counts)
	h.add_child(v)
	h.add_child(Kit.button("-", "ButtonDark", func(): _set_amount(_amount - 1), 18))
	_s_amount = Kit.label("1")
	_s_amount.custom_minimum_size.x = 24
	_s_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(_s_amount)
	h.add_child(Kit.button("+", "ButtonDark", func(): _set_amount(_amount + 1), 18))
	h.add_child(Kit.button("All", "ButtonDark", func(): _set_amount(999999)))
	_btn_dep = Kit.button("Deposit", "ButtonGreen", _deposit, 56)
	_btn_wd = Kit.button("Withdraw", "", _withdraw, 60)
	_btn_sell = Kit.button("Sell", "ButtonGold", _sell, 40, "sell")
	h.add_child(_btn_dep)
	h.add_child(_btn_wd)
	h.add_child(_btn_sell)
	Events.inventory_changed.connect(func():
		if is_inside_tree():
			refresh())
	Events.storage_changed.connect(func():
		if is_inside_tree():
			refresh())

func _grid_column(parent: Control, title: String, icon_i: int) -> GridContainer:
	var v := Kit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	var th := Kit.hbox(3)
	th.add_child(Kit.ui_icon(icon_i))
	th.add_child(Kit.label(title, "LabelGold"))
	v.add_child(th)
	var p := Kit.panel("PanelDark")
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(p)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(COLS * 26 + 10, 130)
	p.add_child(sc)
	var g := GridContainer.new()
	g.columns = COLS
	g.add_theme_constant_override("h_separation", 2)
	g.add_theme_constant_override("v_separation", 2)
	sc.add_child(g)
	return g

func open(_data: Variant = null) -> void:
	_sel_id = ""
	refresh()

func refresh() -> void:
	var used := GameState.storage_used_slots()
	var cap := GameState.storage_capacity()
	_cap_bar.value = float(used) / maxf(1.0, cap)
	_cap_l.text = "%d / %d stacks" % [used, cap]
	var org := int(GameState.stat(&"organizer_level"))
	_btn_quick.disabled = org < 1
	_btn_quick.tooltip_text = "Deposit only items you already store" if org >= 1 else "Unlock with the Resource Organizer skill"
	_btn_sort.disabled = org < 1
	_btn_sort.text = ("Smart Sort" if _smart else "A-Z Sort") if org >= 1 else "Smart Sort"
	_btn_sort.tooltip_text = "Group storage by category" if org >= 1 else "Unlock with the Resource Organizer skill"
	# backpack
	Kit.clear(_bag)
	for i in GameState.inventory.size():
		var s: Dictionary = GameState.inventory[i]
		var slot = ItemSlot.new(24)
		if s.is_empty():
			slot.set_item("")
			slot.disabled = true
		else:
			slot.set_item(s.id, int(s.n))
			slot.set_pressed_no_signal(_sel_from == "bag" and _sel_id == s.id)
			var id: String = s.id
			slot.pressed.connect(func(): _select(id, "bag"))
		_bag.add_child(slot)
	# storage
	Kit.clear(_store)
	var ids: Array = GameState.storage.keys()
	if _smart and org >= 1:
		var order := ["ore", "rock", "gem", "polished", "bar", "processed", "special", "essence", "geode", "fossil", "artifact", "consumable"]
		ids.sort_custom(func(a, b):
			var ca := order.find(ResourceDatabase.item_category(a))
			var cb := order.find(ResourceDatabase.item_category(b))
			return ca < cb if ca != cb else ResourceDatabase.item_value(a) > ResourceDatabase.item_value(b))
	else:
		ids.sort_custom(func(a, b): return ResourceDatabase.item_name(a) < ResourceDatabase.item_name(b))
	for id in ids:
		var n := GameState.storage_count(id)
		if n <= 0:
			continue
		var slot2 = ItemSlot.new(24)
		slot2.set_item(id, n)
		if n > 999:
			slot2.set_count_text(ResourceDatabase.fmt_short(n))
		slot2.set_pressed_no_signal(_sel_from == "store" and _sel_id == id)
		var sid: String = id
		slot2.pressed.connect(func(): _select(sid, "store"))
		_store.add_child(slot2)
	for i in maxi(0, cap - _store.get_child_count()):
		if i > 40:
			break
		var e = ItemSlot.new(24)
		e.disabled = true
		_store.add_child(e)
	_refresh_strip()

func _select(id: String, from: String) -> void:
	_sel_id = id
	_sel_from = from
	_amount = GameState.count_item(id) if from == "bag" else GameState.storage_count(id)
	refresh()

func _set_amount(n: int) -> void:
	if _sel_id == "":
		return
	var mx := GameState.count_item(_sel_id) if _sel_from == "bag" else GameState.storage_count(_sel_id)
	_amount = clampi(n, 1, maxi(1, mx))
	_s_amount.text = str(_amount)

func _refresh_strip() -> void:
	var has := _sel_id != "" and (GameState.count_item(_sel_id) > 0 or GameState.storage_count(_sel_id) > 0)
	if not has:
		_sel_id = ""
		_s_icon.set_item("")
		_s_name.text = "Select an item"
		_s_counts.text = "Click an item to move it."
	else:
		_s_icon.set_item(_sel_id, 1)
		_s_name.text = ResourceDatabase.item_name(_sel_id)
		_s_name.add_theme_color_override("font_color", ResourceDatabase.rarity_color(ResourceDatabase.item_rarity(_sel_id)))
		_s_counts.text = "Bag %d • Stored %d • $%s" % [GameState.count_item(_sel_id), GameState.storage_count(_sel_id), ResourceDatabase.fmt_num(GameState.sell_value(_sel_id))]
		var mx := GameState.count_item(_sel_id) if _sel_from == "bag" else GameState.storage_count(_sel_id)
		_amount = clampi(_amount, 1, maxi(1, mx))
	_s_amount.text = str(_amount)
	_btn_dep.disabled = not has or GameState.count_item(_sel_id) <= 0
	_btn_wd.disabled = not has or GameState.storage_count(_sel_id) <= 0
	_btn_sell.disabled = not has or GameState.sell_value(_sel_id) <= 0

func _deposit() -> void:
	var n := GameState.deposit(_sel_id, mini(_amount, GameState.count_item(_sel_id)))
	if n <= 0:
		error("Storage is full!")
	else:
		AudioManager.play("place", -4.0)

func _withdraw() -> void:
	var n := GameState.withdraw(_sel_id, mini(_amount, GameState.storage_count(_sel_id)))
	if n <= 0:
		error("Your backpack is full!")
	else:
		AudioManager.play("pickup", -4.0)

func _sell() -> void:
	var id := _sel_id
	var n := _amount
	var go := func():
		var v := 0
		if _sel_from == "bag":
			v = GameState.sell_from_inventory(id, n)
		else:
			v = GameState.sell_from_storage(id, n)
		if v > 0:
			AudioManager.play("coin", -3.0)
			toast("Sold for $%s" % ResourceDatabase.fmt_num(v), "coin")
	if ResourceDatabase.item_rarity(id) >= 3:
		confirm("Sell %s?" % ResourceDatabase.item_name(id), "Sell %d for $%s?" % [n, ResourceDatabase.fmt_num(n * GameState.sell_value(id))], go, "Sell", false)
	else:
		go.call()

func _deposit_all() -> void:
	var n := GameState.deposit_all()
	if n > 0:
		AudioManager.play("place", -3.0)
		toast("Deposited %d items" % n, "good")
	else:
		error("Nothing to deposit (or Storage is full).")

func _quick_stack() -> void:
	var total := 0
	for id in GameState.storage.keys():
		total += GameState.deposit(id, GameState.count_item(id))
	if total > 0:
		AudioManager.play("place", -3.0)
		toast("Quick-stacked %d items" % total, "good")
	else:
		error("Nothing matching to stack.")
