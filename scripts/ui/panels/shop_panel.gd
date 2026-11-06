extends "res://scripts/ui/panels/panel_base.gd"
## General Shop (reference "Shop" window): tabs Pickaxes / Equipment / Backpacks / Special Items /
## Machines / Sell. Rows: icon slot, white name, gold price + stats, green Buy (or Equip/Owned/Lv lock).
## Sells real equipment only — permanent stat upgrades live in the Skill Tree.

const TABS := ["Pickaxes", "Equipment", "Backpacks", "Special Items", "Machines", "Sell"]
const ROCK_CATS := ["rock", "processed"]
const KEEP_CATS := ["gem", "polished", "geode", "fossil", "artifact", "consumable"]

var _tab := "Pickaxes"
var _list: VBoxContainer
var _scroll: ScrollContainer
var _coins_l: Label
var _tabs: HBoxContainer
var _footer: HBoxContainer

func build() -> void:
	win = Kit.window(self, "Shop", Vector2(436, 296), request_close)
	var coinc := Kit.panel("HudBox")
	coinc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ch := Kit.hbox(3)
	coinc.add_child(ch)
	ch.add_child(Kit.ui_icon(0))
	_coins_l = Kit.label("0", "LabelGold")
	ch.add_child(_coins_l)
	win.extra.add_child(coinc)
	_tabs = make_tabs(TABS, func(n): _tab = n; _scroll.scroll_vertical = 0; refresh())
	win.body.add_child(_tabs)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 196)
	win.body.add_child(_scroll)
	_list = Kit.vbox(3)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_footer = Kit.hbox(4)
	win.body.add_child(_footer)
	Events.coins_changed.connect(func(_t, _d):
		if is_inside_tree():
			refresh())
	Events.equipment_changed.connect(func():
		if is_inside_tree():
			refresh())

func open(data: Variant = null) -> void:
	if data is String and data in TABS:
		_tab = data
		for b in _tabs.get_children():
			b.button_pressed = b.text == _tab
	refresh()

func refresh() -> void:
	_coins_l.text = ResourceDatabase.fmt_num(GameState.coins)
	Kit.clear(_list)
	Kit.clear(_footer)
	match _tab:
		"Pickaxes":
			for id in ResourceDatabase.equipment_by_slot.get("pickaxe", []):
				_equip_row(id)
			_hint("Pickaxe tier decides which rock you can break. Seals between biomes need a stronger tier.")
		"Equipment":
			_section("Lanterns")
			for id in ResourceDatabase.equipment_by_slot.get("lantern", []):
				_equip_row(id)
			_section("Mining Scanners")
			for id in ResourceDatabase.equipment_by_slot.get("scanner", []):
				_equip_row(id)
			_section("Mining Boots")
			for id in ResourceDatabase.equipment_by_slot.get("boots", []):
				_equip_row(id)
			_section("Portable Drills")
			for id in ResourceDatabase.equipment_by_slot.get("drill", []):
				_equip_row(id)
		"Backpacks":
			for id in ResourceDatabase.equipment_by_slot.get("backpack", []):
				_equip_row(id)
			_hint("Skill Tree > Equipment adds even more slots and bigger stacks.")
		"Special Items":
			for id in ResourceDatabase.item_order:
				if ResourceDatabase.item(id).has("price"):
					_consumable_row(id)
		"Machines":
			for mid in ResourceDatabase.machine_order:
				_machine_row(mid)
		"Sell":
			_build_sell()

func _hint(t: String) -> void:
	_footer.add_child(Kit.wrap_label(t, 400, "LabelDim"))

func _section(t: String) -> void:
	var l := Kit.label(t, "LabelGold")
	_list.add_child(l)

## Generic row: [slot icon] [name / price + stats] ... [right controls]
func _row(tex: Texture2D, name_text: String, price: int, stats: String, rarity_col: Variant = null, count: int = 0) -> Dictionary:
	var p := Kit.panel("PanelDark")
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := Kit.hbox(6)
	p.add_child(h)
	var s = ItemSlot.new(26)
	s.toggle_mode = false
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.set_texture(tex, count)
	if rarity_col != null:
		s.get_child(0).visible = true
		s.get_child(0).modulate = rarity_col
	h.add_child(s)
	var v := Kit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(Kit.label(name_text))
	var line := Kit.hbox(6)
	v.add_child(line)
	var price_l := Kit.label(Kit.fmt_price(price) if price > 0 else "Free", "LabelGold")
	line.add_child(price_l)
	if stats != "":
		var st := Kit.label(stats, "LabelDim")
		st.clip_text = true
		st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(st)
	var right := Kit.hbox(3)
	right.alignment = BoxContainer.ALIGNMENT_END
	h.add_child(right)
	_list.add_child(p)
	return {"panel": p, "right": right, "price": price_l, "slot": s}

