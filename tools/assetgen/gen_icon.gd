extends SceneTree
## Builds res://icon.png (256x256) for the DeepMine project/app icon from existing sprites.
const PX = preload("res://px.gd")
func _init() -> void:
	var root := PX.out_root().get_base_dir()
	var c := PX.Canvas.new(256, 256)
	# rounded navy tile with steel bevel
	for y in 256:
		for x in 256:
			var dx := maxf(absf(x - 127.5) - 104.0, 0.0)
			var dy := maxf(absf(y - 127.5) - 104.0, 0.0)
			var d := sqrt(dx * dx + dy * dy)
			if d <= 22.0:
				var t := float(y) / 255.0
				var col := PX.hex("1e2650").lerp(PX.hex("0b1026"), t)
				if d > 16.0: col = PX.hex("8a93a8") if y < 128 else PX.hex("3c4458")
				elif d > 12.0: col = PX.hex("2a3466")
				c.px(x, y, col)
	# glow behind
	for y in 256:
		for x in 256:
			var r := Vector2(x - 128, y - 120).length()
			if r < 92.0 and c.get_px(x, y).a > 0.0:
				c.blend(x, y, Color(0.37, 0.95, 1.0, 0.28 * (1.0 - r / 92.0)))
	var items := Image.load_from_file(PX.out_root().path_join("sprites/items/items.png"))
	var tools := Image.load_from_file(PX.out_root().path_join("sprites/player/tools.png"))
	# amethyst crystal (items icon 13) scaled x6, pickaxe (tools cell 4, crystal) scaled x6
	var equip := Image.load_from_file(PX.out_root().path_join("sprites/items/equipment.png"))
	var pick := equip.get_region(Rect2i(4 * 16, 0, 16, 16))
	pick.resize(144, 144, Image.INTERPOLATE_NEAREST)
	c.blit(pick, 34, 30)
	var gem := items.get_region(Rect2i((20 % 16) * 16, (20 / 16) * 16, 16, 16))
	gem.resize(96, 96, Image.INTERPOLATE_NEAREST)
	c.blit(gem, 132, 122)
	var err := c.img.save_png(root.path_join("icon.png"))
	print("icon saved err=", err)
	quit()
