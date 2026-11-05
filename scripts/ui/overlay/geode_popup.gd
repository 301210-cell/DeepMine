extends Control
## Geode reveal popup: the geode shakes and cracks open (geode_open.png), then each reward pops in
## with a rarity glow. Rewards were already added to the backpack by GameState.open_geode.

signal closed

const Kit = preload("res://scripts/ui/ui_kit.gd")
const ItemSlot = preload("res://scripts/ui/components/item_slot.gd")
const ANIM := "res://assets/sprites/effects/geode_open.png"

var _dim: ColorRect
var _box: PanelContainer
var _title: Label
var _anim: TextureRect
var _items: HBoxContainer
var _coins: Label
var _ok: Button
var _frames: Array[Texture2D] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.03, 0.08, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_box = Kit.panel("PanelPurple")
	_box.custom_minimum_size = Vector2(270, 180)
	add_child(_box)
	var v := Kit.vbox(4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(v)
	_title = Kit.label("Geode Opened!", "LabelTitle")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_anim = Kit.icon(null)
	_anim.custom_minimum_size = Vector2(96, 96)
	_anim.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_anim)
	_items = Kit.hbox(6)
	_items.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_items)
	_coins = Kit.label("", "LabelGold")
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_coins)
	var row := Kit.hbox()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_ok = Kit.button("Awesome!", "ButtonGreen", _close, 90)
	row.add_child(_ok)
	v.add_child(row)
	if ResourceLoader.exists(ANIM):
		var base: Texture2D = load(ANIM)
		var n := int(base.get_width() / 48)
		for i in n:
			var at := AtlasTexture.new()
			at.atlas = base
			at.region = Rect2(i * 48, 0, 48, 48)
			_frames.append(at)

func is_open() -> bool:
	return visible

func show_rewards(geode_id: String, rewards: Array, coins: int) -> void:
	visible = true
	Kit.clear(_items)
	_coins.text = ""
	_ok.disabled = true
	_title.text = ResourceDatabase.item_name(geode_id) + " Opened!"
	await get_tree().process_frame
	_box.position = (size - _box.size) / 2.0
	_box.pivot_offset = _box.size / 2.0
	_box.scale = Vector2(0.8, 0.8)
	var tw := create_tween()
	tw.tween_property(_box, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play("geode_crack")
	# crack animation
	_anim.pivot_offset = Vector2(48, 48)
	if _frames.size() > 0:
		for i in _frames.size():
			_anim.texture = _frames[i]
			_anim.rotation = (0.08 if i % 2 == 0 else -0.08) if i < _frames.size() - 2 else 0.0
			await get_tree().create_timer(0.12).timeout
	else:
		_anim.texture = ResourceDatabase.item_icon(geode_id)
		for i in 6:
			_anim.rotation = 0.12 if i % 2 == 0 else -0.12
			await get_tree().create_timer(0.08).timeout
		_anim.rotation = 0.0
	_anim.rotation = 0.0
	var best := 0
	for pair in rewards:
		best = maxi(best, ResourceDatabase.item_rarity(pair[0]))
	AudioManager.play("legendary" if best >= 4 else ("rare_discovery" if best >= 2 else "geode_reveal"))
	for pair in rewards:
		var col := Kit.vbox(1)
		var s = ItemSlot.new(26)
		s.toggle_mode = false
		s.set_item(pair[0], int(pair[1]))
		s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(s)
		var nl := Kit.label(ResourceDatabase.item_name(pair[0]), "LabelSmall", ResourceDatabase.rarity_color(ResourceDatabase.item_rarity(pair[0])))
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(nl)
		_items.add_child(col)
		col.modulate.a = 0.0
		await get_tree().process_frame
		col.pivot_offset = col.size / 2.0
		col.scale = Vector2(0.4, 0.4)
		var t2 := create_tween().set_parallel(true)
		t2.tween_property(col, "modulate:a", 1.0, 0.15)
		t2.tween_property(col, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		AudioManager.play("pickup_rare" if ResourceDatabase.item_rarity(pair[0]) >= 2 else "pickup", -2.0)
		await get_tree().create_timer(0.22).timeout
	if coins > 0:
		_coins.text = "+$%s" % ResourceDatabase.fmt_num(coins)
		AudioManager.play("coin")
	_ok.disabled = false

func _close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and not _ok.disabled and (event.is_action_pressed("pause") or event.is_action_pressed("interact")):
		_close()
		get_viewport().set_input_as_handled()
