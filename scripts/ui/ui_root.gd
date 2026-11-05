extends CanvasLayer
## UIRoot: owns the HUD, the single open panel, and all overlays (toasts, dialogue, event banner,
## geode popup, confirm dialog, interaction prompt, screen fade). See ARCHITECTURE.md §4.
## Find it from anywhere with: get_tree().get_first_node_in_group("ui_root")

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Kit = preload("res://scripts/ui/ui_kit.gd")

const PANELS := {
	"inventory": "res://scenes/ui/panels/InventoryPanel.tscn",
	"storage": "res://scenes/ui/panels/StoragePanel.tscn",
	"shop": "res://scenes/ui/panels/ShopPanel.tscn",
	"skills": "res://scenes/ui/SkillTreePanel.tscn",
	"machine": "res://scenes/ui/panels/MachinePanel.tscn",
	"elevator": "res://scenes/ui/panels/ElevatorPanel.tscn",
	"map": "res://scenes/ui/panels/MapPanel.tscn",
	"journal": "res://scenes/ui/panels/JournalPanel.tscn",
	"pause": "res://scenes/ui/panels/PauseMenu.tscn",
	"settings": "res://scenes/ui/panels/SettingsPanel.tscn",
}
const PAUSING := ["pause", "settings"]

## Set false (e.g. in menus or cutscenes) to ignore the panel hotkeys.
var hotkeys_enabled := true

@onready var root: Control = $Root
@onready var hud: Control = $Root/HUD
@onready var dim: ColorRect = $Root/Dim
@onready var host: Control = $Root/PanelHost
@onready var overlay: Control = $Root/Overlay
@onready var toasts: VBoxContainer = $Root/Overlay/Toasts
@onready var banner: Control = $Root/Overlay/EventBanner
@onready var dialogue: Control = $Root/Overlay/Dialogue
@onready var geode: Control = $Root/Overlay/GeodePopup
@onready var confirm: Control = $Root/Overlay/Confirm
@onready var fade_rect: ColorRect = $Root/Overlay/Fade

var _panel: Control = null
var _panel_name := ""
var _instances: Dictionary = {}
var _return_to := ""
var _prompt: PanelContainer
var _prompt_key: Control
var _prompt_label: Label
var _fade_tw: Tween

func _ready() -> void:
	add_to_group("ui_root")
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.theme = UiTheme.get_theme()
	hud.ui = self
	# Toasts under the top-right HUD buttons
	toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 5)
	toasts.offset_top = 42
	toasts.custom_minimum_size.x = 120
	_build_prompt()
	Events.open_panel_requested.connect(func(p: String, d: Variant): open_panel(p, d))
	Events.mara_dialog.connect(func(lines: Array, title: String): show_dialog(lines, title))
	Events.geode_opened.connect(_on_geode_opened)
	geode.closed.connect(_update_blocking)
	confirm.closed.connect(_update_blocking)

func _build_prompt() -> void:
	_prompt = Kit.panel("PanelDark")
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := Kit.hbox(4)
	_prompt.add_child(h)
	_prompt_key = Kit.keycap("E")
	_prompt_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_prompt_key)
	_prompt_label = Kit.label("")
	h.add_child(_prompt_label)
	_prompt.visible = false
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	overlay.add_child(_prompt)
	overlay.move_child(_prompt, 0)

