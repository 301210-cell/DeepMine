extends "res://scripts/ui/panels/panel_base.gd"
## Elevator (data = {"current": station_index}): depth gauge coloured by biome on the left,
## station list on the right with lock state, "You are here" marker and Travel buttons.

var _current := 0
var _list: VBoxContainer
var _gauge: Control

class DepthGauge:
	extends Control
	var current := 0
	func _draw() -> void:
		var stations: Array = ResourceDatabase.stations
		var max_d := 3200.0
		var h := size.y - 8.0
		var x := size.x / 2.0
		for b in ResourceDatabase.biomes:
			var y0 := 4.0 + float(b.depth[0]) / max_d * h
			var y1 := 4.0 + float(b.depth[1]) / max_d * h
			draw_rect(Rect2(x - 3, y0, 6, y1 - y0), Color(b.color).darkened(0.25))
		draw_rect(Rect2(x - 3, 4, 6, h), Color("0b0d18"), false, 1.0)
		for i in stations.size():
			var y := 4.0 + float(stations[i].depth) / max_d * h
			var unlocked: bool = i < GameState.stations.size() and GameState.stations[i]
			var col := Color("ffc93c") if i == current else (Color("eef2ff") if unlocked else Color("5a6378"))
			draw_rect(Rect2(x - 6, y - 1, 12, 2), col)
		var cy := 4.0 + float(stations[clampi(current, 0, stations.size() - 1)].depth) / max_d * h
		draw_colored_polygon(PackedVector2Array([Vector2(x + 8, cy), Vector2(x + 13, cy - 4), Vector2(x + 13, cy + 4)]), Color("ffc93c"))

func build() -> void:
	win = Kit.window(self, "Elevator", Vector2(330, 296), request_close)
	var body := Kit.hbox(6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	win.body.add_child(body)
	_gauge = DepthGauge.new()
	_gauge.custom_minimum_size = Vector2(28, 240)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_gauge)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, 240)
	body.add_child(sc)
	_list = Kit.vbox(2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	Events.station_unlocked.connect(func(_i):
		if is_inside_tree():
			refresh())

func open(data: Variant = null) -> void:
	_current = 0
	if data is Dictionary:
		_current = int(data.get("current", 0))
	elif data is int:
		_current = data
	refresh()

func refresh() -> void:
	_gauge.current = _current
	_gauge.queue_redraw()
	Kit.clear(_list)
	var stations: Array = ResourceDatabase.stations
	for i in stations.size():
		var s: Dictionary = stations[i]
		var unlocked: bool = i < GameState.stations.size() and GameState.stations[i]
		var bi := ResourceDatabase.biome_for_depth(float(s.depth)) if int(s.depth) > 0 else -1
		var bd := ResourceDatabase.biome(bi)
		var p := Kit.panel("PanelPurple" if i == _current else "PanelDark")
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		var h := Kit.hbox(5)
		p.add_child(h)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(4, 18)
		dot.color = Color(bd.get("color", "9fe0a8")) if bi >= 0 else Color("9fe0a8")
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(dot)
		var dl := Kit.label("%dm" % int(s.depth), "LabelGold" if unlocked else "LabelDim")
		dl.custom_minimum_size.x = 40
		h.add_child(dl)
		var v := Kit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(Kit.label(s.name if unlocked else "???", "" if unlocked else "LabelDim"))
		v.add_child(Kit.label(bd.get("name", "Surface") if bi >= 0 else "Surface", "LabelDim"))
		h.add_child(v)
		if i == _current:
			var here := Kit.label("You are here", "LabelGold")
			h.add_child(here)
		elif unlocked:
			var idx := i
			h.add_child(Kit.button("Travel", "", func(): _travel(idx), 56))
		else:
			h.add_child(Kit.ui_icon(14))
			h.add_child(Kit.label("Reach %dm" % int(s.depth), "LabelDim"))
		_list.add_child(p)

func _travel(i: int) -> void:
	AudioManager.play("elevator_ding", -2.0)
	request_close()
	Events.elevator_travel_requested.emit(i)
