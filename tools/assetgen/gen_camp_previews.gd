## Composite previews of camp row + machines (self-review only; writes to scratchpad).
extends SceneTree
const PX = preload("res://px.gd")
const K = preload("res://campkit.gd")

func ld(rel: String) -> Image:
	return Image.load_from_file(PX.out_root().path_join(rel))

func _init() -> void:
	var names := ["mara_tent", "shop", "skill_board", "storage", "M:smelter", "M:crusher", "machine_pad", "machine_pad", "mining_board", "museum", "elevator", "mine_entrance"]
	var W := 1000
	var c = PX.Canvas.new(W, 150, Color.html("3a5a9a"))
	# sky gradient
	for y in 150:
		for x in W:
			c.px(x, y, Color.html("2a3c7a").lerp(Color.html("e08a5a"), clampf((y - 30) / 110.0, 0.0, 1.0) * 0.6))
	# ground
	for y in range(130, 150):
		for x in W:
			c.px(x, y, K.GREEN[3] if y < 132 else K.WOOD[2 + (x + y) % 2])
	var x := 6
	for n in names:
		var img: Image
		var fw := 0
		if n.begins_with("M:"):
			img = ld("sprites/machines/%s.png" % n.substr(2))
			fw = 64
		else:
			img = ld("sprites/world/%s.png" % n)
			fw = img.get_width()
			if n == "skill_board": fw = 64
			if n == "elevator": fw = 48
		var h := img.get_height()
		c.blit(img, x, 130 - h, 0, 0, fw, h)
		x += fw + 6
	K.preview(c.img, "camp_row", 2, Color.BLACK)
	quit()