# ================================================================ panels
func open_panel(name: String, data: Variant = null) -> void:
	if dialogue.is_open():
		return
	if name == _panel_name and _panel:
		if _panel.has_method("open"):
			_panel.open(data)
		return
	var path: String = PANELS.get(name, "")
	if path == "" or not ResourceLoader.exists(path):
		Events.notify.emit("That screen isn't available yet.", "warn")
		return
	if _panel:
		if name == "settings" and _panel_name == "pause":
			_return_to = "pause"
		_detach_current()
	var p: Control = _instances.get(name)
	if p == null or not is_instance_valid(p):
		var packed: PackedScene = load(path)
		if packed == null:
			return
		p = packed.instantiate()
		_instances[name] = p
		if "ui" in p:
			p.set("ui", self)
		if p.has_signal("close_requested"):
			p.connect("close_requested", close_panel)
	host.add_child(p)
	_panel = p
	_panel_name = name
	if p.has_method("open"):
		p.call("open", data)
	dim.visible = true
	get_tree().paused = name in PAUSING
	hide_prompt()
	_update_blocking()
	AudioManager.play("ui_open", -3.0)
	Events.panel_opened.emit(name)
	# open animation
	p.modulate.a = 0.0
	var start_y := p.position.y
	p.position.y = start_y + 8
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "modulate:a", 1.0, 0.12)
	tw.tween_property(p, "position:y", start_y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _detach_current() -> void:
	if _panel == null:
		return
	var p := _panel
	var n := _panel_name
	_panel = null
	_panel_name = ""
	p.position.y = 0
	if p.get_parent():
		p.get_parent().remove_child(p)
	if p.has_method("on_closed"):
		p.call("on_closed")
	Events.panel_closed.emit(n)

func close_panel() -> void:
	if _panel == null:
		return
	_detach_current()
	if _return_to != "":
		var r := _return_to
		_return_to = ""
		open_panel(r)
		return
	dim.visible = false
	get_tree().paused = false
	_update_blocking()
	AudioManager.play("ui_close", -3.0)

func toggle_panel(name: String) -> void:
	if _panel_name == name:
		close_panel()
	else:
		open_panel(name)

func is_open() -> bool:
	return _panel != null

func current_panel() -> String:
	return _panel_name

func get_panel(name: String) -> Control:
	return _instances.get(name)

func _update_blocking() -> void:
	GameState.ui_blocking = _panel != null or dialogue.is_open() or confirm.is_open() or geode.is_open()

func is_mouse_over_ui() -> bool:
	var c := root.get_viewport().gui_get_hovered_control()
	return c != null

func skills_allowed() -> bool:
	var t: Dictionary = GameState.tutorial
	if t.get("done", false) or t.get("skipped", false):
		return true
	var steps: Array = ResourceDatabase.quests.get("tutorial", [])
	for i in steps.size():
		if steps[i].id == "t_board":
			return int(t.get("step", 0)) >= i
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not hotkeys_enabled or event.is_echo():
		return
	if dialogue.is_open() or confirm.is_open() or geode.is_open():
		return
	if event.is_action_pressed("pause"):
		if _panel:
			close_panel()
		else:
			open_panel("pause")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		_hotkey("inventory")
	elif event.is_action_pressed("skill_tree"):
		if skills_allowed():
			_hotkey("skills")
		else:
			Events.notify.emit("Mara will show you the Skill Tree soon!", "info")
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map"):
		_hotkey("map")
	elif event.is_action_pressed("journal"):
		_hotkey("journal")

func _hotkey(name: String) -> void:
	if _panel_name in PAUSING:
		return
	toggle_panel(name)
	get_viewport().set_input_as_handled()

# ================================================================ prompt / fade
func show_prompt(text: String, key: String = "") -> void:
	if _panel:
		return
	var k := key if key != "" else SaveManager.binding_text("interact")
	var l: Label = _prompt_key.get_child(0)
	l.text = k
	_prompt_key.custom_minimum_size.x = maxf(16.0, 8.0 + k.length() * 5.0)
	_prompt_label.text = text
	if not _prompt.visible:
		_prompt.visible = true
		_prompt.modulate.a = 0.0
		var tw := _prompt.create_tween()
		tw.tween_property(_prompt, "modulate:a", 1.0, 0.12)
	_prompt.reset_size()
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 5)
	_prompt.offset_top -= 34
	_prompt.offset_bottom -= 34

func hide_prompt() -> void:
	_prompt.visible = false

func fade_out(t: float = 0.35) -> void:
	if _fade_tw and _fade_tw.is_valid():
		_fade_tw.kill()
	fade_rect.visible = true
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_tw = create_tween()
	_fade_tw.tween_property(fade_rect, "color:a", 1.0, t)
	await _fade_tw.finished