func _equip_stats(e: Dictionary) -> String:
	match e.get("slot", ""):
		"pickaxe":
			return "Power %s  •  Speed x%s  •  Tier %d" % [str(e.power), str(e.speed), int(e.tier)]
		"backpack":
			return "Holds %d stacks" % int(e.slots)
		"lantern":
			return "Light radius %d" % int(e.radius)
		"scanner":
			return "Range %d tiles" % int(e.range)
		"boots":
			var parts: Array[String] = []
			if float(e.speed) > 0.0: parts.append("+%d%% speed" % int(float(e.speed) * 100))
			if float(e.grip) > 0.0: parts.append("ice grip")
			if e.get("heat", false): parts.append("heat proof")
			if float(e.fall) >= 1.0: parts.append("no fall damage")
			return "  •  ".join(parts) if not parts.is_empty() else "Standard"
		"drill":
			return "Area mining  •  x%s power" % str(e.power_mult)
	return ""

func _equip_row(id: String) -> void:
	var e := ResourceDatabase.equip(id)
	var r := _row(ResourceDatabase.equip_icon(id), e.get("name", id), int(e.get("price", 0)), _equip_stats(e))
	r.panel.tooltip_text = e.get("desc", "")
	var right: HBoxContainer = r.right
	var price := int(e.get("price", 0))
	if GameState.owns(id):
		var equipped: bool = GameState.equipped.get(e.slot, "") == id
		if equipped:
			var b := Kit.button("Equipped", "ButtonDark", Callable(), 70)
			b.disabled = true
			right.add_child(b)
		else:
			right.add_child(Kit.button("Equip", "", func(): GameState.equip_item(id); AudioManager.play("buy", -6.0), 70))
		r.price.text = "Owned"
		r.price.theme_type_variation = "LabelDim"
		return
	var req := GameState.equipment_level_req(id)
	if GameState.level < req:
		var lb := Kit.button("Lv %d" % req, "ButtonDark", Callable(), 70)
		lb.disabled = true
		lb.icon = ResourceDatabase.ui_icon(14)
		lb.tooltip_text = "Reach level %d to buy this" % req
		right.add_child(lb)
		return
	var buy := Kit.button("Buy", "ButtonGreen", func(): _buy_equipment(id), 70, "buy")
	if GameState.coins < price:
		buy.disabled = true
		buy.tooltip_text = "Need $%s more" % ResourceDatabase.fmt_num(price - GameState.coins)
		r.price.add_theme_color_override("font_color", Color("ff6a6a"))
	right.add_child(buy)

func _buy_equipment(id: String) -> void:
	var why := GameState.buy_equipment(id)
	if why != "":
		error(why)
		return
	AudioManager.play("coin", -4.0)
	fx_purchase(ResourceDatabase.equip_icon(id))
	toast("Bought %s!" % ResourceDatabase.equip(id).get("name", id), "good")
	refresh()

func _consumable_row(id: String) -> void:
	var it := ResourceDatabase.item(id)
	var have := GameState.count_item(id)
	var r := _row(ResourceDatabase.item_icon(id), it.name, int(it.price), "You have %d" % have, null, have)
	r.panel.tooltip_text = it.get("desc", "")
	var right: HBoxContainer = r.right
	for n in [1, 5]:
		var nn: int = n
		var b := Kit.button("Buy x%d" % n, "ButtonGreen", func(): _buy_item(id, nn), 52, "buy")
		if GameState.coins < int(it.price) * n:
			b.disabled = true
		right.add_child(b)

func _buy_item(id: String, n: int) -> void:
	var why := GameState.buy_item(id, n)
	if why != "":
		error(why)
		return
	AudioManager.play("coin", -4.0)
	fx_purchase(ResourceDatabase.item_icon(id), "+%d %s" % [n, ResourceDatabase.item_name(id)])
	refresh()

func _machine_row(mid: String) -> void:
	var m := ResourceDatabase.machine(mid)
	var st := GameState.machine_state(mid)
	var why := GameState.machine_unlocked_for_purchase(mid)
	var stats: String = m.get("desc", "")
	var r := _row(ResourceDatabase.machine_icon(mid), m.get("name", mid), int(m.get("price", 0)), stats)
	r.panel.tooltip_text = m.get("desc", "")
	var right: HBoxContainer = r.right
	if st.owned:
		r.price.text = "Built  •  Lv %d" % int(st.level)
		r.price.theme_type_variation = "LabelDim"
		var b := Kit.button("Built", "ButtonDark", Callable(), 70)
		b.disabled = true
		right.add_child(b)
		return
	if why != "":
		var lb := Kit.button("Locked", "ButtonDark", Callable(), 70)
		lb.disabled = true
		lb.icon = ResourceDatabase.ui_icon(14)
		lb.tooltip_text = why
		right.add_child(lb)
		r.price.text = Kit.fmt_price(int(m.price)) + "   " + why
		return
	var buy := Kit.button("Build", "ButtonGreen", func():
		var w := GameState.buy_machine(mid)
		if w != "":
			error(w)
		else:
			AudioManager.play("coin", -4.0)
			fx_purchase(ResourceDatabase.machine_icon(mid), "Built!", false)
			toast("%s built at the camp!" % m.name, "good")
			refresh(), 70, "buy")
	if GameState.coins < int(m.get("price", 0)):
		buy.disabled = true
		r.price.add_theme_color_override("font_color", Color("ff6a6a"))
	right.add_child(buy)

