extends "res://scripts/ui/panels/panel_base.gd"
## Backpack: filterable/sortable slot grid, selected-item details and actions
## (Use, Open Geode, Store, Sell, Drop) plus the equipped-gear strip.

const COLS := 9

var _filter := "All"
var _sel := -1
var _amount := 1
var _grid: GridContainer
var _cap_l: Label
var _coins: HBoxContainer
var _d_icon
var _d_name: Label
var _d_meta: Label
var _d_value: Label
var _d_desc: Label
var _d_proc: Label
var _d_amount: Label
var _d_box: VBoxContainer
var _empty_hint: Label
var _btn_use: Button
var _btn_geode: Button
var _btn_store: Button
var _btn_sell: Button
var _btn_drop: Button
var _btn_deposit_all: Button
var _equip_row: HBoxContainer
var _where: Label

func build() -> void:
	win = Kit.window(self, "Backpack", Vector2(460, 296), request_close)
	var extra: HBoxContainer = win.extra
	var capc := Kit.panel("HudBox")
	capc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ch := Kit.hbox(3)
	capc.add_child(ch)
	ch.add_child(Kit.ui_icon(8))
	_cap_l = Kit.label("0 / 20")
	ch.add_child(_cap_l)
	extra.add_child(capc)
	var coinc := Kit.panel("HudBox")
	coinc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coins = Kit.coin_label(0, "")
	coinc.add_child(_coins)
	extra.add_child(coinc)

	var body := Kit.hbox(6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	win.body.add_child(body)

	# ---------------- left: tabs + grid + equipment
	var left := Kit.vbox(4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	left.add_child(make_tabs(ResourceDatabase.FILTERS.keys(), func(n): _filter = n; _sel = -1; refresh()))
	var sort_row := Kit.hbox(3)
	sort_row.add_child(Kit.label("Sort:", "LabelDim"))
	for m in [["Value", "value"], ["Rarity", "rarity"], ["Name", "name"]]:
		var mode: String = m[1]
		sort_row.add_child(Kit.button(m[0], "ButtonDark", func(): GameState.sort_inventory(mode); _sel = -1; refresh()))
	sort_row.add_child(Kit.spacer())
	_btn_deposit_all = Kit.button("Deposit All", "ButtonGreen", _deposit_all)
	_btn_deposit_all.tooltip_text = "Move every resource into camp Storage"
	sort_row.add_child(_btn_deposit_all)
	left.add_child(sort_row)
	var gp := Kit.panel("PanelDark")
	gp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(gp)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(COLS * 26 + 8, 150)
	gp.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(_grid)
	_empty_hint = Kit.label("Nothing here yet. Go mine something!", "LabelDim")
	_empty_hint.visible = false
	left.add_child(_empty_hint)
	_equip_row = Kit.hbox(2)
	left.add_child(_equip_row)

	# ---------------- right: details
	var det := Kit.panel("PanelDark")
	det.custom_minimum_size = Vector2(168, 0)
	body.add_child(det)
	_d_box = Kit.vbox(3)
	det.add_child(_d_box)
	var top := Kit.hbox(5)
	_d_icon = ItemSlot.new(40)
	_d_icon.toggle_mode = false
	_d_icon.disabled = true
	_d_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_d_icon.set_icon_scale(2)
	top.add_child(_d_icon)
	var tv := Kit.vbox(0)
	_d_name = Kit.wrap_label("", 112, "LabelHeader")
	_d_name.remove_theme_font_override("font")
	tv.add_child(_d_name)
	_d_meta = Kit.label("", "LabelSmall")
	tv.add_child(_d_meta)
	top.add_child(tv)
	_d_box.add_child(top)
	_d_value = Kit.label("", "LabelGold")
	_d_box.add_child(_d_value)
	_d_desc = Kit.wrap_label("", 156)
	_d_box.add_child(_d_desc)
	_d_proc = Kit.wrap_label("", 156, "LabelDim")
	_d_box.add_child(_d_proc)
	_d_box.add_child(Kit.spacer(false))
	var amt := Kit.hbox(2)
	amt.add_child(Kit.label("Amount", "LabelDim"))
	amt.add_child(Kit.spacer())
	amt.add_child(Kit.button("-", "ButtonDark", func(): _set_amount(_amount - 1), 18))
	_d_amount = Kit.label("1")
	_d_amount.custom_minimum_size.x = 22
	_d_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amt.add_child(_d_amount)
	amt.add_child(Kit.button("+", "ButtonDark", func(): _set_amount(_amount + 1), 18))
	amt.add_child(Kit.button("All", "ButtonDark", func(): _set_amount(9999)))
	_d_box.add_child(amt)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 3)
	g.add_theme_constant_override("v_separation", 3)
	_btn_use = Kit.button("Use", "", _use, 78)
	_btn_geode = Kit.button("Open Geode", "ButtonGold", _open_geode, 78)
	_btn_store = Kit.button("Store", "ButtonDark", _store, 78)
	_btn_sell = Kit.button("Sell", "ButtonGreen", _sell, 78, "sell")
	_btn_drop = Kit.button("Drop", "ButtonRed", _drop, 78)
	for b in [_btn_use, _btn_geode, _btn_store, _btn_sell, _btn_drop]:
		g.add_child(b)
	_d_box.add_child(g)
	_where = Kit.wrap_label("", 156, "LabelDim")
	_d_box.add_child(_where)
	Events.inventory_changed.connect(func():
		if is_inside_tree():
			refresh())
	Events.coins_changed.connect(func(_t, _d):
		if is_inside_tree():
			(_coins.get_node("Amount") as Label).text = ResourceDatabase.fmt_num(GameState.coins))

func open(_data: Variant = null) -> void:
	_sel = -1
	refresh()

func _visible_slots() -> Array:
	var out: Array = []
	var cats: Array = ResourceDatabase.FILTERS.get(_filter, [])
	for i in GameState.inventory.size():
		var s: Dictionary = GameState.inventory[i]
		if cats.is_empty():
			out.append(i)
		elif not s.is_empty() and ResourceDatabase.item_category(s.id) in cats:
			out.append(i)
	return out

func refresh() -> void:
	(_coins.get_node("Amount") as Label).text = ResourceDatabase.fmt_num(GameState.coins)
	_cap_l.text = "%d / %d" % [GameState.used_slots(), GameState.inventory_capacity()]
	Kit.clear(_grid)
	var shown := _visible_slots()
	if _sel >= 0 and (_sel >= GameState.inventory.size() or GameState.inventory[_sel].is_empty()):
		_sel = -1
	if _sel < 0:
		for i in shown:
			if not GameState.inventory[i].is_empty():
				_sel = i
				break
	var any := false
	for i: int in shown:
		var s: Dictionary = GameState.inventory[i]
		var slot = ItemSlot.new(24)
		slot.index = i
		if s.is_empty():
			slot.set_item("")
		else:
			slot.set_item(s.id, int(s.n))
			any = true
		slot.set_pressed_no_signal(i == _sel)
		var idx := i
		slot.pressed.connect(func(): _select(idx))
		_grid.add_child(slot)
	_empty_hint.visible = not any and _filter != "All"
	_btn_deposit_all.disabled = not GameState.at_surface or GameState.used_slots() == 0
	_refresh_equipment()
	_refresh_details()

func _refresh_equipment() -> void:
	Kit.clear(_equip_row)
	_equip_row.add_child(Kit.label("Gear:", "LabelDim"))
	for slot in ["pickaxe", "drill", "backpack", "lantern", "boots", "scanner"]:
		var id: String = GameState.equipped.get(slot, "")
		var s = ItemSlot.new(22)
		s.toggle_mode = false
		if id != "":
			var e := ResourceDatabase.equip(id)
			s.set_texture(ResourceDatabase.equip_icon(id), 0, Color.WHITE, "%s: %s\n%s" % [slot.capitalize(), e.get("name", id), e.get("desc", "")])
		else:
			s.set_texture(null, 0, Color.WHITE, "%s: none (buy at the Shop)" % slot.capitalize())
		_equip_row.add_child(s)

func _select(i: int) -> void:
	_sel = i
	var s: Dictionary = GameState.inventory[i] if i < GameState.inventory.size() else {}
	_amount = int(s.get("n", 1))
	for c in _grid.get_children():
		c.set_pressed_no_signal(c.index == i)
	_refresh_details()

func _sel_item() -> Dictionary:
	if _sel < 0 or _sel >= GameState.inventory.size():
		return {}
	return GameState.inventory[_sel]

func _set_amount(n: int) -> void:
	var s := _sel_item()
	if s.is_empty():
		return
	_amount = clampi(n, 1, GameState.count_item(s.id))
	_d_amount.text = str(_amount)

func _refresh_details() -> void:
	var s := _sel_item()
	var has := not s.is_empty()
	for c in _d_box.get_children():
		c.visible = has
	_where.visible = true
	if not has:
		_where.text = "Select an item to see its details."
		return
	var id: String = s.id
	var it := ResourceDatabase.item(id)
	var r := ResourceDatabase.item_rarity(id)
	_d_icon.set_item(id, int(s.n))
	_d_name.text = it.get("name", id)
	_d_name.add_theme_color_override("font_color", ResourceDatabase.rarity_color(r))
	_d_meta.text = "%s  •  %s" % [ResourceDatabase.rarity_name(r), ResourceDatabase.CATEGORY_NAMES.get(it.get("category", ""), "")]
	var total := GameState.count_item(id)
	var v := GameState.sell_value(id)
	_d_value.text = "$%s each  •  x%d = $%s" % [ResourceDatabase.fmt_num(v), total, ResourceDatabase.fmt_num(v * total)]
	_d_desc.text = it.get("desc", "")
	_d_proc.text = it.get("process", "")
	_d_proc.visible = _d_proc.text != ""
	_amount = clampi(_amount, 1, maxi(1, total))
	_d_amount.text = str(_amount)
	var surface := GameState.at_surface
	var use: String = it.get("use", "")
	_btn_use.visible = use != ""
	_btn_use.text = "Use" if use in ["heal", "recall"] else "Hold"
	_btn_use.tooltip_text = "Drink / use now" if use in ["heal", "recall"] else "Select on the hotbar (right-click in the world to use)"
	_btn_geode.visible = it.get("category", "") == "geode"
	_btn_geode.disabled = not surface
	_btn_geode.tooltip_text = "Open it at the camp" if not surface else "Crack it open!"
	_btn_store.disabled = not surface
	_btn_sell.disabled = not surface or v <= 0
	_btn_store.tooltip_text = "Only at the camp" if not surface else "Move to Storage"
	_btn_sell.tooltip_text = "Only at the camp" if not surface else "Sell %d for $%s" % [_amount, ResourceDatabase.fmt_num(v * _amount)]
	_where.text = "" if surface else "Selling, storage and geodes are available back at the mining camp."
	_where.visible = not surface

# ---------------------------------------------------------------- actions
func _use() -> void:
	var s := _sel_item()
	if s.is_empty():
		return
	var use: String = ResourceDatabase.item(s.id).get("use", "")
	if use in ["heal", "recall"]:
		Events.use_item_requested.emit(s.id)
		if use == "recall":
			request_close()
	else:
		var hi := GameState.HOTBAR.find(s.id)
		if hi >= 0:
			GameState.hotbar_index = hi
			Events.hotbar_changed.emit()
			toast("%s ready on hotbar slot %d. Right-click to use it." % [ResourceDatabase.item_name(s.id), hi + 1])
			request_close()
		else:
			Events.use_item_requested.emit(s.id)

func _open_geode() -> void:
	var s := _sel_item()
	if s.is_empty():
		return
	if not GameState.at_surface:
		error("Geodes can only be opened at the camp.")
		return
	var res := GameState.open_geode(s.id)
	if res.is_empty():
		error("Couldn't open that geode.")

func _store() -> void:
	var s := _sel_item()
	if s.is_empty():
		return
	var n := GameState.deposit(s.id, _amount)
	if n <= 0:
		error("Storage is full! Upgrade it with Resource Organizer.")
	else:
		AudioManager.play("place", -4.0)
		toast("Stored %d %s" % [n, ResourceDatabase.item_name(s.id)], "good")

func _sell() -> void:
	var s := _sel_item()
	if s.is_empty():
		return
	var id: String = s.id
	var n := _amount
	var go := func():
		var v := GameState.sell_from_inventory(id, n)
		if v > 0:
			AudioManager.play("coin", -2.0)
			toast("Sold %d %s for $%s" % [n, ResourceDatabase.item_name(id), ResourceDatabase.fmt_num(v)], "coin")
	if ResourceDatabase.item_rarity(id) >= 3:
		confirm("Sell %s?" % ResourceDatabase.item_name(id), "This is a rare find. Sell %d for $%s?" % [n, ResourceDatabase.fmt_num(n * GameState.sell_value(id))], go, "Sell", false)
	else:
		go.call()

func _drop() -> void:
	var s := _sel_item()
	if s.is_empty():
		return
	var id: String = s.id
	var n := _amount
	confirm("Drop Items?", "Drop %d %s on the ground? You can pick it up again." % [n, ResourceDatabase.item_name(id)], func():
		var removed := GameState.remove_item(id, n)
		if removed > 0:
			Events.drop_item_requested.emit(id, removed), "Drop")

func _deposit_all() -> void:
	if not GameState.at_surface:
		error("Storage is at the camp.")
		return
	var n := GameState.deposit_all()
	if n > 0:
		AudioManager.play("place", -4.0)
		toast("Deposited %d items into Storage" % n, "good")
	else:
		error("Nothing to deposit (or Storage is full).")