func fade_in(t: float = 0.35) -> void:
	if _fade_tw and _fade_tw.is_valid():
		_fade_tw.kill()
	_fade_tw = create_tween()
	_fade_tw.tween_property(fade_rect, "color:a", 0.0, t)
	await _fade_tw.finished
	fade_rect.visible = false
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

# ================================================================ overlays
func show_confirm(title: String, text: String, on_yes: Callable, yes_text: String = "Confirm", danger: bool = true) -> void:
	confirm.ask(title, text, on_yes, yes_text, danger)
	_update_blocking()

## Awaitable. Emits Events.dialog_finished when the player has read every line.
func show_dialog(lines: Array, title: String = "Mara") -> void:
	while dialogue.is_open():
		await dialogue.finished
	hide_prompt()
	dialogue.start(lines, title)
	_update_blocking()
	await dialogue.finished
	_update_blocking()
	Events.dialog_finished.emit()

func set_tutorial_objective(title: String, text: String, progress: String = "") -> void:
	hud.set_objective_override(title, text, progress)

func notify(text: String, kind: String = "info") -> void:
	toasts.push(text, kind)

func _on_geode_opened(geode_id: String, rewards: Array, coins: int) -> void:
	geode.show_rewards(geode_id, rewards, coins)
	_update_blocking()

# ================================================================ capture/demo
func _capture_setup(args: Array) -> void:
	var what: String = args[0] if args.size() > 0 else "hud"
	if not is_node_ready():
		await ready
	hotkeys_enabled = false
	await get_tree().process_frame
	GameState.new_game(42)
	GameState.coins = 12450
	GameState.level = 5
	GameState.xp = 120
	GameState.skill_points = 3
	GameState.current_depth = 120
	GameState.current_biome = 0
	GameState.at_surface = what != "hud"
	GameState.day_time = 10.4 / 24.0
	GameState.hp = 100.0
	for pair in [["stone", 24], ["copper_ore", 12], ["coal", 9], ["quartz", 3], ["amethyst", 2], ["geode_small", 2], ["iron_ore", 6], ["health_potion", 3], ["dynamite", 3], ["sapphire", 1], ["fossil_fern", 1], ["gold_bar", 2]]:
		GameState.add_item(pair[0], pair[1], false)
	GameState.storage = {"stone": 220, "coal": 40, "copper_bar": 12, "iron_ore": 30, "emerald": 2}
	GameState.machine_state("smelter").queue = [{"r": 0, "n": 3}]
	GameState.machine_state("smelter").progress = 1.6
	GameState.machine_state("smelter").output = {"copper_bar": 2}
	GameState.quest_state["hud"] = {"title": "Mine 50 Stone", "text": "Mine 50 Stone", "progress": "12 / 50"}
	GameState.event_state = {"id": "crystal_surge", "time_left": 300.0, "progress": 2, "count": 8, "quest_text": "Mine 8 crystal or gem deposits"}
	for i in 7:
		GameState.stations[i] = true
	# Cave backdrop so the HUD reads like in game
	var bgp := "res://assets/backgrounds/cave_crystal_far.png"
	var bg := TextureRect.new()
	bg.texture = ResourceDatabase.tex(bgp)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(bg)
	root.move_child(bg, 0)
	hud.refresh_all()
	await get_tree().process_frame
	match what:
		"hud":
			Events.item_collected.emit("stone", 12)
			Events.xp_gained.emit(5)
			Events.notify.emit("New discovery: Quartz!", "rare")
			Events.notify.emit("Elevator checkpoint unlocked: Old Workings (150m)", "good")
			Events.world_event_started.emit("crystal_surge")
		"dialog":
			show_dialog(["Great! You found some ore. Mine it with your pickaxe and collect the resources!"], "Tutorial")
		"event":
			Events.world_event_started.emit("crystal_surge")
		"geode":
			GameState.open_geode("geode_small")
		"confirm":
			show_confirm("Drop Items?", "Drop 24 Stone on the ground? You can pick it back up.", func(): pass, "Drop")
		"machine":
			open_panel("machine", "smelter")
		"elevator":
			open_panel("elevator", {"current": 1})
		_:
			open_panel(what)
