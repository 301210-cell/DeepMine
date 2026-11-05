extends Button
## Inventory-style slot: slot frame, centred 16x16 icon, rarity border, stack count.
##   const ItemSlot = preload("res://scripts/ui/components/item_slot.gd")
##   var s := ItemSlot.new(); s.set_item("copper_ore", 12)

const SLOT := 24

var item_id: String = ""
var count: int = 0
var index: int = -1
var _icon: TextureRect
var _rarity: NinePatchRect
var _count: Label
var _num: Label

func _init(size_px: int = SLOT) -> void:
	theme_type_variation = "SlotButton"
	custom_minimum_size = Vector2(size_px, size_px)
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	_rarity = NinePatchRect.new()
	_rarity.texture = ResourceDatabase.tex("res://assets/ui/slot_rarity.png")
	_rarity.patch_margin_left = 6
	_rarity.patch_margin_top = 6
	_rarity.patch_margin_right = 6
	_rarity.patch_margin_bottom = 6
	_rarity.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rarity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rarity.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rarity.visible = false
	add_child(_rarity)
	_icon = TextureRect.new()
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_count = Label.new()
	_count.set_anchors_preset(Control.PRESET_FULL_RECT)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count.offset_right = -2
	_count.offset_bottom = 1
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count)
	mouse_entered.connect(func():
		if item_id != "":
			AudioManager.play("ui_hover", -14.0, 0.05, 0.05))

func set_number(n: int) -> void:
	## Small hotbar number in the top-left corner.
	if _num == null:
		_num = Label.new()
		_num.theme_type_variation = "LabelDim"
		_num.position = Vector2(2, -1)
		_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_num)
	_num.text = str(n)

func set_item(id: String, n: int = 1, show_rarity: bool = true) -> void:
	item_id = id
	count = n
	if id == "" or not ResourceDatabase.has_item(id):
		item_id = ""
		_icon.texture = null
		_count.text = ""
		_rarity.visible = false
		tooltip_text = ""
		return
	_icon.texture = ResourceDatabase.item_icon(id)
	_icon.modulate = Color.WHITE
	_count.text = str(n) if n > 1 else ""
	var r := ResourceDatabase.item_rarity(id)
	_rarity.visible = show_rarity and r > 0
	_rarity.modulate = ResourceDatabase.rarity_color(r)
	tooltip_text = "%s\n%s  •  %s each" % [ResourceDatabase.item_name(id), ResourceDatabase.rarity_name(r), "$" + ResourceDatabase.fmt_num(GameState.sell_value(id))]

func set_texture(tex: Texture2D, n: int = 0, tint: Color = Color.WHITE, tip: String = "") -> void:
	item_id = ""
	count = n
	_icon.texture = tex
	_icon.modulate = tint
	_count.text = str(n) if n > 0 else ""
	_rarity.visible = false
	tooltip_text = tip

func set_count_text(t: String) -> void:
	_count.text = t

func set_dim(d: bool) -> void:
	_icon.modulate = Color(1, 1, 1, 0.35) if d else Color.WHITE

## Draw the icon scaled (e.g. 2 for the 32x32 detail view) and centred in the slot.
func set_icon_scale(s: int) -> void:
	var inset := (custom_minimum_size.x - 16.0 * s) / 2.0
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.offset_left = inset
	_icon.offset_top = inset
	_icon.offset_right = -inset
	_icon.offset_bottom = -inset