# ---------------------------------------------------------------- selling
func _sell_totals() -> Dictionary:
	var totals: Dictionary = {}
	for s in GameState.inventory:
		if not s.is_empty():
			totals[s.id] = int(totals.get(s.id, 0)) + int(s.n)
	return totals

func _build_sell() -> void:
	if not GameState.at_surface:
		_hint("You can only sell at the mining camp.")
		return
	var totals := _sell_totals()
	var ids: Array = []
	for id in ResourceDatabase.item_order:
		if int(totals.get(id, 0)) > 0 or GameState.storage_count(id) > 0:
			ids.append(id)
	if ids.is_empty():
		_list.add_child(Kit.label("Nothing to sell yet. Bring back resources from the mine!", "LabelDim"))
	for id in ids:
		var bp := int(totals.get(id, 0))
		var stg := GameState.storage_count(id)
		var v := GameState.sell_value(id)
		var stats := "each  •  Backpack %d%s" % [bp, ("  •  Storage %d" % stg) if stg > 0 else ""]
		var r := _row(ResourceDatabase.item_icon(id), ResourceDatabase.item_name(id), v, stats, ResourceDatabase.rarity_color(ResourceDatabase.item_rarity(id)) if ResourceDatabase.item_rarity(id) > 0 else null, bp + stg)
		var right: HBoxContainer = r.right
		right.add_child(Kit.button("Sell 1", "ButtonDark", func(): _sell(id, 1), 44, "sell"))
		right.add_child(Kit.button("Sell All", "ButtonGreen", func(): _sell_all_of(id), 58, "sell"))
	# helpers
	var rocks_v := _bulk_value(func(id): return ResourceDatabase.item_category(id) in ROCK_CATS)
	var nongem_v := _bulk_value(func(id): return not (ResourceDatabase.item_category(id) in KEEP_CATS))
	var b1 := Kit.button("Sell All Rocks ($%s)" % ResourceDatabase.fmt_num(rocks_v), "ButtonGreen", func(): _bulk(func(id): return ResourceDatabase.item_category(id) in ROCK_CATS, "all rocks and gravel"), 0, "sell")
	b1.disabled = rocks_v <= 0
	var b2 := Kit.button("Sell All Except Gems ($%s)" % ResourceDatabase.fmt_num(nongem_v), "ButtonGreen", func(): _bulk(func(id): return not (ResourceDatabase.item_category(id) in KEEP_CATS), "everything except gems, geodes, fossils, artifacts and tools"), 0, "sell")
	b2.disabled = nongem_v <= 0
	_footer.add_child(b1)
	_footer.add_child(b2)

func _sell(id: String, n: int) -> void:
	var v := GameState.sell_from_inventory(id, n)
	if v <= 0:
		v = GameState.sell_from_storage(id, n)
	if v > 0:
		AudioManager.play("coin", -3.0)
		toast("+$%s" % ResourceDatabase.fmt_num(v), "coin")
	refresh()

func _sell_all_of(id: String) -> void:
	var go := func():
		var v := GameState.sell_from_inventory(id, GameState.count_item(id))
		v += GameState.sell_from_storage(id, GameState.storage_count(id))
		if v > 0:
			AudioManager.play("coin", -2.0)
			toast("Sold all %s for $%s" % [ResourceDatabase.item_name(id), ResourceDatabase.fmt_num(v)], "coin")
		refresh()
	if ResourceDatabase.item_rarity(id) >= 3:
		confirm("Sell all %s?" % ResourceDatabase.item_name(id), "These are rare. Are you sure?", go, "Sell", false)
	else:
		go.call()

func _bulk_value(pred: Callable) -> int:
	var total := 0
	var totals := _sell_totals()
	for id in totals:
		if pred.call(id):
			total += int(totals[id]) * GameState.sell_value(id)
	for id in GameState.storage:
		if pred.call(id):
			total += int(GameState.storage[id]) * GameState.sell_value(id)
	return total

func _bulk(pred: Callable, what: String) -> void:
	var value := _bulk_value(pred)
	confirm("Sell %s?" % what.capitalize().left(28), "Sell %s from your backpack and storage for $%s?" % [what, ResourceDatabase.fmt_num(value)], func():
		var got := 0
		var totals := _sell_totals()
		for id in totals:
			if pred.call(id):
				got += GameState.sell_from_inventory(id, int(totals[id]))
		for id in GameState.storage.keys():
			if pred.call(id):
				got += GameState.sell_from_storage(id, GameState.storage_count(id))
		if got > 0:
			AudioManager.play("sell")
			toast("Sold for $%s" % ResourceDatabase.fmt_num(got), "coin")
		refresh(), "Sell", false)
