extends Control
## Loading screen (matches the loading-screen reference): mine-entrance art, title, "Loading... 78%"
## above a rounded blue bar, tagline and rotating tips. Drives res://scripts/main/game_loader.gd:
##   start(mode), poll() -> float 0..1, is_done(), error_text(), game_scene() -> PackedScene
## Set `LoadingScreen.next_mode` (static, via preload of this script) before changing to this scene.

static var next_mode := "new"

const LOADER_PATH := "res://scripts/main/game_loader.gd"
const TIPS := [
	"Stronger pickaxes can break tougher rocks.",
	"Remember to check your backpack capacity.",
	"Rare geodes may contain valuable gems.",
	"Explore side tunnels for hidden treasures.",
	"Skill points can unlock powerful abilities.",
	"Smelt raw ore into bars to sell it for much more.",
	"Elevator checkpoints save you the long climb back up.",
	"Place ladders with Right Mouse so you never get stuck.",
	"Cracked walls often hide secret caches.",
	"Thermal Boots let you walk on Magma Crust safely.",
	"Events like Crystal Surge make rare ore appear for a while.",
	"Polished gems sell for more than twice the raw price.",
	"Open geodes at the surface to reveal what's inside.",
	"Cave Sense highlights ore through the darkness.",
	"Mine carts are the fastest way through long tunnels.",
]
# Track curve (640x360 art space) the cart rolls along; it advances as loading progresses.
const P0 := Vector2(320, 303)
const P1 := Vector2(340, 322)
const P2 := Vector2(450, 345)
const P3 := Vector2(650, 356)

@onready var stage: Control = %Stage
@onready var cart: Sprite2D = %Cart
@onready var logo: TextureRect = %Logo
@onready var bar: ProgressBar = %Bar
@onready var percent_label: Label = %PercentLabel
@onready var tip_label: Label = %TipLabel
@onready var error_box: Control = %ErrorBox
@onready var error_label: Label = %ErrorLabel
@onready var back_button: Button = %BackButton
@onready var fade: ColorRect = %Fade
@onready var glows: Node2D = %Glows

var loader = null
var shown := 0.0
var time := 0.0
var tip_i := 0
var tip_t := 0.0
var finishing := false
var failed := false
var stub_t := 0.0

func _ready() -> void:
	_apply_theme()
	get_tree().paused = false
	resized.connect(_fit_stage)
	_fit_stage()
	back_button.pressed.connect(_back_to_menu)
	error_box.visible = false
	tip_i = randi() % TIPS.size()
	tip_label.text = "Tip: " + TIPS[tip_i]
	cart.texture = _cart_frame(0)
	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, 0.35)
	if ResourceLoader.exists(LOADER_PATH):
		loader = load(LOADER_PATH)
		loader.start(next_mode)
	_update_cart(0.0)

func _apply_theme() -> void:
	if theme == null and ResourceLoader.exists("res://scripts/ui/ui_theme.gd"):
		theme = load("res://scripts/ui/ui_theme.gd").get_theme()

func _fit_stage() -> void:
	var s := maxf(size.x / 640.0, size.y / 360.0)
	stage.scale = Vector2(s, s)
	stage.position = (size - Vector2(640, 360) * s) * 0.5

func _cart_frame(i: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = ResourceDatabase.tex("res://assets/backgrounds/menu_cart.png")
	at.region = Rect2(64 * i, 0, 64, 48)
	return at

static func bezier(t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * u * P0 + 3.0 * u * u * t * P1 + 3.0 * u * t * t * P2 + t * t * t * P3

func _update_cart(t: float) -> void:
	var p := bezier(t)
	var d := bezier(minf(t + 0.01, 1.0)) - bezier(maxf(t - 0.01, 0.0))
	cart.position = p.round()
	cart.rotation = atan2(d.y, d.x) * 0.6
	var s := lerpf(0.45, 1.05, smoothstep(0.0, 0.75, t))
	cart.scale = Vector2(s, s)

func _process(delta: float) -> void:
	time += delta
	logo.position.y = 6.0 + round(sin(time * 1.6) * 2.0)
	for g in glows.get_children():
		g.modulate.a = 0.55 + 0.25 * sin(time * 7.0 + g.position.x) + 0.1 * sin(time * 13.0 + g.position.y)
	# tips
	tip_t += delta
	if tip_t > 3.6:
		tip_t = 0.0
		tip_i = (tip_i + 1) % TIPS.size()
		var tw := create_tween()
		tw.tween_property(tip_label, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func(): tip_label.text = "Tip: " + TIPS[tip_i])
		tw.tween_property(tip_label, "modulate:a", 1.0, 0.25)
	if failed:
		return
	var target := 0.0
	var done := false
	if loader:
		target = clampf(float(loader.poll()), 0.0, 1.0)
		done = bool(loader.is_done())
		var err := String(loader.error_text())
		if err != "":
			_fail(err)
			return
	else:
		stub_t += delta
		target = clampf(stub_t / 2.5, 0.0, 1.0)
		done = target >= 1.0
	if done:
		target = 1.0
	shown = minf(move_toward(shown, target, delta * (0.9 if not done else 2.2)), target)
	bar.value = shown * 100.0
	percent_label.text = "Loading... %d%%" % int(floor(shown * 100.0))
	_update_cart(shown * 0.9)
	cart.texture = _cart_frame(int(time * 8.0) % 2) if shown < target or done else cart.texture
	if done and shown >= 0.999 and not finishing:
		finishing = true
		_finish()

func _finish() -> void:
	var scene: PackedScene = loader.game_scene() if loader else null
	if scene == null:
		_fail("The game scene isn't available yet (GameLoader not found).")
		return
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.35)
	await tw.finished
	get_tree().change_scene_to_packed(scene)

func _fail(msg: String) -> void:
	failed = true
	error_box.visible = true
	error_label.text = msg
	percent_label.text = "Loading failed"
	AudioManager.play("ui_error")

func _back_to_menu() -> void:
	AudioManager.play("ui_click")
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

func _capture_setup(args: Array) -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	# Freeze at a given progress for screenshots, e.g. capture arg "0.78"
	if args.size() > 0:
		failed = true
		shown = float(args[0])
		bar.value = shown * 100.0
		percent_label.text = "Loading... %d%%" % int(floor(shown * 100.0))
		_update_cart(shown * 0.9)
		fade.color.a = 0.0
